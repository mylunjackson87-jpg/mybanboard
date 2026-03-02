//
//  MyBanBoardTests.swift
//  MyBanBoardTests
//
//  Created by Mylun Jackson on 3/2/26.
//

import Testing
import Foundation
import SwiftData
@testable import MyBanBoard

struct MyBanBoardTests {

    @MainActor @Test func modelCRUDWorksInMemory() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let board = Board(title: "Sprint")
        context.insert(board)

        let column = Column(board: board, title: "Todo", order: 0)
        context.insert(column)

        let card = Card(board: board, title: "Model setup", content: "Implement Board/Card/Column", kanbanColumn: column, orderInColumn: 0)
        context.insert(card)

        try context.save()

        let boards = try context.fetch(FetchDescriptor<Board>())
        let cards = try context.fetch(FetchDescriptor<Card>())
        let columns = try context.fetch(FetchDescriptor<Column>())

        #expect(boards.count == 1)
        #expect(cards.count == 1)
        #expect(columns.count == 1)
        #expect(cards.first?.board.id == board.id)
        #expect(cards.first?.kanbanColumn?.id == column.id)
    }

    @MainActor @Test func modelPersistenceWorksWithDiskBackedStore() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let storeURL = tempDirectory.appendingPathComponent("MyBanBoardTests.store")

        do {
            let container = try makeDiskBackedContainer(storeURL: storeURL)
            let context = container.mainContext
            let board = Board(title: "Persisted Board")
            context.insert(board)
            try context.save()
        }

        do {
            let container = try makeDiskBackedContainer(storeURL: storeURL)
            let context = container.mainContext
            let boards = try context.fetch(FetchDescriptor<Board>())
            #expect(boards.contains(where: { $0.title == "Persisted Board" }))
        }
    }

    @MainActor @Test func movingCardBetweenColumnsUpdatesRelationshipsAndOrder() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let board = Board(title: "Flow")
        context.insert(board)

        let todo = Column(board: board, title: "Todo", order: 0)
        let done = Column(board: board, title: "Done", order: 1)
        context.insert(todo)
        context.insert(done)

        let first = Card(board: board, title: "First", kanbanColumn: todo, orderInColumn: 0)
        let second = Card(board: board, title: "Second", kanbanColumn: todo, orderInColumn: 1)
        context.insert(first)
        context.insert(second)

        second.kanbanColumn = done
        second.orderInColumn = 0
        first.orderInColumn = 0

        try context.save()

        #expect(first.kanbanColumn?.id == todo.id)
        #expect(second.kanbanColumn?.id == done.id)
        #expect(first.orderInColumn == 0)
        #expect(second.orderInColumn == 0)
    }

    @MainActor @Test func orderInColumnCanBeNormalizedAfterReorder() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let board = Board(title: "Normalize")
        context.insert(board)

        let column = Column(board: board, title: "Backlog", order: 0)
        context.insert(column)

        let cards = [
            Card(board: board, title: "A", kanbanColumn: column, orderInColumn: 2),
            Card(board: board, title: "B", kanbanColumn: column, orderInColumn: 7),
            Card(board: board, title: "C", kanbanColumn: column, orderInColumn: 4),
        ]

        for card in cards {
            context.insert(card)
        }

        let sorted = cards.sorted { $0.orderInColumn < $1.orderInColumn }
        for (index, card) in sorted.enumerated() {
            card.orderInColumn = index
        }

        try context.save()

        let fetchedCards = try context.fetch(FetchDescriptor<Card>())
            .filter { $0.kanbanColumn?.id == column.id }
            .sorted { $0.orderInColumn < $1.orderInColumn }

        #expect(fetchedCards.map(\.orderInColumn) == [0, 1, 2])
    }
}

private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([Board.self, Card.self, Column.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
}

private func makeDiskBackedContainer(storeURL: URL) throws -> ModelContainer {
    let schema = Schema([Board.self, Card.self, Column.self])
    let configuration = ModelConfiguration(schema: schema, url: storeURL)
    return try ModelContainer(for: schema, configurations: [configuration])
}
