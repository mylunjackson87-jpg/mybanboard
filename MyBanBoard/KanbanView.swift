import SwiftUI
import SwiftData

struct KanbanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Bindable var board: Board

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(columns) { column in
                    KanbanColumnView(
                        column: column,
                        cards: cards(in: column),
                        canMoveLeft: column.order > 0,
                        canMoveRight: column.order < columns.count - 1,
                        onMoveLeft: { moveColumn(column, by: -1) },
                        onMoveRight: { moveColumn(column, by: 1) },
                        onDelete: { deleteColumn(column) },
                        onSave: { saveChanges() },
                        onDropCardAtEnd: { cardID in
                            moveCard(cardID: cardID, to: column, before: nil)
                        },
                        onDropCardBefore: { cardID, beforeCardID in
                            moveCard(cardID: cardID, to: column, before: beforeCardID)
                        },
                        onSendToCanvas: sendCardToCanvas,
                        onRename: { oldTitle, newTitle in
                            renameColumn(columnID: column.id, from: oldTitle, to: newTitle)
                        }
                    )
                }

                Button {
                    addColumn()
                } label: {
                    Label("Add Column", systemImage: "plus")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
    }

    private var columns: [Column] {
        board.columns.sorted { $0.order < $1.order }
    }

    private var undoService: UndoService? {
        guard let undoManager else { return nil }
        return UndoService(modelContext: modelContext, undoManager: undoManager)
    }

    private func cards(in column: Column) -> [Card] {
        board.cards
            .filter { $0.kanbanColumn?.id == column.id }
            .sorted { $0.orderInColumn < $1.orderInColumn }
    }

    private func addColumn() {
        let column = Column(board: board, title: "Column \(columns.count + 1)", order: columns.count)
        modelContext.insert(column)
        saveChanges(context: "KanbanView.addColumn")
        undoService?.registerColumnCreated(ColumnSnapshot(column: column))
    }

    private func deleteColumn(_ column: Column) {
        let columnSnapshot = ColumnSnapshot(column: column)
        let cardsSnapshot = cards(in: column).map(CardSnapshot.init(card:))
        for card in cards(in: column) {
            card.kanbanColumn = nil
            card.orderInColumn = 0
        }
        modelContext.delete(column)
        normalizeColumnOrder()
        saveChanges(context: "KanbanView.deleteColumn")
        undoService?.registerColumnDeleted(column: columnSnapshot, affectedCards: cardsSnapshot)
    }

    private func moveColumn(_ column: Column, by delta: Int) {
        let ordered = columns
        guard let sourceIndex = ordered.firstIndex(where: { $0.id == column.id }) else { return }
        let destinationIndex = sourceIndex + delta
        guard ordered.indices.contains(destinationIndex) else { return }

        let target = ordered[destinationIndex]
        let previous = column.order
        column.order = target.order
        target.order = previous
        normalizeColumnOrder()
        saveChanges(context: "KanbanView.moveColumn")
    }

    private func normalizeColumnOrder() {
        for (index, column) in columns.enumerated() {
            column.order = index
        }
    }

    private func moveCard(cardID: UUID, to destinationColumn: Column, before destinationCardID: UUID?) {
        let beforeOrder = board.cards.map(CardOrderSnapshot.init(card:))
        guard let card = board.cards.first(where: { $0.id == cardID }) else { return }
        let sourceColumn = card.kanbanColumn
        card.kanbanColumn = destinationColumn

        var destinationCards = cards(in: destinationColumn).filter { $0.id != card.id }

        if let destinationCardID,
           let targetIndex = destinationCards.firstIndex(where: { $0.id == destinationCardID }) {
            destinationCards.insert(card, at: targetIndex)
        } else {
            destinationCards.append(card)
        }

        for (index, columnCard) in destinationCards.enumerated() {
            columnCard.orderInColumn = index
        }

        if let sourceColumn, sourceColumn.id != destinationColumn.id {
            let sourceCards = cards(in: sourceColumn)
            for (index, sourceCard) in sourceCards.enumerated() {
                sourceCard.orderInColumn = index
            }
        }

        saveChanges(context: "KanbanView.moveCard")
        let afterOrder = board.cards.map(CardOrderSnapshot.init(card:))
        undoService?.registerCardOrderChange(
            actionName: sourceColumn?.id == destinationColumn.id ? "Reorder Card" : "Move Card",
            before: beforeOrder,
            after: afterOrder,
            boardID: board.id
        )
    }

    private func sendCardToCanvas(cardID: UUID) {
        let beforeOrder = board.cards.map(CardOrderSnapshot.init(card:))
        guard let card = board.cards.first(where: { $0.id == cardID }) else { return }
        let sourceColumn = card.kanbanColumn
        card.kanbanColumn = nil
        card.orderInColumn = 0

        if let sourceColumn {
            let sourceCards = cards(in: sourceColumn)
            for (index, sourceCard) in sourceCards.enumerated() {
                sourceCard.orderInColumn = index
            }
        }

        saveChanges(context: "KanbanView.sendCardToCanvas")
        let afterOrder = board.cards.map(CardOrderSnapshot.init(card:))
        undoService?.registerCardOrderChange(
            actionName: "Send to Canvas",
            before: beforeOrder,
            after: afterOrder,
            boardID: board.id
        )
    }

    private func renameColumn(columnID: UUID, from oldTitle: String, to newTitle: String) {
        guard oldTitle != newTitle else { return }
        undoService?.registerColumnRename(columnID: columnID, from: oldTitle, to: newTitle)
        saveChanges(context: "KanbanView.renameColumn")
    }

    private func saveChanges(context: String = "KanbanView.saveChanges") {
        board.updatedAt = .now
        modelContext.saveWithLogging(context)
    }
}

