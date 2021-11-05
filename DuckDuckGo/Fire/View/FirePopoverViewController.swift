//
//  FirePopoverViewController.swift
//
//  Copyright © 2021 DuckDuckGo. All rights reserved.
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
import Combine

protocol FirePopoverViewControllerDelegate: AnyObject {

    func firePopoverViewControllerDidClear(_ firePopoverViewController: FirePopoverViewController)
    func firePopoverViewControllerDidCancel(_ firePopoverViewController: FirePopoverViewController)

}

final class FirePopoverViewController: NSViewController {

    struct Constants {
        static let maximumContentHeight: CGFloat = 42 + 230 + 32
        static let minimumContentHeight: CGFloat = 42
        static let headerHeight: CGFloat = 28
        static let footerHeight: CGFloat = 8
    }

    weak var delegate: FirePopoverViewControllerDelegate?

    private let fireViewModel: FireViewModel
    private let tabCollectionViewModel: TabCollectionViewModel
    private var firePopoverViewModel: FirePopoverViewModel
    private let historyCoordinating: HistoryCoordinating

    @IBOutlet weak var optionsButton: NSPopUpButton!
    @IBOutlet weak var openDetailsButton: NSButton!
    @IBOutlet weak var closeDetailsButton: NSButton!
    @IBOutlet weak var detailsWrapperView: NSView!
    @IBOutlet weak var contentHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var detailsWrapperViewHeightContraint: NSLayoutConstraint!
    @IBOutlet weak var closeWrapperView: NSView!
    @IBOutlet weak var collectionView: NSCollectionView!
    @IBOutlet weak var collectionViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var warningWrapperView: NSView!
    @IBOutlet weak var clearButton: NSButton!

    private var viewModelCancellable: AnyCancellable?
    private var selectedCancellable: AnyCancellable?

    required init?(coder: NSCoder) {
        fatalError("FirePopoverViewController: Bad initializer")
    }

    init?(coder: NSCoder,
          fireViewModel: FireViewModel,
          tabCollectionViewModel: TabCollectionViewModel,
          historyCoordinating: HistoryCoordinating = HistoryCoordinator.shared,
          fireproofDomains: FireproofDomains = FireproofDomains.shared,
          faviconService: FaviconService = LocalFaviconService.shared) {
        self.fireViewModel = fireViewModel
        self.tabCollectionViewModel = tabCollectionViewModel
        self.historyCoordinating = historyCoordinating
        self.firePopoverViewModel = FirePopoverViewModel(fireViewModel: fireViewModel,
                                                         tabCollectionViewModel: tabCollectionViewModel,
                                                         historyCoordinating: historyCoordinating,
                                                         fireproofDomains: fireproofDomains,
                                                         faviconService: faviconService)

        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let nib = NSNib(nibNamed: "FirePopoverCollectionViewItem", bundle: nil)
        collectionView.register(nib, forItemWithIdentifier: FirePopoverCollectionViewItem.identifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        setupOptionsButton()
        updateCloseDetailsButton()
        updateWarningWrapperView()

        subscribeToViewModel()
        subscribeToSelected()
    }

    @IBAction func optionsButtonAction(_ sender: NSPopUpButton) {
        guard let tag = sender.selectedItem?.tag else {
            assertionFailure("No tag in the selected menu item")
            return
        }
        let clearingOption = FirePopoverViewModel.ClearingOption.allCases[tag]
        firePopoverViewModel.clearingOption = clearingOption
        updateCloseDetailsButton()
        updateWarningWrapperView()
    }

    @IBAction func openDetailsButtonAction(_ sender: Any) {
        toggleDetails()
    }

    @IBAction func closeDetailsButtonAction(_ sender: Any) {
        toggleDetails()
    }

    private func updateCloseDetailsButton() {
        guard firePopoverViewModel.areAllSelected else {
            closeDetailsButton.title = "     \(UserText.selectedDomainsDescription)"
            return
        }

        switch firePopoverViewModel.clearingOption {
        case .currentTab: closeDetailsButton.title = "     \(UserText.currentTabDescription)"
        case .currentWindow: closeDetailsButton.title = "     \(UserText.currentWindowDescription)"
        case .allData: closeDetailsButton.title = "     \(UserText.allDataDescription)"
        }
    }

    private func updateWarningWrapperView() {
        warningWrapperView.isHidden = firePopoverViewModel.clearingOption == .allData ||
        firePopoverViewModel.selectable.isEmpty || detailsWrapperView.isHidden

        collectionViewBottomConstraint.constant = warningWrapperView.isHidden ? 0 : 32
    }

    @IBAction func clearButtonAction(_ sender: Any) {
        delegate?.firePopoverViewControllerDidClear(self)
        firePopoverViewModel.burn()

    }

    @IBAction func cancelButtonAction(_ sender: Any) {
        delegate?.firePopoverViewControllerDidCancel(self)
    }

    private func subscribeToViewModel() {
        viewModelCancellable = Publishers.Zip(
            firePopoverViewModel.$fireproofed,
            firePopoverViewModel.$selectable
        ).receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.collectionView.reloadData()
                self.adjustContentHeight()
                if self.firePopoverViewModel.selectable.isEmpty && !self.detailsWrapperView.isHidden {
                    self.toggleDetails()
                }
                self.updateOpenDetailsButton()
            }
    }

