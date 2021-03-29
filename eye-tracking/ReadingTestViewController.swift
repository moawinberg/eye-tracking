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
    @IBOutlet weak var stimuli: UIImageView!
    @IBOutlet weak var nextBtn: UIButton!
    
    // MARK: - variables
    var leftEye: SCNNode = SCNNode()
    var rightEye: SCNNode = SCNNode()
    
    var isRecording = false
    
    var gazePointCtrl = GazePointViewController()
    var gazeData = [Dictionary<String, Any>]()
    
    var pageNumber = 0
    var maxPages = 4
    var pages = [
        "stimulus/grade9text1.png",
        "stimulus/whitebg.png",
        "stimulus/grade9text1.png",
        "stimulus/whitebg.png",
        "stimulus/done.png"
    ]
    
    // MARK: - button clicks
    @IBAction func next(_ sender: Any) {
        DispatchQueue.main.async {
            self.pageNumber += 1
            self.stimuli.image = UIImage(named: self.pages[self.pageNumber])
            
            if (self.pageNumber == self.maxPages) {
                self.isRecording = false
                self.label.isHidden = true
                
                print("participant: ", Participant.data.id)
                print("data: ", self.gazeData)
                
                self.nextBtn.isHidden = false
            }
        }
    }
    
    @IBAction func start(_ sender: UIButton) {
        DispatchQueue.main.async {
            self.stimuli.image = UIImage(named: self.pages[self.pageNumber])
            self.InfoPage.isHidden = true
            self.isRecording = true
        }
    }
    
    // MARK: - view sessions
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
                self.gazeData.append([
                    "timestamp": gazePoints["timestamp"]!,
                    "head_movement": gazePoints["head_movement"]!,
                    "left_eye_NDC": gazePoints["left_eye"]!,
                    "right_eye_NDC": gazePoints["right_eye"]!,
                    "left_eye_dist": self.gazePointCtrl.distance(node: leftEye),
                    "right_eye_dist": self.gazePointCtrl.distance(node: rightEye)
                ])
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
    }
}
