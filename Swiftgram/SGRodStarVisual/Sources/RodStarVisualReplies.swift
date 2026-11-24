import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import SGRodStarCore

// Verbatim pool from rodstar_visual.plugin (_PF_DEFAULT_GIFT_REPLIES), 87 entries.
let rodStarVisualBuiltinReplies: [String] = [
    "Спасибо за подарок ❤️",
    "Спасибо ❤️",
    "Спасибо ❤️",
    "Спасибо ❤️",
    "Спасибо ❤️",
    "Спасибо ❤️",
    "Спасибо ❤️",
    "Спасибо",
    "Спасибо",
    "Вау, спасибо большое",
    "Ты лучший, спасибо ❤️",
    "Неожиданно, ну спасибо)",
    "Благодарю 🙏",
    "Офигеть, спасибо!",
    "Спасибо, очень приятно",
    "Ты ахуенный, спасибо",
    "Аж мурашки, спасибо",
    "Спасибо тебе!",
    "Обалдеть, спасибо ❤️",
    "Спасибо 🙏",
    "Спасибо, это очень мило с твоей стороны",
    "Вот это да, спасибо!",
    "Приятный момент за день, спасибо",
    "Спасибо, теперь я улыбаюсь",
    "Огоо, спасибо ❤️",
    "Благодарю бро",
    "Бро, сяпки",
    "Не верю, спасибо",
    "Ты супер, спасибо",
    "Приятно, спасибо огромное)",
    "Спасибо, неожиданно)",
    "Благодарю, ты чудо",
    "Это так приятно, спасибо)",
    "Благодарю, это очень щедро с твоей стороны",
    "Такое не каждый день, спасибо)",
    "Благодарю брат",
    "благодарю бро",
    "ЕБАТЬ СПАСИБО Я НЕ ВЕРИЛ ДО КОНЦА",
    "БЛЯ, ЭТО МНЕ? СПАСИБО",
    "АХУЕТЬ, СПАСИБО",
    "ВОТ ЭТО ДА, НИХУЯ СЕБЕ",
    "СПАСИБО БРО, ТЫ ЛУЧШИЙ",
    "ЧЕГООО, СПАСИБО",
    "ПИЗДЕЦ, КАК ПРИЯТНО",
    "СПАСИБО, ЧЕЛ",
    "БОЖЕ, КАК ПРИЯТНО",
    "ААА, СПАСИБО!",
    "НЕ ВЕРЮ, СПАСИБО",
    "ВСЁ, Я ТВОЙ ДОЛЖНИК",
    "СПАСИБО, РОДНОЙ",
    "БРАТУХА, ТЫ ЛУЧШИЙ",
    "кайф, спасибо",
    "ЧЕЛ, НУ СПАСИБО",
    "ТЫ ПРОСТО ОГОНЬ, СПАСИБО",
    "БЛЯ, КАК ПРИЯТНО",
    "СПАСИБО, ПРИШЛО",
    "СПАСИБО, Я АЖ ОФИГЕЛ",
    "бро, лучший",
    "ТЫ ЧТО ТВОРИШЬ, СПАСИБООО 😭",
    "АХУЕННО, СПАСИБО ТЕБЕ",
    "ЭТО ПРОСТО ВАУ, СПАСИБО ОГРОМНОЕ",
    "ААААА, Я ТЕБЯ ОБОЖАЮ",
    "лучший",
    "лучший)",
    "лучший 😭",
    "лучший ❤️",
    "еба, лучший",
    "Еба, лучший",
    "Емааа, лучший, сяп",
    "Сяп",
    "Сяпки",
    "Сяп)",
    "Сяпки)",
    "Сяп ❤️",
    "Сяпки ❤️",
    "Сяп))",
    "сяпки",
    "сяп",
    "сяпки",
    "Лучший, просто лучший",
    "Лучший, просто лучший)",
    "лучший, просто лучший",
    "лучший, просто лучший)",
    "Лучший, от души)",
    "Лучший, от души)",
    "лучший, от души)",
    "лучший, от души)"
]

private let rodStarVisualDefaultReactionEmojis = ["❤️", "🔥", "👍", "😍", "🎉"]

private func rodStarVisualRandomDelay(_ lo: Int, _ hi: Int) -> Double {
    let span = max(1, (hi - lo) * 1000)
    return Double(lo) + Double(arc4random_uniform(UInt32(span))) / 1000.0
}

