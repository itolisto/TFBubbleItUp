//
//  TFContactCollection.swift
//  TFContactCollection
//
//  Created by Aleš Kocur on 12/09/15.
//  Copyright © 2015 The Funtasty. All rights reserved.
//
//  Edited by Edgar Gomez on 01/04/16.
//  Delegates now return index of tags plus new delegate method when tags are deleted

import UIKit

public struct TFBubbleItem {
    var text: String
    var becomeFirstResponder: Bool = false
    
    init(text: String, becomeFirstResponder: Bool = false) {
        self.text = text
        self.becomeFirstResponder = becomeFirstResponder
    }
}

enum DataSourceOperationError: ErrorType {
    case OutOfBounds
}

@objc public protocol TFBubbleItUpViewDelegate {
    func bubbleItUpViewDidFinishEditingBubble(view: TFBubbleItUpView, text: String, index: Int)
    func bubbleItUpViewDidDeleteBubbles(view: TFBubbleItUpView, text: String, actualIndex: Int, otherIndex: Int)
    optional func bubbleItUpViewDidChange(view: TFBubbleItUpView, text: String, index: Int)
}

@IBDesignable public class TFBubbleItUpView: UICollectionView, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource, UIGestureRecognizerDelegate, TFBubbleItUpViewCellDelegate {
    
    private var items: [TFBubbleItem] = []
    private var sizingCell: TFBubbleItUpViewCell!
    private var tapRecognizer: UITapGestureRecognizer!
    private var placeholderLabel: UILabel!
    
