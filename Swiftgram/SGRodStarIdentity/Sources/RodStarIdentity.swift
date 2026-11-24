import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import SGRodStarCore

private let rodStarHoldBadgeFileId: Int64 = 6291816386410847066
private let rodStarMajorBadgeFileId: Int64 = 6016937066422604737

private func rodStarBadgeInfo(mode: Int) -> (fileId: Int64, organization: String)? {
    switch mode {
    case 1:
        return (rodStarHoldBadgeFileId, "Hold")
    case 2:
        return (rodStarMajorBadgeFileId, "Major")
    default:
        return nil
    }
}

private func rodStarNormalizeAvatarUsername(_ raw: String) -> String {
    var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.hasPrefix("@") {
        value = String(value.dropFirst())
    }
    return value.lowercased()
}

private func rodStarApplyBadge(_ user: TelegramUser, fileId: Int64) -> TelegramUser {
    var flags = user.flags
    flags.remove(.isVerified)
    return TelegramUser(id: user.id, accessHash: user.accessHash, firstName: user.firstName, lastName: user.lastName, username: user.username, phone: user.phone, photo: user.photo, botInfo: user.botInfo, restrictionInfo: user.restrictionInfo, flags: flags, emojiStatus: user.emojiStatus, usernames: user.usernames, storiesHidden: user.storiesHidden, nameColor: user.nameColor, backgroundEmojiId: user.backgroundEmojiId, profileColor: user.profileColor, profileBackgroundEmojiId: user.profileBackgroundEmojiId, subscriberCount: user.subscriberCount, verificationIconFileId: fileId, linkedCommunityId: user.linkedCommunityId)
}

private final class RodStarIdentityWeakContext {
    weak var value: AccountContext?

    init(_ value: AccountContext) {
        self.value = value
    }
}

private final class RodStarIdentityRuntime {
    static let shared = RodStarIdentityRuntime()

    private let lock = NSLock()
    private var contexts: [PeerId: RodStarIdentityWeakContext] = [:]
    private var avatarPhotos: [String: [TelegramMediaImageRepresentation]] = [:]
    private var resolvingAvatarUsernames: Set<String> = []
    private var avatarFailedAt: [String: Double] = [:]

    func setContext(_ context: AccountContext) {
        self.lock.lock()
        self.contexts[context.account.peerId] = RodStarIdentityWeakContext(context)
        self.lock.unlock()
    }

    func context(for accountPeerId: PeerId) -> AccountContext? {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.contexts[accountPeerId]?.value
    }

    func cachedAvatarPhoto(username: String) -> [TelegramMediaImageRepresentation]? {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.avatarPhotos[username]
    }

    func beginAvatarResolve(username: String) -> Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        if self.resolvingAvatarUsernames.contains(username) {
            return false
        }
        if self.avatarPhotos[username] != nil {
            return false
        }
        if let failedAt = self.avatarFailedAt[username], CFAbsoluteTimeGetCurrent() - failedAt < 60.0 {
            return false
        }
        self.resolvingAvatarUsernames.insert(username)
        return true
    }

    func finishAvatarResolve(username: String, photo: [TelegramMediaImageRepresentation]?) {
        self.lock.lock()
        self.resolvingAvatarUsernames.remove(username)
        if let photo = photo {
            self.avatarPhotos[username] = photo
            self.avatarFailedAt.removeValue(forKey: username)
        } else {
            self.avatarFailedAt[username] = CFAbsoluteTimeGetCurrent()
        }
        self.lock.unlock()
    }
}

// Re-applies the hooks to the stored self peer and its cached data so settings
// changes and late avatar resolution propagate without waiting for a server update.
func rodStarIdentityRefreshSelf(context: AccountContext) {
    let accountPeerId = context.account.peerId
    let _ = context.account.postbox.transaction { transaction -> Void in
        if let user = transaction.getPeer(accountPeerId) as? TelegramUser, let transformUser = SGRodStarHooks.transformUser {
            updatePeersCustom(transaction: transaction, peers: [transformUser(user, accountPeerId)], update: { _, updated in updated })
        }
        transaction.updatePeerCachedData(peerIds: Set([accountPeerId]), update: { _, current in
            if let current = current as? CachedUserData, let transformCachedUserData = SGRodStarHooks.transformCachedUserData {
                return transformCachedUserData(current, accountPeerId)
            }
            return current
        })
    }.start()
}

