/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Byte-bounded truncation for attribute values whose size is capped in UTF-8 bytes.
enum UTF8Truncation {
  /// Returns the longest prefix of `string` whose UTF-8 encoding is at most `maxBytes` long.
  ///
  /// The cut is only made between characters (extended grapheme clusters), so a multi-byte
  /// scalar, a combining sequence, an emoji ZWJ sequence or a `\r\n` pair is either kept whole
  /// or dropped whole. A first character that is larger than `maxBytes` therefore yields an
  /// empty string, and a negative `maxBytes` is treated as zero.
  static func truncate(_ string: String, maxBytes: Int) -> String {
    var string = string
    // Bridged NSStrings may be UTF-16 backed; native UTF-8 makes the byte walk below exact and cheap.
    string.makeContiguousUTF8()

    let utf8 = string.utf8
    guard utf8.count > maxBytes else {
      return string
    }
    var end = utf8.index(utf8.startIndex, offsetBy: max(maxBytes, 0))
    while end > utf8.startIndex, String.Index(end, within: string) == nil {
      end = utf8.index(before: end)
    }
    return String(string[..<end])
  }
}
