//
//  DownloadManager.swift
//  DuckDuckGo
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
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

import Common
import Foundation
import Core
import WebKit
import UniformTypeIdentifiers
import os.log

class DownloadManager {

    struct UserInfoKeys {
        static let download = "com.duckduckgo.com.userInfoKey.download"
        static let error = "com.duckduckgo.com.userInfoKey.error"
    }

    private(set) var downloadList = Set<Download>()
    private let notificationCenter: NotificationCenter
    private var downloadsDirectoryMonitor: DirectoryMonitor?
    private let downloadsDirectoryHandler: DownloadsDirectoryHandling

    @UserDefaultsWrapper(key: .unseenDownloadsAvailable, defaultValue: false)
    private(set) var unseenDownloadsAvailable: Bool

    init(_ notificationCenter: NotificationCenter = NotificationCenter.default,
         downloadsDirectoryHandler: DownloadsDirectoryHandling = DownloadsDirectoryHandler()) {
        self.notificationCenter = notificationCenter
        self.downloadsDirectoryHandler = downloadsDirectoryHandler
        downloadsDirectoryHandler.createDownloadsDirectoryIfNeeded()
        Logger.general.debug("Downloads directory location \(self.downloadsDirectoryHandler.downloadsDirectory.absoluteString)")
    }

    func makeDownload(response: URLResponse,
                      suggestedFilename: String? = nil,
                      downloadSession: DownloadSession? = nil,
                      cookieStore: WKHTTPCookieStore? = nil,
                      temporary: Bool? = nil) -> Download? {

        guard let metaData = downloadMetaData(for: response, suggestedFilename: suggestedFilename),
              let url = response.url
        else { return nil }

        let temporaryFile: Bool
        if let temporary = temporary {
            temporaryFile = temporary
        } else {
            temporaryFile = FilePreviewHelper.canAutoPreviewMIMEType(metaData.mimeType)
        }

        let session: DownloadSession
        if let downloadSession = downloadSession {
            session = downloadSession
        } else {
            session = URLDownloadSession(metaData.url, cookieStore: cookieStore)
        }

        let download = Download(url: url,
                                filename: metaData.filename,
                                mimeType: metaData.mimeType,
                                temporary: temporaryFile,
                                downloadSession: session,
                                delegate: self)

        downloadList.insert(download)
        return download
    }

    func makeDownload(navigationResponse: WKNavigationResponse,
                      suggestedFilename: String? = nil,
                      downloadSession: DownloadSession? = nil,
                      cookieStore: WKHTTPCookieStore? = nil,
                      temporary: Bool? = nil) -> Download? {
        makeDownload(response: navigationResponse.response,
                     suggestedFilename: suggestedFilename,
                     downloadSession: downloadSession,
                     cookieStore: cookieStore,
                     temporary: temporary)
    }

    func downloadMetaData(for response: URLResponse, suggestedFilename: String? = nil) -> DownloadMetadata? {
        let filename = filename(forSuggestedFilename: suggestedFilename ?? response.suggestedFilename, mimeType: response.mimeType)
        return DownloadMetadata(response, filename: filename)
    }

    func startDownload(_ download: Download, completion: Download.Completion? = nil) {
        download.completionBlock = completion
        notificationCenter.post(name: .downloadStarted, object: nil, userInfo: [UserInfoKeys.download: download])
        download.start()
    }

    func cancelDownload(_ download: Download) {
        download.cancel()
    }

    func cancelAllDownloads() {
        downloadList.forEach { $0.cancel() }
    }

    func markAllDownloadsSeen() {
        unseenDownloadsAvailable = false
    }

