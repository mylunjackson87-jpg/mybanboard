//
//  Board.swift
//  MyBanBoard
//
//  Created by Mylun Jackson on 3/2/26.
//

import Foundation
import SwiftData

@Model
final class Board {
    @Attribute(.unique) var id: UUID
    var title: String
    var updatedAt: Date
    var viewportOffsetX: Double
    var viewportOffsetY: Double
    var viewportScale: Double
    var drawingData: Data
    @Relationship(deleteRule: .cascade, inverse: \Card.board) var cards: [Card]
    @Relationship(deleteRule: .cascade, inverse: \Column.board) var columns: [Column]

    init(
        id: UUID = UUID(),
        title: String,
        updatedAt: Date = .now,
        viewportOffsetX: Double = 0,
        viewportOffsetY: Double = 0,
        viewportScale: Double = 1,
        drawingData: Data = Data()
    ) {
        self.id = id
        self.title = title
        self.updatedAt = updatedAt
        self.viewportOffsetX = viewportOffsetX
        self.viewportOffsetY = viewportOffsetY
        self.viewportScale = viewportScale
        self.drawingData = drawingData
        self.cards = []
        self.columns = []
    }
}
