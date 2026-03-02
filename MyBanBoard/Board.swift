//
//  Board.swift
//  MyBanBoard
//
//  Created by Mylun Jackson on 3/2/26.
//

import Foundation

struct Board: Identifiable, Hashable {
    let id: UUID
    var title: String
    var detailText: String

    static let sampleBoards: [Board] = [
        Board(id: UUID(), title: "Personal", detailText: "Capture ideas and tasks."),
        Board(id: UUID(), title: "Work", detailText: "Track delivery for current sprint."),
        Board(id: UUID(), title: "Planning", detailText: "Outline upcoming goals.")
    ]
}
