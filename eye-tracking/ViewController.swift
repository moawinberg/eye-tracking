//
//  ViewController.swift
//  eye-tracking
//
//  Created by moa on 2021-01-13.
//

import UIKit
import SceneKit
import ARKit
import WebKit

class ViewController: UIViewController, ARSCNViewDelegate {

    // MARK: - outlets
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var gazeIndicator: UIImageView!
    @IBOutlet weak var calibrationPoint: UIImageView!
    @IBOutlet weak var startCalibrationBtn: UIButton!
    @IBOutlet weak var savePosBtn: UIButton!
    
    // MARK: - button actions
    
    @IBAction func savePosition(_ sender: UIButton) {
        gazeData[counter] = gazePoint
        calibration()
    }
    @IBAction func startCalibration(_ sender: UIButton) {
        savePosBtn.isHidden = false
        startCalibrationBtn.isHidden = true
        calibration()
    }
    
    // MARK: - variables
    var phonePointsWidth = CGFloat(414);
    var phonePointsHeight = CGFloat(896);
    
    var screenPointsX: [CGFloat] = []
    var screenPointsY: [CGFloat] = []
    
    var leftEye: SCNNode = SCNNode()
    var rightEye: SCNNode = SCNNode()
    
    var gazePoint = CGPoint(x: 0, y: 0)
    var distance = Float(0.0)
    
    var counter = 0
    var gazeData: [Int: CGPoint] = [:]
    
    var calibrationPoints = [
        CGPoint(x: 50, y: 850), // bottom-left,
        CGPoint(x: 360, y: 850), // bottom-right
        CGPoint(x: 50, y: 50), // top-left
        CGPoint(x: 360, y: 50), // top-right
        CGPoint(x: 207, y: 448) // center
    ]
    
    func calibration() {
        if (counter < 5) {
            calibrationPoint.center = calibrationPoints[counter]
        } else {
            print(gazeData)
            calibrationPoint.isHidden = true
            savePosBtn.isHidden = true
            startCalibrationBtn.isHidden = false
        }
        counter += 1
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        UIApplication.shared.isIdleTimerDisabled = true
        
        calibrationPoint.isHidden = true
        savePosBtn.isHidden = true
        startCalibrationBtn.isHidden = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    
    // add face mesh
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let faceMesh = ARSCNFaceGeometry(device: sceneView.device!)
        let node = SCNNode(geometry: faceMesh)
        node.geometry?.firstMaterial?.fillMode = .lines
        
        node.addChildNode(leftEye)
        node.addChildNode(rightEye)
        
        return node
    }
    
    func averageDistance() {
        // euqludian distance of the eyes to the camera don't have to subtract because the center of worldPosition (camera) is (0,0,0)
        let distanceL = sqrt(leftEye.worldPosition.x*leftEye.worldPosition.x + leftEye.worldPosition.y*leftEye.worldPosition.y + leftEye.worldPosition.z*leftEye.worldPosition.z)
        let distanceR = sqrt(rightEye.worldPosition.x*rightEye.worldPosition.x + rightEye.worldPosition.y*rightEye.worldPosition.y + rightEye.worldPosition.z*rightEye.worldPosition.z)
        
        distance = (distanceL + distanceR) / 2
    }
    
    func smoothing() {
        let threshold = 10
        
        // limit number of points in array to threhold
        let pointsX = screenPointsX.suffix(threshold)
        let pointsY = screenPointsY.suffix(threshold)
        
        // get average point in array
        let avgX =  pointsX.reduce(0, +) / CGFloat(pointsX.count)
        let avgY = pointsY.reduce(0, +) / CGFloat(pointsY.count)
        
        // clamp point to screen size
        let pointX = min(max(avgX, 0), CGFloat(phonePointsWidth))
        let pointY = min(max(avgY, 0), CGFloat(phonePointsHeight))
        
        DispatchQueue.main.async {
            self.gazeIndicator.center = CGPoint(x: CGFloat(pointX), y: CGFloat(pointY))
        }
    }
    
