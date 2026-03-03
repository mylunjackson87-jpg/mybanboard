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

    @MainActor @Test func undoRedoCardFrameMoveRestoresPosition() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let undoManager = UndoManager()
        let undoService = UndoService(modelContext: context, undoManager: undoManager)

        let board = Board(title: "Frame")
        context.insert(board)
        let card = Card(board: board, title: "Card", x: 0, y: 0, width: 260, height: 160)
        context.insert(card)
        try context.save()

        let from = CardFrameSnapshot(x: 0, y: 0, width: 260, height: 160)
        card.x = 120
        card.y = 80
        try context.save()
        let to = CardFrameSnapshot(x: 120, y: 80, width: 260, height: 160)

        undoService.registerCardFrameChange(cardID: card.id, from: from, to: to)

        undoManager.undo()
        #expect(card.x == 0)
        #expect(card.y == 0)

        undoManager.redo()
        #expect(card.x == 120)
        #expect(card.y == 80)
    }

    @MainActor @Test func undoSendToKanbanRestoresCanvasState() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let undoManager = UndoManager()
        let undoService = UndoService(modelContext: context, undoManager: undoManager)

        let board = Board(title: "Transfer")
        context.insert(board)
        let todo = Column(board: board, title: "Todo", order: 0)
        context.insert(todo)
        let card = Card(board: board, title: "Card", x: 10, y: 20, width: 260, height: 160, kanbanColumn: nil, orderInColumn: 0)
        context.insert(card)
        try context.save()

        let before = board.cards.map(CardOrderSnapshot.init(card:))
        card.kanbanColumn = todo
        card.orderInColumn = 0
        try context.save()
        let after = board.cards.map(CardOrderSnapshot.init(card:))

        undoService.registerCardOrderChange(actionName: "Send to Kanban", before: before, after: after, boardID: board.id)

        undoManager.undo()
        #expect(card.kanbanColumn == nil)
        #expect(card.x == 10)
        #expect(card.y == 20)
        #expect(card.width == 260)
        #expect(card.height == 160)

        undoManager.redo()
        #expect(card.kanbanColumn?.id == todo.id)
    }

    @MainActor @Test func undoReorderRestoresOriginalOrderInColumn() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let undoManager = UndoManager()
        let undoService = UndoService(modelContext: context, undoManager: undoManager)

        let board = Board(title: "Reorder")
        context.insert(board)
        let column = Column(board: board, title: "Todo", order: 0)
        context.insert(column)
        let first = Card(board: board, title: "First", kanbanColumn: column, orderInColumn: 0)
        let second = Card(board: board, title: "Second", kanbanColumn: column, orderInColumn: 1)
        context.insert(first)
        context.insert(second)
        try context.save()

        let before = board.cards.map(CardOrderSnapshot.init(card:))
        first.orderInColumn = 1
        second.orderInColumn = 0
        try context.save()
        let after = board.cards.map(CardOrderSnapshot.init(card:))

        undoService.registerCardOrderChange(actionName: "Reorder Card", before: before, after: after, boardID: board.id)

        undoManager.undo()
        #expect(first.orderInColumn == 0)
        #expect(second.orderInColumn == 1)

        undoManager.redo()
        #expect(first.orderInColumn == 1)
        #expect(second.orderInColumn == 0)
    }

    @MainActor @Test func undoWorksAfterUndoServiceFallsOutOfScope() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let undoManager = UndoManager()

        let board = Board(title: "Ephemeral Service")
        context.insert(board)
        let card = Card(board: board, title: "Card", x: 0, y: 0, width: 260, height: 160)
        context.insert(card)
        try context.save()

        let from = CardFrameSnapshot(x: 0, y: 0, width: 260, height: 160)
        card.x = 80
        card.y = 40
        try context.save()
        let to = CardFrameSnapshot(x: 80, y: 40, width: 260, height: 160)

        do {
            let undoService = UndoService(modelContext: context, undoManager: undoManager)
            undoService.registerCardFrameChange(cardID: card.id, from: from, to: to)
        }

        undoManager.undo()
        #expect(card.x == 0)
        #expect(card.y == 0)

        undoManager.redo()
        #expect(card.x == 80)
        #expect(card.y == 40)
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
