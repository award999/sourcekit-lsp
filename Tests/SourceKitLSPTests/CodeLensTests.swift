//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import LanguageServerProtocol
import SKTestSupport
import ToolchainRegistry
import XCTest

final class CodeLensTests: XCTestCase {
  func testNoLenses() async throws {
    var codeLensCapabilities = TextDocumentClientCapabilities.CodeLens()
    codeLensCapabilities.supportedCommands = [
      SupportedCodeLensCommand.run: "swift.run",
      SupportedCodeLensCommand.debug: "swift.debug",
    ]
    let capabilities = ClientCapabilities(textDocument: TextDocumentClientCapabilities(codeLens: codeLensCapabilities))

    let project = try await SwiftPMTestProject(
      files: [
        "Test.swift": """
        struct MyApp {
          public static func main() {}
        }
        """
      ],
      capabilities: capabilities
    )
    let (uri, _) = try project.openDocument("Test.swift")

    let response = try await project.testClient.send(
      CodeLensRequest(textDocument: TextDocumentIdentifier(uri))
    )

    XCTAssertEqual(response, [])
  }

  func testNoClientCodeLenses() async throws {
    let project = try await SwiftPMTestProject(
      files: [
        "Test.swift": """
        import Playgrounds
        @main
        struct MyApp {
          public static func main() {}
        }

        #Playground {
          print("Hello Playground!")
        }

        #Playground("named") {
          print("Hello named Playground!")
        }
        """
      ]
    )

    let (uri, _) = try project.openDocument("Test.swift")

    let response = try await project.testClient.send(
      CodeLensRequest(textDocument: TextDocumentIdentifier(uri))
    )

    XCTAssertEqual(response, [])
  }

  func testSuccessfulCodeLensRequest() async throws {
    var codeLensCapabilities = TextDocumentClientCapabilities.CodeLens()
    codeLensCapabilities.supportedCommands = [
      SupportedCodeLensCommand.run: "swift.run",
      SupportedCodeLensCommand.debug: "swift.debug",
      SupportedCodeLensCommand.play: "swift.play",
    ]
    let capabilities = ClientCapabilities(textDocument: TextDocumentClientCapabilities(codeLens: codeLensCapabilities))
    let toolchain = try await unwrap(ToolchainRegistry.forTesting.default)
    let toolchainRegistry = ToolchainRegistry(toolchains: [
        Toolchain(
          identifier: "\(toolchain.identifier)-crashing-swift-format",
          displayName: "\(toolchain.identifier) with crashing swift-format",
          path: toolchain.path,
          clang: toolchain.clang,
          swift: toolchain.swift,
          swiftc: toolchain.swiftc,
          swiftPlay: URL(string: "/path/to/swift-play"),
          clangd: toolchain.clangd,
          sourcekitd: toolchain.sourcekitd,
          sourceKitClientPlugin: toolchain.sourceKitClientPlugin,
          sourceKitServicePlugin: toolchain.sourceKitServicePlugin,
          libIndexStore: toolchain.libIndexStore
        )
      ])

    let project = try await SwiftPMTestProject(
      files: [
        "Sources/MyApp/Test.swift": """
        import Playgrounds
        1️⃣@main2️⃣
        struct MyApp {
          public static func main() {}
        }

        3️⃣#Playground {
          print("Hello Playground!")
        }4️⃣

        5️⃣#Playground("named") {
          print("Hello named Playground!")
        }6️⃣
        """
      ],
      manifest: """
        // swift-tools-version: 5.7

        import PackageDescription

        let package = Package(
          name: "MyApp",
          targets: [.executableTarget(name: "MyApp")]
        )
        """,
      capabilities: capabilities,
      toolchainRegistry: toolchainRegistry
    )

    let (uri, positions) = try project.openDocument("Test.swift")

    let response = try await project.testClient.send(
      CodeLensRequest(textDocument: TextDocumentIdentifier(uri))
    )

    XCTAssertEqual(
      response,
      [
        CodeLens(
          range: positions["1️⃣"]..<positions["2️⃣"],
          command: Command(title: "Run MyApp", command: "swift.run", arguments: [.string("MyApp")])
        ),
        CodeLens(
          range: positions["1️⃣"]..<positions["2️⃣"],
          command: Command(title: "Debug MyApp", command: "swift.debug", arguments: [.string("MyApp")])
        ),
        CodeLens(
          range: positions["3️⃣"]..<positions["4️⃣"],
          command: Command(
            title: "Play \"MyApp/Test.swift:7\"",
            command: "swift.play",
            arguments: [
              PlaygroundItem(
                id: "MyApp/Test.swift:7",
                label: nil,
                location: Location(uri: uri, range: positions["3️⃣"]..<positions["4️⃣"]),
              ).encodeToLSPAny()
            ]
          )
        ),
        CodeLens(
          range: positions["5️⃣"]..<positions["6️⃣"],
          command: Command(
            title: "Play \"named\"",
            command: "swift.play",
            arguments: [
              PlaygroundItem(
                id: "MyApp/Test.swift:11",
                label: "named",
                location: Location(uri: uri, range: positions["5️⃣"]..<positions["6️⃣"]),
              ).encodeToLSPAny()
            ]
          )
        ),
      ]
    )
  }

