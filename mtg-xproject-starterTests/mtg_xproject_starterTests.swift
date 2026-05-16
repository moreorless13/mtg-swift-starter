//
//  mtg_xproject_starterTests.swift
//  mtg-xproject-starterTests
//
//  Created by James Strande on 5/16/26.
//

import Foundation
import Testing
@testable import mtg_xproject_starter

@MainActor
struct mtg_xproject_starterTests {

    @Test func cardSummaryMapsOptionalFields() {
        let summary = MTGCardSummary.make(
            id: "abc-123",
            name: "  Counterspell  ",
            manaCost: "  {U}{U}  ",
            type: "  Instant  ",
            setCode: "  7ed  ",
            setName: "  Seventh Edition  ",
            collectorNumber: "  67  ",
            setIconURL: URL(string: "https://example.com/7ed.svg"),
            imageURL: URL(string: "https://example.com/counterspell.jpg"),
            rarity: "  Uncommon  "
        )

        #expect(summary.id == "abc-123")
        #expect(summary.name == "Counterspell")
        #expect(summary.manaCost == "{U}{U}")
        #expect(summary.type == "Instant")
        #expect(summary.setCode == "7ED")
        #expect(summary.setName == "Seventh Edition")
        #expect(summary.collectorNumber == "67")
        #expect(summary.setIconURL == URL(string: "https://example.com/7ed.svg"))
        #expect(summary.imageURL == URL(string: "https://example.com/counterspell.jpg"))
        #expect(summary.rarity == "Uncommon")
    }

    @Test func cardSummaryProvidesFallbacksForMissingFields() {
        let summary = MTGCardSummary.make(
            id: nil,
            name: nil,
            manaCost: nil,
            type: nil,
            setCode: nil,
            rarity: nil
        )

        #expect(summary.id == "Unknown card-Unknown set-Unknown type")
        #expect(summary.name == "Unknown card")
        #expect(summary.manaCost == "No mana cost")
        #expect(summary.type == "Unknown type")
        #expect(summary.setCode == "Unknown set")
        #expect(summary.setName == nil)
        #expect(summary.collectorNumber == nil)
        #expect(summary.setIconURL == nil)
        #expect(summary.imageURL == nil)
        #expect(summary.rarity == "Unknown rarity")
    }

    @Test func recognizedTextParsesNameSetAndCollectorNumber() {
        let text = RecognizedCardText(rawLines: [
            "Lightning Bolt",
            "Instant",
            "150/280 M10"
        ])

        #expect(text.nameCandidate == "Lightning Bolt")
        #expect(text.collectorNumberCandidate == "150")
        #expect(text.setCodeCandidate == "M10")
    }

    @Test func recognizedTextParsesNameOnly() {
        let text = RecognizedCardText(rawLines: [
            "Black Lotus",
            "Artifact"
        ])

        #expect(text.nameCandidate == "Black Lotus")
        #expect(text.collectorNumberCandidate == nil)
        #expect(text.setCodeCandidate == nil)
    }

    @Test func recognizedTextParsesPromoCollectorNumbers() {
        let text = RecognizedCardText(rawLines: [
            "Fabled Passage",
            "Land",
            "F30★ PFRF"
        ])

        #expect(text.nameCandidate == "Fabled Passage")
        #expect(text.collectorNumberCandidate == "F30★")
        #expect(text.setCodeCandidate == "PFRF")
    }

    @Test func recognizedTextIgnoresEmptyNoisyLines() {
        let text = RecognizedCardText(rawLines: [
            "  ",
            "© 2026 Wizards",
            "123/456"
        ])

        #expect(text.nameCandidate == nil)
        #expect(text.collectorNumberCandidate == nil)
        #expect(text.setCodeCandidate == nil)
    }

