import Foundation

fileprivate var latestHolder = [String: UUID]()

func withDebounce<T>(key: String, for: Duration, _ action: @escaping () -> T) async -> DebounceResult<T> {
    let thisHolder = UUID()
    latestHolder[key] = thisHolder
    try? await Task.sleep(for: `for`)
    if let holder = latestHolder[key], holder == thisHolder {
        latestHolder.removeValue(forKey: key)
        return .won(action())
    }
    return .lost
}

enum DebounceResult<T> {
    case won(T)
    case lost
}
