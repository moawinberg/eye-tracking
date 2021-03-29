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
    @IBOutlet weak var gazeIndicator: UIImageView!
    @IBOutlet weak var quitBtn: UIButton!
    @IBOutlet weak var readingTestBtn: UIButton!
    @IBOutlet weak var distanceLabel: UILabel!
    
    // MARK: - variables
    var leftEye: SCNNode = SCNNode()
    var rightEye: SCNNode = SCNNode()
    var gazePoint = CGPoint()
    var previousGazePoint = CGPoint()
    var index = 0
    var gazePointCtrl = GazePointViewController()
    var wait = true
    
    @IBAction func start(_ sender: UIButton) {
        DispatchQueue.main.async {
            self.infoPage.isHidden = true
            self.PoR.center = CalibrationData.data.calibrationPoints[self.index]!
            
            UIImageView.animate(withDuration: 1.0, delay: 1.0, animations: {
                self.PoR.alpha = 1.0
            }, completion: { finished in
                self.wait = false
            })
        }
    }
    
    func stop() {
        CalibrationData.data.isCalibrated = true
        
        DispatchQueue.main.async {
            self.readingTestBtn.isHidden = false
            self.quitBtn.isHidden = false
            self.PoR.isHidden = true
            self.gazeIndicator.isHidden = false
            self.wait = true
            self.PoR.layer.removeAllAnimations()
            
            // show points
            let calibrationPoints = CalibrationData.data.calibrationPoints
            let result = CalibrationData.data.result
            for (index, _) in calibrationPoints.enumerated() {
                let dot = UIView(frame: CGRect(x: calibrationPoints[index]!.x-5, y: calibrationPoints[index]!.y-5, width: 10, height: 10))
                dot.backgroundColor = .red
                self.view.addSubview(dot)
            }
            
            for (index, _) in result.enumerated() {
                let dot = UIView(frame: CGRect(x: result[index]!.x-5, y: result[index]!.y-5, width: 10, height: 10))
                dot.backgroundColor = .blue
                self.view.addSubview(dot)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        UIApplication.shared.isIdleTimerDisabled = true
        
        CalibrationData.data.result = [:]
        CalibrationData.data.isCalibrated = false
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
    
    func fixation(currentGazePoint: CGPoint, previousGazePoint: CGPoint) {
        if (previousGazePoint == currentGazePoint) {
            self.wait = true
            self.PoR.layer.removeAllAnimations()
            CalibrationData.data.result[self.index] = currentGazePoint
                        
            DispatchQueue.main.async {
                // hide point to indicate done
                UIImageView.animate(withDuration: 1, animations: {
                    self.PoR.alpha = 0
                }, completion: { finished in
                    if (self.index < CalibrationData.data.calibrationPoints.count - 1) {
                        self.index += 1
                        
                        // show point and move to its new position
                        UIImageView.animate(withDuration: 1, animations: {
                            self.PoR.alpha = 1.0
                        }, completion: { finished in
                            UIImageView.animate(withDuration: 1.0, delay: 0, options: .curveEaseIn, animations: {
                                self.PoR.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                                self.PoR.center = CalibrationData.data.calibrationPoints[self.index]!
                            }, completion: { finished in
                                self.wait = false
                                self.PoR.layer.removeAllAnimations()
                            })
                        })
                    } else {
                        self.stop()
                    }
                    
                })
            }
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry {
            faceGeometry.update(from: faceAnchor.geometry)
            
            let ARFrame = sceneView.session.currentFrame
            
            DispatchQueue.main.async {
                // show distance to screen before start
                if (!self.infoPage.isHidden) {
                    let distance = self.gazePointCtrl.distance(node: node)
                    self.distanceLabel.text = "\(Int(round(distance * 100))) cm"
                }
                
                // show gaze indicator after finished
                if (!self.gazeIndicator.isHidden) {
                    let gazePoints = self.gazePointCtrl.gazePoints(withFaceAnchor: faceAnchor, frame: ARFrame!)
                    self.gazeIndicator.center = gazePoints["POG"] as! CGPoint
                }

                // perform calibration
                if (!self.wait) {
                    // pulsating animation to find fixation
                    UIImageView.animate(withDuration: 0.1, delay: 0, options: [.repeat, .autoreverse], animations: {
                        self.PoR.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                        let previousGazePoints = self.gazePointCtrl.gazePoints(withFaceAnchor: faceAnchor, frame: ARFrame!)
                        self.previousGazePoint = previousGazePoints["POG"] as! CGPoint
                    }, completion: { finished in
                        let gazePoints = self.gazePointCtrl.gazePoints(withFaceAnchor: faceAnchor, frame: ARFrame!)
                        self.gazePoint = gazePoints["POG"] as! CGPoint
                        self.fixation(currentGazePoint: self.gazePoint, previousGazePoint: self.previousGazePoint)
                    })
                }
            }
        }
    }
}
