//
//  ViewController.swift
//  eye-tracking
//
//  Created by moa on 2021-01-13.
//

import UIKit
import SceneKit
import ARKit
import WebKit

class ViewController: UIViewController, ARSCNViewDelegate {

    // MARK: - outlets
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var gazeIndicator: UIImageView!
    
    // MARK: - variables
    var phonePointsWidth = CGFloat(414);
    var phonePointsHeight = CGFloat(896);
    var phoneWidth = CGFloat(0.1509)
    var phoneHeight = CGFloat(0.0757)
    
    var gazePoints: [CGPoint] = []
    
    // Set target at 2 meters away from the center of eyeballs to create segment vector
    var leftEyeEnd: SCNNode = {
        let node = SCNNode()
        node.position.z = 2
        return node
    }()
    
    var rightEyeEnd: SCNNode = {
        let node = SCNNode()
        node.position.z = 2
        return node
    }()
    
    var leftEye: SCNNode = {
        let geometry = SCNCone(topRadius: 0.005, bottomRadius: 0, height: 0.2)
        geometry.radialSegmentCount = 3
        geometry.firstMaterial?.diffuse.contents = UIColor.blue
        let node = SCNNode()
        node.geometry = geometry
        node.eulerAngles.x = -.pi / 2
        node.position.z = 0.1
        let parentNode = SCNNode()
        parentNode.addChildNode(node)
        return parentNode
    }()
    
    var rightEye: SCNNode = {
        let geometry = SCNCone(topRadius: 0.005, bottomRadius: 0, height: 0.2)
        geometry.radialSegmentCount = 3
        geometry.firstMaterial?.diffuse.contents = UIColor.blue
        let node = SCNNode()
        node.geometry = geometry
        node.eulerAngles.x = -.pi / 2
        node.position.z = 0.1
        let parentNode = SCNNode()
        parentNode.addChildNode(node)
        return parentNode
    }()

    var virtualPhoneNode: SCNNode = {
        let geometry = SCNPlane(width: 1, height: 1)
        geometry.firstMaterial?.isDoubleSided = true
        geometry.firstMaterial?.diffuse.contents = UIColor.blue
        let node = SCNNode()
        node.geometry = geometry
        return node
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        UIApplication.shared.isIdleTimerDisabled = true

        sceneView.pointOfView?.addChildNode(virtualPhoneNode)
        
        // set camera to center of screen
        sceneView.pointOfView?.position.x = 207.0
        sceneView.pointOfView?.position.y = 448.0
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

    // MARK: - ARSCNViewDelegate
    
    // add face mesh
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let faceMesh = ARSCNFaceGeometry(device: sceneView.device!)
        let node = SCNNode(geometry: faceMesh)
        node.geometry?.firstMaterial?.fillMode = .lines
        
        // add nodes to face
        node.addChildNode(leftEye)
        node.addChildNode(rightEye)
        
        // add target to eyes
        leftEye.addChildNode(leftEyeEnd)
        rightEye.addChildNode(rightEyeEnd)
        
        return node
    }
    
    func averageDistance() {
        // Distance of the eyes to the camera don't have to subtract because the center of worldPosition (camera) is (0,0,0)
        let distanceL = leftEye.worldPosition
        let distanceR = rightEye.worldPosition
        
        // euqludian distance
        let distanceLLength = sqrt(distanceL.x*distanceL.x + distanceL.y*distanceL.y + distanceL.z*distanceL.z)
        let distanceRLength = sqrt(distanceR.x*distanceR.x + distanceR.y*distanceR.y + distanceR.z*distanceR.z)
        
        let distance = (distanceLLength + distanceRLength) / 2

        DispatchQueue.main.async{
            self.distanceLabel.text = "\(Int(round(distance * 100))) cm"
        }
    }
    
    func smoothing() {
        let threshold = 50
        let points = gazePoints.suffix(threshold)
        
        var sumX = 0
        var sumY = 0
        for point in points {
            sumX += Int(point.x)
            sumY += Int(point.y)
        }
        
        let avgX = sumX / gazePoints.count
        let avgY = sumY / gazePoints.count
        

    }
    
    func hitTest() {
        guard let rightEyeHitTestResults = self.virtualPhoneNode.hitTestWithSegment(
            from: rightEye.worldPosition,
            to: rightEyeEnd.worldPosition,
            options: nil
        ).first else { return }
        
        guard let leftEyeHitTestResults = self.virtualPhoneNode.hitTestWithSegment(
            from: leftEye.worldPosition,
            to: leftEyeEnd.worldPosition,
            options: nil
        ).first else { return }
        
        // number of points for x, half of the screen. from meter to number of points. divide to get half of screen, get points relative to origo
        let rightEyeX = CGFloat(rightEyeHitTestResults.localCoordinates.x) / ((phoneWidth / 2) * phonePointsWidth)
        let rightEyeY = CGFloat(rightEyeHitTestResults.localCoordinates.y) / (phoneHeight / 2) * phonePointsHeight
        
        let leftEyeX = CGFloat(leftEyeHitTestResults.localCoordinates.x) / (phoneWidth / 2) * phonePointsWidth
        let leftEyeY = CGFloat(leftEyeHitTestResults.localCoordinates.y) / (phoneHeight / 2) * phonePointsHeight
        
        let avgX = (rightEyeX + leftEyeX) / 2
        let avgY = -(rightEyeY + leftEyeY) / 2
        
        gazePoints.append(CGPoint(x: avgX, y: avgY))

        DispatchQueue.main.async{
            self.gazeIndicator.center = CGPoint(x: avgX, y: avgY)
        }
    }
    
    // runs when face changes
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry {
            faceGeometry.update(from: faceAnchor.geometry)
            
            leftEye.simdTransform = faceAnchor.leftEyeTransform
            rightEye.simdTransform = faceAnchor.rightEyeTransform
            
            averageDistance()
            hitTest()
        }
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


