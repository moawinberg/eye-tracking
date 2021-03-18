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
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var InfoPage: UIView!
    @IBOutlet weak var label: UIButton!
    @IBOutlet weak var distanceLabel: UILabel!
    
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
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry {
            faceGeometry.update(from: faceAnchor.geometry)
            let ARFrame = sceneView.session.currentFrame
            
            let gazePoints = self.gazePointCtrl.gazePoints(withFaceAnchor: faceAnchor, frame: ARFrame!)
            
            // show distance to screen before start
            DispatchQueue.main.async {
                if (!self.InfoPage.isHidden) {
                    let distance = self.gazePointCtrl.distance(node: node)
                    self.distanceLabel.text = "\(Int(round(distance * 100))) cm"
                }
            }

            if (self.isRecording) {
                gazeData[textNumber] = [
                    "timestamp": gazePoints["timestamp"]!,
                    "POG": gazePoints["POG"]!,
                    "left_eye_NDC": gazePoints["left_eye"]!,
                    "right_eye_NDC": gazePoints["right_eye"]!,
                    "left_eye_dist": self.gazePointCtrl.distance(node: leftEye),
                    "right_eye_dist": self.gazePointCtrl.distance(node: rightEye)
                ]
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
