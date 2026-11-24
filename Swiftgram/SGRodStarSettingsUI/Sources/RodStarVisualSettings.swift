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

private enum RodStarVisualSection: Int32, SGItemListSection {
    case main
    case balance
    case reply
    case reaction
}

private enum RodStarVisualToggle: String, Hashable {
    case hiddenGiftSwitch
    case giftToggleToast
    case customBalance
    case customGram
    case autoSpend
    case replyEnabled
    case replyBuiltin
    case reactionEnabled
}

private enum RodStarVisualSelector: String, Hashable {
    case sendMode
}

private enum RodStarVisualAction: String, Hashable {
    case balanceValue
    case gramValue
    case replyMin
    case replyMax
    case replyChance
    case typingMin
    case typingMax
    case replyTexts
    case reactionChance
    case reactionMin
    case reactionMax
    case reactionEmojis
}

private typealias RodStarVisualEntry = SGItemListUIEntry<RodStarVisualSection, RodStarVisualToggle, RodStarVisualToggle, RodStarVisualSelector, RodStarVisualAction, RodStarVisualAction>

public func sgRodStarVisualSettingsController(context: AccountContext) -> ViewController {
    let settings = RodStarSettings.shared
    weak var controllerImpl: ItemListController?

    let simplePromise = ValuePromise(true, ignoreRepeated: false)

    let arguments = SGItemListArguments<RodStarVisualToggle, RodStarVisualToggle, RodStarVisualSelector, RodStarVisualAction, RodStarVisualAction>(context: context, setBoolValue: { setting, value in
        switch setting {
        case .hiddenGiftSwitch:
            settings.hiddenGiftSwitch = value
        case .giftToggleToast:
            settings.giftToggleToast = value
        case .customBalance:
            settings.customBalance = value
        case .customGram:
            settings.customGram = value
        case .autoSpend:
            settings.autoSpendVisualStars = value
        case .replyEnabled:
            settings.giftReplyEnabled = value
        case .replyBuiltin:
            settings.giftReplyBuiltin = value
        case .reactionEnabled:
            settings.giftReactionEnabled = value
        }
        simplePromise.set(true)
    }, setOneFromManyValue: { setting in
        guard let controller = controllerImpl else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        var options: [SGOneFromManyOption] = []
        switch setting {
        case .sendMode:
            options.append(SGOneFromManyOption(title: "Оригинал", isSelected: settings.defaultSendMode == 0, action: {
                settings.defaultSendMode = 0
                simplePromise.set(true)
            }))
            options.append(SGOneFromManyOption(title: "Визуал", isSelected: settings.defaultSendMode == 1, action: {
                settings.defaultSendMode = 1
                simplePromise.set(true)
            }))
            options.append(SGOneFromManyOption(title: "Последний выбранный", isSelected: settings.defaultSendMode == 2, action: {
                settings.defaultSendMode = 2
                simplePromise.set(true)
            }))
        }
        sgPresentOneFromManySelector(controller: controller, setting: setting, presentationData: presentationData, options: options)
    }, action: { action in
        guard let controller = controllerImpl else {
            return
        }
        let saveInt: (String) -> Void = { value in
            let digits = value.filter { $0 >= "0" && $0 <= "9" }
            let parsed = Int(digits) ?? 0
            switch action {
            case .replyMin:
                settings.giftReplyMin = parsed
            case .replyMax:
                settings.giftReplyMax = parsed
            case .replyChance:
                settings.giftReplyChance = parsed
            case .typingMin:
                settings.giftTypingMin = parsed
            case .typingMax:
                settings.giftTypingMax = parsed
            case .reactionChance:
                settings.giftReactionChance = parsed
            case .reactionMin:
                settings.giftReactionMin = parsed
            case .reactionMax:
                settings.giftReactionMax = parsed
            default:
                break
            }
            simplePromise.set(true)
        }
        let saveDouble: (String) -> Void = { value in
            let normalized = value.replacingOccurrences(of: ",", with: ".")
            let parsed = Double(normalized) ?? 0.0
            switch action {
            case .balanceValue:
                settings.balanceValue = max(0.0, parsed)
            case .gramValue:
                settings.gramValue = max(0.0, parsed)
            default:
                break
            }
            simplePromise.set(true)
        }
        switch action {
        case .balanceValue:
            rodStarPresentTextInput(from: controller, title: "Количество Stars", message: "Например: 67", value: String(Int(settings.balanceValue)), placeholder: "0", keyboardType: .numberPad, save: saveDouble)
        case .gramValue:
            rodStarPresentTextInput(from: controller, title: "Количество Gram", message: "Например: 77 или 77.5", value: String(settings.gramValue), placeholder: "0", keyboardType: .decimalPad, save: saveDouble)
        case .replyMin:
            rodStarPresentTextInput(from: controller, title: "Задержка от, сек", value: String(settings.giftReplyMin), placeholder: "3", keyboardType: .numberPad, save: saveInt)
        case .replyMax:
            rodStarPresentTextInput(from: controller, title: "Задержка до, сек", value: String(settings.giftReplyMax), placeholder: "10", keyboardType: .numberPad, save: saveInt)
        case .replyChance:
            rodStarPresentTextInput(from: controller, title: "Шанс ответа, %", value: String(settings.giftReplyChance), placeholder: "100", keyboardType: .numberPad, save: saveInt)
        case .typingMin:
            rodStarPresentTextInput(from: controller, title: "Задержка «печатает» от, сек", value: String(settings.giftTypingMin), placeholder: "2", keyboardType: .numberPad, save: saveInt)
        case .typingMax:
            rodStarPresentTextInput(from: controller, title: "Задержка «печатает» до, сек", value: String(settings.giftTypingMax), placeholder: "5", keyboardType: .numberPad, save: saveInt)
        case .replyTexts:
            rodStarPresentTextEditor(from: controller, context: context, title: "Тексты ответов: через | или с новой строки", text: settings.giftReplyTexts, save: { value in
                settings.giftReplyTexts = value
                simplePromise.set(true)
            })
        case .reactionChance:
            rodStarPresentTextInput(from: controller, title: "Шанс эмоции, %", value: String(settings.giftReactionChance), placeholder: "50", keyboardType: .numberPad, save: saveInt)
        case .reactionMin:
            rodStarPresentTextInput(from: controller, title: "Задержка от, сек", value: String(settings.giftReactionMin), placeholder: "3", keyboardType: .numberPad, save: saveInt)
        case .reactionMax:
            rodStarPresentTextInput(from: controller, title: "Задержка до, сек", value: String(settings.giftReactionMax), placeholder: "10", keyboardType: .numberPad, save: saveInt)
        case .reactionEmojis:
            rodStarPresentTextInput(from: controller, title: "Эмодзи: через пробел или запятую", message: "Пусто = стандартные (❤️ 🔥 👍 😍 🎉)", value: settings.giftReactionEmojis, placeholder: "❤️ 🔥 👍 😍 🎉", save: { value in
                settings.giftReactionEmojis = value
                simplePromise.set(true)
            })
        }
    })

    let signal = combineLatest(simplePromise.get(), context.sharedContext.presentationData)
    |> map { _, presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [RodStarVisualEntry] = []
        var id: Int = 0
        func nextId() -> Int {
            id += 1
            return id
        }

        entries.append(.header(id: nextId(), section: .main, text: "Основное", badge: nil))
        entries.append(.toggle(id: nextId(), section: .main, settingName: .hiddenGiftSwitch, value: settings.hiddenGiftSwitch, text: "Невидимая кнопка", enabled: true))
        if settings.hiddenGiftSwitch {
            let modeTitle: String
            switch settings.defaultSendMode {
            case 0:
                modeTitle = "Оригинал"
            case 2:
                modeTitle = "Последний выбранный"
            default:
                modeTitle = "Визуал"
            }
            entries.append(.oneFromManySelector(id: nextId(), section: .main, settingName: .sendMode, text: "Режим при открытии", value: modeTitle, enabled: true))
            entries.append(.toggle(id: nextId(), section: .main, settingName: .giftToggleToast, value: settings.giftToggleToast, text: "Уведомления о смене режима", enabled: true))
        }

        entries.append(.header(id: nextId(), section: .balance, text: "Баланс", badge: nil))
        entries.append(.toggle(id: nextId(), section: .balance, settingName: .customBalance, value: settings.customBalance, text: "Визуальный баланс Stars", enabled: true))
        entries.append(.action(id: nextId(), section: .balance, actionType: .balanceValue, text: "Количество Stars — \(Int(settings.balanceValue))", kind: .generic))
        entries.append(.toggle(id: nextId(), section: .balance, settingName: .customGram, value: settings.customGram, text: "Визуальный баланс Gram", enabled: true))
        entries.append(.action(id: nextId(), section: .balance, actionType: .gramValue, text: "Количество Gram — \(settings.gramValue)", kind: .generic))
        entries.append(.toggle(id: nextId(), section: .balance, settingName: .autoSpend, value: settings.autoSpendVisualStars, text: "Трата Звезд в Маркете", enabled: true))

        entries.append(.header(id: nextId(), section: .reply, text: "Автоответ", badge: nil))
        entries.append(.toggle(id: nextId(), section: .reply, settingName: .replyEnabled, value: settings.giftReplyEnabled, text: "Автоответ на подарок", enabled: true))
        entries.append(.action(id: nextId(), section: .reply, actionType: .replyMin, text: "Задержка от, сек — \(settings.giftReplyMin)", kind: .generic))
        entries.append(.action(id: nextId(), section: .reply, actionType: .replyMax, text: "Задержка до, сек — \(settings.giftReplyMax)", kind: .generic))
        entries.append(.action(id: nextId(), section: .reply, actionType: .replyChance, text: "Шанс ответа, % — \(settings.giftReplyChance)", kind: .generic))
        entries.append(.action(id: nextId(), section: .reply, actionType: .typingMin, text: "Задержка «печатает» от, сек — \(settings.giftTypingMin)", kind: .generic))
        entries.append(.action(id: nextId(), section: .reply, actionType: .typingMax, text: "Задержка «печатает» до, сек — \(settings.giftTypingMax)", kind: .generic))
        entries.append(.toggle(id: nextId(), section: .reply, settingName: .replyBuiltin, value: settings.giftReplyBuiltin, text: "Встроенный пул фраз (87)", enabled: true))
        entries.append(.action(id: nextId(), section: .reply, actionType: .replyTexts, text: "Тексты ответов", kind: .generic))

        entries.append(.header(id: nextId(), section: .reaction, text: "Эмоция на подарок", badge: nil))
        entries.append(.toggle(id: nextId(), section: .reaction, settingName: .reactionEnabled, value: settings.giftReactionEnabled, text: "Эмоция на подарок", enabled: true))
        entries.append(.action(id: nextId(), section: .reaction, actionType: .reactionChance, text: "Шанс эмоции, % — \(settings.giftReactionChance)", kind: .generic))
        entries.append(.action(id: nextId(), section: .reaction, actionType: .reactionMin, text: "Задержка от, сек — \(settings.giftReactionMin)", kind: .generic))
        entries.append(.action(id: nextId(), section: .reaction, actionType: .reactionMax, text: "Задержка до, сек — \(settings.giftReactionMax)", kind: .generic))
        entries.append(.action(id: nextId(), section: .reaction, actionType: .reactionEmojis, text: "Эмодзи", kind: .generic))

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Visual"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controllerImpl = controller
    return controller
}