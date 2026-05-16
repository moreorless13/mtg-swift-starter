import Foundation

struct MTGCardSummary: Identifiable, Equatable {
    let id: String
    let name: String
    let manaCost: String
    let type: String
    let setCode: String
    let rarity: String

    static func make(
        id: String?,
        name: String?,
        manaCost: String?,
        type: String?,
        setCode: String?,
        rarity: String?
    ) -> MTGCardSummary {
        let displayName = name.nonEmptyValue ?? "Unknown card"
        let displayType = type.nonEmptyValue ?? "Unknown type"
        let displaySetCode = setCode.nonEmptyValue ?? "Unknown set"

        return MTGCardSummary(
            id: id.nonEmptyValue ?? "\(displayName)-\(displaySetCode)-\(displayType)",
            name: displayName,
            manaCost: manaCost.nonEmptyValue ?? "No mana cost",
            type: displayType,
            setCode: displaySetCode,
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
