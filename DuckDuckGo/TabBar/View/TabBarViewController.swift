//
//  TabBarViewController.swift
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Cocoa
import os.log
import Combine

class TabBarViewController: NSViewController {

    enum CollectionViewHorizontalSpace: CGFloat {
        case withScrollButtons = 112
        case withoutScrollButtons = 80
    }

    @IBOutlet weak var collectionView: NSCollectionView!
    @IBOutlet weak var scrollView: TabBarScrollView!
    @IBOutlet weak var scrollViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var rightScrollButton: MouseOverButton!
    @IBOutlet weak var leftScrollButton: MouseOverButton!
    @IBOutlet weak var rightShadowImageView: NSImageView!
    @IBOutlet weak var leftShadowImageView: NSImageView!
    @IBOutlet weak var windowDraggingViewLeadingConstraint: NSLayoutConstraint!

    private let tabCollectionViewModel: TabCollectionViewModel
    private var tabsCancelable: AnyCancellable?
    private var selectionIndexCancelable: AnyCancellable?

    required init?(coder: NSCoder) {
        fatalError("TabBarViewController: Bad initializer")
    }

    init?(coder: NSCoder, tabCollectionViewModel: TabCollectionViewModel) {
        self.tabCollectionViewModel = tabCollectionViewModel

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()
        bindSelectionIndex()
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        addInitialTab()
        setWindowDraggingArea()
        tabCollectionViewModel.tabCollection.delegate = self
    }

