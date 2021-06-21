//
//  BookmarkManagementDetailViewController.swift
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

import Foundation
import Combine

protocol BookmarkManagementDetailViewControllerDelegate: AnyObject {

    func bookmarkManagementDetailViewControllerDidSelectFolder(_ folder: BookmarkFolder)

}

private struct EditedBookmarkMetadata {
    let uuid: UUID
    let index: Int
}

final class BookmarkManagementDetailViewController: NSViewController {

    fileprivate enum Constants {
        static let bookmarkCellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "BookmarksCellIdentifier")
        static let animationSpeed: TimeInterval = 0.3
    }

    @IBOutlet var tableView: NSTableView!
    @IBOutlet var colorView: ColorView!

    weak var delegate: BookmarkManagementDetailViewControllerDelegate?

    private var bookmarkManager: BookmarkManager = LocalBookmarkManager.shared
    private var bookmarkListCancellable: AnyCancellable?
    private var selectionState: BookmarkManagementSidebarViewController.SelectionState = .empty {
        didSet {
            editingBookmarkIndex = nil
            reloadData()
        }
    }

    private var isEditing: Bool {
        return editingBookmarkIndex != nil
    }

    private var editingBookmarkIndex: EditedBookmarkMetadata? {
        didSet {
            NSAnimationContext.runAnimationGroup { context in
                context.allowsImplicitAnimation = true
                context.duration = Constants.animationSpeed

                NSAppearance.withAppAppearance {
                    if editingBookmarkIndex != nil {
                        colorView.animator().layer?.backgroundColor = NSColor.backgroundSecondaryColor.cgColor
                    } else {
                        colorView.animator().layer?.backgroundColor = NSColor.homepageBackgroundColor.cgColor
                    }
                }
            }
        }
    }

    func update(selectionState: BookmarkManagementSidebarViewController.SelectionState) {
        self.selectionState = selectionState
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let nib = NSNib(nibNamed: "BookmarkTableCellView", bundle: Bundle.main)
        tableView.register(nib, forIdentifier: Constants.bookmarkCellIdentifier)
        tableView.setDraggingSourceOperationMask([.move], forLocal: true)
        tableView.registerForDraggedTypes([BookmarkPasteboardWriter.bookmarkUTIInternalType,
                                           FolderPasteboardWriter.folderUTIInternalType])

        configureTableHighlight()
        reloadData()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        editingBookmarkIndex = nil
        reloadData()
    }

    override func mouseUp(with event: NSEvent) {
        // Clicking anywhere outside of the table view should end editing mode for a given cell.
        updateEditingState(forRowAt: -1)
    }

    func configureTableHighlight() {
        tableView.selectionHighlightStyle = .none
    }

    fileprivate func reloadData() {
        guard editingBookmarkIndex == nil else {
            // If the table view is editing, the reload will be deferred until after the cell animation has completed.
            return
        }

        self.tableView.reloadData()
    }

    @IBAction func handleClick(_ sender: NSTableView) {
        let index = sender.clickedRow

        guard index != -1, let entity = fetchEntity(at: index) else {
            updateEditingState(forRowAt: index)
            return
        }

        let row = sender.view(atColumn: 0, row: index, makeIfNecessary: false) as? BookmarkTableCellView

        if row?.editing ?? false {
            return
        }

        // 1. Command: Open in Background Tab
        // 2. Command + Shift: Open in New Window
        // 3. Default: Open in Current Tab

        editingBookmarkIndex = nil

        if let bookmark = entity as? Bookmark {
            if NSApplication.shared.isCommandPressed && NSApplication.shared.isShiftPressed {
                WindowsManager.openNewWindow(with: bookmark.url)
            } else if NSApplication.shared.isCommandPressed {
                WindowControllersManager.shared.show(url: bookmark.url, newTab: true)
            } else {
                WindowControllersManager.shared.show(url: bookmark.url)
                tableView.deselectAll(nil)
            }

            Pixel.fire(.navigation(kind: .bookmark(isFavorite: bookmark.isFavorite), source: .managementInterface))
        } else if let folder = entity as? BookmarkFolder {
            delegate?.bookmarkManagementDetailViewControllerDidSelectFolder(folder)
        } else {
            assertionFailure("\(#file): Failed to cast selected object to Folder or Bookmark")
        }
    }

    @IBAction func presentAddBookmarkModal(_ sender: Any) {
        let addBookmarkViewController = AddBookmarkModalViewController.create()
        addBookmarkViewController.delegate = self
        beginSheet(addBookmarkViewController)
    }

    @IBAction func presentAddFolderModal(_ sender: Any) {
        let addFolderViewController = AddFolderModalViewController.create()
        addFolderViewController.delegate = self
        beginSheet(addFolderViewController)
    }

    private func updateEditingState(forRowAt index: Int) {
        guard index != -1 else {
            if let expandedIndex = self.editingBookmarkIndex?.index {
                animateEditingState(forRowAt: expandedIndex, editing: false) {
                    self.editingBookmarkIndex = nil
                }
            }

            return
        }

        // Cancel the current editing state, if one exists.
        if let expandedIndex = self.editingBookmarkIndex?.index {
            animateEditingState(forRowAt: expandedIndex, editing: false)
            self.editingBookmarkIndex = nil
        }

        // If the current expanded row matches the one that has just been double clicked, we're going to deselect it.
        if editingBookmarkIndex?.index == index {
            editingBookmarkIndex = nil
            animateEditingState(forRowAt: index, editing: false)
        } else if let entity = fetchEntity(at: index) {
            editingBookmarkIndex = EditedBookmarkMetadata(uuid: entity.id, index: index)
            animateEditingState(forRowAt: index, editing: true)
        } else {
            assertionFailure("\(#file): Failed to find entity when updating editing state")
        }
    }

    private func animateEditingState(forRowAt index: Int, editing: Bool, completion: (() -> Void)? = nil) {
        if let cell = tableView.view(atColumn: 0, row: index, makeIfNecessary: false) as? BookmarkTableCellView,
           let row = tableView.rowView(atRow: index, makeIfNecessary: false) as? BookmarkTableRowView {

            tableView.beginUpdates()
            NSAnimationContext.runAnimationGroup { context in
                context.allowsImplicitAnimation = true
                context.duration = Constants.animationSpeed
                context.completionHandler = completion

                cell.editing = editing
                row.editing = editing

                row.layoutSubtreeIfNeeded()
                cell.layoutSubtreeIfNeeded()
                tableView.noteHeightOfRows(withIndexesChanged: IndexSet(arrayLiteral: 0, index))
            }

            tableView.endUpdates()
        }
    }

    private func totalRows() -> Int {
        switch selectionState {
        case .empty:
            return LocalBookmarkManager.shared.list?.topLevelEntities.count ?? 0
        case .folder(let folder):
            return folder.children.count
        case .favorites:
            return LocalBookmarkManager.shared.list?.favoriteBookmarks.count ?? 0
        }
    }

}

