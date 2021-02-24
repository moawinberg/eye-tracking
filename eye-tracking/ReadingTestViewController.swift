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
    @IBOutlet weak var confirmText: UILabel!
    @IBOutlet weak var backBtn: UIButton!
    @IBOutlet weak var stopBtn: UIButton!
    @IBOutlet weak var backArrow: UIImageView!
    
    
    // MARK: - variables
    var leftEye: SCNNode = SCNNode()
    var rightEye: SCNNode = SCNNode()
    var isRecording = false
    
    let gazePointCtrl = GazePointViewController()
    var gazePoints: [CGPoint] = []
    
    @IBAction func stop(_ sender: UIButton) {
        DispatchQueue.main.async {
            self.isRecording = false
            self.confirmText.isHidden = false
            self.gazeIndicator.isHidden = true
            self.stopBtn.isHidden = true
        }
        
        print("collected data: ", gazePoints)
        
        // go back to main after finished
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
          self.performSegue(withIdentifier: "Back", sender: self)
        }
    }
    
    @IBAction func start(_ sender: UIButton) {
        DispatchQueue.main.async {
            self.InfoPage.isHidden = true
            self.isRecording = true
            self.backBtn.isHidden = true
            self.backArrow.isHidden = true
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        UIApplication.shared.isIdleTimerDisabled = true
        
        confirmText.isHidden = true
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
    func averageDistance() -> Float {
        // euqludian distance of the eyes to the camera don't have to subtract because the center of worldPosition (camera) is (0,0,0)
        let distanceL = sqrt(leftEye.worldPosition.x*leftEye.worldPosition.x + leftEye.worldPosition.y*leftEye.worldPosition.y + leftEye.worldPosition.z*leftEye.worldPosition.z)
        let distanceR = sqrt(rightEye.worldPosition.x*rightEye.worldPosition.x + rightEye.worldPosition.y*rightEye.worldPosition.y + rightEye.worldPosition.z*rightEye.worldPosition.z)
        
        let distance = Float((distanceL + distanceR) / 2)
        
        return distance
    }
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let faceMesh = ARSCNFaceGeometry(device: sceneView.device!)
        let node = SCNNode(geometry: faceMesh)
        node.geometry?.firstMaterial?.fillMode = .lines
        
        node.addChildNode(leftEye)
        node.addChildNode(rightEye)
        
        return node
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry {
            faceGeometry.update(from: faceAnchor.geometry)
            
            let ARFrame = sceneView.session.currentFrame
            let gazePoint = gazePointCtrl.rayPlaneIntersection(withFaceAnchor: faceAnchor, frame: ARFrame!)
            
            // let distance = averageDistance()
            
            if (isRecording) {
                gazePoints.append(gazePoint)
            }
            
            DispatchQueue.main.async {
                self.gazeIndicator.center = gazePoint
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
