import Foundation
import OpenAPIClient

extension SupportedLocale {
    var name: String {
        switch self {
        case .en:
            String(localized: "English")
        case .zh:
            String(localized: "Chinese (Simplified)")
        case .zhTw:
            String(localized: "Chinese (Traditional)")
        }
    }
}
