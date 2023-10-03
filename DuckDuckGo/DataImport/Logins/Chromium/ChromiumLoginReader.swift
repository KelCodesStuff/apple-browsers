//
//  ChromiumLoginReader.swift
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
import CommonCrypto
import GRDB

final class ChromiumLoginReader {

    struct ImportError: DataImportError {
        enum OperationType: Int {
            case couldNotFindLoginData
            case databaseAccessFailed
            case decryptionFailed
            case failedToDecodePasswordData
            case userDeniedKeychainPrompt
            case decryptionKeyAccessFailed
            case failedToTemporarilyCopyDatabase
            case passwordDataTooShort
            case dataToStringConversionError
            case createImportedLoginCredentialsFailure
        }

        var action: DataImportAction { .logins }
        let source: DataImport.Source
        let type: OperationType
        let underlyingError: Error?

    }
    private func importError(type: ImportError.OperationType, underlyingError: Error? = nil) -> ImportError {
        ImportError(source: source, type: type, underlyingError: underlyingError)
    }
    private func decryptionKeyAccessFailed(_ status: OSStatus) -> ImportError {
        importError(type: .decryptionKeyAccessFailed, underlyingError: NSError(domain: "KeychainError", code: Int(status)))
    }

    enum LoginDataFileName: String, CaseIterable {
        case loginData = "Login Data"
        case loginDataForAccount = "Login Data for Account"
    }

    private let chromiumLocalLoginDirectoryURL: URL
    private let chromiumGoogleAccountLoginDirectoryURL: URL
    private let processName: String
    private let decryptionKey: String?
    private let decryptionKeyPrompt: ChromiumKeychainPrompting

    private static let sqlSelectWithPasswordTimestamp = "SELECT signon_realm, username_value, password_value, date_password_modified FROM logins;"
    private static let sqlSelectWithCreatedTimestamp = "SELECT signon_realm, username_value, password_value, date_created FROM logins;"
    private static let sqlSelectWithoutTimestamp = "SELECT signon_realm, username_value, password_value FROM logins;"

    private let source: DataImport.Source

    init(chromiumDataDirectoryURL: URL,
         source: DataImport.Source,
         processName: String,
         decryptionKey: String? = nil,
         decryptionKeyPrompt: ChromiumKeychainPrompting = ChromiumKeychainPrompt()) {
        self.chromiumLocalLoginDirectoryURL = chromiumDataDirectoryURL.appendingPathComponent(LoginDataFileName.loginData.rawValue)
        self.chromiumGoogleAccountLoginDirectoryURL = chromiumDataDirectoryURL.appendingPathComponent(LoginDataFileName.loginDataForAccount.rawValue)
        self.processName = processName
        self.decryptionKey = decryptionKey
        self.decryptionKeyPrompt = decryptionKeyPrompt
        self.source = source
    }

    func readLogins() -> DataImportResult<[ImportedLoginCredential]> {
        let key: String

        if let decryptionKey = decryptionKey {
            key = decryptionKey
        } else {
            let keyPromptResult = decryptionKeyPrompt.promptForChromiumPasswordKeychainAccess(processName: processName)

            switch keyPromptResult {
            case .password(let passwordString): key = passwordString
            case .failedToDecodePasswordData: return .failure(importError(type: .failedToDecodePasswordData))
            case .userDeniedKeychainPrompt: return .failure(importError(type: .userDeniedKeychainPrompt))
            case .keychainError(let status): return .failure(decryptionKeyAccessFailed(status))
            }
        }

        let derivedKey: Data
        do {
            derivedKey = try deriveKey(from: key)
        } catch {
            return .failure(importError(type: .decryptionFailed, underlyingError: error))
        }

        return readLogins(using: derivedKey)
    }

    private func readLogins(using key: Data) -> DataImportResult<[ImportedLoginCredential]> {
        let loginFileURLs = [chromiumLocalLoginDirectoryURL, chromiumGoogleAccountLoginDirectoryURL]
            .filter { FileManager.default.fileExists(atPath: $0.path) }

        guard !loginFileURLs.isEmpty else {
            return .failure(importError(type: .couldNotFindLoginData))
        }

        var loginRows = [ChromiumCredential.ID: ChromiumCredential]()

        for loginFileURL in loginFileURLs {
            let result = readLoginRows(loginFileURL: loginFileURL)

            switch result {
            case .success(let newLoginRows):
                loginRows.merge(newLoginRows) { existingRow, newRow in
                    if let newDate = newRow.passwordModifiedAt, let existingDate = existingRow.passwordModifiedAt, newDate > existingDate {
                        return newRow
                    } else {
                        return existingRow
                    }
                }
            case .failure(let error):
                return .failure(error)
            }
        }

        do {
            let importedLogins = try createImportedLoginCredentials(from: loginRows.values, decryptionKey: key)
            return .success(importedLogins)

        } catch let error as ImportError {
            return .failure(error)
        } catch {
            return .failure(importError(type: .createImportedLoginCredentialsFailure, underlyingError: error))
        }
    }

