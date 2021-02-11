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
    
    // MARK: - variables
    var phonePointsWidth = CGFloat(414);
    var phonePointsHeight = CGFloat(896);
    
    var screenPointsX: [CGFloat] = []
    var screenPointsY: [CGFloat] = []
    
    var leftEye: SCNNode = SCNNode()
    var rightEye: SCNNode = SCNNode()
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        UIApplication.shared.isIdleTimerDisabled = true
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
        
        let distance = (distanceL + distanceR) / 2
        
        DispatchQueue.main.async{
            self.distanceLabel.text = "\(Int(round(distance * 100))) cm"
        }
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

        DispatchQueue.main.async {
            self.gazeIndicator.center = CGPoint(x: xPos, y: yPos)
        }
    }

    // runs when face changes
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry {
            faceGeometry.update(from: faceAnchor.geometry)
            
            averageDistance()
           // rasterization(withFaceAnchor: faceAnchor)
            rayPlaneIntersection(withFaceAnchor: faceAnchor)
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


