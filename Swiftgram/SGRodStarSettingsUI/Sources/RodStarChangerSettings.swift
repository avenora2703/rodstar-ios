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

private enum RodStarChangerSection: Int32, SGItemListSection {
    case stickers
    case gifs
    case emoji
    case blur
    case banwords
    case service
}

private enum RodStarChangerToggle: String, Hashable {
    case stickersEnabled
    case gifsEnabled
    case emojiEnabled
    case blurEnabled
    case banwordsEnabled
    case banwordsBuiltin
}

private enum RodStarChangerSelector: String, Hashable {
    case stickerMode
}

private enum RodStarChangerAction: String, Hashable {
    case stickerPacks
    case fillInstalledPacks
    case stickerAllow
    case gifIds
    case fillSavedGifs
    case emojiTexts
    case banwords
    case replacements
    case exportBanwords
    case importBanwords
    case refreshPools
}

private typealias RodStarChangerEntry = SGItemListUIEntry<RodStarChangerSection, RodStarChangerToggle, RodStarChangerToggle, RodStarChangerSelector, RodStarChangerAction, RodStarChangerAction>

private func rodStarChangerValueSummary(_ raw: String) -> String {
    let lines = rodStarParseList(raw)
    if lines.isEmpty {
        return ""
    }
    let first = lines[0].count > 24 ? String(lines[0].prefix(24)) + "…" : lines[0]
    if lines.count == 1 {
        return first
    }
    return "\(first) +\(lines.count - 1)"
}

private func rodStarChangerInputTitle(_ title: String, _ raw: String) -> String {
    let summary = rodStarChangerValueSummary(raw)
    return summary.isEmpty ? title : "\(title) — \(summary)"
}

