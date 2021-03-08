//
//  GazePointViewController.swift
//  eye-tracking
//
//  Created by moa on 2021-02-16.
//

import UIKit
import SceneKit
import ARKit

class GazePointViewController: UIViewController {
    var previousHeadIntersection = simd_float4()
    var intersections: [simd_float4] = []
    var phonePointsWidth = Float(UIScreen.main.bounds.width)
    var phonePointsHeight = Float(UIScreen.main.bounds.height)
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // our first mapping function
    func correctPoint(point: simd_float4) -> CGPoint {
        // both calibration points and result are in screen coords!
        if (CalibrationData.data.isCalibrated) {
            let calibrationResult = CalibrationData.data.result
            let calibrationPoints = CalibrationData.data.calibrationPoints
            
            let calibrationGazeWidth = abs((calibrationResult[1]!.x - calibrationResult[0]!.x) + (calibrationResult[3]!.x - calibrationResult[2]!.x)) / 2
            let calibrationGazeHeight = abs((calibrationResult[2]!.y - calibrationResult[0]!.y) + (calibrationResult[3]!.y - calibrationResult[1]!.y)) / 2

            let calibrationWidth = calibrationPoints[1].x - calibrationPoints[0].x
            let calibrationHeight = calibrationPoints[0].y - calibrationPoints[2].y

            let calibrationScaleWidth = calibrationWidth / calibrationGazeWidth //divide by  start value of scale? //x-wise factor that is multiplied later
            let calibrationScaleHeight = calibrationHeight / calibrationGazeHeight //divide by start value of scale  //y-wise factor that is multiplied later

            var displacement_x = CGFloat(0)
            var displacement_y = CGFloat(0)
            for (index, _) in calibrationPoints.enumerated() {
                displacement_x += calibrationPoints[index].x - calibrationResult[index]!.x*calibrationScaleWidth
                displacement_y += calibrationPoints[index].y - calibrationResult[index]!.y*calibrationScaleHeight
            }

            displacement_x /= CGFloat(calibrationPoints.count)
            displacement_y /= CGFloat(calibrationPoints.count)

            let x = CGFloat(point.x) * calibrationScaleWidth + displacement_x
            let y = CGFloat(point.y) * calibrationScaleHeight + displacement_y
            
            return CGPoint(x: x, y: y)
        } else {
            return CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))
        }
    }
    
    func smoothing(point: simd_float4) -> simd_float4 {
        // more smoothing => more lag
        let threshold = 40
        intersections.append(point)
        intersections = intersections.suffix(threshold)
        
        var sumX = Float(0);
        var sumY = Float(0);
        for i in intersections {
            sumX += i.x
            sumY += i.y
        }

        let avgX = sumX / Float(intersections.count)
        let avgY = sumY / Float(intersections.count)
        
        return simd_float4(Float(avgX), Float(avgY), point.z, point.w)
    }
    
    func getIntersection(withFaceAnchor anchor: ARFaceAnchor, frame: ARFrame, worldTransformMatrix: simd_float4x4) -> simd_float4 {
        let cameraTransformMatrix = frame.camera.viewMatrix(for: .portrait)
        
        let localEyePosition = simd_float4(0, 0, 0, 1) // local space for eye
        let localEyeDirection = simd_float4(0, 0, 1, 0) // direction vector for eye
        
        let worldToCameraMatrix = cameraTransformMatrix * worldTransformMatrix
        
        let cameraEyePosition = worldToCameraMatrix * localEyePosition // eye center in camera coords
        let cameraEyeDirection = worldToCameraMatrix * localEyeDirection // direction vector in camera coords
        
        let t = (0.0 - cameraEyePosition.z) / cameraEyeDirection.z // since all coords except z is 0 we only focus on z
        return cameraEyePosition + t * cameraEyeDirection // intersection between ray-plane in NDC. value between 0 and 1
    }
    
    func rayPlaneIntersection(withFaceAnchor anchor: ARFaceAnchor, frame: ARFrame) -> [String : Any] {
        var intersections = [
            "leftEye": getIntersection(withFaceAnchor: anchor, frame: frame, worldTransformMatrix: anchor.transform*anchor.leftEyeTransform),
            "rightEye": getIntersection(withFaceAnchor: anchor, frame: frame, worldTransformMatrix: anchor.transform*anchor.rightEyeTransform),
            "head": getIntersection(withFaceAnchor: anchor, frame: frame, worldTransformMatrix: anchor.transform)
        ]
        
        // extract movement of head
        let headMovement = previousHeadIntersection - intersections["head"]!
        previousHeadIntersection = intersections["head"]!
        
        let scaleX = Float(10)
        let scaleY = Float(5)
        for eye in Array(intersections.keys) {
            // remove movement of head
            intersections[eye]! -= headMovement
            
            // scale
            intersections[eye]!.x *= scaleX
            intersections[eye]!.y *= scaleY
            
            // translate to center of screen, convert to screen coords
            intersections[eye]!.x = (intersections[eye]!.x + 0.5) * phonePointsWidth
            intersections[eye]!.y = (1 - (intersections[eye]!.y + 0.5)) * phonePointsHeight
        }

        // smoth average point of both eyes
        let averageIntersection = ((intersections["leftEye"]! + intersections["rightEye"]!) / 2)
        let smoothedPoint = smoothing(point: averageIntersection)

        // correct point after calibration
        var screenPOG = correctPoint(point: smoothedPoint)
        var leftEyePOG = correctPoint(point: intersections["leftEye"]!)
        var rightEyePOG = correctPoint(point: intersections["rightEye"]!)

        // return to NDC
        leftEyePOG.x /= CGFloat(phonePointsWidth)
        leftEyePOG.y /= CGFloat(phonePointsHeight)
        rightEyePOG.x /= CGFloat(phonePointsWidth)
        rightEyePOG.y /= CGFloat(phonePointsHeight)
        
        // round screen POG to 1 decimals
        screenPOG.x = round(10*screenPOG.x)/10
        screenPOG.y = round(10*screenPOG.y)/10

        return [
            "left_eye": leftEyePOG,
            "right_eye": rightEyePOG,
            "POG": screenPOG
        ]
    }
}
