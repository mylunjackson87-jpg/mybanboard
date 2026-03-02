//
//  BoardDetailView.swift
//  MyBanBoard
//
//  Created by Mylun Jackson on 3/2/26.
//

import SwiftUI

struct BoardDetailView: View {
    let board: Board

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(board.title)
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text(board.detailText)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle(board.title)
    }
}

#Preview {
    BoardDetailView(board: .sampleBoards[0])
}
