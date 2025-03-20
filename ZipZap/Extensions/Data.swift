//
//  Data.swift
//  ZipZap
//
//  Created by Chris Jones on 27/12/2024.
//

import Foundation

/// An extension on `Data` that provides convenient access to the underlying bytes.
extension Data {
    /// Returns the underlying bytes of the `Data` instance as an array of `UInt8`.
    ///
    /// This property provides a convenient way to access the raw bytes of a `Data` instance
    /// without explicitly converting it to an array.
    ///
    /// Example:
    /// ```swift
    /// let data = Data([1, 2, 3])
    /// let bytes = data.bytes // [1, 2, 3]
    /// ```
    public var bytes: [UInt8]
    {
        return [UInt8](self)
    }
}