    private func move(_ download: Download, toPath path: URL) {
        guard let location = download.location else { return }
        do {
            let newPath = path.appendingPathComponent(download.filename)
            try? FileManager.default.removeItem(at: newPath)
            try FileManager.default.moveItem(at: location, to: newPath)
            download.location = newPath
        } catch {
            Logger.general.error("Error moving file to downloads directory: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func moveToDownloadDirectortIfNeeded(_ download: Download) {
        guard !download.temporary else { return }
        move(download, toPath: downloadsDirectoryHandler.downloadsDirectory)
    }
}

// MARK: - Filename Methods

extension DownloadManager {

    private func convertToUniqueFilename(_ filename: String) -> String {
        let downloadingFilenames = Set(downloadList.map { $0.filename })
        let downloadedFilenames = Set(downloadsDirectoryHandler.downloadsDirectoryFiles.map { $0.lastPathComponent })
        let list = downloadingFilenames.union(downloadedFilenames)

        var fileExtension = downloadsDirectoryHandler.downloadsDirectory.appendingPathComponent(filename).pathExtension
        fileExtension = fileExtension.count > 0 ? ".\(fileExtension)" : ""

        let filePrefix = filename.dropping(suffix: fileExtension)

        var counter: Int = 0
        var newFilename: String

        repeat {
            newFilename = counter > 0 ? "\(filePrefix) \(counter)\(fileExtension)" : filename
            counter += 1
        } while list.contains(newFilename)

        return newFilename
    }

    private func filename(forSuggestedFilename suggestedFilename: String?, mimeType: String?) -> String {
        let filename = sanitizeFilename(suggestedFilename, mimeType: mimeType)
        return convertToUniqueFilename(filename)
    }

    private func sanitizeFilename(_ originalFilename: String?, mimeType: String?) -> String {
        var filename = originalFilename ?? "unknown"

        if let mimeType = mimeType,
           let utType = UTType(mimeType: mimeType),
           UTType(filenameExtension: (filename as NSString).pathExtension) != utType,
           let pathExtension = utType.preferredFilenameExtension {
            filename.append("." + pathExtension)
        }

        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet.punctuationCharacters)
        return filename.components(separatedBy: allowedCharacterSet.inverted).joined()
    }
}

// MARK: - Directory monitoring

extension DownloadManager {

    func startMonitoringDownloadsDirectoryChanges() {
        stopMonitoringDownloadsDirectoryChanges()

        downloadsDirectoryMonitor = DirectoryMonitor(directory: downloadsDirectoryHandler.downloadsDirectory)
        downloadsDirectoryMonitor?.delegate = self
        try? downloadsDirectoryMonitor?.start()
    }

    func stopMonitoringDownloadsDirectoryChanges() {
        downloadsDirectoryMonitor?.stop()
        downloadsDirectoryMonitor = nil
    }
}

extension DownloadManager: DownloadDelegate {
    func downloadDidFinish(_ download: Download, error: Error?) {
        moveToDownloadDirectortIfNeeded(download)
        var userInfo: [AnyHashable: Any] = [UserInfoKeys.download: download]
        if let error = error {
            userInfo[UserInfoKeys.error] = error
        } else if !download.temporary {
            unseenDownloadsAvailable = true
        }

        downloadList.remove(download)

        notificationCenter.post(name: .downloadFinished, object: nil, userInfo: userInfo)
    }
}

extension DownloadManager: DirectoryMonitorDelegate {
    func didChange(directoryMonitor: DirectoryMonitor, added: Set<URL>, removed: Set<URL>) {
        notificationCenter.post(name: .downloadsDirectoryChanged, object: nil, userInfo: nil)
    }
}

extension NSNotification.Name {
    static let downloadStarted: NSNotification.Name = Notification.Name(rawValue: "com.duckduckgo.notification.downloadStarted")
    static let downloadFinished: NSNotification.Name = Notification.Name(rawValue: "com.duckduckgo.notification.downloadFinished")
    static let downloadsDirectoryChanged: NSNotification.Name = Notification.Name(rawValue: "com.duckduckgo.notification.downloadsDirectoryChanged")
}


extension DownloadManager {
    var downloadsDirectoryFiles: [URL] { downloadsDirectoryHandler.downloadsDirectoryFiles }
    var downloadsDirectory: URL { downloadsDirectoryHandler.downloadsDirectory }
}
