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
    
    func correctPoint(point: simd_float4) -> CGPoint {
        if (CalibrationData.data.isCalibrated) {
            let calibrationResult = CalibrationData.data.result
            let calibrationPoints = CalibrationData.data.calibrationPoints
            
            let calibrationGazeWidth = (abs(calibrationResult[1]!.x - calibrationResult[0]!.x) + abs(calibrationResult[3]!.x - calibrationResult[2]!.x)) / 2
            let calibrationGazeHeight = (abs(calibrationResult[2]!.y - calibrationResult[0]!.y) + abs(calibrationResult[3]!.y - calibrationResult[1]!.y)) / 2

            let calibrationWidth = abs(calibrationPoints[1].x - calibrationPoints[0].x)
            let calibrationHeight = abs(calibrationPoints[0].y - calibrationPoints[2].y)

            let calibrationScaleWidth = calibrationWidth / calibrationGazeWidth
            let calibrationScaleHeight = calibrationHeight / calibrationGazeHeight

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
        if (CalibrationData.data.isCalibrated) {
            // more smoothing => more lag
            let threshold = 30
            
            self.intersections.append(point)
            if (self.intersections.count >= threshold) {
                self.intersections = self.intersections.suffix(threshold)
            }
            
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
        return point
    }
    
    func intersection(withFaceAnchor anchor: ARFaceAnchor, frame: ARFrame, worldTransformMatrix: simd_float4x4) -> simd_float4 {
        let cameraTransformMatrix = frame.camera.viewMatrix(for: .portrait)
        
        let localEyePosition = simd_float4(0, 0, 0, 1) // local space for eye
        let localEyeDirection = simd_float4(0, 0, 1, 0) // direction vector for eye
        
        let worldToCameraMatrix = cameraTransformMatrix * worldTransformMatrix
        
        let cameraEyePosition = worldToCameraMatrix * localEyePosition // eye center in camera coords
        let cameraEyeDirection = worldToCameraMatrix * localEyeDirection // direction vector in camera coords
        
        let t = (0.0 - cameraEyePosition.z) / cameraEyeDirection.z // since all coords except z is 0 we only focus on z
        return cameraEyePosition + t * cameraEyeDirection // intersection between ray-plane in NDC. value between 0 and 1
    }
    
    func gazePoints(withFaceAnchor anchor: ARFaceAnchor, frame: ARFrame) -> [String : Any] {
        var intersections = [
            "leftEye": intersection(withFaceAnchor: anchor, frame: frame, worldTransformMatrix: anchor.transform*anchor.leftEyeTransform),
            "rightEye": intersection(withFaceAnchor: anchor, frame: frame, worldTransformMatrix: anchor.transform*anchor.rightEyeTransform),
            "head": intersection(withFaceAnchor: anchor, frame: frame, worldTransformMatrix: anchor.transform)
        ]
        
        // timestamp for gaze point
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "H:m:ss.SSSS"
        let timestamp = formatter.string(from: Date())
        
        // movement of head
        let headMovement = self.previousHeadIntersection - intersections["head"]!
        self.previousHeadIntersection = intersections["head"]!
        
        for eye in Array(intersections.keys) {
            intersections[eye]! -= headMovement
            
            // translate to center of screen, convert to screen coords
            intersections[eye]!.x = (intersections[eye]!.x + 0.5) * self.phonePointsWidth
            intersections[eye]!.y = (1 - (intersections[eye]!.y + 0.5)) * self.phonePointsHeight
        }
        
        // smooth average point of both eyes if calibrated
        var averageIntersection = simd_float4()
        averageIntersection = ((intersections["leftEye"]! + intersections["rightEye"]!) / 2)
        
        let smoothedPoint = self.smoothing(point: averageIntersection)

        // correct point after calibration
        var screenPOG = correctPoint(point: smoothedPoint)
        var leftEyePOG = correctPoint(point: intersections["leftEye"]!)
        var rightEyePOG = correctPoint(point: intersections["rightEye"]!)

        // return to NDC
        leftEyePOG.x /= CGFloat(self.phonePointsWidth)
        leftEyePOG.y /= CGFloat(self.phonePointsHeight)
        rightEyePOG.x /= CGFloat(self.phonePointsWidth)
        rightEyePOG.y /= CGFloat(self.phonePointsHeight)
        
        // round screen POG
        let decimalValue = CGFloat(100)
        screenPOG.x = round(decimalValue*screenPOG.x)/decimalValue
        screenPOG.y = round(decimalValue*screenPOG.y)/decimalValue

        return [
            "timestamp": timestamp,
            "left_eye": leftEyePOG,
            "right_eye": rightEyePOG,
            "POG": screenPOG
        ]
    }
}
