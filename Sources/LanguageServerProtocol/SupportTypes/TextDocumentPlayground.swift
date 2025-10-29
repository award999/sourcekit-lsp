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

/// A playground item that can be used to identify playground. Differs from `TextDocumentPlayground`
/// by not including location which is given for `textDocument/playgrounds` request
public struct TextDocumentPlayground: ResponseType, Equatable {
  /// Identifier for the `TextDocumentPlayground`.
  ///
  /// This identifier uniquely identifies the playground. It can be used to run an individual playground with `swift play`.
  public var id: String

  /// Display name describing the playground.
  public var label: String?

  /// The range of the #Playground macro expansion in the given file.
  public var range: Range<Position>

  public init(
    id: String,
    label: String?,
    range: Range<Position>
  ) {
    self.id = id
    self.label = label
    self.range = range
  }

  public func encodeToLSPAny() -> LSPAny {
    var dict: [String: LSPAny] = [
      "id": .string(id),
      "range": range.encodeToLSPAny()
    ]

    if let label {
      dict["label"] = .string(label)
    }

    return .dictionary(dict)
  }
}
