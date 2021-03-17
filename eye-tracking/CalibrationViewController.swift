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
    var gazePointCtrl = GazePointViewController()
    var wait = true
    
    @IBAction func start(_ sender: UIButton) {
        DispatchQueue.main.async {
            self.infoPage.isHidden = true
            self.PoR.center = CalibrationData.data.calibrationPoints[self.index]
            self.wait = false
        }
    }
    
    func stop() {
        // save data to struct
        CalibrationData.data.isCalibrated = true
        
        // print points
        DispatchQueue.main.async {
            self.PoR.isHidden = true
            self.wait = true
            self.PoR.layer.removeAllAnimations()
            
            let calibrationPoints = CalibrationData.data.calibrationPoints
            let result = CalibrationData.data.result
            
            for point in calibrationPoints {
                let dot = UIView(frame: CGRect(x: point.x-5, y: point.y-5, width: 10, height: 10))
                dot.backgroundColor = .blue
                self.view.addSubview(dot)
            }
            
            for (index, points) in result.enumerated() {
                print(points)
                let dot = UIView(frame: CGRect(x: result[index]!.x-5, y: result[index]!.y-5, width: 10, height: 10))
                dot.backgroundColor = .red
                self.view.addSubview(dot)
            }
        }
        
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
    
    func fixation(currentGazePoint: CGPoint, previousGazePoint: CGPoint) {
        if (previousGazePoint == gazePoint) {
            self.wait = true
            CalibrationData.data.result[self.index] = gazePoint
                        
            DispatchQueue.main.async {
                UIImageView.animate(withDuration: 1, delay: 0, options: .curveLinear, animations: {
                    self.PoR.tintColor = UIColor.blue
                }, completion: { finished in
                    if (self.index < CalibrationData.data.calibrationPoints.count - 1) {
                        self.PoR.tintColor = UIColor.red
                        self.index += 1
                        
                        // animate point to next position
                        UIImageView.animate(withDuration: 1.0, delay: 1.0, options: .curveEaseIn, animations: {
                            self.PoR.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                            self.PoR.center = CalibrationData.data.calibrationPoints[self.index]
                        }, completion: { finished in
                            self.wait = false
                            self.PoR.layer.removeAllAnimations()
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
            
            if (!self.wait) {
                DispatchQueue.main.async {
                    // pulsating animation
                    UIImageView.animate(withDuration: 0.1, delay: 0, options: [.repeat, .autoreverse], animations: {
                        self.PoR.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                        let previousGazePoints = self.gazePointCtrl.rayPlaneIntersection(withFaceAnchor: faceAnchor, frame: ARFrame!)
                        self.previousGazePoint = previousGazePoints["POG"] as! CGPoint
                    }, completion: { finished in
                        let gazePoints = self.gazePointCtrl.rayPlaneIntersection(withFaceAnchor: faceAnchor, frame: ARFrame!)
                        self.gazePoint = gazePoints["POG"] as! CGPoint
                        
                        // check fixation
                        self.fixation(currentGazePoint: self.gazePoint, previousGazePoint: self.previousGazePoint)
                    })
                }
            }
        }
    }
}
