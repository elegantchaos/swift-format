//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation

struct IteratorContext {}

private typealias URLIterator = Array<URL>.Iterator

protocol IteratorChain {
  mutating func next() -> URL?
  func nextIterator() -> IteratorChain?
}

struct NestedIterator: Sequence, IteratorProtocol {
  private var current: IteratorChain?

  init(first: IteratorChain) {
    self.current = first
  }

  mutating func next() -> URL? {
    repeat {
      if let next = current?.next() {
        return next
      }
      current = current?.nextIterator()
    } while current != nil
    return nil
  }
}

/// Iterator for looping over lists of files and directories. Directories are automatically
/// traversed recursively, and we check for files with a ".swift" extension.
@_spi(Internal)
public struct FileIterator2: Sequence, IteratorProtocol {
  private var iterators: IteratorChain

  /// Create a new file iterator over the given list of file URLs.
  ///
  /// The given URLs may be files or directories. If they are directories, the iterator will recurse
  /// into them.
  public init(urls: [URL], followSymlinks: Bool) {
    self.iteratorIterator = TopIterator(urls: urls, followSymlinks: followSymlinks)
  }

  /// Iterate through the "paths" list, and emit the file paths in it. If we encounter a directory,
  /// recurse through it and emit .swift file paths.
  public mutating func next() -> URL? {
    return nestedIterator.next()
  }
}

/// Returns the type of the file at the given URL.
private func fileType(at url: URL) -> FileAttributeType? {
  // We cannot use `URL.resourceValues(forKeys:)` here because it appears to behave incorrectly on
  // Linux.
  return try? FileManager.default.attributesOfItem(atPath: url.path)[.type] as? FileAttributeType
}

struct ContextIterator: Sequence, IteratorProtocol {
  var urlIterator: URLIterator
  var nextIterator: IteratorChain?

  init(urls: [URL]) {
    self.urlIterator = urls.makeIterator()
  }

  func next() -> Element? {
    guard let url = urlIterator.next() else {
      return nil
    }

    switch fileType(at: url) {
    case .directory:
      return DirectoryIterator(url: url)
    case .regular:
      return url
    default:
      return nil
    }
  }
}
