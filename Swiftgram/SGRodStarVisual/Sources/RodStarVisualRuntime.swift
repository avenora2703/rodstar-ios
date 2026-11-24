import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import SGRodStarCore

public struct RodStarVisualSpend: Codable {
    public var id: String
    public var date: Int32
    public var value: Int64
    public var nanos: Int32
    public var ton: Bool

    public init(id: String, date: Int32, value: Int64, nanos: Int32, ton: Bool) {
        self.id = id
        self.date = date
        self.value = value
        self.nanos = nanos
        self.ton = ton
    }
}

final class RodStarVisualWeakContext {
    weak var value: AccountContext?

    init(_ value: AccountContext) {
        self.value = value
    }
}

final class RodStarVisualRuntime {
    static let shared = RodStarVisualRuntime()

    private let lock = NSLock()
    private var contexts: [PeerId: RodStarVisualWeakContext] = [:]
    private var selfPeers: [PeerId: EnginePeer] = [:]
    private var modes: [PeerId: Bool] = [:]
    private var busy = false
    private var lastSendAt: [PeerId: Double] = [:]
    private var replyPendingUntil: [PeerId: Double] = [:]

    let spends = RodStarArchiveStore<RodStarVisualSpend>(fileName: "rodstar_spends_v1.json", cap: 200)
    let recipientGifts = RodStarArchiveStore<ProfileGiftsContext.State.StarGift>(fileName: "rodstar_recipient_gifts_v1.json", cap: 500)
    let previews = RodStarArchiveStore<RodStarDialogPreview>(fileName: "rodstar_pf_preview_v1.json", cap: 500)

    func setContext(_ context: AccountContext) {
        self.lock.lock()
        self.contexts[context.account.peerId] = RodStarVisualWeakContext(context)
        self.lock.unlock()

        let accountPeerId = context.account.peerId
        let _ = context.account.postbox.transaction { transaction -> Void in
            if let peer = transaction.getPeer(accountPeerId) {
                self.lock.lock()
                self.selfPeers[accountPeerId] = EnginePeer(peer)
                self.lock.unlock()
            }
        }.start()
    }

    func context(for accountPeerId: PeerId) -> AccountContext? {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.contexts[accountPeerId]?.value
    }

    func selfPeer(for accountPeerId: PeerId) -> EnginePeer? {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.selfPeers[accountPeerId]
    }

