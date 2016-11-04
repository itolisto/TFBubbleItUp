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

enum DataSourceOperationError: Error {
    case outOfBounds
}

@objc public protocol TFBubbleItUpViewDelegate {
    func bubbleItUpViewDidFinishEditingBubble(_ view: TFBubbleItUpView, text: String, index: Int)
    func bubbleItUpViewDidDeleteBubbles(_ view: TFBubbleItUpView, text: String, actualIndex: Int, otherIndex: Int)
    @objc optional func bubbleItUpViewDidChange(_ view: TFBubbleItUpView, text: String, index: Int)
}

@IBDesignable open class TFBubbleItUpView: UICollectionView, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource, UIGestureRecognizerDelegate, TFBubbleItUpViewCellDelegate {
    
    fileprivate var items: [TFBubbleItem] = []
    fileprivate var sizingCell: TFBubbleItUpViewCell!
    fileprivate var tapRecognizer: UITapGestureRecognizer!
    fileprivate var placeholderLabel: UILabel!
    
    open var bubbleItUpDelegate: TFBubbleItUpViewDelegate?
    
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
        self.sizingCell = TFBubbleItUpViewCell(frame: CGRect(x: 0, y: 0, width: 100, height: CGFloat(TFBubbleItUpViewConfiguration.cellHeight)))
        
        self.backgroundColor = UIColor.white
        var frame = self.bounds
        frame.size.height = self.minimumHeight()
        self.placeholderLabel = UILabel(frame: frame.insetBy(dx: 20, dy: 0))
        let view = UIView(frame: frame)
        view.addSubview(self.placeholderLabel)
        self.backgroundView = view
        self.placeholderLabel.font = TFBubbleItUpViewConfiguration.placeholderFont
        self.placeholderLabel.textColor = TFBubbleItUpViewConfiguration.placeholderFontColor
        
        self.register(TFBubbleItUpViewCell.self, forCellWithReuseIdentifier: TFBubbleItUpViewCell.identifier)
        
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
    
    open override func prepareForInterfaceBuilder() {
        self.setItems([TFBubbleItem(text: "exm@ex.com"), TFBubbleItem(text: "hello@thefuntasty.com")])
    }
    
    // MARK:- Public API
    
    /// Sets new items and reloads sizes
    func setItems(_ items: [TFBubbleItem]) {
        
        self.items = items
        
        CATransaction.begin()
        CATransaction.setCompletionBlock { () -> Void in
            self.collectionViewLayout.invalidateLayout() // Invalidate layout
            self.invalidateIntrinsicContentSize(nil) // Invalidate intrinsic size
        }
        
        self.reloadData() // Reload collectionView
        
        CATransaction.commit()
    }
    
