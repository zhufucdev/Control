import Foundation

func getUniqueDocumentURL(filename: String) async throws -> URL {
    let container = (FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory)
        .appending(component: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
    return container.appending(component: filename, directoryHint: .notDirectory)
}
