// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LibYAML",
    products: [.library(name: "LibYAML", type: .static, targets: ["LibYAML"])],
    targets: [.target(
        name: "LibYAML", path: ".",
        exclude: ["License", "PROVENANCE.md", "SHA256.json"],
        sources: ["src"], publicHeadersPath: "include",
        cSettings: [
            .define("YAML_VERSION_MAJOR", to: "0"),
            .define("YAML_VERSION_MINOR", to: "2"),
            .define("YAML_VERSION_PATCH", to: "5"),
            .define("YAML_VERSION_STRING", to: "\"0.2.5\"")
        ]
    )]
)
