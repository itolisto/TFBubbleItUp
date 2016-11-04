//
//  TFContactCollectionConfiguration.swift
//  TFContactCollection
//
//  Created by Aleš Kocur on 13/09/15.
//  Copyright © 2015 The Funtasty. All rights reserved.
//

import Foundation
import UIKit

public enum NumberOfItems {
    case unlimited
    case quantity(Int)
}

open class TFBubbleItUpViewConfiguration {
    
    /// Background color for cell in normal state
    open static var viewBackgroundColor: UIColor = UIColor(red: 0.918, green: 0.933, blue: 0.949, alpha: 1.00)
    
    /// Background color for cell in edit state
    open static var editBackgroundColor: UIColor = UIColor.white
    
    /// Background color for cell in invalid state
    open static var invalidBackgroundColor: UIColor = UIColor.white
    
    /// Font for cell in normal state
    open static var viewFont: UIFont = UIFont.systemFont(ofSize: 12.0)
    
    /// Font for cell in normal state
    open static var placeholderFont: UIFont = UIFont.systemFont(ofSize: 12.0)
    
    /// Font for cell in edit state
    open static var editFont: UIFont = UIFont.systemFont(ofSize: 12.0)
    
    /// Font for cell in invalid state
    open static var invalidFont: UIFont = UIFont.systemFont(ofSize: 12.0)
    
    /// Font color for cell in view state
    open static var viewFontColor: UIColor = UIColor(red: 0.353, green: 0.388, blue: 0.431, alpha: 1.00)
    
    /// Font color for cell in edit state
    open static var editFontColor: UIColor = UIColor(red: 0.510, green: 0.553, blue: 0.596, alpha: 1.00)

    /// Font color for cell in invalid state
    open static var invalidFontColor: UIColor = UIColor(red: 0.510, green: 0.553, blue: 0.596, alpha: 1.00)
    
    /// Font color for cell in invalid state
    open static var placeholderFontColor: UIColor = UIColor(red: 0.510, green: 0.553, blue: 0.596, alpha: 1.00)
    
    /// Corner radius for cell in view state
    open static var viewCornerRadius: Float = 2.0
    
    /// Corner radius for cell in edit state
    open static var editCornerRadius: Float = 2.0

    /// Corner radius for cell in invalid state
    open static var invalidCornerRadius: Float = 2.0

    /// Height for item
    open static var cellHeight: Float = 25.0
    
    /// View insets
    open static var inset: UIEdgeInsets = UIEdgeInsetsMake(5, 5, 5, 5)
    
    /// Interitem spacing
    open static var interitemSpacing: CGFloat = 5.0
    
    /// Line spacing
    open static var lineSpacing: CGFloat = 5.0
    
    /// Keyboard type
    open static var keyboardType: UIKeyboardType = UIKeyboardType.emailAddress
    
    /// Keyboard return key
    open static var returnKey: UIReturnKeyType = UIReturnKeyType.done
    
    /// Field auto-capitalization type
    open static var autoCapitalization: UITextAutocapitalizationType = UITextAutocapitalizationType.none
    
    /// Field auto-correction type
    open static var autoCorrection: UITextAutocorrectionType = UITextAutocorrectionType.no
    
    /// If true it creates new item when user types whitespace
    open static var skipOnWhitespace: Bool = true
    
    /// If true it creates new item when user press the keyboards return key. Otherwise resigns first responder
    open static var skipOnReturnKey: Bool = false
    
    /// Number of items that could be written
    open static var numberOfItems: NumberOfItems = .unlimited
    
    /// Item has to pass validation before it can be bubbled
    open static var itemValidation: Validation? = nil
    
}