    open func setStringItems(_ items: [String]) {
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
    open func stringItems() -> [String] {
        
        return self.items.filter({ (item) -> Bool in item.text != "" }).map({ (item) -> String in item.text })
    }
    
    /// Returns all valid strings
    open func validStrings() -> [String] {
        
        return self.items.filter({ (item) -> Bool in item.text != "" && TFBubbleItUpValidation.isValid(item.text) }).map({ (item) -> String in item.text })
    }
    
    open func setPlaceholderText(_ text: String) {
        self.placeholderLabel.text = text
    }
    
    open func replaceItemsTextAtPosition(_ position: Int, withText text: String, resign: Bool = true, completion: (() -> ())? = nil) throws {
        if position < 0 || position >= self.items.count {
            throw DataSourceOperationError.outOfBounds
        }
        
        self.items[position].text = text
        
        if let cell = self.cellForItem(at: IndexPath(item: position, section: 0)) as? TFBubbleItUpViewCell {
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
    
    open func replaceLastInvalidOrInsertItemText(_ text: String, switchToNext: Bool = true, completion: (() -> ())? = nil) {
        
        if let validator = TFBubbleItUpViewConfiguration.itemValidation, let item = self.items.last, !validator(item.text) {
            
            let position = self.items.index(where: { (i) -> Bool in i.text == item.text })
            
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
    open func addStringItem(_ text: String, completion: (()->())? = nil) -> Bool {
        
        if self.items.count == self.needPreciseNumberOfItems() && self.items.last?.text != "" {
            
            return false
        }
        
        if self.items.last != nil && self.items.last!.text == ""  {
            self.items[self.items.count - 1].text = text
            
            if let cell = self.cellForItem(at: IndexPath(item: self.items.count - 1, section: 0)) as? TFBubbleItUpViewCell {
                cell.configureWithItem(self.items[self.items.count - 1])
                cell.resignFirstResponder()
                self.needUpdateLayout(cell, completion: completion)
            }
            
        } else {
            self.items.append(TFBubbleItem(text: text))
            
            self.performBatchUpdates({ () -> Void in
                let newLastIndexPath = IndexPath(item: self.items.count - 1, section: 0)
                self.insertItems(at: [newLastIndexPath])
            }) { (finished) -> Void in
                // Invalidate intrinsic size when done
                self.invalidateIntrinsicContentSize(completion)
            }
        }
        
        return true
    }
    
    open func removeStringItem(_ text: String) -> Bool {
        let index = self.items.index { (item) -> Bool in item.text == text }
        
        guard let i = index else {
            
            return false
        }
        
        self.items.remove(at: i)
        
        self.performBatchUpdates({ () -> Void in
            let newLastIndexPath = IndexPath(item: i, section: 0)
            self.deleteItems(at: [newLastIndexPath])
        }) { (finished) -> Void in
            // Invalidate intrinsic size when done
            self.invalidateIntrinsicContentSize(nil)
        }
        
        return true
    }
    
    open override func becomeFirstResponder() -> Bool {
        
        self.selectLastPossible()
        
        return true
    }
    
    // MARK:- Autolayout
    
    override open var intrinsicContentSize : CGSize {
        // Calculate custom intrinsic size by collectionViewLayouts contentent size
        let size = (self.collectionViewLayout as! UICollectionViewFlowLayout).collectionViewContentSize
        
        return CGSize(width: self.bounds.width, height: max(self.minimumHeight(), size.height))
    }
    
    func minimumHeight() -> CGFloat {
        let defaultHeight: CGFloat = CGFloat(TFBubbleItUpViewConfiguration.cellHeight)
        let padding = TFBubbleItUpViewConfiguration.inset.top + TFBubbleItUpViewConfiguration.inset.bottom
        
        return defaultHeight + padding
    }
    
    fileprivate func invalidateIntrinsicContentSize(_ completionBlock: (() -> ())?) {
        
        if self.intrinsicContentSize != self.bounds.size {
            UIView.animate(withDuration: 0.2, animations: { () -> Void in
                self.invalidateIntrinsicContentSize()
                
            }, completion: { (finished) -> Void in
                completionBlock?()
            }) 
        } else {
            //self.invalidateIntrinsicContentSize()
            completionBlock?()
        }
    }
    
    // MARK:- Handling gestures
    
    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        
        if gestureRecognizer != self.tapRecognizer {
            return false
        }
        
        if let view = touch.view, view.isKind(of: TFBubbleItUpViewCell.self) {
            return false
        } else {
            return true
        }
    }
    
    func didTapOnView(_ sender: AnyObject) {
        self.selectLastPossible()
    }
    
    internal func selectLastPossible() {
        if let last = self.items.last, last.text == "" || !isTextValid(last.text) || self.items.count == self.needPreciseNumberOfItems() {
            self.cellForItem(at: IndexPath(item: self.items.count - 1, section: 0))?.becomeFirstResponder()
        } else {
            
            if self.items.count == 0 {
                self.placeholderLabel.isHidden = true
            }
            
            // insert new data item at the end
            self.items.append(TFBubbleItem(text: "", becomeFirstResponder: true))
            
            // Update collectionView
            self.performBatchUpdates({ () -> Void in
                self.insertItems(at: [IndexPath(item: self.items.count - 1, section:0)])
            }) { (finished) -> Void in
                // Invalidate intrinsic size when done
                self.invalidateIntrinsicContentSize(nil)
            }
        }
    }
    
    func isTextValid(_ text: String) -> Bool {
        if let validation = TFBubbleItUpViewConfiguration.itemValidation {
            return validation(text)
        } else {
            return true
        }
    }
    
    // MARK:- UICollectionViewDelegate and datasource
    
    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell: TFBubbleItUpViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: TFBubbleItUpViewCell.identifier, for: indexPath) as! TFBubbleItUpViewCell
        
        cell.delegate = self
        
        let item = self.items[indexPath.item]
        cell.configureWithItem(item)
        
        return cell
    }
    
    open func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        var item = self.items[indexPath.item]
        
        if item.becomeFirstResponder {
            cell.becomeFirstResponder()
            item.becomeFirstResponder = false
        }
    }
    
    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return self.items.count
    }
    
