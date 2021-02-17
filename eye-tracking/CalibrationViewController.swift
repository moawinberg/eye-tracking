//
//  CalibrationViewController.swift
//  eye-tracking
//
//  Created by moa on 2021-02-16.
//

import UIKit
import SceneKit
import ARKit

class CalibrationViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var PoR: UIImageView!
    @IBOutlet weak var nextBtn: UIButton!
    @IBOutlet weak var finishedLabel: UILabel!
    
    // MARK: - variables
    var phonePointsWidth = CGFloat(414);
    var phonePointsHeight = CGFloat(896);
    
    var leftEye: SCNNode = SCNNode()
    var rightEye: SCNNode = SCNNode()
    
    var gazePoint = CGPoint(x: 0, y: 0)
    var index = 0
    var gazeData: [Int: CGPoint] = [:]
    
    var gazePointCtrl = GazePointViewController()
    
    @IBAction func next(_ sender: UIButton) {
        if (index < 5) {
            PoR.center = calibrationPoints[index]
            gazeData[index] = gazePoint
            
            index += 1
        } else {
            finishedLabel.isHidden = false
            nextBtn.isHidden = true
            PoR.isHidden = true
            CalibrationData.data.gazePoints = gazeData
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
              self.performSegue(withIdentifier: "Back", sender: self)
            }
        }
    }
    
    var calibrationPoints = [
        CGPoint(x: 50, y: 850), // bottom-left,
        CGPoint(x: 360, y: 850), // bottom-right
        CGPoint(x: 50, y: 50), // top-left
        CGPoint(x: 360, y: 50), // top-right
        CGPoint(x: 207, y: 448) // center
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        UIApplication.shared.isIdleTimerDisabled = true

        finishedLabel.isHidden = true
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
    
    // add face mesh
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let faceMesh = ARSCNFaceGeometry(device: sceneView.device!)
        let node = SCNNode(geometry: faceMesh)
        node.geometry?.firstMaterial?.fillMode = .lines
        
        node.addChildNode(leftEye)
        node.addChildNode(rightEye)
        
        return node
    }
    // runs when face changes
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry {
            faceGeometry.update(from: faceAnchor.geometry)
            
            let ARFrame = sceneView.session.currentFrame
            
            gazePoint = gazePointCtrl.rayPlaneIntersection(withFaceAnchor: faceAnchor, frame: ARFrame!)
        }
    }
}