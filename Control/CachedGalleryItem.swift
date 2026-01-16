import Foundation
import OpenAPIClient
import SwiftData

@Model
final class CachedGalleryItem {
    var id: Int
    var locale: SupportedLocale?
    var tweet: String?
    var image: String
    var created: Date
    var trashed: Bool

    init(id: Int, locale: SupportedLocale? = nil, tweet: String? = nil, image: String, created: Date, trashed: Bool) {
        self.created = created
        self.id = id
        self.locale = locale
        self.tweet = tweet
        self.image = image
        self.created = created
        self.trashed = trashed
    }

    convenience init(from: GalleryItem) {
        self.init(id: from.id, locale: from.locale, tweet: from.tweet, image: from.image, created: from.created, trashed: from.trashed)
    }

    convenience init() {
        self.init(id: -1, image: "", created: Date(), trashed: false)
    }
}

