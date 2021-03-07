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
    var gazePoint = CGPoint(x: 0, y: 0)
    var previousHeadPointNDC = simd_float4()
    var phonePointsWidth = CGFloat(414)
    var phonePointsHeight = CGFloat(896)
    var intersections: [simd_float4] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // our first mapping function
    func correctPoint1(point: CGPoint) -> CGPoint {
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

            print("scale", calibrationScaleWidth, calibrationScaleHeight)

            var displacement_x = CGFloat(0)
            var displacement_y = CGFloat(0)
            for (index, _) in calibrationPoints.enumerated() {
                displacement_x += calibrationPoints[index].x - calibrationResult[index]!.x*calibrationScaleWidth
                displacement_y += calibrationPoints[index].y - calibrationResult[index]!.y*calibrationScaleHeight
            }

            displacement_x /= CGFloat(calibrationPoints.count)
            displacement_y /= CGFloat(calibrationPoints.count)
            
            print("displacement", displacement_x, displacement_y)

            let x = point.x * calibrationScaleWidth + displacement_x
            let y = point.y * calibrationScaleHeight + displacement_y
            
            return CGPoint(x: x, y: y)
        } else {
            return point
        }
    }
    
    // tried correction from report
    func correctPoint2(point: CGPoint) -> CGPoint {
        // both calibration points and result are in screen coords!
        if (CalibrationData.data.isCalibrated) {
            let calibrationResult = CalibrationData.data.result
            let calibrationPoints = CalibrationData.data.calibrationPoints
            var corrected = simd_float2()
            var w = Float()
            var d_sum = Float()
            
            for (index, _) in calibrationPoints.enumerated() {
                let diffx = point.x - calibrationResult[index]!.x
                let diffy = point.y - calibrationResult[index]!.y
                let d = sqrt(diffx*diffx + diffy*diffy)
                d_sum += Float(d)
            }
            
            for (index, _) in calibrationPoints.enumerated() {
                var e = simd_float2()
                
                e[0] = Float(calibrationPoints[index].x - calibrationResult[index]!.x)
                e[1] = Float(calibrationPoints[index].y - calibrationResult[index]!.y)
                
                let diffx = point.x - calibrationResult[index]!.x
                let diffy = point.y - calibrationResult[index]!.y
                let d = Float(sqrt(diffx*diffx + diffy*diffy))
                
                w = 1 / (d * 1/d_sum)
                corrected += w*e
            }
            let x = point.x + CGFloat(corrected.x)
            let y = point.y + CGFloat(corrected.y)
            
            return CGPoint(x: x, y: y)
        } else {
            return point
        }
    }
    
    func smoothing(point: simd_float4) -> CGPoint {
        // larger threshold => more smooth but more lag
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
        
        return CGPoint(x: CGFloat(avgX), y: CGFloat(avgY))
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
        var leftEyeIntersectionNDC = getIntersection(withFaceAnchor: anchor, frame: frame, worldTransformMatrix: anchor.transform*anchor.leftEyeTransform)
        var rightEyeIntersectionNDC = getIntersection(withFaceAnchor: anchor, frame: frame, worldTransformMatrix: anchor.transform*anchor.rightEyeTransform)
        let headIntersectionNDC = getIntersection(withFaceAnchor: anchor, frame: frame, worldTransformMatrix: anchor.transform)
        
        // remove movement from head
        let diffHead = previousHeadPointNDC - headIntersectionNDC
        leftEyeIntersectionNDC -= diffHead
        rightEyeIntersectionNDC -= diffHead
        previousHeadPointNDC = headIntersectionNDC

        let intersection = ((leftEyeIntersectionNDC + rightEyeIntersectionNDC) / 2)
        var smoothedPoint = smoothing(point: intersection)

        // scale
        smoothedPoint.x *= CGFloat(10)
        smoothedPoint.y *= CGFloat(5)
        
        // translate to center of screen, convert to screen coords
        smoothedPoint.x = (smoothedPoint.x + 0.5) * phonePointsWidth
        smoothedPoint.y = (1 - (smoothedPoint.y + 0.5)) * phonePointsHeight
        
        // TODO: Correct points for left and right eye separately in NDC
        var POG = correctPoint1(point: smoothedPoint)
        
        // round to 1 decimals
        POG.x = round(10*POG.x)/10
        POG.y = round(10*POG.y)/10
        
        print("before", smoothedPoint, "after", POG)

        return [
            "left_eye": simd_float2(Float(leftEyeIntersectionNDC.x), Float(leftEyeIntersectionNDC.y)),
            "right_eye": simd_float2(Float(rightEyeIntersectionNDC.x), Float(rightEyeIntersectionNDC.y)),
            "POG": POG
        ]
    }
}
