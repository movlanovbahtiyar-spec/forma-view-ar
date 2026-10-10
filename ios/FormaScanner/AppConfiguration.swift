import Foundation
import Security

enum AppConfiguration {
    static var apiBaseURL: URL? {
        guard let raw = UserDefaults.standard.string(forKey: "forma.api.baseURL"),
              let url = URL(string: raw),
              url.scheme == "https" else { return nil }
        return url
    }

    static func save(baseURL: URL) {
        UserDefaults.standard.set(baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")), forKey: "forma.api.baseURL")
    }

    static var bearerToken: String? { Keychain.read(account: "forma.api.token") }

    static func save(bearerToken: String) throws {
        try Keychain.save(bearerToken, account: "forma.api.token")
    }
}

enum Keychain {
    static func save(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrAccount: account] as CFDictionary)
        let result = SecItemAdd([kSecClass: kSecClassGenericPassword, kSecAttrAccount: account, kSecValueData: data] as CFDictionary, nil)
        guard result == errSecSuccess else { throw KeychainError.unhandled(result) }
    }

    static func read(account: String) -> String? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching([kSecClass: kSecClassGenericPassword, kSecAttrAccount: account, kSecReturnData: true] as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    enum KeychainError: Error { case unhandled(OSStatus) }
}
