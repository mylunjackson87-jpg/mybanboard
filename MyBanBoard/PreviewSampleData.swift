//
//  PreviewSampleData.swift
//  MyBanBoard
//
//  Created by Mylun Jackson on 3/2/26.
//

import Foundation
import SwiftData

enum PreviewSampleData {
    static let container: ModelContainer = makeContainer()

    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            Board.self,
            Card.self,
            Column.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])

        populateIfNeeded(context: container.mainContext)
        return container
    }

    static func sampleBoard() -> Board? {
        try? container.mainContext.fetch(FetchDescriptor<Board>()).first
    }

    private static func populateIfNeeded(context: ModelContext) {
        let existingBoards = (try? context.fetch(FetchDescriptor<Board>())) ?? []
        if !existingBoards.isEmpty {
            return
        }

        let personal = Board(title: "Personal")
        let work = Board(title: "Work")

        let backlog = Column(board: work, title: "Backlog", order: 0)
        let doing = Column(board: work, title: "Doing", order: 1)

        context.insert(personal)
        context.insert(work)
        context.insert(backlog)
        context.insert(doing)
        context.insert(Card(board: personal, title: "Groceries", content: "Eggs, milk, coffee"))
        context.insert(Card(board: work, title: "Task 2.1", content: "SwiftData models", kanbanColumn: backlog, orderInColumn: 0))
    }
}
