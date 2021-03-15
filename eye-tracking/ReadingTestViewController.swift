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
    @IBOutlet weak var label: UIButton!
    
    // MARK: - variables
    var leftEye: SCNNode = SCNNode()
    var rightEye: SCNNode = SCNNode()
    var isRecording = false
    var gazePointCtrl = GazePointViewController()
    var textNumber = 1
    var maxPages = 2
    var gazeData: [Int : [String : Any]] = [:]
    
    @IBAction func next(_ sender: Any) {
        DispatchQueue.main.async {
            if (self.textNumber == self.maxPages-1) {
                self.label.setTitle("Done", for: .normal)
            } else if (self.textNumber == self.maxPages) {
                self.performSegue(withIdentifier: "Back", sender: self)
            }
            self.textNumber += 1
        }
    }
    
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
        sceneView.removeFromSuperview()
        sceneView = nil
    }

    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let faceMesh = ARSCNFaceGeometry(device: sceneView.device!)
        let node = SCNNode(geometry: faceMesh)
        node.geometry?.firstMaterial?.fillMode = .lines
        
        node.addChildNode(self.leftEye)
        node.addChildNode(self.rightEye)
        
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

            if (self.isRecording) {
                gazeData[textNumber] = [
                    "timestamp": gazePoints["timestamp"]!,
                    "POG": gazePoints["POG"]!,
                    "left_eye_dist": distanceToScreen(eyeNode: leftEye),
                    "right_eye_dist": distanceToScreen(eyeNode: rightEye)
                ]
            }
            
            DispatchQueue.main.async {
                self.gazeIndicator.center = gazePoints["POG"] as! CGPoint
            }
        }
    }

    // MARK: - ARSessions
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("didFailWithError", error)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("sessionWasInterrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        sceneView.session.pause()
        sceneView.removeFromSuperview()
        sceneView = nil
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
}
