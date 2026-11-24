load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SGRodStarSettingsUI",
    module_name = "SGRodStarSettingsUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Swiftgram/SGRodStarCore:SGRodStarCore",
        "//Swiftgram/SGItemListUI:SGItemListUI",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/AccountContext:AccountContext",
        "//submodules/AppBundle:AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)