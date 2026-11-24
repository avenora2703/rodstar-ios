load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SGRodStarVisual",
    module_name = "SGRodStarVisual",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Swiftgram/SGRodStarCore:SGRodStarCore",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Display:Display",
    ],
    visibility = [
        "//visibility:public",
    ],
)