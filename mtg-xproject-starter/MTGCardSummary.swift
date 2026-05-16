import Foundation

struct MTGCardSummary: Identifiable, Equatable {
    let id: String
    let name: String
    let manaCost: String
    let type: String
    let setCode: String
    let setName: String?
    let collectorNumber: String?
    let setIconURL: URL?
    let imageURL: URL?
    let rarity: String

    static func make(
        id: String?,
        name: String?,
        manaCost: String?,
        type: String?,
        setCode: String?,
        setName: String? = nil,
        collectorNumber: String? = nil,
        setIconURL: URL? = nil,
        imageURL: URL? = nil,
        rarity: String?
    ) -> MTGCardSummary {
        let displayName = name.nonEmptyValue ?? "Unknown card"
        let displayType = type.nonEmptyValue ?? "Unknown type"
        let displaySetCode = setCode.nonEmptyValue?.uppercased() ?? "Unknown set"

        return MTGCardSummary(
            id: id.nonEmptyValue ?? "\(displayName)-\(displaySetCode)-\(collectorNumber.nonEmptyValue ?? displayType)",
            name: displayName,
            manaCost: manaCost.nonEmptyValue ?? "No mana cost",
            type: displayType,
            setCode: displaySetCode,
            setName: setName.nonEmptyValue,
            collectorNumber: collectorNumber.nonEmptyValue,
            setIconURL: setIconURL,
            imageURL: imageURL,
            rarity: rarity.nonEmptyValue ?? "Unknown rarity"
        )
    }
}

private extension Optional where Wrapped == String {
    var nonEmptyValue: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        return value
    }
}
