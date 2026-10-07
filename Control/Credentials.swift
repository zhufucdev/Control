import Foundation
import Valet

private let kPostAuthKey = "postAuthKey"
private let kEndpointBaseUrl = "endpointBaseUrl"
private let kMainSiteUrl = "mainSiteUrl"

private let kClientSideImageService = "clientImageService"
private let kCloudinaryAPIBaseUrl = "cloudinaryApiBaseUrl"
private let kCloudName = "cloudinaryCloudName"
private let kPresetName = "cloudinaryPresetName"

private let kOpenAIBaseUrl = "openAIBaseUrl"
private let kOpenAIApiKey = "openAIApiKey"
private let kOpenAIModelName = "openAIModelName"

private let kInitialized = "initialized"

#if DEBUG
    fileprivate let SafeStorage = "Control-Debug"
#else
    fileprivate let SafeStorage = "Control"
#endif

struct Credentials {
    static let `default` = Credentials()
    let keyring = Valet.iCloudValet(with: Identifier(nonEmpty: SafeStorage)!, accessibility: .whenUnlocked)
    let presence = SecureEnclaveValet.valet(with: Identifier(nonEmpty: SafeStorage)!, accessControl: .userPresence)

    func ensureUserPresence() throws {
        #if DEBUG
            return
        #endif
        do {
            try presence.setObject(Data(repeating: 1, count: 1), forKey: kInitialized)
            _ = try presence.object(forKey: kInitialized, withPrompt: "access secrets and settings")
        } catch KeychainError.itemNotFound {
            // it's ok
        } catch KeychainError.userCancelled {
            throw CredentialAccessDenialError()
        }
    }

    var postAuthKey: String? {
        get throws {
            try `for`(string: kPostAuthKey)
        }
    }

    func setPostAuthKey(newValue: String?) throws {
        try set(string: kPostAuthKey, newValue: newValue)
    }

    var endpointBaseUrl: String? {
        get throws {
            try `for`(string: kEndpointBaseUrl)
        }
    }

    func setEndpointBaseUrl(newValue: String?) throws {
        try set(string: kEndpointBaseUrl, newValue: newValue)
    }

    var mainSiteUrl: String? {
        get throws {
            try `for`(string: kMainSiteUrl)
        }
    }

    func setMainSiteUrl(newValue: String?) throws {
        try set(string: kMainSiteUrl, newValue: newValue)
    }

    var clientSideImageService: ClientSideImageService? {
        get throws {
            guard let name = try `for`(string: kClientSideImageService) else {
                return nil
            }
            return ClientSideImageService(rawValue: name)
        }
    }

    func setClientSideImageService(newValue: ClientSideImageService?) throws {
        try set(string: kClientSideImageService, newValue: newValue?.rawValue)
    }

    var cloudinaryAPIBaseUrl: String? {
        get throws {
            try `for`(string: kCloudinaryAPIBaseUrl)
        }
    }

    func setCloudinaryAPIBaseUrl(newValue: String?) throws {
        try set(string: kCloudinaryAPIBaseUrl, newValue: newValue)
    }

    var cloudName: String? {
        get throws {
            try `for`(string: kCloudName)
        }
    }

    func setCloudName(newValue: String?) throws {
        try set(string: kCloudName, newValue: newValue)
    }

    var presetName: String? {
        get throws {
            try `for`(string: kPresetName)
        }
    }

    func setPresetName(newValue: String?) throws {
        try set(string: kPresetName, newValue: newValue)
    }

    var initialized: Bool {
        get throws {
            try `for`(bool: kInitialized) == true
        }
    }

    func setInitialized(newValue: Bool) throws {
        try set(bool: kInitialized, newValue: newValue)
    }

    var openAIBaseUrl: String? {
        get throws {
            try `for`(string: kOpenAIBaseUrl)
        }
    }

    func setOpenAIBaseUrl(newValue: String?) throws {
        try set(string: kOpenAIBaseUrl, newValue: newValue)
    }

    var openAIApiKey: String? {
        get throws {
            try `for`(string: kOpenAIApiKey)
        }
    }

    func setOpenAIApiKey(newValue: String?) throws {
        try set(string: kOpenAIApiKey, newValue: newValue)
    }

    var openAIModelName: String? {
        get throws {
            try `for`(string: kOpenAIModelName)
        }
    }

    func setOpenAIModelName(newValue: String?) throws {
        try set(string: kOpenAIModelName, newValue: newValue)
    }

    private func `for`(string: String) throws -> String? {
        do {
            return try keyring.string(forKey: string)
        } catch KeychainError.itemNotFound {
            return nil
        } catch KeychainError.userCancelled {
            throw CredentialAccessDenialError()
        }
    }

    private func `for`(bool: String) throws -> Bool? {
        do {
            guard let data = try keyring.object(forKey: bool).first else {
                return nil
            }
            return data == UInt8(1)
        } catch KeychainError.itemNotFound {
            return nil
        } catch KeychainError.userCancelled {
            throw CredentialAccessDenialError()
        }
    }

    private func set(string: String, newValue: String?) throws {
        if let newValue, !newValue.isEmpty {
            try keyring.setString(newValue, forKey: string)
        } else {
            try keyring.removeObject(forKey: string)
        }
    }

    private func set(bool: String, newValue: Bool?) throws {
        if let newValue {
            try keyring.setObject(Data(repeating: newValue ? 1 : 0, count: 1), forKey: bool)
        } else {
            try keyring.removeObject(forKey: bool)
        }
    }
}

struct CredentialAccessDenialError: Error {}
