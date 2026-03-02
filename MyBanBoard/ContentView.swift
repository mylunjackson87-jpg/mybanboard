//
//  ContentView.swift
//  MyBanBoard
//
//  Created by Mylun Jackson on 3/2/26.
//

import SwiftUI

struct ContentView: View {
    @State private var boards = Board.sampleBoards
    @State private var selection: Board.ID?

    var body: some View {
        NavigationSplitView {
            List(boards, selection: $selection) { board in
                Text(board.title)
                    .tag(board.id)
            }
            .navigationTitle("Boards")
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
        } detail: {
            if let selectedBoard {
                BoardDetailView(board: selectedBoard)
            } else {
                ContentUnavailableView("Select a Board", systemImage: "rectangle.stack")
            }
        }
        .onAppear {
            if selection == nil {
                selection = boards.first?.id
            }
        }
    }

    private var selectedBoard: Board? {
        guard let selection else {
            return nil
        }

        return boards.first { $0.id == selection }
    }
}

#Preview {
    ContentView()
}