    public var bubbleItUpDelegate: TFBubbleItUpViewDelegate?
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.collectionViewLayout = TFBubbleItUpViewFlowLayout()
        self.customInit()
    }
    
    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: TFBubbleItUpViewFlowLayout())
        self.customInit()
        
    }
    
    func customInit() {
        // Load sizing cell for width calculation
        self.sizingCell = TFBubbleItUpViewCell(frame: CGRectMake(0, 0, 100, CGFloat(TFBubbleItUpViewConfiguration.cellHeight)))
        
        self.backgroundColor = UIColor.whiteColor()
        var frame = self.bounds
        frame.size.height = self.minimumHeight()
        self.placeholderLabel = UILabel(frame: CGRectInset(frame, 20, 0))
        let view = UIView(frame: frame)
        view.addSubview(self.placeholderLabel)
        self.backgroundView = view
        self.placeholderLabel.font = TFBubbleItUpViewConfiguration.placeholderFont
        self.placeholderLabel.textColor = TFBubbleItUpViewConfiguration.placeholderFontColor
        
        self.registerClass(TFBubbleItUpViewCell.self, forCellWithReuseIdentifier: TFBubbleItUpViewCell.identifier)
        
        self.dataSource = self
        self.delegate = self
        
        if let layout = self.collectionViewLayout as? TFBubbleItUpViewFlowLayout {
            layout.sectionInset = TFBubbleItUpViewConfiguration.inset
            layout.minimumInteritemSpacing = TFBubbleItUpViewConfiguration.interitemSpacing
            layout.minimumLineSpacing = TFBubbleItUpViewConfiguration.lineSpacing
        }
        
        self.tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(TFBubbleItUpView.didTapOnView(_:)))
        self.addGestureRecognizer(self.tapRecognizer)
    }
    
    public override func prepareForInterfaceBuilder() {
        self.setItems([TFBubbleItem(text: "exm@ex.com"), TFBubbleItem(text: "hello@thefuntasty.com")])
    }
    
    // MARK:- Public API
    
    /// Sets new items and reloads sizes
    func setItems(items: [TFBubbleItem]) {
        
        self.items = items
        
        CATransaction.begin()
        CATransaction.setCompletionBlock { () -> Void in
            self.collectionViewLayout.invalidateLayout() // Invalidate layout
            self.invalidateIntrinsicContentSize(nil) // Invalidate intrinsic size
        }
        
        self.reloadData() // Reload collectionView
        
        CATransaction.commit()
    }
    
    public func setStringItems(items: [String]) {
        // Set new items
        var bubbleItems : [TFBubbleItem] = []
        var index : Int = 1
        
        for text in items {
            bubbleItems.append(TFBubbleItem(text: text))
            index += 1
        }
        
        self.setItems(bubbleItems)
    }
    
    /// Returns all non-empty items
    public func stringItems() -> [String] {
        
        return self.items.filter({ (item) -> Bool in item.text != "" }).map({ (item) -> String in item.text })
    }
    
    /// Returns all valid strings
    public func validStrings() -> [String] {
        
        return self.items.filter({ (item) -> Bool in item.text != "" && TFBubbleItUpValidation.isValid(item.text) }).map({ (item) -> String in item.text })
    }
    
    public func setPlaceholderText(text: String) {
        self.placeholderLabel.text = text
    }
    
    public func replaceItemsTextAtPosition(position: Int, withText text: String, resign: Bool = true, completion: (() -> ())? = nil) throws {
        if position < 0 || position >= self.items.count {
            throw DataSourceOperationError.OutOfBounds
        }
        
        self.items[position].text = text
        
        if let cell = self.cellForItemAtIndexPath(NSIndexPath(forItem: position, inSection: 0)) as? TFBubbleItUpViewCell {
            cell.configureWithItem(self.items[position])
            
            self.needUpdateLayout(cell) {
                self.invalidateIntrinsicContentSize() {
                    
                    if resign {
                        cell.resignFirstResponder()
                    }
                    
                    completion?()
                }
                
            }
        } else {
            completion?()
        }
    }
    
    public func replaceLastInvalidOrInsertItemText(text: String, switchToNext: Bool = true, completion: (() -> ())? = nil) {
        
        if let validator = TFBubbleItUpViewConfiguration.itemValidation, let item = self.items.last where !validator(item.text) {
            
            let position = self.items.indexOf({ (i) -> Bool in i.text == item.text })
            
            // Force try because we know that this position exists
            try! self.replaceItemsTextAtPosition(position!, withText: text) {
                
                if switchToNext {
                    self.selectLastPossible()
                }
                completion?()
            }
            
            
        } else {
            addStringItem(text) {
                
                if switchToNext {
                    self.selectLastPossible()
                }
                completion?()
            }
        }
    }
    
    /// Adds item if possible, returning Bool indicates success or failure
    public func addStringItem(text: String, completion: (()->())? = nil) -> Bool {
        
        if self.items.count == self.needPreciseNumberOfItems() && self.items.last?.text != "" {
            
            return false
        }
        
        if self.items.last != nil && self.items.last!.text == ""  {
            self.items[self.items.count - 1].text = text
            
            if let cell = self.cellForItemAtIndexPath(NSIndexPath(forItem: self.items.count - 1, inSection: 0)) as? TFBubbleItUpViewCell {
                cell.configureWithItem(self.items[self.items.count - 1])
                cell.resignFirstResponder()
                self.needUpdateLayout(cell, completion: completion)
            }
            
        } else {
            self.items.append(TFBubbleItem(text: text))
            
            self.performBatchUpdates({ () -> Void in
                let newLastIndexPath = NSIndexPath(forItem: self.items.count - 1, inSection: 0)
                self.insertItemsAtIndexPaths([newLastIndexPath])
            }) { (finished) -> Void in
                // Invalidate intrinsic size when done
                self.invalidateIntrinsicContentSize(completion)
            }
        }
        
        return true
    }
    
    public func removeStringItem(text: String) -> Bool {
        let index = self.items.indexOf { (item) -> Bool in item.text == text }
        
        guard let i = index else {
            
            return false
        }
        
        self.items.removeAtIndex(i)
        
        self.performBatchUpdates({ () -> Void in
            let newLastIndexPath = NSIndexPath(forItem: i, inSection: 0)
            self.deleteItemsAtIndexPaths([newLastIndexPath])
        }) { (finished) -> Void in
            // Invalidate intrinsic size when done
            self.invalidateIntrinsicContentSize(nil)
        }
        
        return true
    }
    
    public override func becomeFirstResponder() -> Bool {
        
        self.selectLastPossible()
        
        return true
    }
    
    // MARK:- Autolayout
    
    override public func intrinsicContentSize() -> CGSize {
        // Calculate custom intrinsic size by collectionViewLayouts contentent size
        let size = (self.collectionViewLayout as! UICollectionViewFlowLayout).collectionViewContentSize()
        
        return CGSizeMake(CGRectGetWidth(self.bounds), max(self.minimumHeight(), size.height))
    }
    
    func minimumHeight() -> CGFloat {
        let defaultHeight: CGFloat = CGFloat(TFBubbleItUpViewConfiguration.cellHeight)
        let padding = TFBubbleItUpViewConfiguration.inset.top + TFBubbleItUpViewConfiguration.inset.bottom
        
        return defaultHeight + padding
    }
    
    private func invalidateIntrinsicContentSize(completionBlock: (() -> ())?) {
        
        if self.intrinsicContentSize() != self.bounds.size {
            UIView.animateWithDuration(0.2, animations: { () -> Void in
                self.invalidateIntrinsicContentSize()
                
            }) { (finished) -> Void in
                completionBlock?()
            }
        } else {
            //self.invalidateIntrinsicContentSize()
            completionBlock?()
        }
    }
    
    // MARK:- Handling gestures
    
    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldReceiveTouch touch: UITouch) -> Bool {
        
        if gestureRecognizer != self.tapRecognizer {
            return false
        }
        
        if let view = touch.view where view.isKindOfClass(TFBubbleItUpViewCell) {
            return false
        } else {
            return true
        }
    }
    
    func didTapOnView(sender: AnyObject) {
        self.selectLastPossible()
    }
    
    internal func selectLastPossible() {
        if let last = self.items.last where last.text == "" || !isTextValid(last.text) || self.items.count == self.needPreciseNumberOfItems() {
            self.cellForItemAtIndexPath(NSIndexPath(forItem: self.items.count - 1, inSection: 0))?.becomeFirstResponder()
        } else {
            
            if self.items.count == 0 {
                self.placeholderLabel.hidden = true
            }
            
            // insert new data item at the end
            self.items.append(TFBubbleItem(text: "", becomeFirstResponder: true))
            
            // Update collectionView
            self.performBatchUpdates({ () -> Void in
                self.insertItemsAtIndexPaths([NSIndexPath(forItem: self.items.count - 1, inSection:0)])
            }) { (finished) -> Void in
                // Invalidate intrinsic size when done
                self.invalidateIntrinsicContentSize(nil)
            }
        }
    }
    
    func isTextValid(text: String) -> Bool {
        if let validation = TFBubbleItUpViewConfiguration.itemValidation {
            return validation(text)
        } else {
            return true
        }
    }
    
    // MARK:- UICollectionViewDelegate and datasource
    
    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell: TFBubbleItUpViewCell = collectionView.dequeueReusableCellWithReuseIdentifier(TFBubbleItUpViewCell.identifier, forIndexPath: indexPath) as! TFBubbleItUpViewCell
        
        cell.delegate = self
        
        let item = self.items[indexPath.item]
        cell.configureWithItem(item)
        
        return cell
    }
    
    public func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        var item = self.items[indexPath.item]
        
        if item.becomeFirstResponder {
            cell.becomeFirstResponder()
            item.becomeFirstResponder = false
        }
    }
    
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return self.items.count
    }
    
    public func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        
        return 1
    }
    
    // MARK:- UICollectionViewFlowLayout delegate
    
    public func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        
        if indexPath.item >= self.items.count {
            return CGSizeMake(0.0, CGFloat(TFBubbleItUpViewConfiguration.cellHeight))
        }
        
        let item = self.items[indexPath.item]
        
        self.sizingCell.textField.text = item.text
        let size = self.sizingCell.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
        
        let layoutInset = (self.collectionViewLayout as! UICollectionViewFlowLayout).sectionInset
        let maximumWidth = CGRectGetWidth(self.bounds) - layoutInset.left - layoutInset.right
        
        return CGSizeMake(min(size.width, maximumWidth), CGFloat(TFBubbleItUpViewConfiguration.cellHeight))
    }
    
    // MARK:- TFContactCollectionCellDelegate
    
    internal func didChangeText(cell: TFBubbleItUpViewCell, text: String) {
        if let indexPath = self.indexPathForCell(cell) {
            if indexPath.item < self.items.count {
                self.items[indexPath.item].text = text
            } else {
                return
            }
        }
        
        self.bubbleItUpDelegate?.bubbleItUpViewDidChange?(self, text:text, index:(self.indexPathForCell(cell)?.item)!)
    }
    
    internal func needUpdateLayout(cell: TFBubbleItUpViewCell) {
        self.needUpdateLayout(cell, completion:nil)
    }
    
    func needUpdateLayout(cell: TFBubbleItUpViewCell, completion: (() -> ())?) {
        self.collectionViewLayout.invalidateLayout()
        
        // Update cell frame by its intrinsic size
        var frame = cell.frame
        frame.size.width = cell.intrinsicContentSize().width
        cell.frame = frame
        
        self.invalidateIntrinsicContentSize(completion)
    }
    
    internal func createAndSwitchToNewCell(cell: TFBubbleItUpViewCell) {
        
        // If no indexpath found return
        guard let indexPath = self.indexPathForCell(cell) else {
            return
        }
        
        // If user tries to create new cell when he already has one
        if cell.textField.text == "" {
            return
        }
        
        cell.setMode(.View)
        
        if let preciseNumber = self.needPreciseNumberOfItems() where self.items.count == preciseNumber { // If we reach quantity, return
            cell.resignFirstResponder()
            return
        }
        
        // Create indexPath for the last item
        let newIndexPath = NSIndexPath(forItem: self.items.count - 1, inSection: indexPath.section)
        
        // If the next cell is empty, move to it. Otherwise create new.
        if let nextCell = self.cellForItemAtIndexPath(newIndexPath) as? TFBubbleItUpViewCell where nextCell.textField.text == "" {
            
            nextCell.becomeFirstResponder()
            
        } else {
            self.items.append(TFBubbleItem(text: "", becomeFirstResponder: true)) // insert new data item
            
            // Update collectionView
            self.performBatchUpdates({ () -> Void in
                let newLastIndexPath = NSIndexPath(forItem: self.items.count - 1, inSection: indexPath.section)
                self.insertItemsAtIndexPaths([newLastIndexPath])
            }) { (finished) -> Void in
                // Invalidate intrinsic size when done
                self.invalidateIntrinsicContentSize(nil)
                // The new cell should now become the first reponder
                //self.cellForItemAtIndexPath(newIndexPath)?.becomeFirstResponder()
            }
        }
    }
    
    func editingDidEnd(cell: TFBubbleItUpViewCell, text: String) {
        
        guard let indexPath = indexPathForCell(cell) else {
            
            return
        }
        
        if text == "" {
            
            if indexPath.item >= self.items.count {
                return
            }
            
            self.items.removeAtIndex(indexPath.item)
            
            // Update collectionView
            self.performBatchUpdates({ () -> Void in
                self.deleteItemsAtIndexPaths([indexPath])
            }) { (finished) -> Void in
                // Invalidate intrinsic size when done
                self.invalidateIntrinsicContentSize(nil)
                
                if self.items.count == 0 {
                    self.placeholderLabel.hidden = false
                }
            }
            
            self.bubbleItUpDelegate?.bubbleItUpViewDidDeleteBubbles(self, text: text, actualIndex:indexPath.item, otherIndex: -1)
        } else {
            self.bubbleItUpDelegate?.bubbleItUpViewDidFinishEditingBubble(self, text: text, index:indexPath.item)
        }
    }
    
    func shouldDeleteCellInFrontOfCell(cell: TFBubbleItUpViewCell) {
        
        guard let cellsIndexPath = self.indexPathForCell(cell) else {
            assertionFailure("There should be a index for that cell!")
            return
        }
        
        let itemIndex = cellsIndexPath.item
        
        // Don't do anything if there is only one item
        if itemIndex == 0 {
            return
        }
        
        let previousItemIndex = itemIndex - 1
        
        // Remove item
        
        do {
            try self.removeItemAtIndex(previousItemIndex) {
                self.bubbleItUpDelegate?.bubbleItUpViewDidDeleteBubbles(self, text:"", actualIndex:itemIndex, otherIndex: previousItemIndex)
            }
        } catch DataSourceOperationError.OutOfBounds {
            print("Error occured while removing item")
        } catch {
            
        }
    }
    
    //private func updateCellIndex() {
    //    // Update cell index
    //    var temp : Int = 0
    //    let to : Int = self.items.count
    //
    //    //print("updateCellIndex before %@", self.items)
    //
    //    for i in 0 ..< to {
    //        self.items[i] = TFBubbleItem(text: self.items[i].text, becomeFirstResponder: false)
    //        temp += 1
    //    }
    //
    //    //print("updateCellIndex update %@", self.items)
    //}
    
    // MARK: - Helpers
    
    func removeItemAtIndex(index: Int, completion: (() -> ())?) throws {
        
        if self.items.count <= index || index < 0 {
            throw DataSourceOperationError.OutOfBounds
        }
        
        self.items.removeAtIndex(index)
        
        // Update collectionView
        self.performBatchUpdates({ () -> Void in
            self.deleteItemsAtIndexPaths([NSIndexPath(forItem: index, inSection: 0)])
        }) {[weak self] (finished) -> Void in
            // Invalidate intrinsic size when done
            self?.invalidateIntrinsicContentSize(nil)
            completion?()
        }
    }
    
    func needPreciseNumberOfItems() -> Int? {
        switch TFBubbleItUpViewConfiguration.numberOfItems {
        case .Unlimited:
            return nil
        case let .Quantity(value):
            return value
        }
    }
}