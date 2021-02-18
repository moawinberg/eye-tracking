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
    var phonePointsWidth = CGFloat(414);
    var phonePointsHeight = CGFloat(896);
    var gazePoint = CGPoint(x: 0, y: 0)
    var calibrationScaleWidth = CGFloat(4)
    var calibrationScaleHeight = CGFloat(4)

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func rayPlaneIntersection(withFaceAnchor anchor: ARFaceAnchor, frame: ARFrame) -> CGPoint {
        let cameraTransformMatrix = frame.camera.viewMatrix(for: .portrait)
        let worldTransformMatrixLeft = anchor.transform * anchor.leftEyeTransform
        let worldTransformMatrixRight = anchor.transform * anchor.rightEyeTransform
        
        let worldToCameraMatrixLeft = cameraTransformMatrix * worldTransformMatrixLeft
        let worldToCameraMatrixRight = cameraTransformMatrix * worldTransformMatrixRight
        
        let localEyePosition = simd_float4(0, 0, 0, 1) // local space for eye
        let localEyeDirection = simd_float4(0, 0, 1, 0) // direction vector for eye
        
        let cameraEyePositionLeft = worldToCameraMatrixLeft * localEyePosition // eye center in camera coords
        let cameraEyeDirectionLeft = worldToCameraMatrixLeft * localEyeDirection // direction vector in camera coords
        
        let cameraEyePositionRight = worldToCameraMatrixRight * localEyePosition
        let cameraEyeDirectionRight = worldToCameraMatrixRight * localEyeDirection
        
        let tLeft = (0.0 - cameraEyePositionLeft.z) / cameraEyeDirectionLeft.z // since all coords except z is 0 we only focus on z
        let intersectionPointLeft = cameraEyePositionLeft + tLeft*cameraEyeDirectionLeft // intersection between ray-plane in NDC. value between 0 and 1
        
        let tRight = (0.0 - cameraEyePositionRight.z) / cameraEyeDirectionRight.z
        let intersectionPointRight = cameraEyePositionRight + tRight*cameraEyeDirectionRight
        
        let avgIntersectionPoint = (intersectionPointLeft + intersectionPointRight) / 2
        
        if (CalibrationData.data.isCalibrated) {
            //apply smoothing before!! results might be inaccurate otherwise
            
            let calibrationGazePoints = CalibrationData.data.gazePoints

            let calibrationGazeWidth = abs((CGFloat(calibrationGazePoints[1]!.x) - CGFloat(calibrationGazePoints[0]!.x) + CGFloat(calibrationGazePoints[3]!.x) - CGFloat(calibrationGazePoints[2]!.x)) / 2)
            
            let calibrationGazeHeight = abs((CGFloat(calibrationGazePoints[1]!.y) - CGFloat(calibrationGazePoints[0]!.y) + CGFloat(calibrationGazePoints[3]!.y) - CGFloat(calibrationGazePoints[2]!.y)) / 2)
            
            let calibrationPoints = CalibrationData.data.calibrationPoints

            let calibrationWidth = CGFloat(calibrationPoints[1].x) - CGFloat(calibrationPoints[2].x)
            let calibrationHeight = CGFloat(calibrationPoints[1].y) - CGFloat(calibrationPoints[3].y)
            
            calibrationScaleWidth = calibrationWidth / calibrationGazeWidth //x-wise factor that is multiplied later
            calibrationScaleHeight = calibrationHeight / calibrationGazeHeight //y-wise factor that is multiplied later
        }
        
        let p_x = CGFloat(avgIntersectionPoint.x / avgIntersectionPoint.w) * calibrationScaleWidth // remove homogenous coordinate
        let p_y = CGFloat(avgIntersectionPoint.y / avgIntersectionPoint.w) * calibrationScaleHeight
        
        let xPos = (p_x * phonePointsWidth) + phonePointsWidth/2 // positioned in top left corner, translate to half screen
        let yPos = (-p_y * phonePointsHeight) + phonePointsHeight/2 // y is negative along screen
        
        gazePoint.x = xPos
        gazePoint.y = yPos
        
        return gazePoint
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
