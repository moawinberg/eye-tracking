//
//  MainViewController.swift
//  eye-tracking
//
//  Created by moa on 2021-02-16.
//

import UIKit

struct CalibrationData {
    static var data: CalibrationData = CalibrationData()
    var result: [Int: CGPoint] = [:]
    var isCalibrated: Bool = false
    
    var calibrationPoints = [
        // bottom-left
        CGPoint(
            x: UIScreen.main.bounds.width*0.08,
            y: UIScreen.main.bounds.height - (UIScreen.main.bounds.height*0.08)
        ),
        // bottom-right
        CGPoint(
            x: UIScreen.main.bounds.width - (UIScreen.main.bounds.width*0.08),
            y: UIScreen.main.bounds.height - (UIScreen.main.bounds.height*0.08)
        ),
        // top-right
        CGPoint(
            x: UIScreen.main.bounds.width - (UIScreen.main.bounds.width*0.08),
            y: UIScreen.main.bounds.height*0.08
        ),
        // top-left
        CGPoint(
            x: UIScreen.main.bounds.width*0.08,
            y: UIScreen.main.bounds.height*0.08
        )
    ]
}

class MainViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

