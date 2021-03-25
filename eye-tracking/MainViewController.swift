//
//  MainViewController.swift
//  eye-tracking
//
//  Created by moa on 2021-02-16.
//

import UIKit
import SwiftUI

struct Participant {
    static var data: Participant = Participant()
    var id: Int = 0
}

struct CalibrationData {
    static var data: CalibrationData = CalibrationData()
    var result: [Int: CGPoint] = [:]
    var isCalibrated: Bool = false
    
    var calibrationPoints = [
        // bottom-left
        CGPoint(
            x: UIScreen.main.bounds.width*0.05,
            y: UIScreen.main.bounds.height - (UIScreen.main.bounds.height*0.05)
        ),
        // bottom-right
        CGPoint(
            x: UIScreen.main.bounds.width - (UIScreen.main.bounds.width*0.05),
            y: UIScreen.main.bounds.height - (UIScreen.main.bounds.height*0.05)
        ),
        // top-right
        CGPoint(
            x: UIScreen.main.bounds.width - (UIScreen.main.bounds.width*0.05),
            y: UIScreen.main.bounds.height*0.05
        ),
        // top-left
        CGPoint(
            x: UIScreen.main.bounds.width*0.05,
            y: UIScreen.main.bounds.height*0.05
        ),
        CGPoint(
            x: UIScreen.main.bounds.width/2,
            y: UIScreen.main.bounds.height/2
        ),
    ]
}


class MainViewController: UIViewController {
    @IBOutlet weak var textField: UITextField!
    
    // add particpant id to result
    @objc func textFieldDidChange(_ textField: UITextField) {
        let id = (Int(textField.text!))
        if (id != nil) {
            Participant.data.id = id!
        }
    }

    override func viewDidLoad() {
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        super.viewDidLoad()
    }
}

