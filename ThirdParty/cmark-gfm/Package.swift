// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CMarkGFM",
    products: [.library(name: "CMarkGFM", type: .static, targets: ["CMarkGFM"])],
    targets: [
        .target(
            name: "CMarkGFM",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("src"),
                .headerSearchPath("extensions"),
                .headerSearchPath("generated"),
                .define("CMARK_GFM_STATIC_DEFINE"),
                .define("CMARK_GFM_EXTENSIONS_STATIC_DEFINE")
            ]
        )
    ]
)