  func testCodeLensRequestSwiftPlayMissing() async throws {
    var codeLensCapabilities = TextDocumentClientCapabilities.CodeLens()
    codeLensCapabilities.supportedCommands = [
      SupportedCodeLensCommand.run: "swift.run",
      SupportedCodeLensCommand.debug: "swift.debug",
      SupportedCodeLensCommand.play: "swift.play",
    ]
    let capabilities = ClientCapabilities(textDocument: TextDocumentClientCapabilities(codeLens: codeLensCapabilities))
    let toolchain = try await unwrap(ToolchainRegistry.forTesting.default)
    let toolchainRegistry = ToolchainRegistry(toolchains: [
        Toolchain(
          identifier: "\(toolchain.identifier)-crashing-swift-format",
          displayName: "\(toolchain.identifier) with crashing swift-format",
          path: toolchain.path,
          clang: toolchain.clang,
          swift: toolchain.swift,
          swiftc: toolchain.swiftc,
          swiftPlay: nil,
          clangd: toolchain.clangd,
          sourcekitd: toolchain.sourcekitd,
          sourceKitClientPlugin: toolchain.sourceKitClientPlugin,
          sourceKitServicePlugin: toolchain.sourceKitServicePlugin,
          libIndexStore: toolchain.libIndexStore
        )
      ])

    let project = try await SwiftPMTestProject(
      files: [
        "Sources/MyApp/Test.swift": """
        import Playgrounds
        1️⃣@main2️⃣
        struct MyApp {
          public static func main() {}
        }

        #Playground {
          print("Hello Playground!")
        }

        #Playground("named") {
          print("Hello named Playground!")
        }
        """
      ],
      manifest: """
        // swift-tools-version: 5.7

        import PackageDescription

        let package = Package(
          name: "MyApp",
          targets: [.executableTarget(name: "MyApp")]
        )
        """,
      capabilities: capabilities,
      toolchainRegistry: toolchainRegistry
    )

    let (uri, positions) = try project.openDocument("Test.swift")

    let response = try await project.testClient.send(
      CodeLensRequest(textDocument: TextDocumentIdentifier(uri))
    )

    XCTAssertEqual(
      response,
      [
        CodeLens(
          range: positions["1️⃣"]..<positions["2️⃣"],
          command: Command(title: "Run MyApp", command: "swift.run", arguments: [.string("MyApp")])
        ),
        CodeLens(
          range: positions["1️⃣"]..<positions["2️⃣"],
          command: Command(title: "Debug MyApp", command: "swift.debug", arguments: [.string("MyApp")])
        )
      ]
    )
  }
}
