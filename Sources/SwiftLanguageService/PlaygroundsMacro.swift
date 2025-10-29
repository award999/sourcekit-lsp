//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation
package import LanguageServerProtocol
import SKLogging
package import SourceKitLSP
import SwiftSyntax
import Playgrounds
import SwiftParser
internal import BuildServerIntegration

extension SwiftLanguageService {
  package func syntacticDocumentPlaygrounds(for uri: DocumentURI, in workspace: Workspace) async throws -> [PlaygroundItem] {
    let snapshot = try self.documentManager.latestSnapshot(uri)

    let syntaxTree = await syntaxTreeManager.syntaxTree(for: snapshot)

    try Task.checkCancellation()
    return
      await PlaygroundMacroFinder.find(
        in: [Syntax(syntaxTree)],
        workspace: workspace,
        snapshot: snapshot,
        range: syntaxTree.position..<syntaxTree.endPosition
      )
  }
}

// MARK: - PlaygroundMacroFinder

final class PlaygroundMacroFinder: SyntaxAnyVisitor {
  /// The base ID to use to generate IDs for any playgrounds found in this file.
  private let baseID: String

  /// The snapshot of the document for which we are getting playgrounds.
  private let snapshot: DocumentSnapshot

  /// Only playgrounds that intersect with this range get reported.
  private let range: Range<AbsolutePosition>

  /// Accumulating the result in here.
  private var result: [PlaygroundItem] = []

  /// Keep track of if "Playgrounds" has been imported
  private var isPlaygroundImported: Bool = false

  private init(baseID: String, snapshot: DocumentSnapshot, range: Range<AbsolutePosition>) {
    self.baseID = baseID
    self.snapshot = snapshot
    self.range = range
    super.init(viewMode: .sourceAccurate)
  }

  /// Designated entry point for `PlaygroundMacroFinder`.
  static func find(
    in nodes: some Sequence<Syntax>,
    workspace: Workspace,
    snapshot: DocumentSnapshot,
    range: Range<AbsolutePosition>
  ) async -> [PlaygroundItem] {
    guard let canonicalTarget = await workspace.buildServerManager.canonicalTarget(for: snapshot.uri),
      let moduleName = await workspace.buildServerManager.moduleName(for: snapshot.uri, in: canonicalTarget),
      let baseName = snapshot.uri.fileURL?.lastPathComponent 
    else {
      return []
    }
    let visitor = PlaygroundMacroFinder(baseID: "\(moduleName)/\(baseName)", snapshot: snapshot, range: range)
    for node in nodes {
      visitor.walk(node)
    }
    return visitor.result
  }

  /// Add a playground location with the given parameters to the `result` array.
  private func record(
    id: String,
    label: String?,
    range: Range<AbsolutePosition>
  ) {
    if !self.range.overlaps(range) {
      return
    }
    let positionRange = snapshot.absolutePositionRange(of: range)
    let location = Location(uri: snapshot.uri, range: positionRange)
  
    result.append(
      PlaygroundItem(
        id: id,
        label: label,
        location: location,
      )
    )
  }

  override func visit(_ node: ImportPathComponentSyntax) -> SyntaxVisitorContinueKind {
    if node.name.text == "Playgrounds" {
      isPlaygroundImported = true
    }
    return .skipChildren
  }

  override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
    guard isPlaygroundImported, node.macroName.text == "Playground" else {
      return .skipChildren
    }

    let startPosition = snapshot.position(of: node.positionAfterSkippingLeadingTrivia)
    let stringLiteral = node.arguments.first?.expression.as(StringLiteralExprSyntax.self)
    let playgroundLabel = stringLiteral?.representedLiteralValue
    let playgroundID = "\(baseID):\(startPosition.line + 1)"

    record(
      id: playgroundID, 
      label: playgroundLabel,
      range: node.positionAfterSkippingLeadingTrivia..<node.endPositionBeforeTrailingTrivia
    )

    return .skipChildren
  }
}
