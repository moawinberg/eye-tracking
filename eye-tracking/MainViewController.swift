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
}

class MainViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

