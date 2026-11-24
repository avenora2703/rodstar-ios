import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import SGItemListUI
import SGRodStarCore

private enum RodStarIdentitySection: Int32, SGItemListSection {
    case rating
    case profile
}

private enum RodStarIdentityBoolSetting: Hashable {
    case customRating
    case customNumber
    case customName
    case customAvatar
}

private enum RodStarIdentitySelectorSetting: Hashable {
    case badgeMode
}

private enum RodStarIdentityAction: Hashable {
    case stars
    case level
    case nextLevel
    case phone
    case name
    case avatar
}

private typealias RodStarIdentityEntry = SGItemListUIEntry<RodStarIdentitySection, RodStarIdentityBoolSetting, AnyHashable, RodStarIdentitySelectorSetting, AnyHashable, RodStarIdentityAction>

private func rodStarIdentityBadgeTitle(_ mode: Int) -> String {
    switch mode {
    case 1:
        return "Hold"
    case 2:
        return "Major"
    default:
        return "Нет"
    }
}

private func rodStarIdentityRefreshSelf(context: AccountContext) {
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

public func sgRodStarIdentitySettingsController(context: AccountContext) -> ViewController {
    var presentOneFromManyImpl: ((RodStarIdentitySelectorSetting, [SGOneFromManyOption]) -> Void)?
    weak var weakController: ViewController?

    let simplePromise = ValuePromise(true, ignoreRepeated: false)
    let settings = RodStarSettings.shared

    let arguments = SGItemListArguments<RodStarIdentityBoolSetting, AnyHashable, RodStarIdentitySelectorSetting, AnyHashable, RodStarIdentityAction>(context: context, setBoolValue: { setting, value in
        switch setting {
        case .customRating:
            settings.customRating = value
        case .customNumber:
            settings.customNumber = value
        case .customName:
            settings.customName = value
        case .customAvatar:
            settings.customAvatar = value
        }
        simplePromise.set(true)
        rodStarIdentityRefreshSelf(context: context)
    }, setOneFromManyValue: { setting in
        switch setting {
        case .badgeMode:
            let options: [SGOneFromManyOption] = (0 ... 2).map { mode in
                SGOneFromManyOption(title: rodStarIdentityBadgeTitle(mode), isSelected: settings.badgeMode == mode, action: {
                    settings.badgeMode = mode
                    simplePromise.set(true)
                    rodStarIdentityRefreshSelf(context: context)
                })
            }
            presentOneFromManyImpl?(setting, options)
        }
    }, action: { action in
        guard let controller = weakController else {
            return
        }
        let save: (String) -> Void = { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            switch action {
            case .stars:
                if let parsed = Int64(trimmed) {
                    settings.ratingStars = parsed
                }
            case .level:
                if let parsed = Int32(trimmed) {
                    settings.ratingLevel = parsed
                }
            case .nextLevel:
                if let parsed = Int64(trimmed) {
                    settings.ratingNext = parsed
                }
            case .phone:
                settings.phoneNumber = value
            case .name:
                settings.nameValue = value
            case .avatar:
                settings.avatarUsername = value
            }
            simplePromise.set(true)
            rodStarIdentityRefreshSelf(context: context)
        }
        switch action {
        case .stars:
            rodStarPresentTextInput(from: controller, title: "Stars", value: String(settings.ratingStars), placeholder: "150000", keyboardType: .numberPad, save: save)
        case .level:
            rodStarPresentTextInput(from: controller, title: "Уровень", value: String(settings.ratingLevel), placeholder: "10", keyboardType: .numberPad, save: save)
        case .nextLevel:
            rodStarPresentTextInput(from: controller, title: "Следующий уровень", value: String(settings.ratingNext), placeholder: "200000", keyboardType: .numberPad, save: save)
        case .phone:
            rodStarPresentTextInput(from: controller, title: "Номер", value: settings.phoneNumber, placeholder: "79001234567", keyboardType: .numberPad, save: save)
        case .name:
            rodStarPresentTextInput(from: controller, title: "Имя", value: settings.nameValue, placeholder: "RodStar", save: save)
        case .avatar:
            rodStarPresentTextInput(from: controller, title: "Аватар из профиля", value: settings.avatarUsername, placeholder: "@username", save: save)
        }
    })

    let signal = combineLatest(simplePromise.get(), context.sharedContext.presentationData)
    |> map { _, presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries: [RodStarIdentityEntry] = [
            .header(id: 0, section: .rating, text: "Рейтинг", badge: nil),
            .toggle(id: 1, section: .rating, settingName: .customRating, value: settings.customRating, text: "Визуальный рейтинг", enabled: true),
            .action(id: 2, section: .rating, actionType: .stars, text: "Stars: \(settings.ratingStars)", kind: .generic),
            .action(id: 3, section: .rating, actionType: .level, text: "Уровень: \(settings.ratingLevel)", kind: .generic),
            .action(id: 4, section: .rating, actionType: .nextLevel, text: "Следующий уровень: \(settings.ratingNext)", kind: .generic),
            .header(id: 5, section: .profile, text: "Профиль", badge: nil),
            .oneFromManySelector(id: 6, section: .profile, settingName: .badgeMode, text: "Бейдж верификации", value: rodStarIdentityBadgeTitle(settings.badgeMode), enabled: true),
            .toggle(id: 7, section: .profile, settingName: .customNumber, value: settings.customNumber, text: "Визуальный номер", enabled: true),
            .action(id: 8, section: .profile, actionType: .phone, text: "Номер: \(settings.phoneNumber)", kind: .generic),
            .toggle(id: 9, section: .profile, settingName: .customName, value: settings.customName, text: "Визуальное имя", enabled: true),
            .action(id: 10, section: .profile, actionType: .name, text: "Имя: \(settings.nameValue)", kind: .generic),
            .toggle(id: 11, section: .profile, settingName: .customAvatar, value: settings.customAvatar, text: "Визуальный аватар", enabled: true),
            .action(id: 12, section: .profile, actionType: .avatar, text: "Аватар из профиля: \(settings.avatarUsername)", kind: .generic),
        ]
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Identity"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    weakController = controller
    presentOneFromManyImpl = { [weak controller] setting, options in
        guard let controller = controller else {
            return
        }
        sgPresentOneFromManySelector(controller: controller, setting: setting, presentationData: context.sharedContext.currentPresentationData.with { $0 }, options: options)
    }
    return controller
}