    override func viewDidLayout() {
        super.viewDidLayout()

        setTabMode(for: collectionView.numberOfItems(inSection: 0))
        setWindowDraggingArea()
        collectionView.collectionViewLayout?.invalidateLayout()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @IBAction func burnButtonAction(_ sender: NSButton) {

    }

    @IBAction func addButtonAction(_ sender: NSButton) {
        tabCollectionViewModel.appendNewTab()
    }

    @IBAction func rightScrollButtonAction(_ sender: NSButton) {
        scrollToEnd()
    }

    @IBAction func leftScrollButtonAction(_ sender: NSButton) {
        scrollToBeginning()
    }

    private func setupCollectionView() {
        let nib = NSNib(nibNamed: "TabBarViewItem", bundle: nil)
        collectionView.register(nib, forItemWithIdentifier: TabBarViewItem.identifier)

        // Register for the dropped object types we can accept.
        collectionView.registerForDraggedTypes([NSPasteboard.PasteboardType.string])
        // Enable dragging items within and into our CollectionView.
        collectionView.setDraggingSourceOperationMask(NSDragOperation.move, forLocal: false)

        setScrollElasticity()
        receiveScrollNotifications()
    }

    private func bindSelectionIndex() {
        selectionIndexCancelable = tabCollectionViewModel.$selectionIndex.sinkAsync { [weak self] _ in
            self?.reloadSelection()
        }
    }

    private func reloadSelection() {
        guard collectionView.selectionIndexPaths.first?.item != tabCollectionViewModel.selectionIndex else {
            return
        }

        guard let selectionIndex = tabCollectionViewModel.selectionIndex else {
            os_log("TabBarViewController: Selection index is nil", log: OSLog.Category.general, type: .error)
            return
        }

        let newSelectionIndexPath = IndexPath(item: selectionIndex, section: 0)
        if tabMode == .divided {
            collectionView.animator().selectItems(at: [newSelectionIndexPath], scrollPosition: .centeredHorizontally)
        } else {
            collectionView.selectItems(at: [newSelectionIndexPath], scrollPosition: .centeredHorizontally)
        }
    }

    private func addInitialTab() {
        tabCollectionViewModel.appendNewTab()
    }

    private func closeWindowIfNeeded() {
        if tabCollectionViewModel.tabCollection.tabs.count == 0 {
            guard let window = view.window else {
                os_log("AutocompleteSearchField: Window not available", log: OSLog.Category.general, type: .error)
                return
            }
            window.close()
        }
    }

    // MARK: - Window Dragging

    private func setWindowDraggingArea() {
        let leadingSpace = min(CGFloat(collectionView.numberOfItems(inSection: 0)) *
                                currentTabWidth(), scrollView.frame.size.width)
        windowDraggingViewLeadingConstraint.constant = leadingSpace
    }

    // MARK: - Selection

    private func clearCollectionViewSelection() {
        collectionView.deselectItems(at: collectionView.selectionIndexPaths)
    }

    private func selectItem(at indexPath: IndexPath) {
        tabCollectionViewModel.select(at: indexPath.item)
    }

    // MARK: - Closing

    private func closeItem(at indexPath: IndexPath) {
        tabCollectionViewModel.remove(at: indexPath.item)
    }

    // MARK: - Drag and Drop

    private var draggingIndexPaths: Set<IndexPath>?
    private var lastIndexPath: IndexPath?

    private func moveItemIfNeeded(at indexPath: IndexPath, to newIndexPath: IndexPath) {
        guard newIndexPath != lastIndexPath else {
            return
        }

        let index = indexPath.item
        let newIndex = min(newIndexPath.item, max(tabCollectionViewModel.tabCollection.tabs.count - 1, 0))
        let newIndexPath = IndexPath(item: newIndex, section: 0)

        guard index != newIndex else {
            return
        }
        lastIndexPath = newIndexPath

        tabCollectionViewModel.tabCollection.moveTab(at: index, to: newIndex)
        tabCollectionViewModel.select(at: newIndexPath.item)
    }

    // MARK: - Tab Width

    private enum TabMode {
        case divided
        case overflow
    }

    private var tabMode = TabMode.divided {
        didSet {
            if oldValue != tabMode {
                setScrollElasticity()
                setScrollButtons()
                setWindowDraggingArea()
                collectionView.collectionViewLayout?.invalidateLayout()
            }
        }
    }

    private func setTabMode(for numberOfItems: Int? = nil) {
        let items = CGFloat(numberOfItems ?? collectionView.numberOfItems(inSection: 0))
        let tabsWidth = scrollView.bounds.width

        if items * TabBarViewItem.Width.minimum.rawValue < tabsWidth {
            tabMode = .divided
        } else {
            tabMode = .overflow
        }
    }

    private func currentTabWidth() -> CGFloat {
        let numberOfItems = CGFloat(collectionView.numberOfItems(inSection: 0))
        let tabsWidth = scrollView.bounds.width

        if tabMode == .divided {
            return min(TabBarViewItem.Width.maximum.rawValue, tabsWidth / numberOfItems)
        } else {
            return TabBarViewItem.Width.minimum.rawValue
        }
    }

    private func setScrollElasticity() {
        scrollView.horizontalScrollElasticity = tabMode == .divided ? .none : .allowed
    }

    // MARK: - Scrolling & Scroll Buttons

    private func receiveScrollNotifications() {
        scrollView.contentView.postsBoundsChangedNotifications = true

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(scrollViewBoundsDidChange(_:)),
                                               name: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView)
    }

    @objc private func scrollViewBoundsDidChange(_ sender: Any) {
        let clipView = scrollView.contentView
        rightScrollButton.isEnabled = clipView.bounds.origin.x + clipView.bounds.size.width < collectionView.bounds.size.width
        leftScrollButton.isEnabled = clipView.bounds.origin.x > 0
    }

    private func setScrollButtons() {
        let horizontalSpace = tabMode == .divided ?
            CollectionViewHorizontalSpace.withoutScrollButtons.rawValue :
            CollectionViewHorizontalSpace.withScrollButtons.rawValue
        scrollViewLeadingConstraint.constant = horizontalSpace
        scrollViewTrailingConstraint.constant = horizontalSpace

        let scrollViewsAreHidden = tabMode == .divided
        rightScrollButton.isHidden = scrollViewsAreHidden
        leftScrollButton.isHidden = scrollViewsAreHidden
        rightShadowImageView.isHidden = scrollViewsAreHidden
        leftShadowImageView.isHidden = scrollViewsAreHidden
    }

