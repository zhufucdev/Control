import Foundation
import OpenAPIClient
import SwiftData

@Model
final class CachedGalleryItem {
    var id: Int
    var locale: SupportedLocale?
    var tweet: String?
    var image: String
    var alt: String
    var created: Date
    var trashed: Bool

    init(id: Int, locale: SupportedLocale? = nil, tweet: String? = nil, image: String, alt: String, created: Date, trashed: Bool) {
        self.created = created
        self.id = id
        self.locale = locale
        self.tweet = tweet
        self.image = image
        self.alt = alt
        self.created = created
        self.trashed = trashed
    }

    convenience init(from: GalleryItem) {
        self.init(id: from.id, locale: from.locale, tweet: from.tweet, image: from.image, alt: from.alt, created: from.created, trashed: from.trashed)
    }

    convenience init() {
        self.init(id: -1, image: "", alt: "", created: Date(), trashed: false)
    }
}
