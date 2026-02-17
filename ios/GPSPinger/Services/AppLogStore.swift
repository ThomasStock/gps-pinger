import Foundation

struct AppLogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let message: String
}

@MainActor
final class AppLogStore: ObservableObject {
    @Published private(set) var entries: [AppLogEntry] = []
    private let maxEntries = 600

    func add(_ message: String, at timestamp: Date = Date()) {
        entries.append(AppLogEntry(timestamp: timestamp, message: message))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }
}
