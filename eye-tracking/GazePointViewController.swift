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
    var previousHeadPoint = simd_float4()
    var calibrationScaleWidth = CGFloat(1)
    var calibrationScaleHeight = CGFloat(1)
    var displacement_x = CGFloat(0)
    var displacement_y = CGFloat(0)
    var phonePointsWidth = CGFloat(414)
    var phonePointsHeight = CGFloat(896)
    var leftEyeIntersections: [simd_float4] = []
    var rightEyeIntersections: [simd_float4] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func screenPoint(leftEyePoint: CGPoint, rightEyePoint: CGPoint) -> CGPoint {
        let decimalValue = CGFloat(10)
        var x = (leftEyePoint.x + rightEyePoint.x) / 2
        var y = (leftEyePoint.y + rightEyePoint.y) / 2
        
        x *= phonePointsWidth
        y *= phonePointsHeight
        
        x = round(decimalValue*x)/decimalValue
        y = round(decimalValue*y)/decimalValue
        
        return CGPoint(x: x, y: y)
    }
    
    func adjustMapping() {
        // both calibration points and result are in screen coords!
        
        let calibrationResult = CalibrationData.data.result
        let calibrationPoints = CalibrationData.data.calibrationPoints
        
        let calibrationGazeWidth = abs(((calibrationResult[1]!.x) - (calibrationResult[0]!.x) + (calibrationResult[3]!.x) - (calibrationResult[2]!.x)) / 2)
        let calibrationGazeHeight = abs(((calibrationResult[2]!.y) - (calibrationResult[0]!.y) + (calibrationResult[3]!.y) - (calibrationResult[1]!.y)) / 2)

        let calibrationWidth = CGFloat(calibrationPoints[1].x) - CGFloat(calibrationPoints[0].x)
        let calibrationHeight = CGFloat(calibrationPoints[0].y) - CGFloat(calibrationPoints[2].y)

        calibrationScaleWidth = calibrationWidth / calibrationGazeWidth //divide by  start value of scale? //x-wise factor that is multiplied later
        calibrationScaleHeight = calibrationHeight / calibrationGazeHeight //divide by start value of scale  //y-wise factor that is multiplied later
        
        for (index, _) in calibrationPoints.enumerated() {
            displacement_x += CGFloat(calibrationPoints[index].x - calibrationResult[index]!.x*calibrationScaleWidth)
            displacement_y += CGFloat(calibrationPoints[index].y - calibrationResult[index]!.y*calibrationScaleHeight)
        }

        displacement_x /= CGFloat(calibrationPoints.count)
        displacement_y /= CGFloat(calibrationPoints.count)
    }
    
    func smoothing(leftEyeIntersection: simd_float4, rightEyeIntersection: simd_float4) -> Dictionary<String, CGPoint> {
        let threshold = 50
        leftEyeIntersections.append(leftEyeIntersection)
        rightEyeIntersections.append(leftEyeIntersection)
        
        leftEyeIntersections = leftEyeIntersections.suffix(threshold)
        rightEyeIntersections = rightEyeIntersections.suffix(threshold)
        
        var sumXLeft = Float(0);
        var sumYLeft = Float(0);
        for v in leftEyeIntersections {
            sumXLeft += v.x
            sumYLeft += v.y
        }
        
        var sumXRight = Float(0);
        var sumYRight = Float(0);
        for v in rightEyeIntersections {
            sumXRight += v.x
            sumYRight += v.y
        }
        
        let avgLeftX = sumXLeft / Float(leftEyeIntersections.count)
        let avgLeftY = sumYLeft / Float(leftEyeIntersections.count)
        
        let avgRightX = sumXRight / Float(rightEyeIntersections.count)
        let avgRightY = sumYRight / Float(rightEyeIntersections.count)
        
        let leftEyePos = CGPoint(x: CGFloat(avgLeftX), y: CGFloat(avgLeftY))
        let rightEyePos = CGPoint(x: CGFloat(avgRightX), y: CGFloat(avgRightY))
        
        return ["left": leftEyePos, "right": rightEyePos]
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
    
    func rayPlaneIntersection(withFaceAnchor anchor: ARFaceAnchor, frame: ARFrame) -> [String : CGPoint] {
        var leftEyeIntersection = getIntersection(withFaceAnchor: anchor, frame: frame, worldTransformMatrix: anchor.transform*anchor.leftEyeTransform)
        var rightEyeIntersection = getIntersection(withFaceAnchor: anchor, frame: frame, worldTransformMatrix: anchor.transform*anchor.rightEyeTransform)
        let headIntersection = getIntersection(withFaceAnchor: anchor, frame: frame, worldTransformMatrix: anchor.transform)
        
        // check how much head moved since last point
        let diffHeadX = (previousHeadPoint.x - headIntersection.x)
        let diffHeadY = (previousHeadPoint.y - headIntersection.y)
        
        previousHeadPoint = headIntersection
        
        // remove movement from head
        leftEyeIntersection.x -= diffHeadX
        leftEyeIntersection.y -= diffHeadY
        
        rightEyeIntersection.x -= diffHeadX
        rightEyeIntersection.y -= diffHeadY
        
        // apply smoothing for both eyes
        let smoothedPoints = smoothing(leftEyeIntersection: leftEyeIntersection, rightEyeIntersection: rightEyeIntersection)
        var leftEyePoint = smoothedPoints["left"]!
        var rightEyePoint = smoothedPoints["right"]!
        
        if (CalibrationData.data.isCalibrated) {
            adjustMapping()
        }
 
        leftEyePoint.x = leftEyePoint.x * calibrationScaleWidth // + displacement_x
        leftEyePoint.y = leftEyePoint.y * calibrationScaleHeight // + displacement_y
        
        rightEyePoint.x = rightEyePoint.x * calibrationScaleWidth // + displacement_x
        rightEyePoint.y = rightEyePoint.y * calibrationScaleHeight // + displacement_y
        
        // translate to origo from top left to center of screen, y is negative along screen
        leftEyePoint.x = (leftEyePoint.x + 0.5)
        leftEyePoint.y = (1 - (leftEyePoint.y + 0.5))
        
        rightEyePoint.x = (rightEyePoint.x + 0.5)
        rightEyePoint.y = (1 - (rightEyePoint.y + 0.5))
 
        return [
            "left_eye": CGPoint(x: leftEyePoint.x, y: leftEyePoint.y),
            "right_eye": CGPoint(x: rightEyePoint.x, y: rightEyePoint.y),
            "POG": screenPoint(leftEyePoint: leftEyePoint, rightEyePoint: rightEyePoint)
        ]
    }

    ////  NOT USED
//    func rasterization(withFaceAnchor anchor: ARFaceAnchor) {
//        let distanceL = sqrt(leftEye.worldPosition.x*leftEye.worldPosition.x + leftEye.worldPosition.y*leftEye.worldPosition.y + leftEye.worldPosition.z*leftEye.worldPosition.z)
//        let distanceR = sqrt(rightEye.worldPosition.x*rightEye.worldPosition.x + rightEye.worldPosition.y*rightEye.worldPosition.y + rightEye.worldPosition.z*rightEye.worldPosition.z)
//
//        // local to world
//        let p_world_right = anchor.rightEyeTransform * simd_float4(rightEye.worldPosition.x, rightEye.worldPosition.y, rightEye.worldPosition.z, 1)
//        let p_world_left = anchor.leftEyeTransform * simd_float4(leftEye.worldPosition.x, leftEye.worldPosition.y, leftEye.worldPosition.z, 1)
//
//        // world to camera coordinates
//        let camera = sceneView.session.currentFrame?.camera
//        let p_camera_right = camera!.viewMatrix(for: .portrait) * p_world_right
//        let p_camera_left = camera!.viewMatrix(for: .portrait) * p_world_left
//
//        // perspective divide, camera to screen space
//        let p_x_right = distanceR * p_camera_right.x / p_camera_right.z
//        let p_x_left = distanceL * p_camera_left.x / p_camera_left.z
//
//        let p_y_right = distanceR * (p_camera_right.y / p_camera_right.z)
//        let p_y_left = distanceL * (p_camera_left.y / p_camera_left.z)
//
//        // get average point of both eyes
//        var p_x = CGFloat(p_x_right + p_x_left) / 2
//        var p_y = CGFloat(p_y_right + p_y_left) / 2
//
//        let scalingX = CGFloat(10)
//        let scalingY = CGFloat(10)
//
//        p_x *= scalingX
//        p_y *= scalingY
//
//        // translate to middle of screen
//        let xPos = CGFloat(p_x + 0.5) * phonePointsWidth
//        let yPos = -CGFloat(p_y + 0.5) * phonePointsHeight
//
//        gazePoint.x = xPos
//        gazePoint.y = yPos
//
//        DispatchQueue.main.async {
//            self.gazeIndicator.center = CGPoint(x: xPos, y: yPos)
//        }
//    }
}