private struct KanbanColumnView: View {
    @Bindable var column: Column
    let cards: [Card]
    let canMoveLeft: Bool
    let canMoveRight: Bool
    let onMoveLeft: () -> Void
    let onMoveRight: () -> Void
    let onDelete: () -> Void
    let onSave: () -> Void
    let onDropCardAtEnd: (UUID) -> Void
    let onDropCardBefore: (UUID, UUID) -> Void
    let onSendToCanvas: (UUID) -> Void
    let onRename: (String, String) -> Void
    @FocusState private var titleFieldFocused: Bool
    @State private var titleBeforeEditing: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("Column", text: $column.title)
                    .font(.headline)
                    .textFieldStyle(.plain)
                    .focused($titleFieldFocused)
                    .onSubmit {
                        commitRenameIfNeeded()
                        onSave()
                    }

                Button(action: onMoveLeft) {
                    Image(systemName: "arrow.left")
                }
                .disabled(!canMoveLeft)

                Button(action: onMoveRight) {
                    Image(systemName: "arrow.right")
                }
                .disabled(!canMoveRight)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
            }

            ForEach(cards) { card in
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(.subheadline.weight(.semibold))
                    if !card.content.isEmpty {
                        Text(card.content)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .draggable(card.id.uuidString)
                .dropDestination(for: String.self) { items, _ in
                    guard let item = items.first, let draggedID = UUID(uuidString: item) else { return false }
                    onDropCardBefore(draggedID, card.id)
                    return true
                }
                .contextMenu {
                    Button("Send to Canvas") {
                        onSendToCanvas(card.id)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 280, alignment: .top)
        .frame(minHeight: 240, alignment: .top)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onChange(of: titleFieldFocused) { _, isFocused in
            if isFocused {
                titleBeforeEditing = column.title
            } else {
                commitRenameIfNeeded()
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let item = items.first, let draggedID = UUID(uuidString: item) else { return false }
            onDropCardAtEnd(draggedID)
            return true
        }
    }

    private func commitRenameIfNeeded() {
        guard let before = titleBeforeEditing else { return }
        titleBeforeEditing = nil
        onRename(before, column.title)
    }
}
