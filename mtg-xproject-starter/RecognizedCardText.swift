import CoreGraphics
import Foundation

struct RecognizedCardText: Equatable {
    let rawLines: [String]
    let nameCandidate: String?
    let setCodeCandidate: String?
    let collectorNumberCandidate: String?

    init(rawLines: [String]) {
        let normalizedLines = rawLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        self.rawLines = normalizedLines

        let parsedMetadata = CardTextParser.parseCollectorMetadata(from: normalizedLines)
        setCodeCandidate = parsedMetadata?.setCode
        collectorNumberCandidate = parsedMetadata?.collectorNumber
        nameCandidate = CardTextParser.parseName(from: normalizedLines)
    }

    init(
        rawLines: [String],
        nameCandidate: String?,
        setCodeCandidate: String?,
        collectorNumberCandidate: String?
    ) {
        self.rawLines = rawLines
        self.nameCandidate = nameCandidate
        self.setCodeCandidate = setCodeCandidate
        self.collectorNumberCandidate = collectorNumberCandidate
    }
}

enum CardTextParser {
    private static let ignoredLowercaseLines = [
        "instant",
        "sorcery",
        "creature",
        "artifact",
        "enchantment",
        "planeswalker",
        "land",
        "legendary",
        "basic land"
    ]

    static func parseName(from lines: [String]) -> String? {
        lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { line in
                let lowercasedLine = line.lowercased()

                return line.count >= 2
                    && !line.contains("/")
                    && !line.contains("©")
                    && !ignoredLowercaseLines.contains(lowercasedLine)
                    && parseCollectorMetadata(from: [line]) == nil
            }
    }

    static func parseCollectorMetadata(from lines: [String]) -> (collectorNumber: String, setCode: String)? {
        for line in lines.reversed() {
            if let metadata = parseCollectorMetadata(from: line) {
                return metadata
            }
        }

        return nil
    }

    private static func parseCollectorMetadata(from line: String) -> (collectorNumber: String, setCode: String)? {
        let normalizedLine = line
            .replacingOccurrences(of: "•", with: " ")
            .replacingOccurrences(of: "|", with: " ")
            .replacingOccurrences(of: "#", with: " ")
            .replacingOccurrences(of: "—", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .uppercased()

        let pattern = #"(?<![A-Z0-9])([A-Z]?\d{1,4}[A-Z★*]?)(?:\s*/\s*\d{1,4})?\s+([A-Z0-9]{3,5})(?![A-Z0-9])"#

        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.matches(
                in: normalizedLine,
                range: NSRange(normalizedLine.startIndex..<normalizedLine.endIndex, in: normalizedLine)
            ).last,
            match.numberOfRanges == 3,
            let collectorRange = Range(match.range(at: 1), in: normalizedLine),
            let setRange = Range(match.range(at: 2), in: normalizedLine)
        else {
            return nil
        }

        return (
            String(normalizedLine[collectorRange]),
            String(normalizedLine[setRange])
        )
    }
}

protocol CardTextRecognizing {
    func recognizeText(from image: CGImage) async throws -> RecognizedCardText
}

enum CardIdentificationResult: Equatable {
    case exact(MTGCardSummary)
    case candidates([MTGCardSummary])
    case notFound(String)
}

protocol CardIdentifying {
    func identify(_ recognizedText: RecognizedCardText) async throws -> CardIdentificationResult
}
