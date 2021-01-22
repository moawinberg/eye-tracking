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
    var phoneWidth = CGFloat(0.1509)
    var phoneHeight = CGFloat(0.0757)
    
    // Set target at 2 meters away from the center of eyeballs to create segment vector
    var gazeTargetLeftEye: SCNNode = {
        let node = SCNNode()
        node.position.z = 2
        return node
    }()
    
    var gazeTargetRightEye: SCNNode = {
        let node = SCNNode()
        node.position.z = 2
        return node
    }()
    
    var leftEye: SCNNode = {
        let node = SCNNode()
        node.eulerAngles.x = -.pi / 2 // rotate x angle (pitch) -90 degrees to point at device
        node.position.z = 0.1
        let parentNode = SCNNode()
        parentNode.addChildNode(node)
        return parentNode
    }()
    
    var rightEye: SCNNode = {
        let node = SCNNode()
        node.eulerAngles.x = -.pi / 2
        node.position.z = 0.1
        let parentNode = SCNNode()
        parentNode.addChildNode(node)
        return parentNode
    }()

    var virtualPhoneNode: SCNNode = {
        let geometry = SCNPlane(width: 1, height: 1)
        geometry.firstMaterial?.isDoubleSided = true
        geometry.firstMaterial?.fillMode = .fill
        geometry.firstMaterial?.diffuse.contents = UIColor.blue

        let node = SCNNode()
        node.geometry = geometry
        return node
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        UIApplication.shared.isIdleTimerDisabled = true
        
        sceneView.pointOfView?.addChildNode(virtualPhoneNode)
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
        
        // add nodes to face
        node.addChildNode(leftEye)
        node.addChildNode(rightEye)
        
        // add target to eyes
        leftEye.addChildNode(gazeTargetLeftEye)
        rightEye.addChildNode(gazeTargetRightEye)
        
        return node
    }
    
    func averageDistance() {
        // Distance of the eyes to the camera don't have to subtract because the center of worldPosition (camera) is (0,0,0)
        let distanceL = leftEye.worldPosition
        let distanceR = rightEye.worldPosition
        
        // euqludian distance
        let distanceLLength = sqrt(distanceL.x*distanceL.x + distanceL.y*distanceL.y + distanceL.z*distanceL.z)
        let distanceRLength = sqrt(distanceR.x*distanceR.x + distanceR.y*distanceR.y + distanceR.z*distanceR.z)
        
        let distance = (distanceLLength + distanceRLength) / 2

        DispatchQueue.main.async{
            self.distanceLabel.text = "\(Int(round(distance * 100))) cm"
        }
    }
    
    func hitTest() {
        guard let rightEyeHitTestResults = self.virtualPhoneNode.hitTestWithSegment(
                from: self.gazeTargetRightEye.worldPosition,
                to: self.rightEye.worldPosition,
                options: nil
        ).first else { return }
        
        guard let leftEyeHitTestResults = self.virtualPhoneNode.hitTestWithSegment(
                from: self.gazeTargetLeftEye.worldPosition,
                to: self.leftEye.worldPosition,
                options: nil
        ).first else { return }
        
        let rightEyeX = CGFloat(rightEyeHitTestResults.localCoordinates.x) / (phoneWidth / 2) * phonePointsWidth
        let rightEyeY = CGFloat(rightEyeHitTestResults.localCoordinates.y) / (phoneHeight / 2) * phonePointsHeight
        
        let leftEyeX = CGFloat(leftEyeHitTestResults.localCoordinates.x) / (phoneWidth / 2) * phonePointsWidth
        let leftEyeY = CGFloat(leftEyeHitTestResults.localCoordinates.y) / (phoneHeight / 2) * phonePointsHeight
        
        let avgX = (rightEyeX + leftEyeX) / 2
        let avgY = (rightEyeY + leftEyeY) / 2

        DispatchQueue.main.async{
            self.gazeIndicator.center = CGPoint(x: avgX, y: -avgY)
        }
    }
    
    // runs when face changes
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry {
            faceGeometry.update(from: faceAnchor.geometry)
            
            leftEye.simdTransform = faceAnchor.leftEyeTransform
            rightEye.simdTransform = faceAnchor.rightEyeTransform
            
            averageDistance()
            hitTest()
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


