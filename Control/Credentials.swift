import Foundation
import KeychainAccess

fileprivate let PostAuthKey = "post-auth-key"

struct Credentials {
    public static let `default` = Credentials()

    public var postAuthKey: String? {
        get async throws {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global().async {
                    do {
                        let key = try Keychain().getString(PostAuthKey)
                        if let key = key {
                            continuation.resume(returning: key)
                        } else if let hasKey = try? Keychain().contains(PostAuthKey, withoutAuthenticationUI: true), !hasKey {
                            continuation.resume(throwing: CredentialAccessDenialError(keychainKey: PostAuthKey))
                        } else {
                            continuation.resume(returning: nil)
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    public func setPostAuthKey(newValue: String?) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    if let value = newValue {
                        #if os(iOS)
                            let authenticationPolicy: AuthenticationPolicy =
                                [.biometryAny, .devicePasscode]
                        #elseif os(macOS)
                            let authenticationPolicy: AuthenticationPolicy =
                                [.biometryAny, .devicePasscode, .watch]
                        #endif
                        try Keychain()
                            .accessibility(
                                .whenPasscodeSetThisDeviceOnly,
                                authenticationPolicy: authenticationPolicy
                            )
                            .set(value, key: PostAuthKey)
                    } else {
                        try Keychain().remove(PostAuthKey)
                    }
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

struct CredentialAccessDenialError: Error {
    let keychainKey: String
}
