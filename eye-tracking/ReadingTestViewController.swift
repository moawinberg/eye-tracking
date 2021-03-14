//
//  EyeGazeViewController.swift
//  eye-tracking
//
//  Created by moa on 2021-02-16.
//

import UIKit
import SceneKit
import ARKit
import WebKit

class ReadingTestViewController: UIViewController, ARSCNViewDelegate {

    // MARK: - outlets
    @IBOutlet weak var gazeIndicator: UIImageView!
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var InfoPage: UIView!
    @IBOutlet weak var backBtn: UIButton!
    @IBOutlet weak var stopBtn: UIButton!
    
    
    // MARK: - variables
    var leftEye: SCNNode = SCNNode()
    var rightEye: SCNNode = SCNNode()
    var isRecording = false
    let gazePointCtrl = GazePointViewController()
    var gazeData: [[String : Any]] = []
    
    @IBAction func start(_ sender: UIButton) {
        DispatchQueue.main.async {
            self.InfoPage.isHidden = true
            self.isRecording = true
        }
    }
    
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
        
        print("collected data: ", gazeData)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let faceMesh = ARSCNFaceGeometry(device: sceneView.device!)
        let node = SCNNode(geometry: faceMesh)
        node.geometry?.firstMaterial?.fillMode = .lines
        
        node.addChildNode(leftEye)
        node.addChildNode(rightEye)
        
        return node
    }
    
    func distanceToScreen(eyeNode: SCNNode) -> Float {
        // euqludian distance of the eyes to the camera
        // don't have to subtract camera pos because it's in origo
        return sqrt(
            eyeNode.worldPosition.x*eyeNode.worldPosition.x +
            eyeNode.worldPosition.y*eyeNode.worldPosition.y +
            eyeNode.worldPosition.z*eyeNode.worldPosition.z
        )
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry {
            faceGeometry.update(from: faceAnchor.geometry)
            let ARFrame = sceneView.session.currentFrame
            
            let gazePoints = self.gazePointCtrl.rayPlaneIntersection(withFaceAnchor: faceAnchor, frame: ARFrame!)
            
            if (isRecording) {
                // save data
                gazeData.append([
                    "POG": gazePoints["POG"]!,
                    "left_eye_dist": distanceToScreen(eyeNode: leftEye),
                    "right_eye_dist": distanceToScreen(eyeNode: rightEye)
                ])
            }
            
            DispatchQueue.main.async {
                self.gazeIndicator.center = gazePoints["POG"] as! CGPoint
            }
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
