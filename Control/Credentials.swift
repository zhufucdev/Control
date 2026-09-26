import Foundation
import Valet

fileprivate let kPostAuthKey = "postAuthKey"
fileprivate let kEndpointBaseUrl = "endpointBaseUrl"
fileprivate let kMainSiteUrl = "mainSiteUrl"

fileprivate let kClientSideImageService = "clientImageService"
fileprivate let kCloudinaryAPIBaseUrl = "cloudinaryApiBaseUrl"
fileprivate let kCloudName = "cloudinaryCloudName"
fileprivate let kPresetName = "cloudinaryPresetName"
fileprivate let kInitialized = "initialized"

#if DEBUG
fileprivate let SafeStorage = "Control-Debug"
#else
fileprivate let SafeStorage = "Control"
#endif

struct Credentials {
    public static let `default` = Credentials()
    let keyring = Valet.iCloudValet(with: Identifier(nonEmpty: SafeStorage)!, accessibility: .whenUnlocked)
    let presence = SecureEnclaveValet.valet(with: Identifier(nonEmpty: SafeStorage)!, accessControl: .userPresence)
    
    func ensureUserPresence() throws {
        do {
            try presence.setObject(Data(repeating: 1, count: 1), forKey: kInitialized)
            _ = try presence.object(forKey: kInitialized, withPrompt: "access secrets and settings")
        } catch KeychainError.itemNotFound {
            // it's ok
        } catch KeychainError.userCancelled {
            throw CredentialAccessDenialError()
        }
    }
    
    public var postAuthKey: String? {
        get throws {
            try `for`(string: kPostAuthKey)
        }
    }

    public func setPostAuthKey(newValue: String?) throws {
        try set(string: kPostAuthKey, newValue: newValue)
    }
    
    public var endpointBaseUrl: String? {
        get throws {
            try `for`(string: kEndpointBaseUrl)
        }
    }
    
    public func setEndpointBaseUrl(newValue: String?) throws {
        try set(string: kEndpointBaseUrl, newValue: newValue)
    }
    
    public var mainSiteUrl: String? {
        get throws {
            try `for`(string: kMainSiteUrl)
        }
    }
    
    public func setMainSiteUrl(newValue: String?) throws {
        try set(string: kMainSiteUrl, newValue: newValue)
    }
    
    public var clientSideImageService: ClientSideImageService? {
        get throws {
            guard let name = try `for`(string: kClientSideImageService) else {
                return nil
            }
            return ClientSideImageService(rawValue: name)
        }
    }
    
    public func setClientSideImageService(newValue: ClientSideImageService?) throws {
        try set(string: kClientSideImageService, newValue: newValue?.rawValue)
    }
    
    public var cloudinaryAPIBaseUrl: String? {
        get throws {
            try `for`(string: kCloudinaryAPIBaseUrl)
        }
    }
    
    public func setCloudinaryAPIBaseUrl(newValue: String?) throws {
        try set(string: kCloudinaryAPIBaseUrl, newValue: newValue)
    }

    public var cloudName: String? {
        get throws {
            try `for`(string: kCloudName)
        }
    }
    
    public func setCloudName(newValue: String?) throws {
        try set(string: kCloudName, newValue: newValue)
    }
    
    public var presetName: String? {
        get throws {
            try `for`(string: kPresetName)
        }
    }
    
    public func setPresetName(newValue: String?) throws {
        try set(string: kPresetName, newValue: newValue)
    }
    
    public var initialized: Bool {
        get throws {
            try `for`(bool: kInitialized) == true
        }
    }
    
    public func setInitialized(newValue: Bool) throws {
        try set(bool: kInitialized, newValue: newValue)
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

struct CredentialAccessDenialError: Error {
}