    @Test func scryfallServiceUsesExactSetCollectorRoute() async throws {
        var requestedURLs: [URL] = []
        let service = ScryfallCardService(baseURL: URL(string: "https://api.example.test")!) { request in
            requestedURLs.append(try #require(request.url))

            if request.url?.path == "/cards/dom/60" {
                return (
                    Self.scryfallCardJSON(
                        id: "opt-dom-60",
                        name: "Opt",
                        set: "dom",
                        setName: "Dominaria",
                        collectorNumber: "60"
                    ),
                    Self.httpResponse(for: request, statusCode: 200)
                )
            }

            if request.url?.path == "/sets/dom" {
                return (
                    Self.scryfallSetJSON(),
                    Self.httpResponse(for: request, statusCode: 200)
                )
            }

            return (Data(), Self.httpResponse(for: request, statusCode: 404))
        }

        let result = try await service.identify(
            RecognizedCardText(
                rawLines: [],
                nameCandidate: "Opt",
                setCodeCandidate: "DOM",
                collectorNumberCandidate: "60"
            )
        )

        guard case .exact(let card) = result else {
            Issue.record("Expected exact card result")
            return
        }

        #expect(card.name == "Opt")
        #expect(card.setCode == "DOM")
        #expect(card.collectorNumber == "60")
        #expect(card.setIconURL == URL(string: "https://svgs.scryfall.io/sets/dom.svg"))
        #expect(requestedURLs.first?.path == "/cards/dom/60")
    }

    @Test func scryfallServiceFallsBackToPrintCandidatesForNameOnly() async throws {
        var requestedURLs: [URL] = []
        let service = ScryfallCardService(baseURL: URL(string: "https://api.example.test")!) { request in
            requestedURLs.append(try #require(request.url))

            switch request.url?.path {
            case "/cards/named":
                return (
                    Self.scryfallCardJSON(
                        id: "bolt-best",
                        name: "Lightning Bolt",
                        set: "m10",
                        setName: "Magic 2010",
                        collectorNumber: "150"
                    ),
                    Self.httpResponse(for: request, statusCode: 200)
                )
            case "/cards/search":
                return (
                    Self.scryfallListJSON(cards: [
                        Self.scryfallCardJSON(
                            id: "bolt-m10-150",
                            name: "Lightning Bolt",
                            set: "m10",
                            setName: "Magic 2010",
                            collectorNumber: "150"
                        ),
                        Self.scryfallCardJSON(
                            id: "bolt-clu-141",
                            name: "Lightning Bolt",
                            set: "clu",
                            setName: "Ravnica: Clue Edition",
                            collectorNumber: "141"
                        )
                    ]),
                    Self.httpResponse(for: request, statusCode: 200)
                )
            case "/sets/m10", "/sets/clu":
                return (
                    Self.scryfallSetJSON(),
                    Self.httpResponse(for: request, statusCode: 200)
                )
            default:
                return (Data(), Self.httpResponse(for: request, statusCode: 404))
            }
        }

        let result = try await service.identify(
            RecognizedCardText(
                rawLines: [],
                nameCandidate: "Lightning Bolt",
                setCodeCandidate: nil,
                collectorNumberCandidate: nil
            )
        )

        guard case .candidates(let cards) = result else {
            Issue.record("Expected candidate printings")
            return
        }

        #expect(cards.map(\.collectorNumber) == ["150", "141"])
        #expect(requestedURLs.contains { $0.path == "/cards/named" })
        #expect(requestedURLs.contains { $0.path == "/cards/search" })
    }

    @Test func scryfallServiceConvertsEmptyPrintSearchToNotFound() async throws {
        let service = ScryfallCardService(baseURL: URL(string: "https://api.example.test")!) { request in
            switch request.url?.path {
            case "/cards/named":
                return (
                    Self.scryfallCardJSON(
                        id: "found-name",
                        name: "Imaginary Card",
                        set: "abc",
                        setName: "Fake Set",
                        collectorNumber: "1"
                    ),
                    Self.httpResponse(for: request, statusCode: 200)
                )
            case "/cards/search":
                return (
                    """
                    {"data":[]}
                    """.data(using: .utf8)!,
                    Self.httpResponse(for: request, statusCode: 200)
                )
            default:
                return (Data(), Self.httpResponse(for: request, statusCode: 404))
            }
        }

        let result = try await service.identify(
            RecognizedCardText(
                rawLines: [],
                nameCandidate: "Imaginary Card",
                setCodeCandidate: nil,
                collectorNumberCandidate: nil
            )
        )

        #expect(result == .notFound("Imaginary Card"))
    }

    @Test func serviceRejectsEmptyQuery() async {
        let service = MTGCardService { _, completion in
            completion(.success([]))
        }

        do {
            _ = try await service.fetchCards(named: "   ")
            Issue.record("Expected empty query to throw")
        } catch let error as MTGCardServiceError {
            #expect(error == .emptyQuery)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func servicePropagatesSDKErrors() async {
        let service = MTGCardService { _, completion in
            completion(.failure(MTGCardServiceError.sdk("boom")))
        }

        do {
            _ = try await service.fetchCards(named: "Island")
            Issue.record("Expected SDK failure to throw")
        } catch let error as MTGCardServiceError {
            #expect(error == .sdk("boom"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private static func httpResponse(for request: URLRequest, statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }

    private static func scryfallCardJSON(
        id: String,
        name: String,
        set: String,
        setName: String,
        collectorNumber: String
    ) -> Data {
        """
        {
            "id": "\(id)",
            "name": "\(name)",
            "set": "\(set)",
            "set_name": "\(setName)",
            "collector_number": "\(collectorNumber)",
            "scryfall_uri": "https://scryfall.com/card/\(set)/\(collectorNumber)",
            "type_line": "Instant",
            "mana_cost": "{R}",
            "rarity": "common",
            "image_uris": {
                "normal": "https://img.scryfall.com/cards/normal/\(id).jpg",
                "small": "https://img.scryfall.com/cards/small/\(id).jpg"
            }
        }
        """.data(using: .utf8)!
    }

    private static func scryfallListJSON(cards: [Data]) -> Data {
        let body = cards
            .compactMap { String(data: $0, encoding: .utf8) }
            .joined(separator: ",")

        return """
        {"data":[\(body)]}
        """.data(using: .utf8)!
    }

    private static func scryfallSetJSON() -> Data {
        """
        {
            "icon_svg_uri": "https://svgs.scryfall.io/sets/dom.svg"
        }
        """.data(using: .utf8)!
    }

}