    private func readLoginRows(loginFileURL: URL) -> DataImportResult<[ChromiumCredential.ID: ChromiumCredential]> {
        let temporaryFileHandler = TemporaryFileHandler(fileURL: loginFileURL)
        defer { temporaryFileHandler.deleteTemporarilyCopiedFile() }

        let temporaryDatabaseURL: URL
        do {
            temporaryDatabaseURL = try temporaryFileHandler.copyFileToTemporaryDirectory()
        } catch {
            return .failure(importError(type: .failedToTemporarilyCopyDatabase, underlyingError: error))
        }

        var loginRows = [ChromiumCredential.ID: ChromiumCredential]()

        do {
            let queue = try DatabaseQueue(path: temporaryDatabaseURL.path)
            var rows = [ChromiumCredential]()

            try queue.read { database in
                rows = try fetchCredentials(from: database)
            }

            for row in rows {
                let existingRowTimestamp = loginRows[row.id]?.passwordModifiedAt
                let newRowTimestamp = row.passwordModifiedAt

                switch (newRowTimestamp, existingRowTimestamp) {
                case let (.some(new), .some(existing)) where new > existing:
                    loginRows[row.id] = row
                case (_, .none):
                    loginRows[row.id] = row
                default:
                    break
                }
            }

        } catch {
            return .failure(importError(type: .databaseAccessFailed, underlyingError: error))
        }

        return .success(loginRows)
    }

    private func createImportedLoginCredentials(from credentials: Dictionary<ChromiumCredential.ID, ChromiumCredential>.Values,
                                                decryptionKey: Data) throws -> [ImportedLoginCredential] {
        var lastError: Error?
        let result = credentials.compactMap { row -> ImportedLoginCredential? in
            let decryptedPassword: String
            do {
                decryptedPassword = try decrypt(passwordData: row.encryptedPassword, with: decryptionKey)
            } catch {
                lastError = error
                return nil
            }

            return ImportedLoginCredential(
                url: row.url,
                username: row.username,
                password: decryptedPassword
            )
        }
        if result.isEmpty, let lastError {
            throw lastError
        }
        return result
    }

    private func fetchCredentials(from database: GRDB.Database) throws -> [ChromiumCredential] {
        do {
            return try ChromiumCredential.fetchAll(database, sql: Self.sqlSelectWithPasswordTimestamp)
        } catch let databaseError as DatabaseError {
            guard databaseError.isMissingColumnError else {
                throw databaseError
            }

            do {
                return try ChromiumCredential.fetchAll(database, sql: Self.sqlSelectWithCreatedTimestamp)
            } catch let databaseError as DatabaseError {
                guard databaseError.isMissingColumnError else {
                    throw databaseError
                }

                return try ChromiumCredential.fetchAll(database, sql: Self.sqlSelectWithoutTimestamp)
            }
        }
    }

    private func deriveKey(from password: String) throws -> Data {
        return try Cryptography.decryptPBKDF2(password: .utf8(password),
                                              salt: "saltysalt".utf8data,
                                              keyByteCount: 16,
                                              rounds: 1003,
                                              kdf: .sha1)
    }

    private func decrypt(passwordData: Data, with key: Data) throws -> String {
        guard passwordData.count >= 4 else { throw importError(type: .passwordDataTooShort, underlyingError: nil) }

        let trimmedPasswordData = passwordData[3...]
        let iv = String(repeating: " ", count: 16).utf8data
        let decrypted = try Cryptography.decryptAESCBC(data: trimmedPasswordData, key: key, iv: iv)

        return try String(data: decrypted, encoding: .utf8) ?? { throw importError(type: .dataToStringConversionError, underlyingError: nil) }()
    }

}

// MARK: - GRDB Fetchable Records

private struct ChromiumCredential: Identifiable {

    var id: String {
        url + username
    }

    let url: String
    let username: String
    let encryptedPassword: Data
    let passwordModifiedAt: Int64?
}

extension ChromiumCredential: FetchableRecord {

    init(row: Row) {
        url = row["signon_realm"]
        username = row["username_value"]
        encryptedPassword = row["password_value"]
        passwordModifiedAt = row["date_password_modified"]
    }

}

fileprivate extension DatabaseError {
    var isMissingColumnError: Bool {
        guard let message = message else {
            return false
        }
        return message.hasPrefix("no such column")
    }
}
