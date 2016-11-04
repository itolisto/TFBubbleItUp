//
//  TFContactCollectionCellCollectionViewCell.swift
//  TFContactCollection
//
//  Created by Aleš Kocur on 12/09/15.
//  Copyright © 2015 The Funtasty. All rights reserved.
//
//  Edited by Edgar Gomez on 01/04/16.
//  Delegates now return index of tags plus new delegate method when tags are deleted

import UIKit

enum TFBubbleItUpViewCellMode {
    case edit, view, invalid
}

protocol TFBubbleItUpViewCellDelegate {
    func didChangeText(_ cell: TFBubbleItUpViewCell, text: String)
    func needUpdateLayout(_ cell: TFBubbleItUpViewCell)
    func createAndSwitchToNewCell(_ cell: TFBubbleItUpViewCell)
    func editingDidEnd(_ cell: TFBubbleItUpViewCell, text: String)
    func shouldDeleteCellInFrontOfCell(_ cell: TFBubbleItUpViewCell)
}

class TFBubbleItUpViewCell: UICollectionViewCell, UITextFieldDelegate {
    
    var textField: UITextField!
    
    var mode: TFBubbleItUpViewCellMode = .view
    var delegate: TFBubbleItUpViewCellDelegate?
    
    class var identifier: String {
        return "TFContactCollectionCellCollectionViewCell"
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        self.clipsToBounds = true
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    func commonInit() {
        self.layer.cornerRadius = 2.0
        self.layer.masksToBounds = true
        
        self.textField = TFTextField()
        
        self.textField.translatesAutoresizingMaskIntoConstraints = false
        
        self.addSubview(self.textField)
        
        
        // Setup constraints
        let views = ["field": self.textField]
        
        let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[field]-0-|", options: NSLayoutFormatOptions(), metrics: nil, views: views)
        let verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|-(-4)-[field]-(-4)-|", options: NSLayoutFormatOptions(), metrics: nil, views: views)
        
        self.addConstraints(horizontalConstraints)
        self.addConstraints(verticalConstraints)
        
        self.textField.delegate = self
        
        self.textField.addTarget(self, action: #selector(TFBubbleItUpViewCell.editingChanged(_:)), for: UIControlEvents.editingChanged)
        self.textField.addTarget(self, action: #selector(TFBubbleItUpViewCell.editingDidBegin(_:)), for: UIControlEvents.editingDidBegin)
        self.textField.addTarget(self, action: #selector(TFBubbleItUpViewCell.editingDidEnd(_:)), for: UIControlEvents.editingDidEnd)
        
        // Setup appearance
        self.textField.borderStyle = UITextBorderStyle.none
        self.textField.textAlignment = .center
        self.textField.contentMode = UIViewContentMode.left
        self.textField.keyboardType = TFBubbleItUpViewConfiguration.keyboardType
        self.textField.returnKeyType = TFBubbleItUpViewConfiguration.returnKey
        self.textField.autocapitalizationType = TFBubbleItUpViewConfiguration.autoCapitalization
        self.textField.autocorrectionType = TFBubbleItUpViewConfiguration.autoCorrection
        
        self.setMode(.view)
        
    }
    
    func setMode(_ mode: TFBubbleItUpViewCellMode) {
        
        var m = mode
        
        if self.textField.text == "" { // If textfield is empty he should look like ready for editing
            m = .edit
        }
        
        switch m {
        case .edit:
            textField.backgroundColor = TFBubbleItUpViewConfiguration.editBackgroundColor
            textField.font = TFBubbleItUpViewConfiguration.editFont
            textField.textColor = TFBubbleItUpViewConfiguration.editFontColor
            self.backgroundColor = TFBubbleItUpViewConfiguration.editBackgroundColor
            self.layer.cornerRadius = CGFloat(TFBubbleItUpViewConfiguration.editCornerRadius)
        case .view:
            textField.backgroundColor = TFBubbleItUpViewConfiguration.viewBackgroundColor
            textField.font = TFBubbleItUpViewConfiguration.viewFont
            textField.textColor = TFBubbleItUpViewConfiguration.viewFontColor
            self.backgroundColor = TFBubbleItUpViewConfiguration.viewBackgroundColor
            self.layer.cornerRadius = CGFloat(TFBubbleItUpViewConfiguration.viewCornerRadius)
        case .invalid:
            textField.backgroundColor = TFBubbleItUpViewConfiguration.invalidBackgroundColor
            textField.font = TFBubbleItUpViewConfiguration.invalidFont
            textField.textColor = TFBubbleItUpViewConfiguration.invalidFontColor
            self.backgroundColor = TFBubbleItUpViewConfiguration.invalidBackgroundColor
            self.layer.cornerRadius = CGFloat(TFBubbleItUpViewConfiguration.invalidCornerRadius)
        }
        
        self.mode = mode
    }
    
    override var intrinsicContentSize : CGSize {
        var textFieldSize = self.textField.sizeThatFits(CGSize(width: CGFloat(FLT_MAX), height: self.textField.bounds.height))
        textFieldSize.width += 30
        
        return textFieldSize
    }
    
    override func becomeFirstResponder() -> Bool {
        
        self.textField.becomeFirstResponder()
        self.setMode(.edit)
        
        return true
    }
    
    override func resignFirstResponder() -> Bool {
        self.textField.resignFirstResponder()
        return true
    }
    
    func configureWithItem(_ item: TFBubbleItem) {
        self.textField.text = item.text
        self.setMode(TFBubbleItUpValidation.isValid(textField.text) ? .view : .invalid)
    }
    
    // MARK:- UITextField delegate
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        if string == " " && TFBubbleItUpViewConfiguration.skipOnWhitespace && TFBubbleItUpValidation.isValid(self.textField.text) {
            self.delegate?.createAndSwitchToNewCell(self)
            
        } else if string == " " && TFBubbleItUpViewConfiguration.skipOnWhitespace {
            
        } else if string == "" && textField.text == "" {
            self.delegate?.shouldDeleteCellInFrontOfCell(self)
            
        } else {
            return self.mode == .edit
        }
        
        return false
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        if (TFBubbleItUpViewConfiguration.skipOnReturnKey) {
            
            if !TFBubbleItUpValidation.isValid(textField.text) {
                
                return false
            } else {
                self.delegate?.createAndSwitchToNewCell(self)
            }
        } else {
            self.textField.resignFirstResponder()
        }
        
        return false
    }
    
    // MARK:- UITextField handlers
    
    func editingChanged(_ textField: UITextField) {
        self.delegate?.didChangeText(self, text: textField.text ?? "")
        self.delegate?.needUpdateLayout(self)
    }
    
    func editingDidBegin(_ textField: UITextField) {
        self.setMode(.edit)
    }
    
    func editingDidEnd(_ textField: UITextField) {
        
        self.setMode(TFBubbleItUpValidation.isValid(textField.text) ? .view : .invalid)
        
        self.delegate?.editingDidEnd(self, text: textField.text ?? "")
    }
    
    
    
}