// MARK: - Modal Delegates

extension BookmarkManagementDetailViewController: AddBookmarkModalViewControllerDelegate, AddFolderModalViewControllerDelegate {
    
    func addBookmarkViewController(_ viewController: AddBookmarkModalViewController, addedBookmarkWithTitle title: String, url: URL) {
        if !bookmarkManager.isUrlBookmarked(url: url) {
            bookmarkManager.makeBookmark(for: url, title: title, isFavorite: false)
        }
    }

    func addFolderViewController(_ viewController: AddFolderModalViewController, addedFolderWith name: String) {
        if case let .folder(selectedFolder) = selectionState {
            bookmarkManager.makeFolder(for: name, parent: selectedFolder)
        } else {
            bookmarkManager.makeFolder(for: name, parent: nil)
        }
    }

    func addFolderViewController(_ viewController: AddFolderModalViewController, saved folder: BookmarkFolder) {
        bookmarkManager.update(folder: folder)
    }

}

// MARK: - NSTableView

extension BookmarkManagementDetailViewController: NSTableViewDelegate, NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return totalRows()
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return fetchEntity(at: row)
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = BookmarkTableRowView()
        let entity = fetchEntity(at: row)

        if let uuid = editingBookmarkIndex?.uuid, uuid == entity?.id {
            rowView.editing = true
        }

        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let entity = fetchEntity(at: row) else { return nil }

        if let cell = tableView.makeView(withIdentifier: Constants.bookmarkCellIdentifier, owner: nil) as? BookmarkTableCellView {
            cell.delegate = self

            if let bookmark = entity as? Bookmark {
                cell.update(from: bookmark)
                cell.editing = bookmark.id == editingBookmarkIndex?.uuid
            } else if let folder = entity as? BookmarkFolder {
                cell.update(from: folder)
                cell.editing = folder.id == editingBookmarkIndex?.uuid
            } else {
                assertionFailure("Failed to cast bookmark")
            }

            return cell
        }

        return nil
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard let entity = fetchEntity(at: row) else { return nil }
        return entity.pasteboardWriter
    }

    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {

        guard dropOperation == .on,
              row < totalRows(),
              let proposedDestination = fetchEntity(at: row),
              proposedDestination.isFolder else {
            return .none
        }

        if let bookmarks = PasteboardBookmark.pasteboardBookmarks(with: info.draggingPasteboard) {
            return validateDrop(for: bookmarks, destination: proposedDestination)
        }

        if let folders = PasteboardFolder.pasteboardFolders(with: info.draggingPasteboard) {
            return validateDrop(for: folders, destination: proposedDestination)
        }

        return .none
    }

    private func validateDrop(for draggedBookmarks: Set<PasteboardBookmark>, destination: BaseBookmarkEntity) -> NSDragOperation {
        guard destination is BookmarkFolder else {
            return .none
        }

        return .move
    }

    private func validateDrop(for draggedFolders: Set<PasteboardFolder>, destination: BaseBookmarkEntity) -> NSDragOperation {
        guard destination is BookmarkFolder else {
            return .none
        }

        let tryingToDragOntoSameFolder = draggedFolders.contains { folder in
            return folder.id == destination.id.uuidString
        }

        if tryingToDragOntoSameFolder {
            return .none
        }

        return .move
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        let draggingLocation = info.draggingLocation
        let draggingLocationInTableViewCoordinates = tableView.convert(draggingLocation, to: nil)
        let draggingLocationRow = tableView.row(at: draggingLocationInTableViewCoordinates)

        // Prevent drops from being accepted below the final row in the table view. Should likely use an outline view here instead of hacking this in.
        guard draggingLocationRow != -1 else { return false }

        guard let parent = fetchEntity(at: row) as? BookmarkFolder else { return false }

        let draggedBookmarks = PasteboardBookmark.pasteboardBookmarks(with: info.draggingPasteboard) ?? Set<PasteboardBookmark>()
        let draggedFolders = PasteboardFolder.pasteboardFolders(with: info.draggingPasteboard) ?? Set<PasteboardFolder>()

        if draggedBookmarks.isEmpty && draggedFolders.isEmpty {
            return false
        }

        let draggedObjectIdentifierStrings = draggedBookmarks.map(\.id) + draggedFolders.map(\.id)
        let draggedObjectIdentifiers = draggedObjectIdentifierStrings.compactMap(UUID.init(uuidString:))

        LocalBookmarkManager.shared.add(objectsWithUUIDs: draggedObjectIdentifiers, to: parent) { _ in
            // Does anything need to happen here?
        }

        return true
    }

    private func fetchEntity(at row: Int) -> BaseBookmarkEntity? {
        switch selectionState {
        case .empty:
            return LocalBookmarkManager.shared.list?.topLevelEntities[safe: row]
        case .folder(let folder):
            return folder.children[safe: row]
        case .favorites:
            return LocalBookmarkManager.shared.list?.favoriteBookmarks[safe: row]
        }
    }

    private func index(for entity: Bookmark) -> Int? {
        switch selectionState {
        case .empty:
            return LocalBookmarkManager.shared.list?.topLevelEntities.firstIndex(of: entity)
        case .folder(let folder):
            return folder.children.firstIndex(of: entity)
        case .favorites:
            return LocalBookmarkManager.shared.list?.favoriteBookmarks.firstIndex(of: entity)
        }
    }

    fileprivate func selectedItems() -> [AnyObject] {
        return tableView.selectedRowIndexes.compactMap { (index) -> AnyObject? in
            return fetchEntity(at: index) as AnyObject
        }
    }

}