    private func scrollToEnd(completionHandler: ((Bool) -> Void)? = nil) {
        collectionView.animator().performBatchUpdates({
            collectionView.animator().scroll(CGPoint(x: self.collectionView.bounds.size.width, y: 0))
        }, completionHandler: completionHandler)
    }

    private func scrollToBeginning(completionHandler: ((Bool) -> Void)? = nil) {
        collectionView.animator().performBatchUpdates({
            collectionView.animator().scroll(CGPoint(x: 0, y: 0))
        }, completionHandler: completionHandler)
    }

    private func scrollToSelected() {
        guard collectionView.selectionIndexPaths.count == 1, let indexPath = collectionView.selectionIndexPaths.first else {
            os_log("TabBarViewController: More than 1 item highlighted", log: OSLog.Category.general, type: .error)
            return
        }

        let rect = collectionView.frameForItem(at: indexPath.item)
        collectionView.animator().performBatchUpdates({
            collectionView.animator().scrollToVisible(rect)
        }, completionHandler: nil)
    }

}

// swiftlint:disable compiler_protocol_init
extension TabBarViewController: TabCollectionDelegate {

    func tabCollection(_ tabCollection: TabCollection, didAppend tab: Tab) {
        let lastIndex = max(0, tabCollectionViewModel.tabCollection.tabs.count - 1)
        let lastIndexPath = IndexPath(item: lastIndex, section: 0)
        let lastIndexPathSet = Set(arrayLiteral: lastIndexPath)

        setTabMode(for: collectionView.numberOfItems(inSection: 0) + 1)

        clearCollectionViewSelection()
        if tabMode == .divided {
            collectionView.animator().insertItems(at: lastIndexPathSet)
        } else {
            collectionView.insertItems(at: lastIndexPathSet)
            // Old frameworks are like old people. They need special treatment
            scrollToEnd { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.scrollToEnd()
                }
            }
        }
        setWindowDraggingArea()
    }

    func tabCollection(_ tabCollection: TabCollection, didInsert tab: Tab, at index: Int) {
        let indexPath = IndexPath(item: index, section: 0)
        let indexPathSet = Set(arrayLiteral: indexPath)
        collectionView.animator().insertItems(at: indexPathSet)

        setTabMode()
        setWindowDraggingArea()
    }

    func tabCollection(_ tabCollection: TabCollection, didRemoveTabAt index: Int) {
        let indexPath = IndexPath(item: index, section: 0)
        let indexPathSet = Set(arrayLiteral: indexPath)

        collectionView.animator().performBatchUpdates {
            collectionView.animator().deleteItems(at: indexPathSet)
        } completionHandler: { _ in
            self.setTabMode()
        }

        closeWindowIfNeeded()
        setWindowDraggingArea()
    }

    func tabCollection(_ tabCollection: TabCollection, didMoveTabAt index: Int, to newIndex: Int) {
        let indexPath = IndexPath(item: index, section: 0)
        let newIndexPath = IndexPath(item: newIndex, section: 0)
        collectionView.animator().moveItem(at: indexPath, to: newIndexPath)

        setTabMode()
    }

}
// swiftlint:enable compiler_protocol_init

extension TabBarViewController: NSCollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: NSCollectionView,
                        layout collectionViewLayout: NSCollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> NSSize {
        return NSSize(width: self.currentTabWidth(), height: TabBarViewItem.Height.standard.rawValue)
    }

}

extension TabBarViewController: NSCollectionViewDataSource {
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return tabCollectionViewModel.tabCollection.tabs.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: TabBarViewItem.identifier, for: indexPath)
        guard let tabBarViewItem = item as? TabBarViewItem else {
            os_log("", log: OSLog.Category.general, type: .error)
            return item
        }
        
        guard let tabViewModel = tabCollectionViewModel.tabViewModel(at: indexPath.item) else {
            tabBarViewItem.clear()
            return tabBarViewItem
        }

        tabBarViewItem.delegate = self
        tabBarViewItem.bind(tabViewModel: tabViewModel)
        return tabBarViewItem
    }
    
}

extension TabBarViewController: NSCollectionViewDelegate {

