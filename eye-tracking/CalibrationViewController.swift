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
    var wait = true
    var boxBoundaries: [Int: [String: CGPoint]] = [:]
    
    @IBAction func start(_ sender: UIButton) {
        DispatchQueue.main.async {
            self.infoPage.isHidden = true
            self.PoR.center = CalibrationData.data.calibrationPoints[self.index]
            self.wait = false
        }
        NotificationCenter.default.addObserver(self, selector: #selector(self.checkFixation(notification:)), name: Notification.Name("NotificationIdentifier"), object: nil)
    }
    
    func showResult() {
        DispatchQueue.main.async {
            for point in CalibrationData.data.calibrationPoints {
                let dot = UIView(frame: CGRect(x: point.x, y: point.y, width: 10, height: 10))
                dot.backgroundColor = .blue
                self.view.addSubview(dot)
            }
            
            for (index, _) in self.gazeData.enumerated() {
                let dot = UIView(frame: CGRect(x: self.gazeData[index]!.x, y: self.gazeData[index]!.y, width: 10, height: 10))
                dot.backgroundColor = .red
                 self.view.addSubview(dot)
            }
        }
    }
    
    @objc func checkFixation(notification: Notification) {
        let gazePoint = notification.userInfo!["gazePoint"]
        let previousGazePoint = notification.userInfo!["previousGazePoint"]
        
        //pulsating animation
        UIImageView.animate(withDuration: 1.0, delay:0, options: [.repeat, .autoreverse], animations: {
            self.PoR.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }, completion: nil)
        
        // check if fixation
        if (gazePoint as! CGPoint == previousGazePoint as! CGPoint) {
            self.wait = true
            
            // stop animations
            self.PoR.layer.removeAllAnimations()
            self.gazeData[self.index] = self.gazePoint // save gazePoint
            
            UIImageView.animate(withDuration: 0.5, delay: 0, options: .curveLinear, animations: {
                self.PoR.tintColor = UIColor.blue
              })
            
            self.PoR.tintColor = UIColor.blue
            
            // set new point after 2 seconds if not finished
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                if (self.index < CalibrationData.data.calibrationPoints.count - 1) {
                    self.index += 1
                    self.PoR.tintColor = UIColor.red
                    
                    UIImageView.animate(withDuration: 1.0, delay:0, options: .curveEaseIn, animations: {
                        self.PoR.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                        self.PoR.center = CalibrationData.data.calibrationPoints[self.index]
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
                            self.wait = false
                        }
                    })
                } else {
                    self.showResult()
                    self.finished()
                }
            }
        }
    }
    
    func finished() {
        DispatchQueue.main.async {
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
        
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
            
            if (!wait) {
                let previousGazePoints = gazePointCtrl.rayPlaneIntersection(withFaceAnchor: faceAnchor, frame: ARFrame!)
                previousGazePoint = previousGazePoints["POG"] as! CGPoint
                
                // wait 100 ms for new gazePoint
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                    let gazePoints = self.gazePointCtrl.rayPlaneIntersection(withFaceAnchor: faceAnchor, frame: ARFrame!)
                    self.gazePoint = gazePoints["POG"] as! CGPoint
                    print(self.gazePoint)
                    
                    NotificationCenter.default.post(name: Notification.Name("NotificationIdentifier"), object: nil, userInfo: ["gazePoint": self.gazePoint, "previousGazePoint" : self.previousGazePoint])
                }
            }
        }
    }
}
