import Foundation

public final class RodStarArchiveStore<T: Codable> {
    private let fileUrl: URL
    private let cap: Int
    private let queue = DispatchQueue(label: "rodstar.archive")
    private var entries: [String: T] = [:]
    private var order: [String] = []
    private var loaded = false

    public init(fileName: String, cap: Int) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        self.fileUrl = support.appendingPathComponent(fileName)
        self.cap = cap
    }

    private func loadIfNeeded() {
        if self.loaded {
            return
        }
        self.loaded = true
        if let data = try? Data(contentsOf: self.fileUrl),
           let decoded = try? JSONDecoder().decode([String: T].self, from: data) {
            self.entries = decoded
            self.order = Array(decoded.keys)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(self.entries) {
            let tmp = self.fileUrl.appendingPathExtension("tmp")
            try? data.write(to: tmp)
            _ = try? FileManager.default.replaceItemAt(self.fileUrl, withItemAt: tmp)
        }
    }

    public func set(_ key: String, _ value: T) {
        self.queue.sync {
            self.loadIfNeeded()
            if self.entries[key] == nil {
                self.order.append(key)
            }
            self.entries[key] = value
            while self.order.count > self.cap {
                let oldest = self.order.removeFirst()
                self.entries.removeValue(forKey: oldest)
            }
            self.save()
        }
    }

    public func get(_ key: String) -> T? {
        return self.queue.sync {
            self.loadIfNeeded()
            return self.entries[key]
        }
    }

    public func all() -> [String: T] {
        return self.queue.sync {
            self.loadIfNeeded()
            return self.entries
        }
    }

    public func remove(_ key: String) {
        self.queue.sync {
            self.loadIfNeeded()
            self.entries.removeValue(forKey: key)
            self.order.removeAll { $0 == key }
            self.save()
        }
    }
}

public struct RodStarDialogPreview: Codable {
    public var msgId: Int64
    public var text: String
    public var date: Int32

    public init(msgId: Int64, text: String, date: Int32) {
        self.msgId = msgId
        self.text = text
        self.date = date
    }
}