import Foundation

extension URL {
    var isCloudinaryResource: Bool {
        host() == "res.cloudinary.com"
    }

    func limitingSize(width: Int? = nil, height: Int? = nil) -> URL? {
        if width == nil && height == nil {
            return self
        }

        var paths = pathComponents
        guard paths.count > 3 && paths[3] == "upload" else { return nil }
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        var limitPathSeg = "c_limit"
        if let width {
            limitPathSeg += ",w_\(width)"
        }
        if let height {
            limitPathSeg += ",h_\(height)"
        }
        paths.insert(limitPathSeg, at: 4)
        components.path = paths.joined(separator: "/")
        return components.url
    }
}
