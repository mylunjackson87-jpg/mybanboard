//
//  Card.swift
//  MyBanBoard
//
//  Created by Mylun Jackson on 3/2/26.
//

import Foundation
import SwiftData

@Model
final class Card {
    @Attribute(.unique) var id: UUID
    var board: Board
    var title: String
    var content: String
    var deletedAt: Date?
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var kanbanColumn: Column?
    var orderInColumn: Int

    init(
        id: UUID = UUID(),
        board: Board,
        title: String,
        content: String = "",
        deletedAt: Date? = nil,
        x: Double = 0,
        y: Double = 0,
        width: Double = 260,
        height: Double = 160,
        kanbanColumn: Column? = nil,
        orderInColumn: Int = 0
    ) {
        self.id = id
        self.board = board
        self.title = title
        self.content = content
        self.deletedAt = deletedAt
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.kanbanColumn = kanbanColumn
        self.orderInColumn = orderInColumn
    }
}
