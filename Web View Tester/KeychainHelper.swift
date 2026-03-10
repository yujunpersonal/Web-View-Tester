import Foundation
import Security

enum KeychainHelper {

    private static let service = "cn.buddy.webviewtester"

    // MARK: - Launch Count

    private static let launchCountKey = "launchCount"

    static var launchCount: Int {
        get { integer(forKey: launchCountKey) }
        set { setInteger(newValue, forKey: launchCountKey) }
    }

    // MARK: - Generic Helpers

    private static func data(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func setData(_ data: Data, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    private static func integer(forKey key: String) -> Int {
        guard let data = data(forKey: key),
              let string = String(data: data, encoding: .utf8),
              let value = Int(string) else {
            return 0
        }
        return value
    }

    private static func setInteger(_ value: Int, forKey key: String) {
        let data = String(value).data(using: .utf8)!
        setData(data, forKey: key)
    }
}
