//
//  ViewController.swift
//  eye-tracking
//
//  Created by moa on 2021-01-11.
//

import UIKit
import ARKit

class ViewController: UIViewController {
    @IBOutlet weak var ARscene: ARSCNView!
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        DispatchQueue.main.async {
            // find face in scene
            // find left and right eye
            // track position
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // create AR scene
        // Do any additional setup after loading the view.
    }


}