    func isVisualMode(accountPeerId: PeerId) -> Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        if let mode = self.modes[accountPeerId] {
            return mode
        }
        return RodStarSettings.shared.visualMode
    }

    func resetModeForOpen(accountPeerId: PeerId) {
        let settings = RodStarSettings.shared
        let visual: Bool
        switch settings.defaultSendMode {
        case 0:
            visual = false
        case 2:
            visual = settings.lastSendMode != 0
        default:
            visual = true
        }
        self.lock.lock()
        self.modes[accountPeerId] = visual
        self.lock.unlock()
        settings.visualMode = visual
    }

    func toggleMode(accountPeerId: PeerId) -> Bool {
        let visual = !self.isVisualMode(accountPeerId: accountPeerId)
        self.lock.lock()
        self.modes[accountPeerId] = visual
        self.lock.unlock()
        let settings = RodStarSettings.shared
        settings.visualMode = visual
        settings.lastSendMode = visual ? 1 : 0
        return visual
    }

    func claimSend(recipientPeerId: PeerId) -> Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        let now = CFAbsoluteTimeGetCurrent()
        if self.busy {
            return false
        }
        if let last = self.lastSendAt[recipientPeerId], now - last < 0.8 {
            return false
        }
        self.busy = true
        self.lastSendAt[recipientPeerId] = now
        return true
    }

    func releaseBusy() {
        self.lock.lock()
        self.busy = false
        self.lock.unlock()
    }

    func claimReply(recipientPeerId: PeerId, until: Double) -> Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        if let pending = self.replyPendingUntil[recipientPeerId], pending > CFAbsoluteTimeGetCurrent() {
            return false
        }
        self.replyPendingUntil[recipientPeerId] = until
        return true
    }

    func clearReply(recipientPeerId: PeerId) {
        self.lock.lock()
        self.replyPendingUntil.removeValue(forKey: recipientPeerId)
        self.lock.unlock()
    }

    func giftKeyPrefix(accountPeerId: PeerId, recipientPeerId: PeerId) -> String {
        return "\(accountPeerId.toInt64())_\(recipientPeerId.toInt64())_"
    }

    func archivedGifts(accountPeerId: PeerId, recipientPeerId: PeerId) -> [ProfileGiftsContext.State.StarGift] {
        let prefix = self.giftKeyPrefix(accountPeerId: accountPeerId, recipientPeerId: recipientPeerId)
        let fromPeer = self.selfPeer(for: accountPeerId)
        return self.recipientGifts.all().compactMap { key, value -> ProfileGiftsContext.State.StarGift? in
            guard key.hasPrefix(prefix) else {
                return nil
            }
            if value.fromPeer == nil, fromPeer != nil {
                return rodStarVisualRehydrateGift(value, fromPeer: fromPeer)
            }
            return value
        }.sorted(by: { $0.date > $1.date })
    }

    func archiveGift(_ gift: ProfileGiftsContext.State.StarGift, accountPeerId: PeerId, recipientPeerId: PeerId, uniqueKey: String) {
        let prefix = self.giftKeyPrefix(accountPeerId: accountPeerId, recipientPeerId: recipientPeerId)
        let all = self.recipientGifts.all()
        let profileKeys = all.keys.filter { $0.hasPrefix(prefix) }.sorted()
        if profileKeys.count >= 50 {
            for key in profileKeys.prefix(profileKeys.count - 49) {
                self.recipientGifts.remove(key)
            }
        }
        self.recipientGifts.set(prefix + uniqueKey, gift)
    }

    func archivedPinnedCount(accountPeerId: PeerId, recipientPeerId: PeerId) -> Int {
        let prefix = self.giftKeyPrefix(accountPeerId: accountPeerId, recipientPeerId: recipientPeerId)
        return self.recipientGifts.all().filter { key, value in key.hasPrefix(prefix) && value.pinnedToTop }.count
    }

    func injectLocalTransactions(_ transactions: [StarsContext.State.Transaction], accountPeerId: PeerId, ton: Bool) -> [StarsContext.State.Transaction] {
        var existingIds = Set<String>()
        for transaction in transactions {
            existingIds.insert(transaction.id)
        }
        var result = transactions
        for spend in self.spends.all().values {
            guard spend.ton == ton, !existingIds.contains(spend.id) else {
                continue
            }
            let positive = StarsAmount(value: spend.value, nanos: spend.nanos)
            let count = CurrencyAmount(amount: StarsAmount(value: 0, nanos: 0) - positive, currency: ton ? .ton : .stars)
            result.append(StarsContext.State.Transaction(flags: [.isLocal], id: spend.id, count: count, date: spend.date, peer: .appStore, title: "Покупка подарка", description: nil, photo: nil, transactionDate: nil, transactionUrl: nil, paidMessageId: nil, giveawayMessageId: nil, media: [], subscriptionPeriod: nil, starGift: nil, floodskipNumber: nil, starrefCommissionPermille: nil, starrefPeerId: nil, starrefAmount: nil, paidMessageCount: nil, premiumGiftMonths: nil, adsProceedsFromDate: nil, adsProceedsToDate: nil))
            existingIds.insert(spend.id)
        }
        if result.count != transactions.count {
            result.sort(by: { $0.date > $1.date })
        }
        return result
    }
}

func rodStarVisualRehydrateGift(_ gift: ProfileGiftsContext.State.StarGift, fromPeer: EnginePeer?) -> ProfileGiftsContext.State.StarGift {
    return ProfileGiftsContext.State.StarGift(
        gift: gift.gift,
        reference: gift.reference,
        fromPeer: fromPeer,
        date: gift.date,
        text: gift.text,
        entities: gift.entities,
        nameHidden: gift.nameHidden,
        savedToProfile: gift.savedToProfile,
        pinnedToTop: gift.pinnedToTop,
        convertStars: gift.convertStars,
        canUpgrade: gift.canUpgrade,
        canExportDate: gift.canExportDate,
        upgradeStars: gift.upgradeStars,
        transferStars: gift.transferStars,
        canTransferDate: gift.canTransferDate,
        canResaleDate: gift.canResaleDate,
        collectionIds: gift.collectionIds,
        prepaidUpgradeHash: gift.prepaidUpgradeHash,
        upgradeSeparate: gift.upgradeSeparate,
        dropOriginalDetailsStars: gift.dropOriginalDetailsStars,
        number: gift.number,
        isRefunded: gift.isRefunded,
        canCraftAt: gift.canCraftAt
    )
}

