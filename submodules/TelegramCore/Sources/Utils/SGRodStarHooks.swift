import Foundation
import Postbox

// MARK: Swiftgram
// Hook registry for RodStar modules. TelegramCore cannot depend on the RodStar
// modules (they depend on TelegramCore), so call sites invoke these closures and
// the modules register implementations at account setup from the TelegramUI layer.
public enum SGRodStarHooks {
    private static let lock = NSLock()
    private static var _transformIncomingMessages: (([StoreMessage], EnginePeer.Id) -> [StoreMessage])?
    private static var _transformEditedMessage: ((StoreMessage, EnginePeer.Id) -> StoreMessage)?
    private static var _transformUser: ((TelegramUser, EnginePeer.Id) -> TelegramUser)?
    private static var _transformCachedUserData: ((CachedUserData, EnginePeer.Id) -> CachedUserData)?
    private static var _overrideStarsBalance: ((StarsAmount, EnginePeer.Id) -> StarsAmount)?
    private static var _injectProfileGifts: (([ProfileGiftsContext.State.StarGift], EnginePeer.Id, EnginePeer.Id) -> [ProfileGiftsContext.State.StarGift])?
    private static var _profileGiftsCountOffset: ((EnginePeer.Id, EnginePeer.Id) -> Int32)?
    private static var _overrideTonBalance: ((StarsAmount, EnginePeer.Id) -> StarsAmount)?
    private static var _injectLocalStarsTransactions: (([StarsContext.State.Transaction], EnginePeer.Id, Bool) -> [StarsContext.State.Transaction])?

    public static var transformIncomingMessages: (([StoreMessage], EnginePeer.Id) -> [StoreMessage])? {
        get { self.lock.lock(); defer { self.lock.unlock() }; return self._transformIncomingMessages }
        set { self.lock.lock(); defer { self.lock.unlock() }; self._transformIncomingMessages = newValue }
    }
    public static var transformEditedMessage: ((StoreMessage, EnginePeer.Id) -> StoreMessage)? {
        get { self.lock.lock(); defer { self.lock.unlock() }; return self._transformEditedMessage }
        set { self.lock.lock(); defer { self.lock.unlock() }; self._transformEditedMessage = newValue }
    }
    public static var transformUser: ((TelegramUser, EnginePeer.Id) -> TelegramUser)? {
        get { self.lock.lock(); defer { self.lock.unlock() }; return self._transformUser }
        set { self.lock.lock(); defer { self.lock.unlock() }; self._transformUser = newValue }
    }
    public static var transformCachedUserData: ((CachedUserData, EnginePeer.Id) -> CachedUserData)? {
        get { self.lock.lock(); defer { self.lock.unlock() }; return self._transformCachedUserData }
        set { self.lock.lock(); defer { self.lock.unlock() }; self._transformCachedUserData = newValue }
    }
    public static var overrideStarsBalance: ((StarsAmount, EnginePeer.Id) -> StarsAmount)? {
        get { self.lock.lock(); defer { self.lock.unlock() }; return self._overrideStarsBalance }
        set { self.lock.lock(); defer { self.lock.unlock() }; self._overrideStarsBalance = newValue }
    }
    public static var injectProfileGifts: (([ProfileGiftsContext.State.StarGift], EnginePeer.Id, EnginePeer.Id) -> [ProfileGiftsContext.State.StarGift])? {
        get { self.lock.lock(); defer { self.lock.unlock() }; return self._injectProfileGifts }
        set { self.lock.lock(); defer { self.lock.unlock() }; self._injectProfileGifts = newValue }
    }
    public static var profileGiftsCountOffset: ((EnginePeer.Id, EnginePeer.Id) -> Int32)? {
        get { self.lock.lock(); defer { self.lock.unlock() }; return self._profileGiftsCountOffset }
        set { self.lock.lock(); defer { self.lock.unlock() }; self._profileGiftsCountOffset = newValue }
    }
    public static var overrideTonBalance: ((StarsAmount, EnginePeer.Id) -> StarsAmount)? {
        get { self.lock.lock(); defer { self.lock.unlock() }; return self._overrideTonBalance }
        set { self.lock.lock(); defer { self.lock.unlock() }; self._overrideTonBalance = newValue }
    }
    public static var injectLocalStarsTransactions: (([StarsContext.State.Transaction], EnginePeer.Id, Bool) -> [StarsContext.State.Transaction])? {
        get { self.lock.lock(); defer { self.lock.unlock() }; return self._injectLocalStarsTransactions }
        set { self.lock.lock(); defer { self.lock.unlock() }; self._injectLocalStarsTransactions = newValue }
    }
}