import Foundation
import _PhotosUI_SwiftUI
import CoreImage

func getTweetImageURL(photoSelection: PhotosPickerItem, stripExif: Bool) async throws -> URL {
    guard let image = try? await photoSelection.loadTransferable(type: DataUrl.self) else {
        throw DataUrlError.noSuitableConversion
    }

    if stripExif {
        guard let imageData = try? Data(contentsOf: image.url) else {
            throw GetTweetImageError.imageRead
        }
        guard let stripped = imageData.removingEXIF() else {
            throw GetTweetImageError.exifRemoval
        }
        do {
            try await Task.detached {
                try stripped.write(to: image.url)
            }.value
        } catch {
            throw GetTweetImageError.imageWrite(error)
        }
    }

    return image.url
}

