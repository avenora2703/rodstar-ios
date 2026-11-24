import Foundation

public final class RodStarSettings {
    public static let shared = RodStarSettings()

    private let defaults: UserDefaults

    private init() {
        self.defaults = UserDefaults.standard
        self.defaults.register(defaults: RodStarSettings.defaultValues)
    }

    public static let defaultValues: [String: Any] = [
        // Visual
        "rodstar.hiddenGiftSwitch": true,
        "rodstar.defaultSendMode": 1,
        "rodstar.giftToggleToast": true,
        "rodstar.visualMode": true,
        "rodstar.lastSendMode": 1,
        "rodstar.customBalance": false,
        "rodstar.balanceValue": "0",
        "rodstar.customGram": false,
        "rodstar.gramValue": "0",
        "rodstar.autoSpendVisualStars": true,
        "rodstar.giftReplyEnabled": true,
        "rodstar.giftReplyMin": "3",
        "rodstar.giftReplyMax": "10",
        "rodstar.giftReplyChance": "100",
        "rodstar.giftTypingMin": "2",
        "rodstar.giftTypingMax": "5",
        "rodstar.giftReplyBuiltin": true,
        "rodstar.giftReplyTexts": "",
        "rodstar.giftReactionEnabled": true,
        "rodstar.giftReactionChance": "50",
        "rodstar.giftReactionMin": "3",
        "rodstar.giftReactionMax": "10",
        "rodstar.giftReactionEmojis": "❤️ 🔥 👍 😍 🎉",
        // Identity
        "rodstar.customRating": false,
        "rodstar.ratingStars": "150000",
        "rodstar.ratingLevel": "10",
        "rodstar.ratingNext": "200000",
        "rodstar.badgeMode": 0,
        "rodstar.customNumber": false,
        "rodstar.phoneNumber": "88812345678",
        "rodstar.customName": false,
        "rodstar.nameValue": "RodStar",
        "rodstar.customAvatar": false,
        "rodstar.avatarUsername": "SvoZov77",
        // Changer
        "rodstar.stickersEnabled": true,
        "rodstar.stickerMode": 0,
        "rodstar.stickerPacks": "",
        "rodstar.stickerAllow": "",
        "rodstar.gifsEnabled": true,
        "rodstar.gifIds": "",
        "rodstar.emojiEnabled": false,
        "rodstar.emojiTexts": "",
        "rodstar.blurEnabled": true,
        "rodstar.banwordsEnabled": true,
        "rodstar.banwordsBuiltin": true,
        "rodstar.banwords": "",
        "rodstar.replacements": "",
    ]

    public func bool(_ key: String) -> Bool {
        return self.defaults.bool(forKey: key)
    }

    public func setBool(_ key: String, _ value: Bool) {
        self.defaults.set(value, forKey: key)
    }

    public func int(_ key: String) -> Int {
        return self.defaults.integer(forKey: key)
    }

    public func setInt(_ key: String, _ value: Int) {
        self.defaults.set(value, forKey: key)
    }

    public func string(_ key: String) -> String {
        return self.defaults.string(forKey: key) ?? ""
    }

    public func setString(_ key: String, _ value: String) {
        self.defaults.set(value, forKey: key)
    }

    public func double(_ key: String) -> Double {
        return Double(self.string(key)) ?? 0.0
    }

    // MARK: Visual

