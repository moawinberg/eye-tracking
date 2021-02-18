//
//  MainViewController.swift
//  eye-tracking
//
//  Created by moa on 2021-02-16.
//

import UIKit

struct CalibrationData {
    static var data: CalibrationData = CalibrationData()
    var gazePoints: [Int: CGPoint] = [:]
    var isCalibrated: Bool = false
    var calibrationPoints = [
        CGPoint(x: 50, y: 850), // bottom-left,
        CGPoint(x: 360, y: 850), // bottom-right
        CGPoint(x: 50, y: 50), // top-left
        CGPoint(x: 360, y: 50), // top-right
        CGPoint(x: 207, y: 448) // center
    ]
}

class MainViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

