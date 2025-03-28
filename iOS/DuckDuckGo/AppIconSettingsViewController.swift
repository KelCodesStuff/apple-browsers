//
//  AppIconSettingsViewController.swift
//  DuckDuckGo
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

import UIKit
import Core

class AppIconSettingsViewController: UICollectionViewController {
    
    let dataSource = AppIconDataSource()
    private let worker = AppIconWorker()

    let onChange: ((AppIcon) -> Void)?

    init?(onChange: @escaping (AppIcon) -> Void, coder: NSCoder) {
        self.onChange = onChange
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder) {
        self.onChange = nil
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.dataSource = dataSource
        decorate()
    }

    private func initSelection() {
        let icon = AppIconManager.shared.appIcon
        let index = dataSource.appIcons.firstIndex(of: icon) ?? 0
        let indexPath = IndexPath(row: index, section: 0)
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .top)
    }

    // MARK: UICollectionViewDelegate

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let appIcon = dataSource.appIcons[indexPath.row]

        worker.changeAppIcon(appIcon) { success in
            if success {
                self.initSelection()
                self.onChange?(appIcon)
            }
        }
    }

}

class AppIconDataSource: NSObject, UICollectionViewDataSource {
    
    let appIcons = AppIcon.allCases
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return appIcons.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AppIconSettingsCell.reuseIdentifier,
                                                            for: indexPath)
            as? AppIconSettingsCell else {
                fatalError("Expected IconSettingsCell")
        }

        let appIcon = appIcons[indexPath.row]
        cell.appIcon = appIcon

        return cell
    }
}

private class AppIconWorker {
    
    func changeAppIcon(_ appIcon: AppIcon,
                       completion: @escaping (_ success: Bool) -> Void) {
        AppIconManager.shared.changeAppIcon(appIcon) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }

}

extension AppIconSettingsViewController {
    
    private func decorate() {
        let theme = ThemeManager.shared.currentTheme
        collectionView.backgroundColor = theme.backgroundColor
        collectionView.reloadData()
        initSelection()
    }

}
