//
//  MainViewController.swift
//  eye-tracking
//
//  Created by moa on 2021-02-16.
//

import UIKit
import SwiftUI

extension UITextField {
    func addDoneButtonToKeyboard(myAction:Selector?) {
        let doneToolbar: UIToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 300, height: 40))
        doneToolbar.barStyle = UIBarStyle.default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Done", style: UIBarButtonItem.Style.done, target: self, action: myAction)

        var items = [UIBarButtonItem]()
        items.append(flexSpace)
        items.append(done)

        doneToolbar.items = items
        doneToolbar.sizeToFit()

        self.inputAccessoryView = doneToolbar
    }
}

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
        0: CGPoint(
            x: UIScreen.main.bounds.width*0.05,
            y: UIScreen.main.bounds.height - (UIScreen.main.bounds.height*0.05)
        ),
        // bottom-right
        1: CGPoint(
            x: UIScreen.main.bounds.width - (UIScreen.main.bounds.width*0.05),
            y: UIScreen.main.bounds.height - (UIScreen.main.bounds.height*0.05)
        ),
        // top-right
        2: CGPoint(
            x: UIScreen.main.bounds.width - (UIScreen.main.bounds.width*0.05),
            y: UIScreen.main.bounds.height*0.05
        ),
        // top-left
        3: CGPoint(
            x: UIScreen.main.bounds.width*0.05,
            y: UIScreen.main.bounds.height*0.05
        ),
        4: CGPoint(
            x: UIScreen.main.bounds.width/2,
            y: UIScreen.main.bounds.height/2
        ),
    ]
}

struct ValidationData {
    static var data: ValidationData = ValidationData()
    var index = Int(1)
    var result: [Int: Dictionary<String, Any>] = [:]
    
    var validationPoints = [
        // bottom
        0: CGPoint(
            x: UIScreen.main.bounds.width/2,
            y: UIScreen.main.bounds.height - (UIScreen.main.bounds.height*0.05)
        ),
        // right
        1: CGPoint(
            x: UIScreen.main.bounds.width - (UIScreen.main.bounds.width*0.05),
            y: UIScreen.main.bounds.height/2
        ),
        2:
        // top
        CGPoint(
            x: UIScreen.main.bounds.width/2,
            y: UIScreen.main.bounds.height*0.05
        ),
        // left
        3: CGPoint(
            x: UIScreen.main.bounds.width*0.05,
            y: UIScreen.main.bounds.height/2
        ),
        // centre
        4: CGPoint(
            x: UIScreen.main.bounds.width/2,
            y: UIScreen.main.bounds.height/2
        ),
    ]
}


class MainViewController: UIViewController {
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var calibrationBtn: UIButton!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var readingBtn: UIButton!
    
    // add particpant id to result
    @objc func textFieldDidChange(_ textField: UITextField) {
        let id = (Int(textField.text!))
        var highlighted = true
        var alpha = CGFloat(0.5)
        var enabled = false
        
        if (id != nil) {
            Participant.data.id = id!
            highlighted = false
            alpha = CGFloat(1.0)
            enabled = true
        }
        self.label.isHighlighted = highlighted
        self.textField.isHighlighted = highlighted
        self.calibrationBtn.isEnabled = enabled
        self.readingBtn.isEnabled = enabled
        self.calibrationBtn.alpha = alpha
        self.readingBtn.alpha = alpha
    }

    override func viewDidLoad() {
        self.label.isHighlighted = true
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        textField.addDoneButtonToKeyboard(myAction:  #selector(self.textField.resignFirstResponder))
        
        super.viewDidLoad()
    }
}

