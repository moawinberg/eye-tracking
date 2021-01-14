//
//  ViewController.swift
//  eye-tracking
//
//  Created by moa on 2021-01-13.
//

import UIKit
import SceneKit
import ARKit

extension matrix_float4x4 {
    func position() -> SCNVector3 {
        return SCNVector3(columns.3.x, columns.3.y, columns.3.z)
    }
}

class ViewController: UIViewController, ARSCNViewDelegate {

    // MARK: - outlets
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: - variables
    var phonePointsWidth = 414;
    var phonePointsHeight = 896;
    
    var virtualPhone: SCNNode = SCNNode()
    var virtualScreen: SCNNode = {
        let plane = SCNPlane(width: 1, height: 1)
        plane.firstMaterial?.diffuse.contents = UIColor.blue
        return SCNNode(geometry: plane)
    }()
    
    var leftEye: SCNNode = {
        let cylinder = SCNCylinder(radius: 0.002, height: 0.1)
        cylinder.firstMaterial?.diffuse.contents = UIColor.red
        return SCNNode(geometry: cylinder)
    }()
    
    var rightEye: SCNNode = {
        let cylinder = SCNCylinder(radius: 0.002, height: 0.1)
        cylinder.firstMaterial?.diffuse.contents = UIColor.green
        return SCNNode(geometry: cylinder)
    }()
    
    // algebra from: https://github.com/andrewzimmer906/HeatMapEyeTracking?fbclid=IwAR2R663PglsButlR0d-tT9egU3UhTYi4EWIrgs50wRTt2SsfdyfNnJNrPGo
    let eyeRotationMatrix: matrix_float4x4 =
        simd_float4x4(
            SCNMatrix4Mult(
                SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0), SCNMatrix4MakeTranslation(0, 0, 0.1/2)
            )
        )
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        UIApplication.shared.isIdleTimerDisabled = true
        
        // add virtual screen to virtual phone
        virtualPhone.addChildNode(virtualScreen)
        // add virtual phone to scene
        sceneView.scene.rootNode.addChildNode(virtualPhone)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard ARFaceTrackingConfiguration.isSupported else { return }
        
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    
    // add face mesh
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let faceMesh = ARSCNFaceGeometry(device: sceneView.device!)
        let node = SCNNode(geometry: faceMesh)
        node.geometry?.firstMaterial?.fillMode = .lines
        
        node.addChildNode(leftEye)
        node.addChildNode(rightEye)
        
        return node
    }
    
    // update face mesh when face changes
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry {
            faceGeometry.update(from: faceAnchor.geometry)

            leftEye.simdTransform = faceAnchor.leftEyeTransform * eyeRotationMatrix;
            rightEye.simdTransform = faceAnchor.rightEyeTransform * eyeRotationMatrix;
        }
    }
    
    // called once per frame
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        virtualPhone.transform = (sceneView.pointOfView?.transform)!
        print(virtualPhone)
        

    }
    
    // MARK: - ARSessions
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}