    func collectionView(_ collectionView: NSCollectionView,
                        didChangeItemsAt indexPaths: Set<IndexPath>,
                        to highlightState: NSCollectionViewItem.HighlightState) {
        guard indexPaths.count == 1, let indexPath = indexPaths.first else {
            os_log("TabBarViewController: More than 1 item highlighted", log: OSLog.Category.general, type: .error)
            return
        }

        if highlightState == .forSelection {
            clearCollectionViewSelection()
            selectItem(at: indexPath)

            // Poor old NSCollectionView
            DispatchQueue.main.async {
                self.scrollToSelected()
            }
        }
    }

    func collectionView(_ collectionView: NSCollectionView,
                        canDragItemsAt indexPaths: Set<IndexPath>,
                        with event: NSEvent) -> Bool {
        return true
    }

    func collectionView(_ collectionView: NSCollectionView,
                        pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        if let url = tabCollectionViewModel.tabCollection.tabs[indexPath.item].url {
            return url.absoluteString as NSString
        } else {
            return "" as NSString
        }
    }

    func collectionView(_ collectionView: NSCollectionView,
                        draggingSession session: NSDraggingSession,
                        willBeginAt screenPoint: NSPoint,
                        forItemsAt indexPaths: Set<IndexPath>) {
        session.animatesToStartingPositionsOnCancelOrFail = false
        draggingIndexPaths = indexPaths
    }

    func collectionView(_ collectionView: NSCollectionView,
                        draggingSession session: NSDraggingSession,
                        endedAt screenPoint: NSPoint,
                        dragOperation operation: NSDragOperation) {
        draggingIndexPaths = nil
        lastIndexPath = nil
    }

    func collectionView(_ collectionView: NSCollectionView,
                        validateDrop draggingInfo: NSDraggingInfo,
                        proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        guard let draggingIndexPaths = draggingIndexPaths else {
            os_log("TabBarViewController: Dragging index paths is nil", log: OSLog.Category.general, type: .error)
            return .copy
        }

        guard let indexPath = draggingIndexPaths.first, draggingIndexPaths.count == 1 else {
            os_log("TabBarViewController: More than 1 dragging index path", log: OSLog.Category.general, type: .error)
            return .move
        }

        let newIndexPath = proposedDropIndexPath.pointee as IndexPath
        if let lastIndexPath = lastIndexPath {
            moveItemIfNeeded(at: lastIndexPath, to: newIndexPath)
        } else {
            moveItemIfNeeded(at: indexPath, to: newIndexPath)
        }

        proposedDropOperation.pointee = .before
        return .move
    }

    func collectionView(_ collectionView: NSCollectionView,
                        acceptDrop draggingInfo: NSDraggingInfo,
                        indexPath: IndexPath,
                        dropOperation: NSCollectionView.DropOperation) -> Bool {
        guard let draggingIndexPaths = draggingIndexPaths else {
            os_log("TabBarViewController: Dragging index paths is nil", log: OSLog.Category.general, type: .error)
            return false
        }

        guard draggingIndexPaths.count == 1 else {
            os_log("TabBarViewController: More than 1 item selected", log: OSLog.Category.general, type: .error)
            return false
        }

        return true
    }

}

extension TabBarViewController: TabBarViewItemDelegate {

    func tabBarViewItemDuplicateAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get indexPath", log: OSLog.Category.general, type: .error)
            return
        }

        clearCollectionViewSelection()
        tabCollectionViewModel.duplicateTab(at: indexPath.item)
    }

    func tabBarViewItemCloseAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get indexPath", log: OSLog.Category.general, type: .error)
            return
        }

        closeItem(at: indexPath)
    }

    func tabBarViewItemCloseOtherAction(_ tabBarViewItem: TabBarViewItem) {
        guard let indexPath = collectionView.indexPath(for: tabBarViewItem) else {
            os_log("TabBarViewController: Failed to get indexPath", log: OSLog.Category.general, type: .error)
            return
        }

        tabCollectionViewModel.closeOtherTabs(except: indexPath.item)
    }

}