func rodStarVisualScheduleReply(context: AccountContext, peerId: EnginePeer.Id) {
    let settings = RodStarSettings.shared
    let runtime = RodStarVisualRuntime.shared
    let accountPeerId = context.account.peerId

    guard settings.giftReplyEnabled else {
        return
    }
    let chance = max(0, min(settings.giftReplyChance, 100))
    if chance < 100 && Int(arc4random_uniform(100)) >= chance {
        return
    }
    var texts = rodStarParseList(settings.giftReplyTexts, extraSeparators: true)
    if texts.isEmpty && settings.giftReplyBuiltin {
        texts = rodStarVisualBuiltinReplies
    }
    texts = texts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    guard !texts.isEmpty else {
        return
    }

    var lo = settings.giftReplyMin
    var hi = settings.giftReplyMax
    if lo <= 0 && hi <= 0 {
        lo = 3
        hi = 10
    }
    lo = max(2, min(lo, 60))
    hi = max(lo, min(hi, 60))
    let delay = rodStarVisualRandomDelay(lo, hi)

    // Typing indicator is skipped (no cheap local peer-status injection); the
    // typing wait is folded into the reply delay instead.
    let tlo = max(0, settings.giftTypingMin)
    let thi = max(tlo, max(0, settings.giftTypingMax))
    let typingDelay = thi > 0 ? rodStarVisualRandomDelay(tlo, thi) : 0.0

    let text = texts[Int(arc4random_uniform(UInt32(texts.count)))]
    guard runtime.claimReply(recipientPeerId: peerId, until: CFAbsoluteTimeGetCurrent() + delay) else {
        return
    }

    Queue.mainQueue().after(delay + typingDelay) {
        runtime.clearReply(recipientPeerId: peerId)
        guard runtime.isVisualMode(accountPeerId: accountPeerId) else {
            return
        }
        guard let context = runtime.context(for: accountPeerId) else {
            return
        }
        let timestamp = Int32(Date().timeIntervalSince1970)
        let messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: Int32(arc4random_uniform(UInt32(Int32.max - 2)) + 1))
        let storeMessage = StoreMessage(
            id: messageId,
            customStableId: nil,
            globallyUniqueId: nil,
            groupingKey: nil,
            threadId: nil,
            timestamp: timestamp,
            flags: [.Incoming],
            tags: [],
            globalTags: [],
            localTags: [],
            forwardInfo: nil,
            authorId: peerId,
            text: text,
            attributes: [],
            media: []
        )
        let _ = context.account.postbox.transaction { transaction -> Void in
            let _ = transaction.addMessages([storeMessage], location: .Random)
            transaction.applyIncomingReadMaxId(messageId)
        }.start()
        runtime.previews.set("\(accountPeerId.toInt64())_\(peerId.toInt64())", RodStarDialogPreview(msgId: Int64(messageId.id), text: text, date: timestamp))
    }
}

func rodStarVisualScheduleReaction(context: AccountContext, peerId: EnginePeer.Id, messageId: MessageId) {
    let settings = RodStarSettings.shared
    let runtime = RodStarVisualRuntime.shared
    let accountPeerId = context.account.peerId

    guard settings.giftReactionEnabled else {
        return
    }
    let chance = max(0, min(settings.giftReactionChance, 100))
    if chance < 100 && Int(arc4random_uniform(100)) >= chance {
        return
    }
    var lo = settings.giftReactionMin
    var hi = settings.giftReactionMax
    if lo <= 0 && hi <= 0 {
        lo = 3
        hi = 10
    }
    lo = max(1, min(lo, 120))
    hi = max(lo, min(hi, 120))
    let delay = rodStarVisualRandomDelay(lo, hi)

    Queue.mainQueue().after(delay) {
        guard runtime.isVisualMode(accountPeerId: accountPeerId) else {
            return
        }
        guard let context = runtime.context(for: accountPeerId) else {
            return
        }
        var raw = settings.giftReactionEmojis
        for separator in [",", "|", ";"] {
            raw = raw.replacingOccurrences(of: separator, with: " ")
        }
        var emojis = raw.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        if emojis.isEmpty {
            emojis = rodStarVisualDefaultReactionEmojis
        }
        let emoji = emojis[Int(arc4random_uniform(UInt32(emojis.count)))]
        let reaction = MessageReaction.Reaction.builtin(emoji)
        let timestamp = Int32(Date().timeIntervalSince1970)

        let _ = context.account.postbox.transaction { transaction -> Void in
            guard transaction.getMessage(messageId) != nil else {
                return
            }
            transaction.updateMessage(messageId, update: { current in
                let storeForwardInfo = current.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                var attributes = current.attributes.filter { !($0 is ReactionsMessageAttribute) }
                attributes.append(ReactionsMessageAttribute(
                    canViewList: true,
                    isTags: false,
                    reactions: [MessageReaction(value: reaction, count: 1, chosenOrder: nil)],
                    recentPeers: [ReactionsMessageAttribute.RecentPeer(value: reaction, isLarge: false, isUnseen: false, isMy: false, peerId: peerId, timestamp: timestamp)],
                    topPeers: []
                ))
                return .update(StoreMessage(id: current.id, customStableId: nil, globallyUniqueId: current.globallyUniqueId, groupingKey: current.groupingKey, threadId: current.threadId, timestamp: current.timestamp, flags: StoreMessageFlags(current.flags), tags: current.tags, globalTags: current.globalTags, localTags: current.localTags, forwardInfo: storeForwardInfo, authorId: current.author?.id, text: current.text, attributes: attributes, media: current.media))
            })
        }.start()
    }
}