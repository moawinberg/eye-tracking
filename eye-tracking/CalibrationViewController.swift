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
    @IBOutlet weak var finishedLabel: UILabel!
    @IBOutlet weak var startBtn: UIButton!
    @IBOutlet weak var infoPage: UIView!
    
    // MARK: - variables
    var leftEye: SCNNode = SCNNode()
    var rightEye: SCNNode = SCNNode()
    var gazePoint = CGPoint()
    var previousGazePoint = CGPoint()
    var index = 0
    var gazeData: [Int: CGPoint] = [:]
    let gazePointCtrl = GazePointViewController()
    var wait = false
    var boxBoundaries: [Int: [String: CGPoint]] = [:]
    
    @IBAction func start(_ sender: UIButton) {
        DispatchQueue.main.async {
            self.infoPage.isHidden = true
            self.PoR.center = CalibrationData.data.calibrationPoints[self.index]
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.checkFixation(notification:)), name: Notification.Name("NotificationIdentifier"), object: nil)
    }
    
    @objc func checkFixation(notification: Notification) {
        let gazePoint = notification.userInfo!["gazePoint"]
        let previousGazePoint = notification.userInfo!["previousGazePoint"]
        
        // check if fixation
        if (gazePoint as! CGPoint == previousGazePoint as! CGPoint) {
            self.wait = true
            self.gazeData[self.index] = self.gazePoint // save gazePoint
            
            //animation to blue
            UIImageView.animate(withDuration: 0.5, delay: 0, options: .curveLinear, animations: {
                self.PoR.tintColor = UIColor.blue
              })
            
            // set new point after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                if (self.index < CalibrationData.data.calibrationPoints.count - 1) {
                    self.wait = false
                    self.index += 1
                    self.PoR.tintColor = UIColor.red
                    self.PoR.center = CalibrationData.data.calibrationPoints[self.index]
                } else {
                    self.finished()
                }
            }
        }
    }
    
    func finished() {
        DispatchQueue.main.async {
            self.finishedLabel.isHidden = false
            self.PoR.isHidden = true
        }

        // save data to struct
        CalibrationData.data.result = gazeData
        CalibrationData.data.isCalibrated = true
        
        // go back to main after finished
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
          self.performSegue(withIdentifier: "Back", sender: self)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        UIApplication.shared.isIdleTimerDisabled = true

        finishedLabel.isHidden = true
        
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        boxBoundaries = [
            0: [
                "min": CGPoint(x: 0, y: screenHeight/2),
                "max": CGPoint(x: screenWidth/2, y: screenHeight)
            ],
            1: [
                "min": CGPoint(x: screenWidth/2, y: screenHeight/2),
                "max": CGPoint(x: screenWidth, y: screenHeight)
            ],
            2: [
                "min": CGPoint(x: 0, y: 0),
                "max": CGPoint(x: screenWidth/2, y: screenHeight/2)
            ],
            3: [
                "min": CGPoint(x: screenWidth/2, y: 0),
                "max": CGPoint(x: screenWidth, y: screenHeight/2)
            ]
        ]
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
            
            let previousGazePoints = gazePointCtrl.rayPlaneIntersection(withFaceAnchor: faceAnchor, frame: ARFrame!)
            previousGazePoint = previousGazePoints["POG"] as! CGPoint
            
            DispatchQueue.main.async {
                UIImageView.animate(withDuration: 1.0, delay:0, options: [.repeat, .autoreverse], animations: {
                    self.PoR.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
                }, completion: nil)
            }
            
            // wait 100 ms for new gazePoint
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                let gazePoints = self.gazePointCtrl.rayPlaneIntersection(withFaceAnchor: faceAnchor, frame: ARFrame!)
                self.gazePoint = gazePoints["POG"] as! CGPoint
                
                let max = self.boxBoundaries[self.index]!["max"]!
                let min = self.boxBoundaries[self.index]!["min"]!
                if (self.gazePoint.x >= min.x &&
                    self.gazePoint.x <= max.x &&
                    self.gazePoint.y >= min.y &&
                    self.gazePoint.y <= max.y &&
                    !self.wait) {
                    NotificationCenter.default.post(name: Notification.Name("NotificationIdentifier"), object: nil, userInfo: ["gazePoint": self.gazePoint, "previousGazePoint" : self.previousGazePoint])
                }
            }

        }
    }
}
