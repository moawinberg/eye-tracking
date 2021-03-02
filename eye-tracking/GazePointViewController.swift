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
    var previousHeadPoint = simd_float4()
    var calibrationScaleWidth = CGFloat(1)
    var calibrationScaleHeight = CGFloat(1)
    var displacement_x = CGFloat(0)
    var displacement_y = CGFloat(0)
    var valuesX: [CGFloat] = []
    var valuesY: [CGFloat] = []

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func smoothing(point : simd_float4) -> CGPoint {
        let threshold = 50
        
        valuesX.append(CGFloat(point.x))
        valuesY.append(CGFloat(point.y))
        
        valuesX = valuesX.suffix(threshold)
        valuesY = valuesY.suffix(threshold)
    
        let sumX = valuesX.reduce(0, +)
        let sumY = valuesY.reduce(0, +)
        
        let avgX = sumX / CGFloat(valuesX.count)
        let avgY = sumY / CGFloat(valuesY.count)
        
        return CGPoint(x: avgX, y: avgY)
    }
    
    func adjustMapping() {
        let calibrationResult = CalibrationData.data.result
        let calibrationPoints = CalibrationData.data.calibrationPoints
        
        let calibrationGazeWidth = abs(((calibrationResult[1]!.x) - (calibrationResult[0]!.x) + (calibrationResult[3]!.x) - (calibrationResult[2]!.x)) / 2)
        let calibrationGazeHeight = abs(((calibrationResult[2]!.y) - (calibrationResult[0]!.y) + (calibrationResult[3]!.y) - (calibrationResult[1]!.y)) / 2)

        let calibrationWidth = CGFloat(calibrationPoints[1].x) - CGFloat(calibrationPoints[0].x)
        let calibrationHeight = CGFloat(calibrationPoints[0].y) - CGFloat(calibrationPoints[2].y)
        print(calibrationWidth, calibrationGazeWidth)
        calibrationScaleWidth = calibrationWidth / calibrationGazeWidth //divide by  start value of scale? //x-wise factor that is multiplied later
        calibrationScaleHeight = calibrationHeight / calibrationGazeHeight //divide by start value of scale  //y-wise factor that is multiplied later
        
        for (index, _) in calibrationPoints.enumerated() {
            displacement_x += CGFloat(calibrationPoints[index].x - calibrationResult[index]!.x*calibrationScaleWidth)
            displacement_y += CGFloat(calibrationPoints[index].y - calibrationResult[index]!.y*calibrationScaleHeight)
        }

        displacement_x /= CGFloat(calibrationPoints.count)
        displacement_y /= CGFloat(calibrationPoints.count)
        
        print("1", calibrationScaleWidth)
        print("2", displacement_x, displacement_y)
    }
    
    func rayPlaneIntersection(withFaceAnchor anchor: ARFaceAnchor, frame: ARFrame) -> CGPoint {
        let cameraTransformMatrix = frame.camera.viewMatrix(for: .portrait)
        let worldTransformMatrixLeft = anchor.transform * anchor.leftEyeTransform
        let worldTransformMatrixRight = anchor.transform * anchor.rightEyeTransform
        let worldTransformMatrixHead = anchor.transform
        
        let worldToCameraMatrixLeft = cameraTransformMatrix * worldTransformMatrixLeft
        let worldToCameraMatrixRight = cameraTransformMatrix * worldTransformMatrixRight
        let worldToCameraMatrixHead = cameraTransformMatrix * worldTransformMatrixHead
        
        let localEyePosition = simd_float4(0, 0, 0, 1) // local space for eye
        let localEyeDirection = simd_float4(0, 0, 1, 0) // direction vector for eye
        
        let cameraEyePositionLeft = worldToCameraMatrixLeft * localEyePosition // eye center in camera coords
        let cameraEyeDirectionLeft = worldToCameraMatrixLeft * localEyeDirection // direction vector in camera coords
        
        let cameraEyePositionRight = worldToCameraMatrixRight * localEyePosition
        let cameraEyeDirectionRight = worldToCameraMatrixRight * localEyeDirection
        
        let cameraEyePositionHead = worldToCameraMatrixHead * localEyePosition
        let cameraEyeDirectionHead = worldToCameraMatrixHead * localEyeDirection
        
        let tLeft = (0.0 - cameraEyePositionLeft.z) / cameraEyeDirectionLeft.z // since all coords except z is 0 we only focus on z
        let intersectionPointLeft = cameraEyePositionLeft + tLeft*cameraEyeDirectionLeft // intersection between ray-plane in NDC. value between 0 and 1
        
        let tRight = (0.0 - cameraEyePositionRight.z) / cameraEyeDirectionRight.z
        let intersectionPointRight = cameraEyePositionRight + tRight*cameraEyeDirectionRight
        
        let tHead = (0.0 - cameraEyePositionHead.z) / cameraEyeDirectionHead.z
        let intersectionPointHead = cameraEyePositionHead + tHead*cameraEyeDirectionHead
        
        // check how much head moved since last point
        let diffHeadX = (previousHeadPoint.x - intersectionPointHead.x)
        let diffHeadY = (previousHeadPoint.y - intersectionPointHead.y)
        
        previousHeadPoint = intersectionPointHead
        
        var intersectionPoint = (intersectionPointLeft + intersectionPointRight) / 2
        
        // remove movement from head
        intersectionPoint.x -= diffHeadX
        intersectionPoint.y -= diffHeadY
        
        let smoothedIntesectionPoint = smoothing(point: intersectionPoint)
        
        if (CalibrationData.data.isCalibrated) {
            adjustMapping()
        }

        let p_x = (CGFloat(smoothedIntesectionPoint.x) * calibrationScaleWidth) // + displacement_x
        let p_y = (CGFloat(smoothedIntesectionPoint.y) * calibrationScaleHeight) // + displacement_y
        
        let xPos = (p_x + 0.5) * phonePointsWidth // positioned in top left corner, translate to half screen
        let yPos = (1 - (p_y + 0.5)) * phonePointsHeight // y is negative along screen
        
        gazePoint.x = round(100*xPos)/100 // round with 1 decimal
        gazePoint.y = round(100*yPos)/100
        print("3", gazePoint)
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
