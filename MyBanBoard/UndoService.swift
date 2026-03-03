import Foundation
import SwiftData

struct CardFrameSnapshot {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct CardTextSnapshot {
    let title: String
    let content: String
}

struct CardFrameChange {
    let cardID: UUID
    let from: CardFrameSnapshot
    let to: CardFrameSnapshot
}

struct CardSnapshot {
    let id: UUID
    let boardID: UUID
    let title: String
    let content: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let kanbanColumnID: UUID?
    let orderInColumn: Int

    init(card: Card) {
        self.id = card.id
        self.boardID = card.board.id
        self.title = card.title
        self.content = card.content
        self.x = card.x
        self.y = card.y
        self.width = card.width
        self.height = card.height
        self.kanbanColumnID = card.kanbanColumn?.id
        self.orderInColumn = card.orderInColumn
    }
}

struct ColumnSnapshot {
    let id: UUID
    let boardID: UUID
    let title: String
    let order: Int

    init(column: Column) {
        self.id = column.id
        self.boardID = column.board.id
        self.title = column.title
        self.order = column.order
    }
}

struct CardOrderSnapshot {
    let cardID: UUID
    let kanbanColumnID: UUID?
    let orderInColumn: Int

    init(card: Card) {
        self.cardID = card.id
        self.kanbanColumnID = card.kanbanColumn?.id
        self.orderInColumn = card.orderInColumn
    }
}

@MainActor
final class UndoService {
    private let modelContext: ModelContext
    private let undoManager: UndoManager

    init(modelContext: ModelContext, undoManager: UndoManager) {
        self.modelContext = modelContext
        self.undoManager = undoManager
    }

    func registerCardFrameChange(cardID: UUID, from: CardFrameSnapshot, to: CardFrameSnapshot) {
        register(actionName: "Move/Resize Card", undo: { [weak self] in
            self?.applyCardFrame(cardID: cardID, snapshot: from)
        }, redo: { [weak self] in
            self?.applyCardFrame(cardID: cardID, snapshot: to)
        })
    }

    func registerCardFrameBatchChange(actionName: String, changes: [CardFrameChange]) {
        guard !changes.isEmpty else { return }
        register(actionName: actionName, undo: { [weak self] in
            self?.applyCardFrameChanges(changes, useToSnapshot: false, source: "UndoService.undo\(actionName)")
        }, redo: { [weak self] in
            self?.applyCardFrameChanges(changes, useToSnapshot: true, source: "UndoService.redo\(actionName)")
        })
    }

    func registerCardTextChange(cardID: UUID, from: CardTextSnapshot, to: CardTextSnapshot) {
        register(actionName: "Edit Card", undo: { [weak self] in
            self?.applyCardText(cardID: cardID, snapshot: from)
        }, redo: { [weak self] in
            self?.applyCardText(cardID: cardID, snapshot: to)
        })
    }

    func registerCardCreated(_ snapshot: CardSnapshot) {
        register(actionName: "Create Card", undo: { [weak self] in
            self?.deleteCard(cardID: snapshot.id, source: "UndoService.undoCreateCard")
        }, redo: { [weak self] in
            self?.applyCardSnapshot(snapshot, source: "UndoService.redoCreateCard")
        })
    }

    func registerCardDeleted(_ snapshot: CardSnapshot) {
        register(actionName: "Delete Card", undo: { [weak self] in
            self?.applyCardSnapshot(snapshot, source: "UndoService.undoDeleteCard")
        }, redo: { [weak self] in
            self?.deleteCard(cardID: snapshot.id, source: "UndoService.redoDeleteCard")
        })
    }

    func registerColumnCreated(_ snapshot: ColumnSnapshot) {
        register(actionName: "Create Column", undo: { [weak self] in
            self?.deleteColumn(columnID: snapshot.id, source: "UndoService.undoCreateColumn")
        }, redo: { [weak self] in
            self?.applyColumnSnapshot(snapshot, source: "UndoService.redoCreateColumn")
        })
    }

    func registerColumnDeleted(column: ColumnSnapshot, affectedCards: [CardSnapshot]) {
        register(actionName: "Delete Column", undo: { [weak self] in
            self?.applyColumnSnapshot(column, source: "UndoService.undoDeleteColumn")
            for card in affectedCards {
                self?.applyCardSnapshot(card, source: "UndoService.undoDeleteColumnCard")
            }
            self?.normalizeKanbanOrdering(boardID: column.boardID)
            self?.modelContext.saveWithLogging("UndoService.undoDeleteColumn")
        }, redo: { [weak self] in
            self?.deleteColumn(columnID: column.id, source: "UndoService.redoDeleteColumn")
        })
    }

    func registerColumnRename(columnID: UUID, from: String, to: String) {
        register(actionName: "Rename Column", undo: { [weak self] in
            self?.renameColumn(columnID: columnID, title: from, source: "UndoService.undoRenameColumn")
        }, redo: { [weak self] in
            self?.renameColumn(columnID: columnID, title: to, source: "UndoService.redoRenameColumn")
        })
    }

    func registerCardOrderChange(actionName: String, before: [CardOrderSnapshot], after: [CardOrderSnapshot], boardID: UUID) {
        register(actionName: actionName, undo: { [weak self] in
            self?.applyCardOrderSnapshots(before, boardID: boardID, source: "UndoService.undo\(actionName)")
        }, redo: { [weak self] in
            self?.applyCardOrderSnapshots(after, boardID: boardID, source: "UndoService.redo\(actionName)")
        })
    }

    private func register(actionName: String, undo: @escaping () -> Void, redo: @escaping () -> Void) {
        undoManager.registerUndo(withTarget: self) { target in
            undo()
            target.register(actionName: actionName, undo: redo, redo: undo)
        }
        undoManager.setActionName(actionName)
    }

