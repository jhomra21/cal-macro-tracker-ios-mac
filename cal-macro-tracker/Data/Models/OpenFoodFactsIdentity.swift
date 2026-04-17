import Foundation

enum OpenFoodFactsIdentity {
    nonisolated static func barcodeAliases(for barcode: String?) -> [String] {
        guard let barcode = trimmedText(from: barcode) else {
            return []
        }

        if CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: barcode)) {
            if barcode.count == 12 {
                return [barcode, "0\(barcode)"]
            }

            if barcode.count == 13, barcode.hasPrefix("0") {
                return [String(barcode.dropFirst()), barcode]
            }
        }

        return [barcode]
    }

    nonisolated static func qualifiedExternalProductID(for barcode: String?) -> String? {
        qualifiedExternalProductID(forRawIdentifier: barcodeAliases(for: barcode).first)
    }

    nonisolated static func qualifiedExternalProductIDAliases(for barcode: String?) -> [String] {
        var seen = Set<String>()
        return barcodeAliases(for: barcode)
            .compactMap { qualifiedExternalProductID(forRawIdentifier: $0) }
            .filter { seen.insert($0).inserted }
    }

    nonisolated static func qualifiedExternalProductID(forRawIdentifier identifier: String?) -> String? {
        guard let identifier = trimmedText(from: identifier) else {
            return nil
        }

        return "openfoodfacts:\(identifier)"
    }

    nonisolated static func trimmedText(from value: String?) -> String? {
        guard let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmedValue.isEmpty else {
            return nil
        }

        return trimmedValue
    }
}
