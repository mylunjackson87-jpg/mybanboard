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