// MARK: - BookmarkTableCellViewDelegate

extension BookmarkManagementDetailViewController: BookmarkTableCellViewDelegate {

    func bookmarkTableCellViewRequestedMenu(_ sender: NSButton, cell: BookmarkTableCellView) {
        guard !isEditing else { return }

        let row = tableView.row(for: cell)

        guard let bookmark = fetchEntity(at: row) as? Bookmark else {
            assertionFailure("BookmarkManagementDetailViewController: Tried to present bookmark menu for nil bookmark or folder")
            return
        }

        if let contextMenu = ContextualMenu.menu(for: [bookmark]), let cursorLocation = self.view.window?.mouseLocationOutsideOfEventStream {
            let convertedLocation = self.view.convert(cursorLocation, from: nil)
            contextMenu.items.forEach { item in
                item.target = self
            }

            contextMenu.popUp(positioning: nil, at: convertedLocation, in: self.view)
        }
    }

    func bookmarkTableCellViewToggledFavorite(cell: BookmarkTableCellView) {
        let row = tableView.row(for: cell)

        guard let bookmark = fetchEntity(at: row) as? Bookmark else {
            assertionFailure("BookmarkManagementDetailViewController: Tried to favorite object which is not bookmark")
            return
        }

        bookmark.isFavorite.toggle()
        LocalBookmarkManager.shared.update(bookmark: bookmark)
    }

