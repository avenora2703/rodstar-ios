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

private enum RodStarRootSection: Int32, SGItemListSection {
    case main
}

private enum RodStarRootLink: String {
    case visual
    case identity
    case changer
}

private typealias RodStarRootEntry = SGItemListUIEntry<RodStarRootSection, RodStarRootLink, RodStarRootLink, RodStarRootLink, RodStarRootLink, AnyHashable>

public func sgRodStarSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?

    let simplePromise = ValuePromise(true, ignoreRepeated: false)

    let arguments = SGItemListArguments<RodStarRootLink, RodStarRootLink, RodStarRootLink, RodStarRootLink, AnyHashable>(context: context, openDisclosureLink: { link in
        switch link {
        case .visual:
            pushControllerImpl?(sgRodStarVisualSettingsController(context: context))
        case .identity:
            pushControllerImpl?(sgRodStarIdentitySettingsController(context: context))
        case .changer:
            pushControllerImpl?(sgRodStarChangerSettingsController(context: context))
        }
    })

    let signal = combineLatest(simplePromise.get(), context.sharedContext.presentationData)
    |> map { _, presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries: [RodStarRootEntry] = [
            .header(id: 0, section: .main, text: "RodStar", badge: nil),
            .disclosure(id: 1, section: .main, link: .visual, text: "Visual — подарки и баланс"),
            .disclosure(id: 2, section: .main, link: .identity, text: "Identity — профиль"),
            .disclosure(id: 3, section: .main, link: .changer, text: "Changer — замена входящих"),
        ]
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("RodStar"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: nil, initialScrollToItem: nil)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}