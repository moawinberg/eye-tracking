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
    var phonePixelWidth = CGFloat(828)
    var phonePixelHeight = CGFloat(1792)
    
    var screenPointsX: [CGFloat] = []
    var screenPointsY: [CGFloat] = []
    
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
    
    func averageDistance() {
        // euqludian distance of the eyes to the camera don't have to subtract because the center of worldPosition (camera) is (0,0,0)
        let distanceL = sqrt(leftEye.worldPosition.x*leftEye.worldPosition.x + leftEye.worldPosition.y*leftEye.worldPosition.y + leftEye.worldPosition.z*leftEye.worldPosition.z)
        let distanceR = sqrt(rightEye.worldPosition.x*rightEye.worldPosition.x + rightEye.worldPosition.y*rightEye.worldPosition.y + rightEye.worldPosition.z*rightEye.worldPosition.z)
        
        let distance = (distanceL + distanceR) / 2
        
        DispatchQueue.main.async{
            self.distanceLabel.text = "\(Int(round(distance * 100))) cm"
        }
    }
    
    func smoothing() {
        let threshold = 10
        
        // limit number of points in array to threhold
        let pointsX = screenPointsX.suffix(threshold)
        let pointsY = screenPointsY.suffix(threshold)
        
        // get average point in array
        let avgX =  pointsX.reduce(0, +) / CGFloat(pointsX.count)
        let avgY = pointsY.reduce(0, +) / CGFloat(pointsY.count)
        
        // clamp point to screen size
        let pointX = min(max(avgX, 0), CGFloat(phonePointsWidth))
        let pointY = min(max(avgY, 0), CGFloat(phonePointsHeight))
        
        DispatchQueue.main.async {
            // self.gazeIndicator.center.x = CGFloat(pointX)
            // self.gazeIndicator.center.y = CGFloat(pointY)
            self.gazeIndicator.center = CGPoint(x: CGFloat(pointX), y: CGFloat(pointY))
        }
    }
    
    func pinholeCamera() {
        // https://staff.fnwi.uva.nl/r.vandenboomgaard/IPCV20172018/LectureNotes/CV/PinholeCamera/PinholeCamera.html
        // http://www.cs.toronto.edu/~jepson/csc420/notes/imageProjection.pdf
        
        let p_world_right = SIMD4<Float>(x: rightEye.worldPosition.x, y: rightEye.worldPosition.y, z: rightEye.worldPosition.z, w: 1)
        let p_world_left = SIMD4<Float>(x: leftEye.worldPosition.x, y: leftEye.worldPosition.y, z: leftEye.worldPosition.z, w: 1)
        
        let p_local_right = p_world_right * rightEye.simdTransform
        let p_local_left = p_world_left * leftEye.simdTransform
        
        let K = sceneView.session.currentFrame?.camera.intrinsics
        var internalMatrix = matrix_identity_float4x4
        
        // [row, column] add empthy fourth column
        internalMatrix[0,0] = K![0,0]
        internalMatrix[2,0] = K![2,0]
        internalMatrix[1,1] = K![1,1]
        internalMatrix[2,1] = K![2,1]
        internalMatrix[3,3] = K![0,0]
        
        let externalMatrix = sceneView.session.currentFrame?.camera.transform.inverse
        
        var right_point = internalMatrix * externalMatrix! * p_local_right
        var left_point = internalMatrix * externalMatrix! * p_local_left
        
        right_point = right_point / right_point.z
        left_point = left_point / left_point.z

        let avgX = (left_point.x + right_point.x) / 2
        let avgY = (left_point.y + right_point.y) / 2

        screenPointsX.append(CGFloat(avgX))
        screenPointsY.append(CGFloat(avgY))
        
        smoothing()
    }
    
    func rasterization() {
        // focal length = sceneView.pointOfView?.camera?.focalLength [mm]
        // frame?.camera.intrinsics
        
        // find point in local coordinate system
        let p_world_right = SCNVector4(x: rightEye.worldPosition.x, y: rightEye.worldPosition.y, z: rightEye.worldPosition.z, w: 1)
        let p_world_left = SCNVector4(x: leftEye.worldPosition.x, y: leftEye.worldPosition.y, z: leftEye.worldPosition.z, w: 1)
        
        let matrix_world_to_local_right = rightEye.simdTransform.inverse
        let matrix_world_to_local_left = leftEye.simdTransform.inverse
        
        let p_local_right = SIMD4<Float>(p_world_right) * matrix_world_to_local_right
        let p_local_left = SIMD4<Float>(p_world_left) * matrix_world_to_local_left
        
        // find point in camera system
        let camera = sceneView.session.currentFrame?.camera
        let p_camera_right = SIMD4<Float>(p_local_right) * camera!.viewMatrix(for: .portrait).inverse
        let p_camera_left = SIMD4<Float>(p_local_left) * camera!.viewMatrix(for: .portrait).inverse
        
        let p_x_right = p_camera_right.x / -p_camera_right.z
        let p_x_left = p_camera_left.x / -p_camera_left.z
    
        let p_y_right = p_camera_right.y / -p_camera_right.z
        let p_y_left = p_camera_left.y / -p_camera_left.z
        
        // get average point of both eyes
        let p_x = (p_x_right + p_x_left) / 2
        let p_y = (p_y_right + p_y_left) / 2
        
        // check if point is visible
        if abs(CGFloat(p_x)) <= phoneWidth/2 || abs(CGFloat(p_y)) <= phoneHeight/2 {
            // Normalized Device Coordinate system. Remaps the point's coordinates in the range [0,1]
            let p_normalized_x  = (CGFloat(p_x) + phoneWidth/2) / phoneWidth
            let p_normalized_y  = (CGFloat(p_y) + phoneHeight/2) / phoneHeight
            
            // define coordinates in raster space
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
            pinholeCamera()
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


