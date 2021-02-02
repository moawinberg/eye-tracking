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
    var phoneHeight = CGFloat(0.1509)
    var phoneWidth = CGFloat(0.0757)
    var phonePixelWidth = CGFloat(1792) // in landscape mode
    var phonePixelHeight = CGFloat(828)
    
    var screenPointsX: [CGFloat] = []
    var screenPointsY: [CGFloat] = []
    
    var leftEye: SCNNode = {
        let geometry = SCNCone(topRadius: 0.005, bottomRadius: 0, height: 0.2)
        geometry.radialSegmentCount = 3
        geometry.firstMaterial?.diffuse.contents = UIColor.blue
        let node = SCNNode()
        node.geometry = geometry
        node.eulerAngles.x = -.pi / 2
        node.position.z = 1
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
        node.position.z = 1
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
    
    func rasterization2() {
        var vr = rightEye.simdTransform * simd_float4(x: rightEye.worldPosition.x, y: rightEye.worldPosition.y, z: rightEye.worldPosition.z, w: 1)
        var vl = leftEye.simdTransform * simd_float4(x: leftEye.worldPosition.x, y: leftEye.worldPosition.y, z: leftEye.worldPosition.z, w: 1)
        
        vr = vr / vr.w
        vl = vl / vl.w
        
        // kanske dela på w istället!!
        let v1 = simd_float3(x: vl.x, y: vl.y, z: vl.z)
        let v2 = simd_float3(x: vr.x, y: vr.y, z: vr.z)
        
        let camera = sceneView.session.currentFrame?.camera
        
        // which rotation to use??
//        var R = matrix_identity_float3x3
//        R[0,0] = camera!.transform[0,0]
//        R[0,1] = camera!.transform[0,1]
//        R[0,2] = camera!.transform[0,2]
//        R[1,0] = camera!.transform[1,0]
//        R[1,1] = camera!.transform[1,1]
//        R[1,2] = camera!.transform[1,2]
//        R[2,0] = camera!.transform[2,0]
//        R[2,1] = camera!.transform[2,1]
//        R[2,2] = camera!.transform[2,2]
        
        // in portrait mode, x axis is y axis
        
        // rotate camerea in beginning + rotate with movement in this function?

        let yaw = camera!.eulerAngles.x
        let R = simd_float3x3([[cos(yaw), 0, sin(yaw)], [0, 1, 0], [-sin(yaw), 0, cos(yaw)]]);
//
        let cameraPos = simd_float3(camera!.transform.columns.3.x, camera!.transform.columns.3.y, -camera!.transform.columns.3.z)
        
        let focalLength = camera!.intrinsics.columns.0.x

        let T_l = R * (v1 - cameraPos)
        let T_r = R * (v2 - cameraPos)
        
        // x, y = f X/Z+W2 (4) start in lower left, check offset values!
        let p_right_x = focalLength * (T_r.x / T_r.z) + Float(phonePixelWidth/2)
        let p_right_y = focalLength * (T_r.y / T_r.z) + Float(phonePixelHeight)
    
        let p_left_x = focalLength * (T_l.x / T_l.z) + Float(phonePixelWidth/2)
        let p_left_y = focalLength * (T_l.y / T_l.z) + Float(phonePixelHeight)
        
        let avgX = (p_right_x + p_left_x) / 2
        let avgY = -(p_right_y + p_left_y) / 2
        
        screenPointsX.append(CGFloat(avgX))
        screenPointsY.append(CGFloat(avgY))
        
        smoothing()
        // 1.1 Perspective Projection of Points from 3D to 2D x = f X/Z+W2
        
        // 1.2 Translation  P' = P - C
        
        // 1.3 Rotation P' = P R
        
        // 1.4 Translation & Rotation P' = (P - C) R

        
        let p_point = SCNVector3(x: leftEye.worldPosition.x, y: leftEye.worldPosition.y, z: leftEye.worldPosition.z)

    }
    
    func rasterization() {
        // focal length = sceneView.pointOfView?.camera?.focalLength [mm]
        // frame?.camera.intrinsics
        // sceneView.pointOfView?.camera?.fieldOfView
        // sceneView.sessions.currentFrame.camera.projectionMatrix
        
        // https://www.cs.princeton.edu/courses/archive/spring20/cos426/lectures/Lecture-14.pdf

        var focalLength = sceneView.pointOfView?.camera?.focalLength
        
        // find point in local coordinate system
        let p_world_right = SCNVector4(x: rightEye.worldPosition.x, y: rightEye.worldPosition.y, z: rightEye.worldPosition.z, w: 1)
        let p_world_left = SCNVector4(x: leftEye.worldPosition.x, y: leftEye.worldPosition.y, z: leftEye.worldPosition.z, w: 1)
        
        let matrix_world_to_local_right = rightEye.simdTransform
        let matrix_world_to_local_left = leftEye.simdTransform
        
        let p_local_right = SIMD4<Float>(p_world_right) * matrix_world_to_local_right
        let p_local_left = SIMD4<Float>(p_world_left) * matrix_world_to_local_left
        
        // find point in camera system
        let camera = sceneView.session.currentFrame?.camera
        let p_camera_right = camera!.viewMatrix(for: .portrait) * SIMD4<Float>(p_local_right)
        let p_camera_left = camera!.viewMatrix(for: .portrait) *  SIMD4<Float>(p_local_left)
        
        let p_x_right = CGFloat(focalLength!) * CGFloat(p_camera_right.x / -p_camera_right.z)
        let p_x_left = CGFloat(focalLength!) * CGFloat(p_camera_left.x / -p_camera_left.z)
    
        let p_y_right =  CGFloat(focalLength!) * CGFloat(p_camera_right.y / p_camera_right.z)
        let p_y_left =  CGFloat(focalLength!) * CGFloat(p_camera_left.y / p_camera_left.z)
        
        // get average point of both eyes
        let p_x = CGFloat((p_x_right + p_x_left) / 2)
        let p_y = CGFloat((p_y_right + p_y_left) / 2)
        
        // check if point is visible
        if abs(CGFloat(p_x)) <= phoneWidth/2 || abs(CGFloat(p_y)) <= phoneHeight/2 {
            // Normalized Device Coordinate system. Remaps the point's coordinates in the range [0,1]
            let p_normalized_x  = (CGFloat(p_x) + phoneWidth/2) / phoneWidth
            let p_normalized_y  = (CGFloat(p_y) + phoneHeight/2) / phoneHeight
            
            // define coordinates in raster space
            let p_raster_x = floor(p_normalized_x * phonePixelWidth)
            let p_raster_y = floor(p_normalized_y * phonePixelHeight)
            /// 1pixel  = 0.75point
            
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
            rasterization2()
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