    func rayPlaneIntersection(withFaceAnchor anchor: ARFaceAnchor) {
        let cameraTransformMatrix = sceneView.session.currentFrame?.camera.viewMatrix(for: .portrait)
        let worldTransformMatrixLeft = anchor.transform * anchor.leftEyeTransform
        let worldTransformMatrixRight = anchor.transform * anchor.rightEyeTransform
        
        let worldToCameraMatrixLeft = cameraTransformMatrix! * worldTransformMatrixLeft
        let worldToCameraMatrixRight = cameraTransformMatrix! * worldTransformMatrixRight
        
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

        let scalingFactorX = CGFloat(4)
        let scalingFactorY = CGFloat(4)
        
        let p_x = CGFloat(avgIntersectionPoint.x / avgIntersectionPoint.w) * scalingFactorX // remove homogenous coordinate
        let p_y = CGFloat(avgIntersectionPoint.y / avgIntersectionPoint.w) * scalingFactorY
        
        let xPos = (p_x * phonePointsWidth) + phonePointsWidth/2 // positioned in top left corner, translate to half screen
        let yPos = (-p_y * phonePointsHeight) + phonePointsHeight/2 // y is negative along screen
        
        gazePoint.x = xPos
        gazePoint.y = yPos
        
        DispatchQueue.main.async {
            self.gazeIndicator.center = CGPoint(x: xPos, y: yPos)
        }

    }
    
    func rasterization(withFaceAnchor anchor: ARFaceAnchor) {
        let distanceL = sqrt(leftEye.worldPosition.x*leftEye.worldPosition.x + leftEye.worldPosition.y*leftEye.worldPosition.y + leftEye.worldPosition.z*leftEye.worldPosition.z)
        let distanceR = sqrt(rightEye.worldPosition.x*rightEye.worldPosition.x + rightEye.worldPosition.y*rightEye.worldPosition.y + rightEye.worldPosition.z*rightEye.worldPosition.z)

        // local to world
        let p_world_right = anchor.rightEyeTransform * simd_float4(rightEye.worldPosition.x, rightEye.worldPosition.y, rightEye.worldPosition.z, 1)
        let p_world_left = anchor.leftEyeTransform * simd_float4(leftEye.worldPosition.x, leftEye.worldPosition.y, leftEye.worldPosition.z, 1)

        // world to camera coordinates
        let camera = sceneView.session.currentFrame?.camera
        let p_camera_right = camera!.viewMatrix(for: .portrait) * p_world_right
        let p_camera_left = camera!.viewMatrix(for: .portrait) * p_world_left
        
        // perspective divide, camera to screen space
        let p_x_right = distanceR * p_camera_right.x / p_camera_right.z
        let p_x_left = distanceL * p_camera_left.x / p_camera_left.z
    
        let p_y_right = distanceR * (p_camera_right.y / p_camera_right.z)
        let p_y_left = distanceL * (p_camera_left.y / p_camera_left.z)
        
        // get average point of both eyes
        var p_x = CGFloat(p_x_right + p_x_left) / 2
        var p_y = CGFloat(p_y_right + p_y_left) / 2
        
        let scalingX = CGFloat(10)
        let scalingY = CGFloat(10)
        
        p_x *= scalingX
        p_y *= scalingY
        
        // translate to middle of screen
        let xPos = CGFloat(p_x + 0.5) * phonePointsWidth
        let yPos = -CGFloat(p_y + 0.5) * phonePointsHeight
        
        gazePoint.x = xPos
        gazePoint.y = yPos

        DispatchQueue.main.async {
            self.gazeIndicator.center = CGPoint(x: xPos, y: yPos)
        }
    }

    // runs when face changes
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry {
            faceGeometry.update(from: faceAnchor.geometry)
            
            averageDistance()
            rasterization(withFaceAnchor: faceAnchor)
        }
    }

    // MARK: - ARSessions
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}


