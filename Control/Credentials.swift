import Foundation
import Valet

fileprivate let PostAuthKey = "post-auth-key"
#if DEBUG
fileprivate let SafeStorage = "Control Safe Storage (Debug)"
#else
fileprivate let SafeStorage = "Control Safe Storage"
#endif

struct Credentials {
    public static let `default` = Credentials()
    let keyring = SecureEnclaveValet.valet(with: Identifier(nonEmpty: SafeStorage)!, accessControl: .userPresence)

    public var postAuthKey: String? {
        get async throws {
            do {
                return try keyring.string(forKey: PostAuthKey, withPrompt: "access the post authorization key")
            } catch KeychainError.itemNotFound {
                return nil
            } catch KeychainError.userCancelled {
                throw CredentialAccessDenialError(keychainKey: PostAuthKey)
            }
        }
    }

    @MainActor
    public func setPostAuthKey(newValue: String?) async throws {
        if let value = newValue {
            try keyring.setString(value, forKey: PostAuthKey)
        } else {
            try keyring.removeObject(forKey: PostAuthKey)
        }
    }
}

struct CredentialAccessDenialError: Error {
    let keychainKey: String
}
