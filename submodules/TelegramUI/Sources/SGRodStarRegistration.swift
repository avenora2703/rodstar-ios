import Foundation
import AccountContext
import SGRodStarChanger
import SGRodStarIdentity
import SGRodStarVisual

// MARK: Swiftgram
func sgRodStarRegisterHooks(context: AccountContext) {
    sgRodStarChangerRegister(context: context)
    sgRodStarIdentityRegister(context: context)
    sgRodStarVisualRegister(context: context)
}