import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import SGRodStarCore

private struct RodStarChangerSettingsSnapshot {
    var stickersEnabled: Bool = true
    var stickerMode: Int = 0
    var packs: [String] = []
    var allowPacks: Set<String> = []
    var gifsEnabled: Bool = true
    var gifIds: Set<Int64> = []
    var emojiEnabled: Bool = false
    var emojiTexts: [String] = []
    var blurEnabled: Bool = true
    var banwordsEnabled: Bool = true
    var replies: [String] = []
    var banIndex: RodStarChangerBanIndex = RodStarChangerBanIndex(patterns: [])
    var signature: String = ""

    init() {
    }

    init(from settings: RodStarSettings) {
        self.stickersEnabled = settings.stickersEnabled
        self.stickerMode = settings.stickerMode
        self.packs = rodStarParseList(settings.stickerPacks).compactMap { raw in
            let name = rodStarNormalizePackName(raw)
            return name.isEmpty ? nil : name
        }
        self.allowPacks = Set(rodStarParseList(settings.stickerAllow).compactMap { raw in
            let name = rodStarNormalizePackName(raw)
            return name.isEmpty ? nil : name.lowercased()
        })
        self.gifsEnabled = settings.gifsEnabled
        var gifIds = Set<Int64>()
        for line in rodStarChangerParseLines(settings.gifIds) {
            for part in line.components(separatedBy: CharacterSet(charactersIn: ", ")).filter({ !$0.isEmpty }) {
                if let id = Int64(part) {
                    gifIds.insert(id)
                }
            }
        }
        self.gifIds = gifIds
        self.emojiEnabled = settings.emojiEnabled
        self.emojiTexts = rodStarChangerParseLines(settings.emojiTexts)
        self.blurEnabled = settings.blurEnabled
        self.banwordsEnabled = settings.banwordsEnabled
        self.replies = rodStarChangerParseLines(settings.replacements)
        self.banIndex = rodStarChangerBuildBanIndex(builtin: settings.banwordsBuiltin, userWords: settings.banwords)
        self.signature = RodStarChangerSettingsSnapshot.signature(from: settings)
    }

    static func signature(from settings: RodStarSettings) -> String {
        return [
            String(settings.stickersEnabled), String(settings.stickerMode), settings.stickerPacks, settings.stickerAllow,
            String(settings.gifsEnabled), settings.gifIds, String(settings.emojiEnabled), settings.emojiTexts,
            String(settings.blurEnabled), String(settings.banwordsEnabled), String(settings.banwordsBuiltin),
            settings.banwords, settings.replacements,
        ].joined(separator: "\u{1}")
    }
}

private struct RodStarChangerDecision {
    var file: TelegramMediaFile?
    var origDocId: Int64?
    var chosenDocId: Int64?
    var text: String?
    var origText: String?
    var stripMedia: Bool = false
    var spoiler: Bool = false

    var isEmpty: Bool {
        return self.file == nil && self.text == nil && !self.stripMedia && !self.spoiler
    }
}

private struct RodStarChangerDecisionKey: Hashable {
    let accountPeerId: PeerId
    let peerId: PeerId
    let messageId: Int32
}

private func rodStarChangerIsStickerDoc(_ file: TelegramMediaFile) -> Bool {
    return file.isSticker && !file.isCustomEmoji
}

private func rodStarChangerIsGifDoc(_ file: TelegramMediaFile) -> Bool {
    if rodStarChangerIsStickerDoc(file) || !file.isAnimated {
        return false
    }
    let mime = file.mimeType.lowercased()
    if !mime.isEmpty && !mime.contains("gif") && !mime.contains("mp4") && !mime.contains("webm") {
        return false
    }
    return true
}

private func rodStarChangerIsImageDoc(_ file: TelegramMediaFile) -> Bool {
    if file.mimeType.lowercased().hasPrefix("image/") {
        return true
    }
    for attribute in file.attributes {
        if case .ImageSize = attribute {
            return true
        }
    }
    return false
}

private func rodStarChangerMessageDoc(_ message: StoreMessage) -> TelegramMediaFile? {
    return message.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile
}

private final class RodStarChangerEngine {
    private static let enginesLock = NSLock()
    private static var engines: [PeerId: RodStarChangerEngine] = [:]

