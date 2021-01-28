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

extension CGFloat {

    func clamped(to: ClosedRange<CGFloat>) -> CGFloat {
        return to.lowerBound > self ? to.lowerBound
            : to.upperBound < self ? to.upperBound
            : self
    }
}

struct Constants {

    struct Device {
        static let screenSize = CGSize(width: 0.0623908297, height: 0.135096943231532)
        static let frameSize = CGSize(width: 375, height: 812)
    }

    struct Ranges {
        static let widthRange: ClosedRange<CGFloat> = (0...CGFloat(414))
        static let heightRange: ClosedRange<CGFloat> = (0...CGFloat(896))
    }

    struct Colors {
        static let crosshairColor: UIColor = .white
    }
}

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
    var phonePixelWidth = CGFloat(828)
    var phonePixelHeight = CGFloat(1792)
    
    var screenPointsX: [CGFloat] = []
    var screenPointsY: [CGFloat] = []
    
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
        node.position.z = 1
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
        let threshold = 5
        
        let pointsX = screenPointsX.suffix(threshold)
        let pointsY = screenPointsY.suffix(threshold)
        
        var sumX = CGFloat(0);
        for point in pointsX {
           sumX += point
        }
        
        var sumY = CGFloat(0);
        for point in pointsY {
           sumY += point
        }
        
        var avgX = sumX / CGFloat(pointsX.count)
        var avgY = sumY / CGFloat(pointsY.count)
        
        avgX = avgX.clamped(to: Constants.Ranges.widthRange)
        avgY = avgY.clamped(to: Constants.Ranges.heightRange)
        
        DispatchQueue.main.async {
           // self.gazeIndicator.center.x = CGFloat(avgX)
            self.gazeIndicator.center.y = CGFloat(avgY)
            // self.gazeIndicator.center = CGPoint(x: CGFloat(p_raster_x), y: CGFloat(p_raster_y))
        }
    }
    
    func rasterization() {
        var p_world_right = SCNVector4(x: rightEye.worldPosition.x, y: rightEye.worldPosition.y, z: rightEye.worldPosition.z, w: 1)
        var p_world_left = SCNVector4(x: leftEye.worldPosition.x, y: leftEye.worldPosition.y, z: leftEye.worldPosition.z, w: 1)
        
        let rightEyeNode: SCNNode = {
            let node = SCNNode()
            node.position.x = rightEye.worldPosition.x
            node.position.y = rightEye.worldPosition.y
            node.position.z = rightEye.worldPosition.z
            let parentNode = SCNNode()
            parentNode.addChildNode(node)
            return parentNode
        }()
        
        let leftEyeNode: SCNNode = {
            let node = SCNNode()
            node.position.x = leftEye.worldPosition.x
            node.position.y = leftEye.worldPosition.y
            node.position.z = leftEye.worldPosition.z
            let parentNode = SCNNode()
            parentNode.addChildNode(node)
            return parentNode
        }()
        
        rightEyeNode.simdTransform = rightEye.simdTransform
        leftEyeNode.simdTransform = leftEye.simdTransform
        
        let matrix_world_to_local_right = rightEye.simdTransform
        let matrix_world_to_local_left = leftEye.simdTransform
        
        let p_local_right = SIMD4<Float>(p_world_right) * matrix_world_to_local_right.inverse
        let p_local_left = SIMD4<Float>(p_world_left) * matrix_world_to_local_left.inverse
        
        let camera = sceneView.session.currentFrame?.camera
        let p_camera_right = SIMD4<Float>(p_local_right) * camera!.viewMatrix(for: .portrait).inverse
        let p_camera_left = SIMD4<Float>(p_local_left) * camera!.viewMatrix(for: .portrait).inverse
        
        let p_x_right = p_camera_right.x / -p_camera_right.z
        let p_x_left = p_camera_left.x / -p_camera_left.z
    
        let p_y_right = p_camera_right.y / -p_camera_right.z
        let p_y_left = p_camera_left.y / -p_camera_left.z
        
        let p_x = (p_x_right + p_x_left) / 2
        let p_y = (p_y_right + p_y_left) / 2
        
        if abs(CGFloat(p_x)) <= phoneWidth/2 || abs(CGFloat(p_y)) <= phoneHeight/2 {
            let p_normalized_x  = (CGFloat(p_x) + phoneWidth/2) / phoneWidth
            let p_normalized_y  = (CGFloat(p_y) + phoneHeight/2) / phoneHeight
            
            let p_raster_x = floor(p_normalized_x * phonePixelWidth)
            let p_raster_y = floor(p_normalized_y * phonePixelHeight)
            
            screenPointsX.append(p_raster_x)
            screenPointsY.append(p_raster_y)
            
            smoothing()
        }
    }

    // runs when face changes
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry {
            faceGeometry.update(from: faceAnchor.geometry)
            
            leftEye.simdTransform = faceAnchor.leftEyeTransform
            rightEye.simdTransform = faceAnchor.rightEyeTransform
            
            averageDistance()
            rasterization()
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


