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
    var gazePointCtrl = GazePointViewController()
    var wait = true
    
    @IBAction func start(_ sender: UIButton) {
        DispatchQueue.main.async {
            self.infoPage.isHidden = true
            self.PoR.center = CalibrationData.data.calibrationPoints[self.index]
            self.wait = false
        }
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
    
    func finished() {
        DispatchQueue.main.async {
            self.PoR.isHidden = true
        }

        // save data to struct
        CalibrationData.data.result = self.gazeData
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
        
        // Pause the view's session
        sceneView.session.pause()
        sceneView.removeFromSuperview()
        sceneView = nil
    }
    
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
            
            if (!self.wait) {
                DispatchQueue.main.async {
                    UIImageView.animate(withDuration: 0.1, delay: 0, options: [.repeat, .autoreverse], animations: {
                        self.PoR.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                        let previousGazePoints = self.gazePointCtrl.rayPlaneIntersection(withFaceAnchor: faceAnchor, frame: ARFrame!)
                        self.previousGazePoint = previousGazePoints["POG"] as! CGPoint
                    }, completion: { finished in
                        let gazePoints = self.gazePointCtrl.rayPlaneIntersection(withFaceAnchor: faceAnchor, frame: ARFrame!)
                        self.gazePoint = gazePoints["POG"] as! CGPoint
                        
                        if (self.previousGazePoint == self.gazePoint) {
                            self.wait = true
                            self.gazeData[self.index] = self.gazePoint // save gazePoint
                                        
                            DispatchQueue.main.async {
                                UIImageView.animate(withDuration: 1, delay: 0, options: .curveLinear, animations: {
                                    self.PoR.tintColor = UIColor.blue
                                }, completion: { finished in
                                    self.PoR.tintColor = UIColor.red
                                    if (self.index < CalibrationData.data.calibrationPoints.count - 1) {
                                        UIImageView.animate(withDuration: 1.0, delay: 1.0, options: .curveEaseIn, animations: {
                                            self.index += 1
                                            self.PoR.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                                            self.PoR.center = CalibrationData.data.calibrationPoints[self.index]
                                        }, completion: { finished in
                                            self.wait = false
                                            self.PoR.layer.removeAllAnimations()
                                        })
                                    } else {
                                        self.wait = true
                                        self.PoR.layer.removeAllAnimations()
                                        self.showResult()
                                        self.finished()
                                    }
                                })
                            }
                        }
                    })
                }
            }
        }
    }
}
