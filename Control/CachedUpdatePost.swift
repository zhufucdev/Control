import Foundation
import SwiftData
import OpenAPIClient

@Model
final class CachedUpdatePost {
    var id: Int
    var created: Date
    var header: String
    var title: String
    var summary: String
    var cover: UpdatePostCover?
    var mask: Shape
    var locale: SupportedLocale
    var trashed: Bool
    
    var draft: Bool {
        id < 0
    }
    
    init(id: Int, created: Date, header: String, title: String, summary: String, cover: UpdatePostCover? = nil, mask: Shape, locale: SupportedLocale, trashed: Bool) {
        self.id = id
        self.created = created
        self.header = header
        self.title = title
        self.summary = summary
        self.cover = cover
        self.mask = mask
        self.locale = locale
        self.trashed = trashed
    }
    
    convenience init(from: UpdatePost) {
        self.init(id: from.id, created: from.created, header: from.header, title: from.title, summary: from.summary, cover: from.cover, mask: from.mask, locale: from.locale, trashed: from.trashed)
    }
    
    convenience init() {
        self.init(id: -1, created: Date(), header: String(localized: "Status update"), title: String(localized: "New post"), summary: String(localized: "No content"), mask: .clover, locale: .en, trashed: false)
    }
}

extension UpdatePost {
    init(cache: CachedUpdatePost) {
        self.init(id: cache.id, created: cache.created, header: cache.header, title: cache.title, summary: cache.summary, mask: cache.mask, locale: cache.locale, trashed: cache.trashed, cover: cache.cover)
    }
}
