//
//  ValidationViewController.swift
//  eye-tracking
//
//  Created by moa on 2021-03-29.
//

import UIKit
import ARKit

class ValidationViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var PoR: UIImageView!
    @IBOutlet weak var infoPage: UIView!
    @IBOutlet weak var readingTestBtn: UIButton!
    @IBOutlet weak var quitBtn: UIButton!
    
    // MARK: - variables
    var leftEye: SCNNode = SCNNode()
    var rightEye: SCNNode = SCNNode()
    var gazePoint = CGPoint()
    var previousGazePoint = CGPoint()
    var index = 0
    var gazePointCtrl = GazePointViewController()
    var wait = true
    
    @IBAction func start(_ sender: Any) {
        DispatchQueue.main.async {
            self.infoPage.isHidden = true
            self.PoR.center = ValidationData.data.validationPoints[self.index]
            
            UIImageView.animate(withDuration: 1.0, delay: 1.0, animations: {
                self.PoR.alpha = 1.0
            }, completion: { finished in
                self.wait = false
            })
        }
    }
    
    func stop() {
        DispatchQueue.main.async {
            self.readingTestBtn.isHidden = false
            self.quitBtn.isHidden = false
            self.PoR.isHidden = true
            self.wait = true
            self.PoR.layer.removeAllAnimations()
            
            print("validation number: ", ValidationData.data.index)
            print("data: ", ValidationData.data.result)
            
            ValidationData.data.index += 1
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
    
    func fixation(currentGazePoint: CGPoint, previousGazePoint: CGPoint) {
        if (previousGazePoint == currentGazePoint) {
            self.wait = true
            self.PoR.layer.removeAllAnimations()
            ValidationData.data.result[self.index] = currentGazePoint
                        
            DispatchQueue.main.async {
                // hide point to indicate done
                UIImageView.animate(withDuration: 1, animations: {
                    self.PoR.alpha = 0
                }, completion: { finished in
                    if (self.index < ValidationData.data.validationPoints.count - 1) {
                        self.index += 1
                        
                        // show point and move to its new position
                        UIImageView.animate(withDuration: 1, animations: {
                            self.PoR.alpha = 1.0
                        }, completion: { finished in
                            UIImageView.animate(withDuration: 1.0, delay: 0, options: .curveEaseIn, animations: {
                                self.PoR.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                                self.PoR.center = ValidationData.data.validationPoints[self.index]
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
                
                // perform validation
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
