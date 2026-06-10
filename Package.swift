// swift-tools-version: 5.10
import PackageDescription

let pjRoot = "\(Context.packageDirectory)/third_party/pjproject-2.17"
let pjSuffix = "aarch64-apple-darwin25.5.0"
let opusPrefix = "/opt/homebrew/opt/opus"
let opensslPrefix = "/opt/homebrew/opt/openssl@3"

let pjIncludeFlags = [
    "pjlib/include", "pjlib-util/include", "pjnath/include",
    "pjmedia/include", "pjsip/include",
].map { "-I\(pjRoot)/\($0)" }

let pjLibSearchFlags = [
    "pjlib/lib", "pjlib-util/lib", "pjnath/lib",
    "pjmedia/lib", "pjsip/lib", "third_party/lib",
].map { "-L\(pjRoot)/\($0)" }

let pjLinkFlags = [
    "pjsua2", "pjsua", "pjsip-ua", "pjsip-simple", "pjsip",
    "pjmedia-codec", "pjmedia", "pjmedia-audiodev", "pjmedia-videodev", "pjsdp",
    "pjnath", "pjlib-util", "pj",
    "g7221codec", "gsmcodec", "ilbccodec", "resample", "speex", "srtp", "webrtc", "yuv",
].map { "-l\($0)-\(pjSuffix)" }

let externalLinkFlags = [
    "-L\(opusPrefix)/lib", "-lopus",
    "-L\(opensslPrefix)/lib", "-lssl", "-lcrypto",
]

let package = Package(
    name: "Orelhao",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "PJSIPBridge",
            path: "Sources/PJSIPBridge",
            publicHeadersPath: "include",
            cxxSettings: [
                .define("PJ_AUTOCONF", to: "1"),
                .unsafeFlags(pjIncludeFlags + ["-fobjc-arc"]),
            ],
            linkerSettings: [
                .unsafeFlags(pjLibSearchFlags + pjLinkFlags + externalLinkFlags),
                .linkedLibrary("c++"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("Foundation"),
                .linkedFramework("Security"),
            ]
        ),
        .target(name: "SIPCore", path: "Sources/SIPCore"),
        .target(
            name: "SIPCoreReal",
            dependencies: ["SIPCore", "PJSIPBridge"],
            path: "Sources/SIPCoreReal"
        ),
        .executableTarget(
            name: "OrelhaoApp",
            dependencies: ["SIPCore", "SIPCoreReal"],
            path: "Sources/OrelhaoApp"
        ),
        .executableTarget(
            name: "OrelhaoSmoke",
            dependencies: ["SIPCore", "SIPCoreReal"],
            path: "Sources/OrelhaoSmoke"
        ),
        .testTarget(
            name: "SIPCoreTests",
            dependencies: ["SIPCore"],
            path: "Tests/SIPCoreTests"
        ),
    ],
    cxxLanguageStandard: .cxx17
)