    open func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        return 1
    }
    
    // MARK:- UICollectionViewFlowLayout delegate
    
    open func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        if indexPath.item >= self.items.count {
            return CGSize(width: 0.0, height: CGFloat(TFBubbleItUpViewConfiguration.cellHeight))
        }
        
        let item = self.items[indexPath.item]
        
        self.sizingCell.textField.text = item.text
        let size = self.sizingCell.systemLayoutSizeFitting(UILayoutFittingCompressedSize)
        
        let layoutInset = (self.collectionViewLayout as! UICollectionViewFlowLayout).sectionInset
        let maximumWidth = self.bounds.width - layoutInset.left - layoutInset.right
        
        return CGSize(width: min(size.width, maximumWidth), height: CGFloat(TFBubbleItUpViewConfiguration.cellHeight))
    }
    
    // MARK:- TFContactCollectionCellDelegate
    
    internal func didChangeText(_ cell: TFBubbleItUpViewCell, text: String) {
        if let indexPath = self.indexPath(for: cell) {
            if indexPath.item < self.items.count {
                self.items[indexPath.item].text = text
            } else {
                return
            }
        }
        
        self.bubbleItUpDelegate?.bubbleItUpViewDidChange?(self, text:text, index:(self.indexPath(for: cell)?.item)!)
    }
    
    internal func needUpdateLayout(_ cell: TFBubbleItUpViewCell) {
        self.needUpdateLayout(cell, completion:nil)
    }
    
    func needUpdateLayout(_ cell: TFBubbleItUpViewCell, completion: (() -> ())?) {
        self.collectionViewLayout.invalidateLayout()
        
        // Update cell frame by its intrinsic size
        var frame = cell.frame
        frame.size.width = cell.intrinsicContentSize.width
        cell.frame = frame
        
        self.invalidateIntrinsicContentSize(completion)
    }
    
    internal func createAndSwitchToNewCell(_ cell: TFBubbleItUpViewCell) {

        // If no indexpath found return
        guard let indexPath = self.indexPath(for: cell) else {
            return
        }
        
        // If user tries to create new cell when he already has one
        if cell.textField.text == "" {
            return
        }
        
        cell.setMode(.view)
        
        if let preciseNumber = self.needPreciseNumberOfItems(), self.items.count == preciseNumber { // If we reach quantity, return
            cell.resignFirstResponder()
            return
        }
        
        // Create indexPath for the last item
        let newIndexPath = IndexPath(item: self.items.count - 1, section: indexPath.section)
        
        // If the next cell is empty, move to it. Otherwise create new.
        if let nextCell = self.cellForItem(at: newIndexPath) as? TFBubbleItUpViewCell, nextCell.textField.text == "" {
            
            nextCell.becomeFirstResponder()
            
        } else {
            self.items.append(TFBubbleItem(text: "", becomeFirstResponder: true)) // insert new data item
            
            // Update collectionView
            self.performBatchUpdates({ () -> Void in
                let newLastIndexPath = IndexPath(item: self.items.count - 1, section: indexPath.section)
                self.insertItems(at: [newLastIndexPath])
            }) { (finished) -> Void in
                // Invalidate intrinsic size when done
                self.invalidateIntrinsicContentSize(nil)
                // The new cell should now become the first reponder
                //self.cellForItemAtIndexPath(newIndexPath)?.becomeFirstResponder()
            }
        }
    }
    
    func editingDidEnd(_ cell: TFBubbleItUpViewCell, text: String) {
        
        guard let indexPath = indexPath(for: cell) else {
            
            return
        }
        
        if text == "" {
            
            if indexPath.item >= self.items.count {
                return
            }
            
            self.items.remove(at: indexPath.item)
            
            // Update collectionView
            self.performBatchUpdates({ () -> Void in
                self.deleteItems(at: [indexPath])
            }) { (finished) -> Void in
                // Invalidate intrinsic size when done
                self.invalidateIntrinsicContentSize(nil)
                
                if self.items.count == 0 {
                    self.placeholderLabel.isHidden = false
                }
            }
            
            self.bubbleItUpDelegate?.bubbleItUpViewDidDeleteBubbles(self, text: text, actualIndex:indexPath.item, otherIndex: -1)
        } else {
            self.bubbleItUpDelegate?.bubbleItUpViewDidFinishEditingBubble(self, text: text, index:indexPath.item)
        }
    }
    
    func shouldDeleteCellInFrontOfCell(_ cell: TFBubbleItUpViewCell) {
        
        guard let cellsIndexPath = self.indexPath(for: cell) else {
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
        } catch DataSourceOperationError.outOfBounds {
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
    
    func removeItemAtIndex(_ index: Int, completion: (() -> ())?) throws {
        
        if self.items.count <= index || index < 0 {
            throw DataSourceOperationError.outOfBounds
        }
        
        self.items.remove(at: index)
        
        // Update collectionView
        self.performBatchUpdates({ () -> Void in
            self.deleteItems(at: [IndexPath(item: index, section: 0)])
        }) {[weak self] (finished) -> Void in
            // Invalidate intrinsic size when done
            self?.invalidateIntrinsicContentSize(nil)
            completion?()
        }
    }
    
    func needPreciseNumberOfItems() -> Int? {
        switch TFBubbleItUpViewConfiguration.numberOfItems {
        case .unlimited:
            return nil
        case let .quantity(value):
            return value
        }
    }
}