    static func register(context: AccountContext) {
        let accountPeerId = context.account.peerId
        self.enginesLock.lock()
        let engine = self.engines[accountPeerId] ?? RodStarChangerEngine()
        self.engines[accountPeerId] = engine
        self.enginesLock.unlock()
        engine.attach(context: context)

        SGRodStarHooks.transformIncomingMessages = { messages, accountPeerId in
            self.enginesLock.lock()
            let engine = self.engines[accountPeerId]
            self.enginesLock.unlock()
            return engine?.transform(messages: messages, accountPeerId: accountPeerId) ?? messages
        }
        SGRodStarHooks.transformEditedMessage = { message, accountPeerId in
            self.enginesLock.lock()
            let engine = self.engines[accountPeerId]
            self.enginesLock.unlock()
            return engine?.transformEdited(message: message, accountPeerId: accountPeerId) ?? message
        }
    }

    private weak var context: AccountContext?
    private let queue = Queue(name: "SGRodStarChanger")
    private let lock = NSLock()

    private var settings = RodStarChangerSettingsSnapshot()
    private var packDocs: [String: [TelegramMediaFile]] = [:]
    private var fetchingPacks: Set<String> = []
    private var savedGifs: [TelegramMediaFile] = []
    private var gifPool: [TelegramMediaFile] = []
    private var installedPackNames: [Int64: String] = [:]
    private var decisions: [RodStarChangerDecisionKey: RodStarChangerDecision] = [:]
    private var decisionOrder: [RodStarChangerDecisionKey] = []

    private let gifsDisposable = MetaDisposable()
    private let installedDisposable = MetaDisposable()
    private var fetchDisposables: [Disposable] = []
    private var observers: [NSObjectProtocol] = []

    deinit {
        self.gifsDisposable.dispose()
        self.installedDisposable.dispose()
        for disposable in self.fetchDisposables {
            disposable.dispose()
        }
        for observer in self.observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func attach(context: AccountContext) {
        self.context = context

        for observer in self.observers {
            NotificationCenter.default.removeObserver(observer)
        }
        self.observers = []
        self.observers.append(NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: nil, using: { [weak self] _ in
            self?.queue.async {
                self?.rebuildSettingsIfChanged(force: false)
            }
        }))
        self.observers.append(NotificationCenter.default.addObserver(forName: Notification.Name("SGRodStarChangerRefreshPools"), object: nil, queue: nil, using: { [weak self] _ in
            self?.queue.async {
                self?.refreshPools()
            }
        }))

        self.gifsDisposable.set((context.engine.data.subscribe(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs))
        |> deliverOn(self.queue)).start(next: { [weak self] entries in
            guard let self else {
                return
            }
            let files = entries.compactMap { entry -> TelegramMediaFile? in
                guard let item = entry.contents.get(RecentMediaItem.self) else {
                    return nil
                }
                let file = item.media._parse()
                return rodStarChangerIsGifDoc(file) ? file : nil
            }
            self.lock.lock()
            self.savedGifs = files
            self.gifPool = self.filterGifs(files)
            self.lock.unlock()
        }))

        self.installedDisposable.set((context.engine.data.subscribe(TelegramEngine.EngineData.Item.ItemCollections.InstalledPackInfos(namespace: Namespaces.ItemCollection.CloudStickerPacks))
        |> deliverOn(self.queue)).start(next: { [weak self] entries in
            guard let self else {
                return
            }
            var names: [Int64: String] = [:]
            for entry in entries {
                if let info = entry.info as? StickerPackCollectionInfo, !info.shortName.isEmpty {
                    names[entry.id.id] = info.shortName.lowercased()
                }
            }
            self.lock.lock()
            self.installedPackNames = names
            self.lock.unlock()
        }))

