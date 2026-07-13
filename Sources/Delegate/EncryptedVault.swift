import CryptoKit
import Foundation
import Security

enum VaultError: Error {
    case keychain(OSStatus)
    case invalidCiphertext
}

struct EncryptedVault: Sendable {
    private let service = "com.delegate.local-vault"
    private let account = "vault-key"
    private let fileURL: URL
    private let developmentKeyURL: URL

    init() {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let directory = support.appendingPathComponent("Delegate", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        fileURL = directory.appendingPathComponent("vault.bin")
        developmentKeyURL = directory.appendingPathComponent("development-vault.key")
    }

    func save<T: Encodable>(_ value: T) throws {
        let plaintext = try JSONEncoder().encode(value)
        let sealed = try AES.GCM.seal(plaintext, using: symmetricKey())
        guard let combined = sealed.combined else { throw VaultError.invalidCiphertext }
        try combined.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func load<T: Decodable>(_ type: T.Type) throws -> T? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let ciphertext = try Data(contentsOf: fileURL)
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        let plaintext = try AES.GCM.open(box, using: symmetricKey())
        return try JSONDecoder().decode(type, from: plaintext)
    }

    private func symmetricKey() throws -> SymmetricKey {
        if Bundle.main.object(forInfoDictionaryKey: "DelegateDevelopmentBuild") as? Bool == true {
            return try developmentKey()
        }
        if let existing = try readKey() {
            return SymmetricKey(data: existing)
        }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        try writeKey(data)
        return key
    }

    /// Ad-hoc signatures change identity after every local rebuild. A normal
    /// login-Keychain item therefore triggers an unresolvable trust prompt.
    /// Development builds use a 0600 local key; notarized builds use Keychain.
    private func developmentKey() throws -> SymmetricKey {
        if let data = try? Data(contentsOf: developmentKeyURL), data.count == 32 {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        try data.write(to: developmentKeyURL, options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: developmentKeyURL.path
        )
        return key
    }

    private func readKey() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw VaultError.keychain(status) }
        return result as? Data
    }

    private func writeKey(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw VaultError.keychain(status) }
    }
}
