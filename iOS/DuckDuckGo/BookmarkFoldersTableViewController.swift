//
//  BookmarkFoldersTableViewController.swift
//  DuckDuckGo
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

import UIKit
import Core
import Bookmarks
import DesignResourcesKit
import DesignResourcesKitIcons

protocol BookmarkFoldersViewControllerDelegate: AnyObject {

    func textDidChange(_ controller: BookmarkFoldersViewController)
    func textDidReturn(_ controller: BookmarkFoldersViewController)
    func addFolder(_ controller: BookmarkFoldersViewController)
    func deleteBookmark(_ controller: BookmarkFoldersViewController)

}

class BookmarkFoldersViewController: UITableViewController {

    weak var delegate: BookmarkFoldersViewControllerDelegate?

    var viewModel: BookmarkEditorViewModel?
    var selected: IndexPath?

    var locationCount: Int {
        guard let viewModel = viewModel else { return 0 }
        return viewModel.locations.count
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.sectionIndexBackgroundColor = UIColor(designSystemColor: .background)
        self.tableView.separatorColor = ThemeManager.shared.currentTheme.tableCellSeparatorColor
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.backgroundColor = UIColor(designSystemColor: .background)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section != 0 else { return }
        guard let viewModel = viewModel else {
            assertionFailure("No view model")
            return
        }

        if indexPath.row >= viewModel.locations.count {
            delegate?.addFolder(self)
        } else {
            viewModel.selectLocationAtIndex(indexPath.row)
            if let selected = selected {
                tableView.reloadRows(at: [
                    selected,
                    indexPath
                ], with: .automatic)
            }
        }

        if tableView.cellForRow(at: indexPath)?.reuseIdentifier == "BookmarksDeleteButtonCell" {
            confirmDelete()
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if viewModel?.bookmark.isFolder == true {
            switch indexPath.section {
            case 0:
                return detailCellForFolder(tableView)

            case 1:
                return folderSelectorCell(tableView, forIndexPath: indexPath)

            default:
                fatalError("Unexpected section")
            }
        } else {
            switch indexPath.section {
            case 0:
                return titleAndUrlCellForBookmark(tableView)

            case 1:
                return favoriteCellForBookmark(tableView)

            case 2:
                return indexPath.row >= locationCount ?
                    tableView.dequeueReusableCell(withIdentifier: "AddFolderCell")! :
                    folderSelectorCell(tableView, forIndexPath: indexPath)

            case 3:
                return deleteCell(tableView)

            default:
                fatalError("Unexpected section")
            }
        }
    }

    func deleteCell(_ tableView: UITableView) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "BookmarksDeleteButtonCell")!
    }

    private func confirmDelete() {
        guard let title = viewModel?.bookmark.title ?? viewModel?.bookmark.url?.droppingWwwPrefix() else {
            assertionFailure()
            return
        }

        let controller = UIAlertController(title: UserText.deleteBookmarkAlertTitle,
                                           message: UserText.deleteBookmarkAlertMessage.format(arguments: title),
                                           preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: UserText.actionDelete, style: .destructive) { [weak self] _ in
            self?.performDelete()
        })
        controller.addAction(UIAlertAction(title: UserText.actionCancel, style: .cancel))
        present(controller, animated: true)
    }

    func performDelete() {
        delegate?.deleteBookmark(self)
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        cell.backgroundColor = UIColor(designSystemColor: .surface)
    }

    func folderSelectorCell(_ tableView: UITableView, forIndexPath indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: BookmarkFolderCell.reuseIdentifier) else {
            fatalError("Failed to dequeue cell for BookmarkFolder")
        }
        if let viewModel = viewModel, let folderCell = cell as? BookmarkFolderCell {
            folderCell.folder = viewModel.locations[indexPath.row].bookmark
            folderCell.depth = viewModel.locations[indexPath.row].depth
            folderCell.isSelected = viewModel.isSelected(viewModel.locations[indexPath.row].bookmark)
            if folderCell.isSelected {
                selected = indexPath
            }
        }
        return cell
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        let extraSectionsForBookmark = (viewModel?.isNew ?? true) ? 0 : 1
        return viewModel?.bookmark.isFolder == true ? 2 : 3 + extraSectionsForBookmark
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let viewModel = viewModel else {
            assertionFailure()
            return 0
        }

        let locationCount = self.locationCount + (viewModel.canAddNewFolder ? 1 : 0)
        if viewModel.bookmark.isFolder && section == 1 {
            return locationCount
        } else if section == 2 {
            return locationCount
        }

        return 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if viewModel?.bookmark.isFolder == true {
            return section == 1 ? UserText.bookmarkFolderSelectTitle : nil
        } else {
            return section == 2 ? UserText.bookmarkFolderSelectTitle : nil
        }
    }

    func favoriteCellForBookmark(_ tableView: UITableView) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: FavoriteCell.reuseIdentifier) as? FavoriteCell else {
            fatalError("Failed to dequeue \(FavoriteCell.reuseIdentifier) as FavoriteCell")
        }

        let displayedFolder = viewModel?.favoritesDisplayMode.displayedFolder ?? .mobile

        cell.favoriteToggle.isOn = viewModel?.bookmark.isFavorite(on: displayedFolder) == true
        cell.favoriteToggle.removeTarget(self, action: #selector(favoriteToggleDidChange(_:)), for: .valueChanged)
        cell.favoriteToggle.addTarget(self, action: #selector(favoriteToggleDidChange(_:)), for: .valueChanged)
        cell.favoriteToggle.onTintColor = ThemeManager.shared.currentTheme.buttonTintColor

        return cell
    }

    func titleAndUrlCellForBookmark(_ tableView: UITableView) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: BookmarkDetailsCell.reuseIdentifier) as? BookmarkDetailsCell else {
            fatalError("Failed to dequeue \(BookmarkDetailsCell.reuseIdentifier) as BookmarkDetailsCell")
        }
        cell.titleTextField.removeTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        cell.titleTextField.removeTarget(self, action: #selector(textFieldDidReturn), for: .editingDidEndOnExit)
        cell.titleTextField.becomeFirstResponder()
        cell.titleTextField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        cell.titleTextField.addTarget(self, action: #selector(textFieldDidReturn), for: .editingDidEndOnExit)

        cell.urlTextField.removeTarget(self, action: #selector(urlTextFieldDidChange(_:)), for: .editingChanged)
        cell.urlTextField.removeTarget(self, action: #selector(urlTextFieldDidReturn), for: .editingDidEndOnExit)
        cell.urlTextField.becomeFirstResponder()
        cell.urlTextField.addTarget(self, action: #selector(urlTextFieldDidChange(_:)), for: .editingChanged)
        cell.urlTextField.addTarget(self, action: #selector(urlTextFieldDidReturn), for: .editingDidEndOnExit)

        cell.faviconImageView.loadFavicon(forDomain: viewModel?.bookmark.urlObject?.host, usingCache: .fireproof)

        cell.selectionStyle = .none
        cell.title = viewModel?.bookmark.title
        cell.urlString = viewModel?.bookmark.url
        return cell
    }

    func detailCellForFolder(_ tableView: UITableView) -> BookmarksTextFieldCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: BookmarksTextFieldCell.reuseIdentifier) as? BookmarksTextFieldCell else {
            fatalError("Failed to dequeue \(BookmarksTextFieldCell.reuseIdentifier) as BookmarksTextFieldCell")
        }
        cell.textField.removeTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        cell.textField.removeTarget(self, action: #selector(textFieldDidReturn), for: .editingDidEndOnExit)
        cell.textField.becomeFirstResponder()
        cell.textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        cell.textField.addTarget(self, action: #selector(textFieldDidReturn), for: .editingDidEndOnExit)

        cell.selectionStyle = .none
        cell.title = viewModel?.bookmark.title
        return cell
    }

    @objc func favoriteToggleDidChange(_ toggle: UISwitch) {
        if toggle.isOn {
            viewModel?.addToFavorites()
        } else {
            viewModel?.removeFromFavorites()
        }
    }

    @objc func textFieldDidChange(_ textField: UITextField) {
        viewModel?.bookmark.title = textField.text?.trimmingWhitespace()
        delegate?.textDidChange(self)
    }

    @objc func textFieldDidReturn() {
        if viewModel?.bookmark.isFolder == true {
            delegate?.textDidReturn(self)
        }
    }

    @objc func urlTextFieldDidChange(_ textField: UITextField) {
        viewModel?.bookmark.url = textField.text?.trimmingWhitespace()
        delegate?.textDidChange(self)
    }

    @objc func urlTextFieldDidReturn() {
        delegate?.textDidReturn(self)
    }

    func refresh() {
        viewModel?.refresh()
        tableView.reloadData()
    }

}

class FavoriteCell: UITableViewCell {

    static let reuseIdentifier = "FavoriteCell"

    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet var favoriteToggle: UISwitch!

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = UIColor(designSystemColor: .surface)
        iconImageView.image = DesignSystemImages.Color.Size24.folder
        iconImageView.tintColor = UIColor(designSystemColor: .icons)
        label.textColor = UIColor(designSystemColor: .textPrimary)
    }
}

class BookmarksDeleteButtonCell: UITableViewCell {
 
    @IBOutlet weak var deleteButton: UILabel!
    static let reuseIdentifier = "BookmarksDeleteButtonCell"

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = UIColor(designSystemColor: .surface)
        deleteButton.textColor = UIColor(designSystemColor: .buttonsDeleteGhostText)
    }
}

class AddFolderCell: UITableViewCell {
    
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    static let reuseIdentifier = "AddFolderCell"

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = UIColor(designSystemColor: .surface)
        iconImageView.image = DesignSystemImages.Glyphs.Size24.folderAdd
        iconImageView.tintColor = UIColor(designSystemColor: .icons)
        label.textColor = UIColor(designSystemColor: .textPrimary)
    }
}