    public var hiddenGiftSwitch: Bool {
        get { self.bool("rodstar.hiddenGiftSwitch") }
        set { self.setBool("rodstar.hiddenGiftSwitch", newValue) }
    }
    public var defaultSendMode: Int {
        get { self.int("rodstar.defaultSendMode") }
        set { self.setInt("rodstar.defaultSendMode", newValue) }
    }
    public var giftToggleToast: Bool {
        get { self.bool("rodstar.giftToggleToast") }
        set { self.setBool("rodstar.giftToggleToast", newValue) }
    }
    public var visualMode: Bool {
        get { self.bool("rodstar.visualMode") }
        set { self.setBool("rodstar.visualMode", newValue) }
    }
    public var lastSendMode: Int {
        get { self.int("rodstar.lastSendMode") }
        set { self.setInt("rodstar.lastSendMode", newValue) }
    }
    public var customBalance: Bool {
        get { self.bool("rodstar.customBalance") }
        set { self.setBool("rodstar.customBalance", newValue) }
    }
    public var balanceValue: Double {
        get { self.double("rodstar.balanceValue") }
        set { self.setString("rodstar.balanceValue", String(newValue)) }
    }
    public var customGram: Bool {
        get { self.bool("rodstar.customGram") }
        set { self.setBool("rodstar.customGram", newValue) }
    }
    public var gramValue: Double {
        get { self.double("rodstar.gramValue") }
        set { self.setString("rodstar.gramValue", String(newValue)) }
    }
    public var autoSpendVisualStars: Bool {
        get { self.bool("rodstar.autoSpendVisualStars") }
        set { self.setBool("rodstar.autoSpendVisualStars", newValue) }
    }
    public var giftReplyEnabled: Bool {
        get { self.bool("rodstar.giftReplyEnabled") }
        set { self.setBool("rodstar.giftReplyEnabled", newValue) }
    }
    public var giftReplyMin: Int {
        get { max(2, Int(self.string("rodstar.giftReplyMin")) ?? 3) }
        set { self.setString("rodstar.giftReplyMin", String(newValue)) }
    }
    public var giftReplyMax: Int {
        get { min(60, Int(self.string("rodstar.giftReplyMax")) ?? 10) }
        set { self.setString("rodstar.giftReplyMax", String(newValue)) }
    }
    public var giftReplyChance: Int {
        get { Int(self.string("rodstar.giftReplyChance")) ?? 100 }
        set { self.setString("rodstar.giftReplyChance", String(newValue)) }
    }
    public var giftTypingMin: Int {
        get { Int(self.string("rodstar.giftTypingMin")) ?? 2 }
        set { self.setString("rodstar.giftTypingMin", String(newValue)) }
    }
    public var giftTypingMax: Int {
        get { Int(self.string("rodstar.giftTypingMax")) ?? 5 }
        set { self.setString("rodstar.giftTypingMax", String(newValue)) }
    }
    public var giftReplyBuiltin: Bool {
        get { self.bool("rodstar.giftReplyBuiltin") }
        set { self.setBool("rodstar.giftReplyBuiltin", newValue) }
    }
    public var giftReplyTexts: String {
        get { self.string("rodstar.giftReplyTexts") }
        set { self.setString("rodstar.giftReplyTexts", newValue) }
    }
    public var giftReactionEnabled: Bool {
        get { self.bool("rodstar.giftReactionEnabled") }
        set { self.setBool("rodstar.giftReactionEnabled", newValue) }
    }
    public var giftReactionChance: Int {
        get { Int(self.string("rodstar.giftReactionChance")) ?? 50 }
        set { self.setString("rodstar.giftReactionChance", String(newValue)) }
    }
    public var giftReactionMin: Int {
        get { max(1, Int(self.string("rodstar.giftReactionMin")) ?? 3) }
        set { self.setString("rodstar.giftReactionMin", String(newValue)) }
    }
    public var giftReactionMax: Int {
        get { min(120, Int(self.string("rodstar.giftReactionMax")) ?? 10) }
        set { self.setString("rodstar.giftReactionMax", String(newValue)) }
    }
    public var giftReactionEmojis: String {
        get { self.string("rodstar.giftReactionEmojis") }
        set { self.setString("rodstar.giftReactionEmojis", newValue) }
    }

    // MARK: Identity

    public var customRating: Bool {
        get { self.bool("rodstar.customRating") }
        set { self.setBool("rodstar.customRating", newValue) }
    }
    public var ratingStars: Int64 {
        get { Int64(self.string("rodstar.ratingStars")) ?? 150000 }
        set { self.setString("rodstar.ratingStars", String(newValue)) }
    }
    public var ratingLevel: Int32 {
        get { Int32(self.string("rodstar.ratingLevel")) ?? 10 }
        set { self.setString("rodstar.ratingLevel", String(newValue)) }
    }
    public var ratingNext: Int64 {
        get { Int64(self.string("rodstar.ratingNext")) ?? 200000 }
        set { self.setString("rodstar.ratingNext", String(newValue)) }
    }
    public var badgeMode: Int {
        get { self.int("rodstar.badgeMode") }
        set { self.setInt("rodstar.badgeMode", newValue) }
    }
    public var customNumber: Bool {
        get { self.bool("rodstar.customNumber") }
        set { self.setBool("rodstar.customNumber", newValue) }
    }
    public var phoneNumber: String {
        get { self.string("rodstar.phoneNumber") }
        set { self.setString("rodstar.phoneNumber", newValue) }
    }
    public var customName: Bool {
        get { self.bool("rodstar.customName") }
        set { self.setBool("rodstar.customName", newValue) }
    }
    public var nameValue: String {
        get { self.string("rodstar.nameValue") }
        set { self.setString("rodstar.nameValue", newValue) }
    }
    public var customAvatar: Bool {
        get { self.bool("rodstar.customAvatar") }
        set { self.setBool("rodstar.customAvatar", newValue) }
    }
    public var avatarUsername: String {
        get { self.string("rodstar.avatarUsername") }
        set { self.setString("rodstar.avatarUsername", newValue) }
    }