public func sgRodStarVisualRegister(context: AccountContext) {
    RodStarVisualRuntime.shared.setContext(context)

    SGRodStarHooks.overrideStarsBalance = { balance, _ in
        let settings = RodStarSettings.shared
        if settings.customBalance {
            return StarsAmount(value: max(0, Int64(settings.balanceValue)), nanos: 0)
        }
        return balance
    }

    SGRodStarHooks.overrideTonBalance = { balance, _ in
        let settings = RodStarSettings.shared
        if settings.customGram {
            let total = max(0, Int64(settings.gramValue * 1_000_000_000.0))
            return StarsAmount(value: total / 1_000_000_000, nanos: Int32(total % 1_000_000_000))
        }
        return balance
    }

    SGRodStarHooks.injectLocalStarsTransactions = { transactions, accountPeerId, ton in
        return RodStarVisualRuntime.shared.injectLocalTransactions(transactions, accountPeerId: accountPeerId, ton: ton)
    }

    SGRodStarHooks.injectProfileGifts = { gifts, profilePeerId, accountPeerId in
        let local = RodStarVisualRuntime.shared.archivedGifts(accountPeerId: accountPeerId, recipientPeerId: profilePeerId)
        if local.isEmpty {
            return gifts
        }
        var existingReferences = Set<StarGiftReference>()
        for gift in gifts {
            if let reference = gift.reference {
                existingReferences.insert(reference)
            }
        }
        var result = gifts
        for gift in local {
            if let reference = gift.reference, existingReferences.contains(reference) {
                continue
            }
            result.append(gift)
        }
        result.sort(by: { $0.date > $1.date })
        return result
    }

    SGRodStarHooks.profileGiftsCountOffset = { profilePeerId, accountPeerId in
        return Int32(RodStarVisualRuntime.shared.archivedGifts(accountPeerId: accountPeerId, recipientPeerId: profilePeerId).count)
    }
}

public func sgRodStarVisualCurrentMode(accountPeerId: PeerId) -> Int {
    return RodStarVisualRuntime.shared.isVisualMode(accountPeerId: accountPeerId) ? 1 : 0
}

public func sgRodStarVisualResetModeForOpen(accountPeerId: PeerId) {
    RodStarVisualRuntime.shared.resetModeForOpen(accountPeerId: accountPeerId)
}

public func sgRodStarVisualToggleZoneEnabled() -> Bool {
    return RodStarSettings.shared.hiddenGiftSwitch
}

public func sgRodStarVisualToggleMode(context: AccountContext) -> Int {
    let visual = RodStarVisualRuntime.shared.toggleMode(accountPeerId: context.account.peerId)
    if RodStarSettings.shared.giftToggleToast {
        sgRodStarVisualShowModeToast(context: context, visual: visual)
    }
    return visual ? 1 : 0
}

public func sgRodStarVisualShowModeToast(context: AccountContext, visual: Bool) {
    DispatchQueue.main.async {
        guard let hostView = context.sharedContext.mainWindow?.hostView else {
            return
        }
        let label = UILabel()
        label.text = visual ? "Визуал" : "Ориг"
        label.font = UIFont.systemFont(ofSize: 15.0, weight: .medium)
        label.textColor = .white
        label.backgroundColor = UIColor(white: 0.0, alpha: 0.75)
        label.textAlignment = .center
        label.layer.cornerRadius = 16.0
        label.layer.masksToBounds = true
        label.sizeToFit()
        let width = label.bounds.width + 32.0
        let height: CGFloat = 32.0
        label.frame = CGRect(x: (hostView.bounds.width - width) / 2.0, y: hostView.bounds.height - 140.0, width: width, height: height)
        label.alpha = 0.0
        hostView.addSubview(label)
        UIView.animate(withDuration: 0.2, animations: {
            label.alpha = 1.0
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.0, options: [], animations: {
                label.alpha = 0.0
            }, completion: { _ in
                label.removeFromSuperview()
            })
        })
    }
}

private func rodStarVisualRandomMessageId() -> Int32 {
    return Int32(arc4random_uniform(UInt32(Int32.max - 2)) + 1)
}

