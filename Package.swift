// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

guard #available(OSX 10.11, *) else {
    fatalError("macOS 10.11+ is required")
}

let package = Package(
    name: "Kinvey",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "Kinvey",
            targets: ["Kinvey"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/heyzooi/ObjectMapper.git", .branch("master")),
        .package(url: "https://github.com/mxcl/PromiseKit.git", from: "6.0.0"),
        // .package(url: "https://github.com/heyzooi/KeychainAccess.git", .branch("master")),
        .package(url: "https://github.com/DaveWoodCom/XCGLogger.git", .branch("master")),
        .package(url: "https://github.com/tjboneman/NSPredicate-MongoDB-Adaptor.git", .branch("master")),
        // .package(url: "https://github.com/heyzooi/objective-c.git", .branch("master")),
        // .package(url: "https://github.com/heyzooi/realm-cocoa.git", .branch("master")),
        .package(url: "https://github.com/Quick/Nimble.git", from: "7.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Kinvey",
            dependencies: [
                "ObjectMapper",
                "PromiseKit",
                // "KeychainAccess",
                "XCGLogger",
                "MongoDBPredicateAdaptor",
                // "PubNub",
                // Waiting for Swift Package Manager Support https://github.com/realm/realm-cocoa/pull/5828
                // "RealmSwift",
            ]),
        .testTarget(
            name: "KinveyTests",
            dependencies: [
                "Kinvey",
                "Nimble",
            ],
            exclude: [
                "CacheMigrationTestCaseStep1.swift",
                "CacheMigrationTestCaseStep2.swift",
                "CacheStoreTests.swift",
                "EncryptedDataStoreTestCase.swift",
                "KIF.swift",
                "RealtimeTestCase.swift",
                "SyncStoreTests.swift",
                "BasicStoreTestCase.swift",
                "GetOperationTest.swift",
                "DeltaSetCacheTestCase.swift",
                "PushMissingConfiguration.swift",
                "SaveOperationTest.swift",
                "PerformanceProductTestCase.swift",
            ]
        ),
    ]
)
