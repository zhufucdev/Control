import Foundation
import SwiftData
import OpenAPIClient

@Model
final class CachedShape {
    @Attribute(.unique) var shape: Shape
    @Attribute(.externalStorage)  var image: Data
    var cacheTime: Date
    
    init(shape: Shape, image: Data, cacheTime: Date) {
        self.shape = shape
        self.image = image
        self.cacheTime = cacheTime
    }
}
