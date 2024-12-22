//
//  RandomAccessCollection.swift
//  ZipZap
//
//  Created by Chris Jones on 04/06/2024.
//

//import Foundation
//
//// Taken from: https://stackoverflow.com/questions/26678362/how-do-i-insert-an-element-at-the-correct-position-into-a-sorted-array-in-swift/55395494#55395494
//extension RandomAccessCollection where Element : Comparable {
//    func insertionIndex(of value: Element) -> Index {
//        var slice : SubSequence = self[...]
//
//        while !slice.isEmpty {
//            let middle = slice.index(slice.startIndex, offsetBy: slice.count / 2)
//            if value < slice[middle] {
//                slice = slice[..<middle]
//            } else {
//                slice = slice[index(after: middle)...]
//            }
//        }
//        return slice.startIndex
//    }
//}