public func sgRodStarChangerSettingsController(context: AccountContext) -> ViewController {
    let settings = RodStarSettings.shared
    weak var controllerImpl: ItemListController?

    let simplePromise = ValuePromise(true, ignoreRepeated: false)

    let arguments = SGItemListArguments<RodStarChangerToggle, RodStarChangerToggle, RodStarChangerSelector, RodStarChangerAction, RodStarChangerAction>(context: context, setBoolValue: { setting, value in
        switch setting {
        case .stickersEnabled:
            settings.stickersEnabled = value
        case .gifsEnabled:
            settings.gifsEnabled = value
        case .emojiEnabled:
            settings.emojiEnabled = value
        case .blurEnabled:
            settings.blurEnabled = value
        case .banwordsEnabled:
            settings.banwordsEnabled = value
        case .banwordsBuiltin:
            settings.banwordsBuiltin = value
        }
        simplePromise.set(true)
    }, setOneFromManyValue: { setting in
        guard let controller = controllerImpl else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        var options: [SGOneFromManyOption] = []
        switch setting {
        case .stickerMode:
            options.append(SGOneFromManyOption(title: "Заменять все", isSelected: settings.stickerMode == 0, action: {
                settings.stickerMode = 0
                simplePromise.set(true)
            }))
            options.append(SGOneFromManyOption(title: "Все, кроме списка ниже", isSelected: settings.stickerMode == 1, action: {
                settings.stickerMode = 1
                simplePromise.set(true)
            }))
        }
        sgPresentOneFromManySelector(controller: controller, setting: setting, presentationData: presentationData, options: options)
    }, action: { action in
        guard let controller = controllerImpl else {
            return
        }
        let saveString: (String) -> Void = { value in
            switch action {
            case .stickerPacks:
                settings.stickerPacks = value
            case .stickerAllow:
                settings.stickerAllow = value
            case .gifIds:
                settings.gifIds = value
            case .emojiTexts:
                settings.emojiTexts = value
            case .banwords:
                settings.banwords = value
            case .replacements:
                settings.replacements = value
            default:
                break
            }
            simplePromise.set(true)
        }
        switch action {
        case .stickerPacks:
            rodStarPresentTextEditor(from: controller, context: context, title: "Паки для замены (t.me/addstickers/Name…)", text: settings.stickerPacks, save: saveString)
        case .stickerAllow:
            rodStarPresentTextEditor(from: controller, context: context, title: "Паки, которые не заменять", text: settings.stickerAllow, save: saveString)
        case .gifIds:
            rodStarPresentTextEditor(from: controller, context: context, title: "ID гиф", text: settings.gifIds, save: saveString)
        case .emojiTexts:
            rodStarPresentTextEditor(from: controller, context: context, title: "Тексты замен", text: settings.emojiTexts, save: saveString)
        case .banwords:
            rodStarPresentTextEditor(from: controller, context: context, title: "Свои слова/фразы", text: settings.banwords, save: saveString)
        case .replacements:
            rodStarPresentTextEditor(from: controller, context: context, title: "Замены", text: settings.replacements, save: saveString)
        case .fillInstalledPacks:
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.ItemCollections.InstalledPackInfos(namespace: Namespaces.ItemCollection.CloudStickerPacks))
            |> take(1)
            |> deliverOnMainQueue).start(next: { entries in
                let names = entries.compactMap { entry -> String? in
                    if let info = entry.info as? StickerPackCollectionInfo, !info.shortName.isEmpty {
                        return info.shortName
                    }
                    return nil
                }
                settings.stickerPacks = names.joined(separator: "\n")
                simplePromise.set(true)
            })
        case .fillSavedGifs:
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs))
            |> take(1)
            |> deliverOnMainQueue).start(next: { entries in
                let ids = entries.compactMap { entry -> String? in
                    guard let item = entry.contents.get(RecentMediaItem.self) else {
                        return nil
                    }
                    return String(item.media._parse().fileId.id)
                }
                settings.gifIds = ids.joined(separator: "\n")
                simplePromise.set(true)
            })
        case .exportBanwords:
            UIPasteboard.general.string = settings.banwords
            let alert = UIAlertController(title: "Экспорт банвордов", message: "Скопировано в буфер обмена", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            DispatchQueue.main.async {
                var top: UIViewController? = controller.view.window?.rootViewController
                while let presented = top?.presentedViewController {
                    top = presented
                }
                top?.present(alert, animated: true)
            }
        case .importBanwords:
            if let value = UIPasteboard.general.string {
                settings.banwords = value
                simplePromise.set(true)
            }
        case .refreshPools:
            NotificationCenter.default.post(name: Notification.Name("SGRodStarChangerRefreshPools"), object: nil)
        }
    })

    let signal = combineLatest(simplePromise.get(), context.sharedContext.presentationData)
    |> map { _, presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [RodStarChangerEntry] = []
        var id: Int = 0
        func nextId() -> Int {
            id += 1
            return id
        }

        entries.append(.header(id: nextId(), section: .stickers, text: "Замена входящих стикеров", badge: nil))
        entries.append(.toggle(id: nextId(), section: .stickers, settingName: .stickersEnabled, value: settings.stickersEnabled, text: "Заменять стикеры", enabled: true))
        entries.append(.oneFromManySelector(id: nextId(), section: .stickers, settingName: .stickerMode, text: "Что заменять", value: settings.stickerMode == 0 ? "Заменять все" : "Все, кроме списка ниже", enabled: true))
        entries.append(.action(id: nextId(), section: .stickers, actionType: .stickerPacks, text: rodStarChangerInputTitle("Паки для замены", settings.stickerPacks), kind: .generic))
        entries.append(.action(id: nextId(), section: .stickers, actionType: .fillInstalledPacks, text: "Заполнить список установленными паками", kind: .generic))
        entries.append(.action(id: nextId(), section: .stickers, actionType: .stickerAllow, text: rodStarChangerInputTitle("Паки, которые не заменять", settings.stickerAllow), kind: .generic))

        entries.append(.header(id: nextId(), section: .gifs, text: "Замена входящих GIF", badge: nil))
        entries.append(.toggle(id: nextId(), section: .gifs, settingName: .gifsEnabled, value: settings.gifsEnabled, text: "Заменять GIF", enabled: true))
        entries.append(.action(id: nextId(), section: .gifs, actionType: .gifIds, text: rodStarChangerInputTitle("ID гиф", settings.gifIds), kind: .generic))
        entries.append(.action(id: nextId(), section: .gifs, actionType: .fillSavedGifs, text: "Заполнить список сохранёнными GIF", kind: .generic))

        entries.append(.header(id: nextId(), section: .emoji, text: "Замена сообщений с эмоджи", badge: nil))
        entries.append(.toggle(id: nextId(), section: .emoji, settingName: .emojiEnabled, value: settings.emojiEnabled, text: "Заменять сообщения с эмоджи", enabled: true))
        entries.append(.action(id: nextId(), section: .emoji, actionType: .emojiTexts, text: rodStarChangerInputTitle("Тексты замен", settings.emojiTexts), kind: .generic))

        entries.append(.header(id: nextId(), section: .blur, text: "Блюр фото и видео", badge: nil))
        entries.append(.toggle(id: nextId(), section: .blur, settingName: .blurEnabled, value: settings.blurEnabled, text: "Блюрить входящие фото/видео", enabled: true))

        entries.append(.header(id: nextId(), section: .banwords, text: "Фильтр по банвордам", badge: nil))
        entries.append(.toggle(id: nextId(), section: .banwords, settingName: .banwordsEnabled, value: settings.banwordsEnabled, text: "Заменять сообщения с банвордами", enabled: true))
        entries.append(.toggle(id: nextId(), section: .banwords, settingName: .banwordsBuiltin, value: settings.banwordsBuiltin, text: "Встроенный список (скам + мат)", enabled: true))
        entries.append(.action(id: nextId(), section: .banwords, actionType: .banwords, text: rodStarChangerInputTitle("Свои слова/фразы", settings.banwords), kind: .generic))
        entries.append(.action(id: nextId(), section: .banwords, actionType: .replacements, text: rodStarChangerInputTitle("Замены", settings.replacements), kind: .generic))
        entries.append(.action(id: nextId(), section: .banwords, actionType: .exportBanwords, text: "Экспорт банвордов в буфер", kind: .generic))
        entries.append(.action(id: nextId(), section: .banwords, actionType: .importBanwords, text: "Импорт банвордов из буфера", kind: .generic))

        entries.append(.header(id: nextId(), section: .service, text: "Служебное", badge: nil))
        entries.append(.action(id: nextId(), section: .service, actionType: .refreshPools, text: "Обновить пул стикеров/GIF", kind: .generic))

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Changer"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controllerImpl = controller
    return controller
}