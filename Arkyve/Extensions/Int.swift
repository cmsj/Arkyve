//
//  Int.swift
//  Arkyve
//
//  Created by Chris Jones on 31/05/2025.
//

import Foundation

extension Int {
    var human: String {
        get {
            // Define the units and the base for calculation
            let units = ["bytes", "KB", "MB", "GB", "TB", "PB", "EB"]
            let base: Double = 1024.0

            // Handle non-positive values
            if self < 0 {
                return "--"
            }
            guard self > 0 else {
                return "0 bytes"
            }

            // Calculate the exponent and the value
            let exponent = Int(log(Double(self)) / log(base))
            // Ensure exponent doesn't exceed available units
            let unitIndex = Swift.min(exponent, units.count - 1)
            let value = Double(self) / pow(base, Double(unitIndex))

            // Format the number
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            // Show integer if value is whole (e.g., 1MB instead of 1.0MB)
            formatter.minimumFractionDigits = 0
            // Show at most one decimal place otherwise (e.g., 1.5KB)
            formatter.maximumFractionDigits = 1
            // Use rounding strategy that feels natural for file sizes
            formatter.roundingMode = .halfUp

            // Handle the base "bytes" case specifically (no decimals needed)
            if unitIndex == 0 {
                // Use the original integer value for "bytes"
                return "\(self) \(units[unitIndex])"
            } else {
                // Format the calculated value for KB, MB, etc.
                if let formattedValue = formatter.string(from: NSNumber(value: value)) {
                    return "\(formattedValue) \(units[unitIndex])"
                } else {
                    // Fallback formatting in case NumberFormatter fails
                    return String(format: "%.1f %@", value, units[unitIndex])
                }
            }
        }
    }
}
