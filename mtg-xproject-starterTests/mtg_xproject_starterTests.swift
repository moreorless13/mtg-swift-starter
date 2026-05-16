//
//  mtg_xproject_starterTests.swift
//  mtg-xproject-starterTests
//
//  Created by James Strande on 5/16/26.
//

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
            setCode: "  7ED  ",
            rarity: "  Uncommon  "
        )

        #expect(summary.id == "abc-123")
        #expect(summary.name == "Counterspell")
        #expect(summary.manaCost == "{U}{U}")
        #expect(summary.type == "Instant")
        #expect(summary.setCode == "7ED")
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
        #expect(summary.rarity == "Unknown rarity")
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

}
