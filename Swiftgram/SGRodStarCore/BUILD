load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SGRodStarCore",
    module_name = "SGRodStarCore",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Swiftgram/SGAppGroupIdentifier:SGAppGroupIdentifier",
    ],
    visibility = [
        "//visibility:public",
    ],
)