//
//  Column.swift
//  MyBanBoard
//
//  Created by Mylun Jackson on 3/2/26.
//

import Foundation
import SwiftData

@Model
final class Column {
    @Attribute(.unique) var id: UUID
    var board: Board
    var title: String
    var order: Int
    @Relationship(inverse: \Card.kanbanColumn) var cards: [Card]

    init(
        id: UUID = UUID(),
        board: Board,
        title: String,
        order: Int
    ) {
        self.id = id
        self.board = board
        self.title = title
        self.order = order
        self.cards = []
    }
}