    // MARK: Changer

    public var stickersEnabled: Bool {
        get { self.bool("rodstar.stickersEnabled") }
        set { self.setBool("rodstar.stickersEnabled", newValue) }
    }
    public var stickerMode: Int {
        get { min(1, self.int("rodstar.stickerMode")) }
        set { self.setInt("rodstar.stickerMode", newValue) }
    }
    public var stickerPacks: String {
        get { self.string("rodstar.stickerPacks") }
        set { self.setString("rodstar.stickerPacks", newValue) }
    }
    public var stickerAllow: String {
        get { self.string("rodstar.stickerAllow") }
        set { self.setString("rodstar.stickerAllow", newValue) }
    }
    public var gifsEnabled: Bool {
        get { self.bool("rodstar.gifsEnabled") }
        set { self.setBool("rodstar.gifsEnabled", newValue) }
    }
    public var gifIds: String {
        get { self.string("rodstar.gifIds") }
        set { self.setString("rodstar.gifIds", newValue) }
    }
    public var emojiEnabled: Bool {
        get { self.bool("rodstar.emojiEnabled") }
        set { self.setBool("rodstar.emojiEnabled", newValue) }
    }
    public var emojiTexts: String {
        get { self.string("rodstar.emojiTexts") }
        set { self.setString("rodstar.emojiTexts", newValue) }
    }
    public var blurEnabled: Bool {
        get { self.bool("rodstar.blurEnabled") }
        set { self.setBool("rodstar.blurEnabled", newValue) }
    }
    public var banwordsEnabled: Bool {
        get { self.bool("rodstar.banwordsEnabled") }
        set { self.setBool("rodstar.banwordsEnabled", newValue) }
    }
    public var banwordsBuiltin: Bool {
        get { self.bool("rodstar.banwordsBuiltin") }
        set { self.setBool("rodstar.banwordsBuiltin", newValue) }
    }
    public var banwords: String {
        get { self.string("rodstar.banwords") }
        set { self.setString("rodstar.banwords", newValue) }
    }
    public var replacements: String {
        get { self.string("rodstar.replacements") }
        set { self.setString("rodstar.replacements", newValue) }
    }
}

public func rodStarParseList(_ raw: String, extraSeparators: Bool = false) -> [String] {
    var separators = CharacterSet(charactersIn: "|\n\r")
    if extraSeparators {
        separators.insert(charactersIn: ",;")
    }
    var result: [String] = []
    var seen = Set<String>()
    for part in raw.components(separatedBy: separators) {
        let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            continue
        }
        let key = trimmed.lowercased()
        if seen.contains(key) {
            continue
        }
        seen.insert(key)
        result.append(trimmed)
    }
    return result
}

public func rodStarNormalizePackName(_ raw: String) -> String {
    var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    for prefix in ["https://", "http://", "tg://"] {
        if value.hasPrefix(prefix) {
            value = String(value.dropFirst(prefix.count))
        }
    }
    for prefix in ["t.me/", "telegram.me/", "addstickers/", "addemoji/"] {
        if let range = value.range(of: prefix) {
            value = String(value[range.upperBound...])
        }
    }
    if value.hasPrefix("@") {
        value = String(value.dropFirst())
    }
    if let index = value.firstIndex(where: { $0 == "?" || $0 == "#" || $0 == "/" }) {
        value = String(value[..<index])
    }
    return value
}