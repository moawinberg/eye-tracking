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
    var displacement_x = CGFloat(0)
    var displacement_y = CGFloat(0)
    var valuesX: [CGFloat] = []
    var valuesY: [CGFloat] = []

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func smoothing(point : simd_float4) -> CGPoint {
        let threshold = 10
        valuesX.append(CGFloat(point.x))
        valuesY.append(CGFloat(point.y))
        
        valuesX = valuesX.suffix(threshold)
        valuesY = valuesY.suffix(threshold)
        
        var sumX = CGFloat(0)
        var sumY = CGFloat(0)
        
        for value in valuesX {
            sumX += value
        }
        
        for value in valuesY {
            sumY += value
        }
        
        let avgX = sumX / CGFloat(valuesX.count)
        let avgY = sumY / CGFloat(valuesY.count)
        
        return CGPoint(x: avgX, y: avgY)
    }
    
    func adjustMapping() {
        let calibrationResult = CalibrationData.data.result
        let calibrationPoints = CalibrationData.data.calibrationPoints
        
        let calibrationGazeWidth = abs((CGFloat(calibrationResult[1]!.x) - CGFloat(calibrationResult[0]!.x) + CGFloat(calibrationResult[3]!.x) - CGFloat(calibrationResult[2]!.x)) / 2)
        let calibrationGazeHeight = abs((CGFloat(calibrationResult[1]!.y) - CGFloat(calibrationResult[0]!.y) + CGFloat(calibrationResult[3]!.y) - CGFloat(calibrationResult[2]!.y)) / 2)
        
        let calibrationWidth = CGFloat(calibrationPoints[1].x) - CGFloat(calibrationPoints[2].x)
        let calibrationHeight = CGFloat(calibrationPoints[1].y) - CGFloat(calibrationPoints[3].y)
        
        calibrationScaleWidth = calibrationWidth / calibrationGazeWidth //divide by  start value of scale? //x-wise factor that is multiplied later
        calibrationScaleHeight = calibrationHeight / calibrationGazeHeight //divide by start value of scale  //y-wise factor that is multiplied later
       
        for (index, _) in calibrationPoints.enumerated() {
            displacement_x += CGFloat(calibrationResult[index]!.x - calibrationPoints[index].x)
            displacement_y += CGFloat(calibrationResult[index]!.y - calibrationPoints[index].y)
            
            if index == (calibrationPoints.count - 1) {
                displacement_x /= CGFloat(calibrationPoints.count) * calibrationScaleWidth
                displacement_y /= CGFloat(calibrationPoints.count) * calibrationScaleHeight
            }
        }
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
        
        var intersectionPoint = (intersectionPointLeft + intersectionPointRight) / 2
        intersectionPoint /= intersectionPoint.w // remove homogenous coord
        
        let smoothedIntesectionPoint = smoothing(point: intersectionPoint)
        
        if (CalibrationData.data.isCalibrated) {
            adjustMapping()
        }

        let p_x = CGFloat(smoothedIntesectionPoint.x) * calibrationScaleWidth //+ CGFloat(displacement_x)
        let p_y = CGFloat(smoothedIntesectionPoint.y) * calibrationScaleHeight //+ CGFloat(displacement_y)
        
        let xPos = (p_x * phonePointsWidth) + phonePointsWidth/2 // positioned in top left corner, translate to half screen
        let yPos = (-p_y * phonePointsHeight) + phonePointsHeight/2 // y is negative along screen
        
        gazePoint.x = round(10*xPos)/10 // round with 1 decimal
        gazePoint.y = round(10*yPos)/10
        
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