// Returns true when the send was intercepted as a visual (fake) gift; the caller
// must then skip the real purchase entirely.
public func sgRodStarVisualHandleGiftSend(
    context: AccountContext,
    gift: StarGift,
    peerId: EnginePeer.Id,
    text: String?,
    entities: [MessageTextEntity]?,
    hideName: Bool,
    price: StarsAmount,
    ton: Bool,
    marketPurchase: Bool = false
) -> Bool {
    let runtime = RodStarVisualRuntime.shared
    let accountPeerId = context.account.peerId
    guard runtime.isVisualMode(accountPeerId: accountPeerId) else {
        return false
    }
    // Swallow duplicate taps in fake mode too: falling through would send a real gift.
    guard runtime.claimSend(recipientPeerId: peerId) else {
        return true
    }
    Queue.mainQueue().after(1.0) {
        runtime.releaseBusy()
    }

    let timestamp = Int32(Date().timeIntervalSince1970)
    let messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: rodStarVisualRandomMessageId())
    let cleanText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
    let messageText: String? = (cleanText?.isEmpty ?? true) ? nil : cleanText

    let action: TelegramMediaActionType
    var convertStars: Int64?
    var upgradeStars: Int64?
    var canUpgrade = false
    switch gift {
    case let .generic(genericGift):
        convertStars = genericGift.convertStars
        upgradeStars = genericGift.upgradeStars
        canUpgrade = genericGift.upgradeStars != nil
        action = .starGift(gift: gift, convertStars: nil, text: messageText, entities: entities, nameHidden: hideName, savedToProfile: false, converted: false, upgraded: false, canUpgrade: false, upgradeStars: nil, isRefunded: false, isPrepaidUpgrade: false, upgradeMessageId: nil, peerId: peerId, senderId: accountPeerId, savedId: nil, prepaidUpgradeHash: nil, giftMessageId: nil, upgradeSeparate: false, isAuctionAcquired: false, toPeerId: nil, number: nil)
    case .unique:
        action = .starGiftUnique(gift: gift, isUpgrade: false, isTransferred: false, savedToProfile: false, canExportDate: nil, transferStars: nil, isRefunded: false, isPrepaidUpgrade: false, peerId: peerId, senderId: accountPeerId, savedId: nil, resaleAmount: marketPurchase ? CurrencyAmount(amount: price, currency: ton ? .ton : .stars) : nil, canTransferDate: nil, canResaleDate: nil, dropOriginalDetailsStars: nil, assigned: false, fromOffer: false, canCraftAt: nil, isCrafted: false, text: messageText, entities: entities, nameHidden: hideName)
    }

    let storeMessage = StoreMessage(
        id: messageId,
        customStableId: nil,
        globallyUniqueId: nil,
        groupingKey: nil,
        threadId: nil,
        timestamp: timestamp,
        flags: StoreMessageFlags(),
        tags: [],
        globalTags: [],
        localTags: [],
        forwardInfo: nil,
        authorId: accountPeerId,
        text: "",
        attributes: [],
        media: [TelegramMediaAction(action: action)]
    )

    let isUnique: Bool
    if case .unique = gift {
        isUnique = true
    } else {
        isUnique = false
    }
    let pinnedCount = runtime.archivedPinnedCount(accountPeerId: accountPeerId, recipientPeerId: peerId)

    let _ = context.account.postbox.transaction { transaction -> Void in
        let _ = transaction.addMessages([storeMessage], location: .Random)

        let fromPeer = transaction.getPeer(accountPeerId).flatMap(EnginePeer.init)
        let profileGift = ProfileGiftsContext.State.StarGift(
            gift: gift,
            reference: .message(messageId: messageId),
            fromPeer: fromPeer,
            date: timestamp,
            text: messageText,
            entities: entities,
            nameHidden: hideName,
            savedToProfile: true,
            pinnedToTop: isUnique && pinnedCount < 6,
            convertStars: convertStars,
            canUpgrade: canUpgrade,
            canExportDate: nil,
            upgradeStars: upgradeStars,
            transferStars: nil,
            canTransferDate: nil,
            canResaleDate: nil,
            collectionIds: nil,
            prepaidUpgradeHash: nil,
            upgradeSeparate: false,
            dropOriginalDetailsStars: nil,
            number: nil,
            isRefunded: false,
            canCraftAt: nil
        )
        runtime.archiveGift(profileGift, accountPeerId: accountPeerId, recipientPeerId: peerId, uniqueKey: "\(timestamp)_\(messageId.id)")
    }.start()

    rodStarVisualApplySpend(context: context, price: price, ton: ton)

    if peerId.namespace == Namespaces.Peer.CloudUser {
        rodStarVisualScheduleReply(context: context, peerId: peerId)
    }
    rodStarVisualScheduleReaction(context: context, peerId: peerId, messageId: messageId)

    return true
}

private func rodStarVisualApplySpend(context: AccountContext, price: StarsAmount, ton: Bool) {
    let settings = RodStarSettings.shared
    guard settings.autoSpendVisualStars else {
        return
    }
    if ton {
        guard settings.customGram else {
            return
        }
        let cost = Double(price.value) + Double(price.nanos) / 1_000_000_000.0
        let remaining = max(0.0, settings.gramValue - cost)
        settings.gramValue = remaining
    } else {
        guard settings.customBalance else {
            return
        }
        let remaining = max(0, Int64(settings.balanceValue) - price.value)
        settings.balanceValue = Double(remaining)
    }
    guard price.value > 0 || price.nanos > 0 else {
        return
    }

    let spend = RodStarVisualSpend(id: "rodstar_\(arc4random())_\(Int32(Date().timeIntervalSince1970))", date: Int32(Date().timeIntervalSince1970), value: price.value, nanos: price.nanos, ton: ton)
    RodStarVisualRuntime.shared.spends.set(spend.id, spend)

    // Re-emit the state so the override and the injected spend transaction show up
    // without waiting for a server refresh.
    if ton {
        context.tonContext?.add(balance: StarsAmount(value: 0, nanos: 0), addTransaction: false)
    } else {
        context.starsContext?.add(balance: StarsAmount(value: 0, nanos: 0), addTransaction: false)
    }
}