    private func subscribeToSelected() {
        selectedCancellable = firePopoverViewModel.$selected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] selected in
                let selectionIndexPaths = Set(selected.map {IndexPath(item: $0, section: 1)})
                self?.collectionView.selectionIndexPaths = selectionIndexPaths
                self?.updateCloseDetailsButton()
                self?.updateClearButton()
            }
    }

    private func toggleDetails() {
        let showDetails = detailsWrapperView.isHidden
        openDetailsButton.isHidden = showDetails
        detailsWrapperView.isHidden = !showDetails

        adjustContentHeight()
        updateWarningWrapperView()
    }

    private func adjustContentHeight() {
        NSAnimationContext.runAnimationGroup { [weak self] context in
            context.duration = 1/3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            let contentHeight = contentHeight()
            self?.contentHeightConstraint.animator().constant = contentHeight
            if contentHeight != Constants.minimumContentHeight {
                self?.detailsWrapperViewHeightContraint.animator().constant = contentHeight
            }
        }
    }

    private func contentHeight() -> CGFloat {
        if detailsWrapperView.isHidden {
            return Constants.minimumContentHeight
        } else {
            if let contentHeight = collectionView.collectionViewLayout?.collectionViewContentSize.height {
                let height = contentHeight + closeWrapperView.frame.height + warningWrapperView.frame.height
                return min(Constants.maximumContentHeight, height)
            } else {
                return Constants.maximumContentHeight
            }
        }
    }

    private func setupOptionsButton() {
        FirePopoverViewModel.ClearingOption.allCases.enumerated().forEach { (index, option) in
            optionsButton.menu?.item(withTag: index)?.title = option.string
        }
    }

    private func updateClearButton() {
        clearButton.isEnabled = !firePopoverViewModel.selected.isEmpty
    }

    private func updateOpenDetailsButton() {
        openDetailsButton.title = firePopoverViewModel.selectable.isEmpty ? UserText.fireDialogNothingToBurn : UserText.fireDialogDetails
        openDetailsButton.isEnabled = !firePopoverViewModel.selectable.isEmpty
    }

}

extension FirePopoverViewController: NSCollectionViewDataSource {

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? firePopoverViewModel.fireproofed.count : firePopoverViewModel.selectable.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: FirePopoverCollectionViewItem.identifier, for: indexPath)
        guard let firePopoverItem = item as? FirePopoverCollectionViewItem else { return item }

        firePopoverItem.delegate = self
        let sectionList = (indexPath.section == 0 ? firePopoverViewModel.fireproofed : firePopoverViewModel.selectable)
        let listItem = sectionList[indexPath.item]
        firePopoverItem.setItem(listItem, isFireproofed: indexPath.section == 0)
        return firePopoverItem
    }

    func collectionView(_ collectionView: NSCollectionView,
                        viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind,
                        at indexPath: IndexPath) -> NSView {
        // swiftlint:disable force_cast
        let view = collectionView.makeSupplementaryView(ofKind: NSCollectionView.elementKindSectionHeader,
                                                        withIdentifier: FirePopoverCollectionViewHeader.identifier,
                                                        for: indexPath) as! FirePopoverCollectionViewHeader
        // swiftlint:enable force_cast

        if indexPath.section == 0 {
            view.title.stringValue = UserText.fireDialogFireproofSites
        } else {
            view.title.stringValue = UserText.fireDialogClearSites
        }

        return view
    }

}

extension FirePopoverViewController: NSCollectionViewDelegate {

}

extension FirePopoverViewController: NSCollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: NSCollectionView,
                        layout collectionViewLayout: NSCollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> NSSize {
        let count: Int
        switch section {
        case 0: count = firePopoverViewModel.fireproofed.count
        case 1: count = firePopoverViewModel.selectable.count
        default: count = 0
        }
        return NSSize(width: collectionView.bounds.width, height: count == 0 ? 0 : Constants.headerHeight)
    }

    func collectionView(_ collectionView: NSCollectionView,
                        layout collectionViewLayout: NSCollectionViewLayout,
                        referenceSizeForFooterInSection section: Int) -> NSSize {
        let count: Int
        switch section {
        case 0: count = firePopoverViewModel.fireproofed.count
        case 1: count = firePopoverViewModel.selectable.count
        default: count = 0
        }
        return NSSize(width: collectionView.bounds.width, height: count == 0 ? 0 : Constants.footerHeight)
    }

}

extension FirePopoverViewController: FirePopoverCollectionViewItemDelegate {

    func firePopoverCollectionViewItemDidToggle(_ firePopoverCollectionViewItem: FirePopoverCollectionViewItem) {
        guard let indexPath = collectionView.indexPath(for: firePopoverCollectionViewItem) else {
            assertionFailure("No index path for the \(firePopoverCollectionViewItem)")
            return
        }

        if firePopoverCollectionViewItem.isSelected {
            firePopoverViewModel.deselect(index: indexPath.item)
        } else {
            firePopoverViewModel.select(index: indexPath.item)
        }
    }

}
