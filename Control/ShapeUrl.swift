import Foundation
import OpenAPIClient

extension URL {
    init?(shape: Shape, mainSiteUrl: String) {
        guard let mainSite = URL(string: mainSiteUrl) else {
            return nil
        }
        self = mainSite.appending(components: "shape", "\(shape.rawValue).svg")
    }
}
