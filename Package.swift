// swift-tools-version:5.5
import PackageDescription

let package = Package(
  name: "VaporUtils",
  platforms: [.macOS(.v11)],
  products: [
    .library(name: "VaporUtils", targets: ["VaporUtils"]),
    .library(name: "XCTVaporUtils", targets: ["XCTVaporUtils"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/vapor/vapor.git",
      from: "4.54.0"
    ),
    .package(
      url: "https://github.com/vapor/fluent.git",
      from: "4.4.0"
    ),
    .package(
      name: "GraphQLKit",
      url: "https://github.com/alexsteinerde/graphql-kit.git",
      from: "2.3.0"
    ),
    .package(
      name: "QueuesFluentDriver",
      url: "https://github.com/m-barthelemy/vapor-queues-fluent-driver.git",
      from: "1.2.0"
    ),
  ],
  targets: [
    .target(
      name: "VaporUtils",
      dependencies: [
        .product(name: "Fluent", package: "fluent"),
        .product(name: "Vapor", package: "vapor"),
        "QueuesFluentDriver",
      ]),
    .target(
      name: "XCTVaporUtils",
      dependencies: [
        .product(name: "Vapor", package: "vapor"),
        .product(name: "XCTVapor", package: "vapor"),
        "GraphQLKit",
      ]
    ),
    .testTarget(
      name: "VaporUtilsTests",
      dependencies: ["VaporUtils"]),
  ]
)
