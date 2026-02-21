// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// On Darwin platforms, use system SQLite; on other platforms, use sbooth/CSQLite.
#if canImport(Darwin)
  let sqliteDependencies: [Package.Dependency] = []
  let sqliteTargetDependencies: [Target.Dependency] = []
#else
  let sqliteDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/sbooth/CSQLite", from: "3.49.1"),
  ]
  let sqliteTargetDependencies: [Target.Dependency] = [
    .product(name: "CSQLite", package: "CSQLite"),
  ]
#endif

let package = Package(
  name: "NCIUserDBKit",
  platforms: [
    .macOS(.v10_14),
  ],
  products: [
    .library(
      name: "NCIUserDBKit",
      targets: ["NCIUserDBKit"]
    ),
    .executable(
      name: "ncidump",
      targets: ["NCIUserDBCLI"]
    ),
  ],
  dependencies: sqliteDependencies,
  targets: [
    .target(
      name: "NCIUserDBKit",
      dependencies: sqliteTargetDependencies
    ),
    .executableTarget(
      name: "NCIUserDBCLI",
      dependencies: ["NCIUserDBKit"]
    ),
    .testTarget(
      name: "NCIUserDBKitTests",
      dependencies: [
        "NCIUserDBKit",
      ]
    ),
  ]
)
