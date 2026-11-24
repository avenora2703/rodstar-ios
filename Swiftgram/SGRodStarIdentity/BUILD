load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SGRodStarIdentity",
    module_name = "SGRodStarIdentity",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Swiftgram/SGRodStarCore:SGRodStarCore",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)