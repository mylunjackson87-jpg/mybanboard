import SwiftUI
import SwiftData

struct DebugView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var boards: [Board]
    @Query private var cards: [Card]
    @Query private var columns: [Column]

    var body: some View {
        Form {
            Section("Counts") {
                LabeledContent("Boards", value: "\(boards.count)")
                LabeledContent("Cards", value: "\(cards.count)")
                LabeledContent("Columns", value: "\(columns.count)")
            }

            Section("Timestamps") {
                if let latest = boards.map(\.updatedAt).max() {
                    LabeledContent("Latest Board Update") {
                        Text(latest, format: .dateTime.year().month().day().hour().minute().second())
                    }
                } else {
                    Text("No board timestamps")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Actions") {
                Button("Create Sample Data") {
                    createSampleData()
                }
            }
        }
        .navigationTitle("Debug")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    private func createSampleData() {
        let board = Board(title: "Debug Board \(boards.count + 1)")
        modelContext.insert(board)

        let todo = Column(board: board, title: "Todo", order: 0)
        let doing = Column(board: board, title: "Doing", order: 1)
        modelContext.insert(todo)
        modelContext.insert(doing)

        let canvasCard = Card(board: board, title: "Canvas Card", content: "Debug sample", x: 80, y: 40)
        let kanbanCard = Card(board: board, title: "Kanban Card", content: "Debug sample", kanbanColumn: todo, orderInColumn: 0)
        modelContext.insert(canvasCard)
        modelContext.insert(kanbanCard)

        modelContext.saveWithLogging("DebugView.createSampleData")
    }
}