private func rodStarResolveAvatarPhoto(username: String, accountPeerId: PeerId) {
    guard let context = RodStarIdentityRuntime.shared.context(for: accountPeerId) else {
        RodStarIdentityRuntime.shared.finishAvatarResolve(username: username, photo: nil)
        return
    }
    let _ = (context.engine.peers.resolvePeerByName(name: username, referrer: nil)
    |> filter { value -> Bool in
        if case .result = value {
            return true
        }
        return false
    }
    |> take(1)
    |> mapToSignal { value -> Signal<TelegramUser?, NoError> in
        guard case let .result(maybePeer) = value, let peer = maybePeer else {
            return .single(nil)
        }
        return context.account.postbox.transaction { transaction -> TelegramUser? in
            return transaction.getPeer(peer.id) as? TelegramUser
        }
    }
    |> deliverOnMainQueue).start(next: { user in
        let photo = user?.photo
        RodStarIdentityRuntime.shared.finishAvatarResolve(username: username, photo: photo)
        if let photo = photo, !photo.isEmpty {
            rodStarIdentityRefreshSelf(context: context)
        }
    })
}

public func sgRodStarIdentityRegister(context: AccountContext) {
    RodStarIdentityRuntime.shared.setContext(context)

    SGRodStarHooks.transformUser = { user, accountPeerId in
        guard user.id == accountPeerId, user.botInfo == nil else {
            return user
        }
        let settings = RodStarSettings.shared
        var updated = user

        if settings.customName {
            let name = settings.nameValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                updated = updated.withUpdatedNames(firstName: name, lastName: nil)
            }
        }

        if settings.customNumber {
            let digits = settings.phoneNumber.filter { $0 >= "0" && $0 <= "9" }
            if digits.count >= 7 && digits.count <= 15 {
                updated = updated.withUpdatedPhone(digits)
            }
        }

        if settings.customAvatar {
            let username = rodStarNormalizeAvatarUsername(settings.avatarUsername)
            if !username.isEmpty {
                if let photo = RodStarIdentityRuntime.shared.cachedAvatarPhoto(username: username) {
                    if !photo.isEmpty {
                        updated = updated.withUpdatedPhoto(photo)
                    }
                } else if RodStarIdentityRuntime.shared.beginAvatarResolve(username: username) {
                    // The hook runs inside a postbox transaction; resolve outside of it.
                    DispatchQueue.main.async {
                        rodStarResolveAvatarPhoto(username: username, accountPeerId: accountPeerId)
                    }
                }
            }
        }

        if let badge = rodStarBadgeInfo(mode: settings.badgeMode) {
            updated = rodStarApplyBadge(updated, fileId: badge.fileId)
        }

        return updated
    }

    SGRodStarHooks.transformCachedUserData = { cachedData, accountPeerId in
        let settings = RodStarSettings.shared
        var updated = cachedData

        if settings.customRating {
            let stars = max(0, settings.ratingStars)
            let next = max(0, settings.ratingNext)
            let level = settings.ratingLevel
            let safeLevel = max(Int64(1), Int64(level))
            let currentLevelStars = min(stars, max(0, next - next / safeLevel))
            updated = updated.withUpdatedStarRating(TelegramStarRating(level: level, currentLevelStars: currentLevelStars, stars: stars, nextLevelStars: next))
        }

        if let badge = rodStarBadgeInfo(mode: settings.badgeMode) {
            updated = updated.withUpdatedVerification(PeerVerification(botId: accountPeerId, iconFileId: badge.fileId, description: "Аккаунт верифицирован организацией «\(badge.organization)».", descriptionEntities: []))
        }

        return updated
    }
}