    private func applyCardFrame(cardID: UUID, snapshot: CardFrameSnapshot) {
        guard let card = fetchCard(id: cardID) else { return }
        card.x = snapshot.x
        card.y = snapshot.y
        card.width = snapshot.width
        card.height = snapshot.height
        card.board.updatedAt = .now
        modelContext.saveWithLogging("UndoService.applyCardFrame")
    }

    private func applyCardFrameChanges(_ changes: [CardFrameChange], useToSnapshot: Bool, source: String) {
        var touchedBoardIDs = Set<UUID>()

        for change in changes {
            guard let card = fetchCard(id: change.cardID) else { continue }
            let snapshot = useToSnapshot ? change.to : change.from
            card.x = snapshot.x
            card.y = snapshot.y
            card.width = snapshot.width
            card.height = snapshot.height
            touchedBoardIDs.insert(card.board.id)
        }

        for boardID in touchedBoardIDs {
            fetchBoard(id: boardID)?.updatedAt = .now
        }

        modelContext.saveWithLogging(source)
    }

    private func applyCardText(cardID: UUID, snapshot: CardTextSnapshot) {
        guard let card = fetchCard(id: cardID) else { return }
        card.title = snapshot.title
        card.content = snapshot.content
        card.board.updatedAt = .now
        modelContext.saveWithLogging("UndoService.applyCardText")
    }

    private func applyCardSnapshot(_ snapshot: CardSnapshot, source: String) {
        guard let board = fetchBoard(id: snapshot.boardID) else { return }
        let column = snapshot.kanbanColumnID.flatMap { fetchColumn(id: $0) }

        if let card = fetchCard(id: snapshot.id) {
            card.title = snapshot.title
            card.content = snapshot.content
            card.x = snapshot.x
            card.y = snapshot.y
            card.width = snapshot.width
            card.height = snapshot.height
            card.kanbanColumn = column
            card.orderInColumn = snapshot.orderInColumn
            card.board = board
            board.updatedAt = .now
            modelContext.saveWithLogging(source)
            return
        }

        let card = Card(
            id: snapshot.id,
            board: board,
            title: snapshot.title,
            content: snapshot.content,
            x: snapshot.x,
            y: snapshot.y,
            width: snapshot.width,
            height: snapshot.height,
            kanbanColumn: column,
            orderInColumn: snapshot.orderInColumn
        )
        modelContext.insert(card)
        board.updatedAt = .now
        modelContext.saveWithLogging(source)
    }

    private func applyColumnSnapshot(_ snapshot: ColumnSnapshot, source: String) {
        guard let board = fetchBoard(id: snapshot.boardID) else { return }

        if let column = fetchColumn(id: snapshot.id) {
            column.title = snapshot.title
            column.order = snapshot.order
            column.board = board
            board.updatedAt = .now
            modelContext.saveWithLogging(source)
            return
        }

        let column = Column(id: snapshot.id, board: board, title: snapshot.title, order: snapshot.order)
        modelContext.insert(column)
        board.updatedAt = .now
        modelContext.saveWithLogging(source)
    }

    private func applyCardOrderSnapshots(_ snapshots: [CardOrderSnapshot], boardID: UUID, source: String) {
        for snapshot in snapshots {
            guard let card = fetchCard(id: snapshot.cardID) else { continue }
            let column = snapshot.kanbanColumnID.flatMap { fetchColumn(id: $0) }
            card.kanbanColumn = column
            card.orderInColumn = snapshot.orderInColumn
        }

        normalizeKanbanOrdering(boardID: boardID)
        if let board = fetchBoard(id: boardID) {
            board.updatedAt = .now
        }
        modelContext.saveWithLogging(source)
    }

    private func normalizeKanbanOrdering(boardID: UUID) {
        guard let board = fetchBoard(id: boardID) else { return }
        let columns = board.columns.sorted { $0.order < $1.order }

        for column in columns {
            let orderedCards = board.cards
                .filter { $0.kanbanColumn?.id == column.id }
                .sorted { $0.orderInColumn < $1.orderInColumn }

            for (index, card) in orderedCards.enumerated() {
                card.orderInColumn = index
            }
        }
    }

    private func renameColumn(columnID: UUID, title: String, source: String) {
        guard let column = fetchColumn(id: columnID) else { return }
        column.title = title
        column.board.updatedAt = .now
        modelContext.saveWithLogging(source)
    }

    private func deleteCard(cardID: UUID, source: String) {
        guard let card = fetchCard(id: cardID) else { return }
        let board = card.board
        modelContext.delete(card)
        board.updatedAt = .now
        modelContext.saveWithLogging(source)
    }

    private func deleteColumn(columnID: UUID, source: String) {
        guard let column = fetchColumn(id: columnID) else { return }
        let board = column.board

        let affectedCards = board.cards.filter { $0.kanbanColumn?.id == columnID }
        for card in affectedCards {
            card.kanbanColumn = nil
            card.orderInColumn = 0
        }

        modelContext.delete(column)
        let remainingColumns = board.columns.sorted { $0.order < $1.order }
        for (index, remainingColumn) in remainingColumns.enumerated() {
            remainingColumn.order = index
        }

        board.updatedAt = .now
        modelContext.saveWithLogging(source)
    }

    private func fetchBoard(id: UUID) -> Board? {
        let descriptor = FetchDescriptor<Board>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchCard(id: UUID) -> Card? {
        let descriptor = FetchDescriptor<Card>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchColumn(id: UUID) -> Column? {
        let descriptor = FetchDescriptor<Column>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }
}