        self.queue.async {
            self.rebuildSettingsIfChanged(force: true)
        }
    }

    private func filterGifs(_ files: [TelegramMediaFile]) -> [TelegramMediaFile] {
        let ids = self.settings.gifIds
        if ids.isEmpty {
            return files
        }
        let filtered = files.filter { ids.contains($0.fileId.id) }
        return filtered.isEmpty ? files : filtered
    }

    private func rebuildSettingsIfChanged(force: Bool) {
        let shared = RodStarSettings.shared
        let signature = RodStarChangerSettingsSnapshot.signature(from: shared)
        self.lock.lock()
        if !force && signature == self.settings.signature {
            self.lock.unlock()
            return
        }
        self.lock.unlock()
        let updated = RodStarChangerSettingsSnapshot(from: shared)
        self.lock.lock()
        self.settings = updated
        self.decisions.removeAll()
        self.decisionOrder.removeAll()
        self.gifPool = self.filterGifs(self.savedGifs)
        self.lock.unlock()
        self.refreshPools()
    }

    private func stickerPool() -> [TelegramMediaFile] {
        var result: [TelegramMediaFile] = []
        for name in self.settings.packs {
            result.append(contentsOf: self.packDocs[name.lowercased()] ?? [])
        }
        return result
    }

    private func refreshPools() {
        guard let context = self.context else {
            return
        }
        self.lock.lock()
        var missing: [String] = []
        for name in self.settings.packs {
            let key = name.lowercased()
            if self.packDocs[key] == nil && !self.fetchingPacks.contains(key) {
                missing.append(name)
                self.fetchingPacks.insert(key)
            }
        }
        self.lock.unlock()

        for name in missing {
            let key = name.lowercased()
            let disposable = (context.engine.stickers.loadedStickerPack(reference: .name(name), forceActualized: false)
            |> deliverOn(self.queue)).start(next: { [weak self] value in
                guard let self else {
                    return
                }
                if case let .result(_, items, _) = value {
                    let files = items.map { $0.file._parse() }.filter { rodStarChangerIsStickerDoc($0) }
                    if !files.isEmpty {
                        self.lock.lock()
                        self.packDocs[key] = files
                        self.lock.unlock()
                    }
                }
            }, completed: { [weak self] in
                guard let self else {
                    return
                }
                self.lock.lock()
                self.fetchingPacks.remove(key)
                self.lock.unlock()
            })
            self.lock.lock()
            self.fetchDisposables.append(disposable)
            if self.fetchDisposables.count > 64 {
                self.fetchDisposables.removeFirst(self.fetchDisposables.count - 64)
            }
            self.lock.unlock()
        }
    }

    private func stickerAllowed(_ file: TelegramMediaFile) -> Bool {
        if self.settings.stickerMode <= 0 || self.settings.allowPacks.isEmpty {
            return false
        }
        for attribute in file.attributes {
            if case let .Sticker(_, packReference, _) = attribute, let packReference = packReference {
                switch packReference {
                case let .name(name):
                    if self.settings.allowPacks.contains(name.lowercased()) {
                        return true
                    }
                case let .id(id, _):
                    if let name = self.installedPackNames[id], self.settings.allowPacks.contains(name) {
                        return true
                    }
                default:
                    break
                }
            }
        }
        return false
    }

    private func decisionValid(_ decision: RodStarChangerDecision, message: StoreMessage) -> Bool {
        if let origDocId = decision.origDocId {
            let current = rodStarChangerMessageDoc(message)?.fileId.id ?? 0
            if current != origDocId && current != (decision.chosenDocId ?? 0) {
                return false
            }
        }
        if let origText = decision.origText {
            if message.text != origText && message.text != (decision.text ?? "") {
                return false
            }
        }
        return true
    }

    private func decide(message: StoreMessage) -> (RodStarChangerDecision, Bool) {
        let settings = self.settings
        let doc = rodStarChangerMessageDoc(message)
        let isPhoto = message.media.contains(where: { $0 is TelegramMediaImage })
        let isSticker = doc.map(rodStarChangerIsStickerDoc) ?? false
        let isGif = doc.map(rodStarChangerIsGifDoc) ?? false
        let isVideo = (doc?.isVideo ?? false) && !isSticker && !isGif
        let isImage = !isSticker && !isGif && (doc.map(rodStarChangerIsImageDoc) ?? false)

        var decision = RodStarChangerDecision()
        var needsRefresh = false

        if isSticker, let doc = doc, settings.stickersEnabled {
            if !self.stickerAllowed(doc) {
                let pool = self.stickerPool()
                if pool.isEmpty {
                    needsRefresh = true
                }
                if let chosen = pool.randomElement() {
                    decision.file = chosen
                    decision.origDocId = doc.fileId.id
                    decision.chosenDocId = chosen.fileId.id
                } else {
                    decision.text = rodStarChangerDefaultReply
                    decision.origText = message.text
                    decision.stripMedia = true
                }
            }
        }

        if decision.isEmpty, isGif, let doc = doc, settings.gifsEnabled {
            let pool = self.gifPool
            if pool.isEmpty {
                needsRefresh = true
            }
            if let chosen = pool.randomElement() {
                decision.file = chosen
                decision.origDocId = doc.fileId.id
                decision.chosenDocId = chosen.fileId.id
            } else {
                decision.text = rodStarChangerDefaultReply
                decision.origText = message.text
                decision.stripMedia = true
            }
        }

        if decision.isEmpty && settings.blurEnabled && (isPhoto || isVideo || isImage) {
            if !message.attributes.contains(where: { $0 is MediaSpoilerMessageAttribute }) {
                decision.spoiler = true
            }
        }

        if settings.banwordsEnabled && !message.text.isEmpty {
            if settings.banIndex.find(message.text) != nil {
                decision.text = settings.replies.randomElement() ?? rodStarChangerDefaultReply
                decision.origText = message.text
            }
        }

        if decision.isEmpty && !(isPhoto || isVideo || isImage || isSticker || isGif) && !message.text.isEmpty && settings.emojiEnabled && rodStarChangerHasEmoji(message.text) {
            decision.text = settings.emojiTexts.randomElement() ?? rodStarChangerDefaultReply
            decision.origText = message.text
        }

        return (decision, needsRefresh)
    }

    private func apply(_ decision: RodStarChangerDecision, to message: StoreMessage) -> StoreMessage {
        if decision.isEmpty {
            return message
        }
        var text = message.text
        var media = message.media
        var attributes = message.attributes
        var changed = false
        if let file = decision.file {
            media = [file]
            text = ""
            attributes.removeAll(where: { $0 is TextEntitiesMessageAttribute })
            changed = true
        }
        if decision.stripMedia && !media.isEmpty {
            media = []
            attributes.removeAll(where: { $0 is TextEntitiesMessageAttribute })
            changed = true
        }
        if decision.spoiler && !attributes.contains(where: { $0 is MediaSpoilerMessageAttribute }) {
            attributes.append(MediaSpoilerMessageAttribute())
            changed = true
        }
        if let newText = decision.text, text != newText {
            text = newText
            attributes.removeAll(where: { $0 is TextEntitiesMessageAttribute })
            changed = true
        }
        if !changed {
            return message
        }
        return StoreMessage(id: message.id, customStableId: message.customStableId, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: text, attributes: attributes, media: media)
    }

    private func transformOne(message: StoreMessage, accountPeerId: PeerId, invalidate: Bool) -> StoreMessage {
        guard message.flags.contains(.Incoming), case let .Id(id) = message.id else {
            return message
        }
        let key = RodStarChangerDecisionKey(accountPeerId: accountPeerId, peerId: id.peerId, messageId: id.id)

        self.lock.lock()
        if invalidate {
            if self.decisions.removeValue(forKey: key) != nil {
                self.decisionOrder.removeAll(where: { $0 == key })
            }
        }
        var decision = self.decisions[key]
        if let existing = decision, !self.decisionValid(existing, message: message) {
            self.decisions.removeValue(forKey: key)
            self.decisionOrder.removeAll(where: { $0 == key })
            decision = nil
        }
        var needsRefresh = false
        if decision == nil {
            let (resolved, refresh) = self.decide(message: message)
            decision = resolved
            needsRefresh = refresh
            self.decisions[key] = resolved
            self.decisionOrder.append(key)
            while self.decisionOrder.count > 6000 {
                let evicted = self.decisionOrder.removeFirst()
                self.decisions.removeValue(forKey: evicted)
            }
        }
        let resolved = decision!
        self.lock.unlock()

        if needsRefresh {
            self.queue.async {
                self.refreshPools()
            }
        }
        return self.apply(resolved, to: message)
    }

    func transform(messages: [StoreMessage], accountPeerId: PeerId) -> [StoreMessage] {
        var result: [StoreMessage] = []
        result.reserveCapacity(messages.count)
        for message in messages {
            result.append(self.transformOne(message: message, accountPeerId: accountPeerId, invalidate: false))
        }
        return result
    }

    func transformEdited(message: StoreMessage, accountPeerId: PeerId) -> StoreMessage {
        return self.transformOne(message: message, accountPeerId: accountPeerId, invalidate: true)
    }
}

public func sgRodStarChangerRegister(context: AccountContext) {
    RodStarChangerEngine.register(context: context)
}