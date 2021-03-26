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
    @IBOutlet weak var calibrationBtn: UIButton!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var readingBtn: UIButton!
    
    // add particpant id to result
    @objc func textFieldDidChange(_ textField: UITextField) {
        let id = (Int(textField.text!))
        
        if (id != nil) {
            Participant.data.id = id!
            self.label.isHighlighted = false
            self.calibrationBtn.isEnabled = true
            self.readingBtn.isEnabled = true
            
            self.calibrationBtn.alpha = 1.0
            self.readingBtn.alpha = 1.0
        } else {
            self.label.isHighlighted = true
            self.textField.isHighlighted = true
            self.calibrationBtn.isEnabled = false
            self.readingBtn.isEnabled = false
            self.calibrationBtn.alpha = 0.5
            self.readingBtn.alpha = 0.5
        }
    }

    override func viewDidLoad() {
        self.label.isHighlighted = true
        textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        textField.addDoneButtonToKeyboard(myAction:  #selector(self.textField.resignFirstResponder))
        
        super.viewDidLoad()
    }
}

