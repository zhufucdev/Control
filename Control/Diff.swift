import Foundation

struct Diff<T: Hashable> {
    let addition: Set<T>
    let removal: Set<T>
}

extension Diff {
    init<I: Sequence<T>>(old: I, new: I) {
        let oldSet = Set(old)
        let newSet = Set(new)
        self.init(addition: newSet.subtracting(oldSet), removal: oldSet.subtracting(newSet))
    }
}