    func bookmarkTableCellView(_ cell: BookmarkTableCellView, updatedBookmarkWithUUID uuid: UUID, newTitle: String, newUrl: String) {
        let row = tableView.row(for: cell)

        guard let bookmark = fetchEntity(at: row) as? Bookmark, bookmark.id == editingBookmarkIndex?.uuid else {
            return
        }

        bookmark.title = newTitle.isEmpty ? bookmark.title : newTitle
        bookmarkManager.update(bookmark: bookmark)

        if let newURL = newUrl.url, newURL != bookmark.url {
            _ = LocalBookmarkManager.shared.updateUrl(of: bookmark, to: newURL)
        }
    }

}

// MARK: - NSMenuDelegate

extension BookmarkManagementDetailViewController: NSMenuDelegate {

    func contextualMenuForClickedRows() -> NSMenu? {
        guard !isEditing else { return nil }

        let row = tableView.clickedRow

        guard row != -1 else {
            return ContextualMenu.menu(for: nil)
        }

        if tableView.selectedRowIndexes.contains(row) {
            return ContextualMenu.menu(for: self.selectedItems())
        }

        if let item = fetchEntity(at: row) {
            return ContextualMenu.menu(for: [item])
        } else {
            return nil
        }
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        guard let contextualMenu = contextualMenuForClickedRows() else {
            return
        }

        let items = contextualMenu.items
        contextualMenu.removeAllItems()
        for menuItem in items {
            menu.addItem(menuItem)
        }
    }

}

// MARK: - Menu Item Selectors

extension BookmarkManagementDetailViewController: FolderMenuItemSelectors {

    func newFolder(_ sender: NSMenuItem) {
        presentAddFolderModal(sender)
    }

    func renameFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to cast menu represented object to BookmarkFolder")
            return
        }

        let addFolderViewController = AddFolderModalViewController.create()
        addFolderViewController.delegate = self
        addFolderViewController.edit(folder: folder)
        presentAsModalWindow(addFolderViewController)
    }

    func deleteFolder(_ sender: NSMenuItem) {
        guard let folder = sender.representedObject as? BookmarkFolder else {
            assertionFailure("Failed to retrieve Bookmark from Delete Folder context menu item")
            return
        }

        LocalBookmarkManager.shared.remove(folder: folder)
    }

}

extension BookmarkManagementDetailViewController: BookmarkMenuItemSelectors {

    func openBookmarkInNewTab(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        WindowControllersManager.shared.show(url: bookmark.url, newTab: true)
    }

    func openBookmarkInNewWindow(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        WindowsManager.openNewWindow(with: bookmark.url)
    }

    func toggleBookmarkAsFavorite(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        bookmark.isFavorite.toggle()
        LocalBookmarkManager.shared.update(bookmark: bookmark)
    }

    func editBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark, let bookmarkIndex = index(for: bookmark) else { return }
        updateEditingState(forRowAt: bookmarkIndex)
    }

    func copyBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark, let bookmarkURL = bookmark.url as NSURL? else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.URL], owner: nil)
        bookmarkURL.write(to: pasteboard)
    }

    func deleteBookmark(_ sender: NSMenuItem) {
        guard let bookmark = sender.representedObject as? Bookmark else {
            assertionFailure("Failed to cast menu represented object to Bookmark")
            return
        }

        LocalBookmarkManager.shared.remove(bookmark: bookmark)
    }
    
}
