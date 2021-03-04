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
    var valuesX: [CGFloat] = []
    var valuesY: [CGFloat] = []
    var phonePointsWidth = CGFloat(414)
    var phonePointsHeight = CGFloat(896)

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func smoothedGazePoint(gazePoints: [String : CGPoint]) -> CGPoint {
        let threshold = 50
        let decimalValue = CGFloat(100)
        
        // get avg from both eyes
        let x = (gazePoints["left_eye"]!.x + gazePoints["right_eye"]!.x) / 2
        let y = (gazePoints["left_eye"]!.y + gazePoints["right_eye"]!.y) / 2
        
        valuesX.append(round(decimalValue*x)/decimalValue)
        valuesY.append(round(decimalValue*y)/decimalValue)
        
        valuesX = valuesX.suffix(threshold)
        valuesY = valuesY.suffix(threshold)
    
        let sumX = valuesX.reduce(0, +)
        let sumY = valuesY.reduce(0, +)
        
        let avgX = sumX / CGFloat(valuesX.count)
        let avgY = sumY / CGFloat(valuesY.count)
        
        // NDC to screen coords
        return CGPoint(x: avgX * phonePointsWidth, y: avgY * phonePointsHeight)
    }
    
    func adjustMapping() {
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
        
        if (CalibrationData.data.isCalibrated) {
            adjustMapping()
        }
        
        var leftEyeX = (CGFloat(leftEyeIntersection.x) * calibrationScaleWidth) // + displacement_x
        var leftEyeY = (CGFloat(leftEyeIntersection.y) * calibrationScaleHeight) // + displacement_y
        
        var rightEyeX = (CGFloat(leftEyeIntersection.x) * calibrationScaleWidth) // + displacement_x
        var rightEyeY = (CGFloat(leftEyeIntersection.y) * calibrationScaleHeight) // + displacement_y
        
        // translate to origo from top left to center of screen, y is negative along screen
        leftEyeX = (leftEyeX + 0.5)
        leftEyeY = (1 - (leftEyeY + 0.5))
        
        rightEyeX = (rightEyeX + 0.5) // positioned in top left corner, translate to half screen
        rightEyeY = (1 - (rightEyeY + 0.5))

        let leftEyePos = CGPoint(x: leftEyeX, y: leftEyeY)
        let rightEyePos = CGPoint(x: rightEyeX, y: rightEyeY)
        
        return ["left_eye": leftEyePos, "right_eye": rightEyePos]
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
