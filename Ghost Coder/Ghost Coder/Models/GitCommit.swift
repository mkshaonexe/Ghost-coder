//
//  GitCommit.swift
//  Ghost Coder
//
//  Created by AI on 17/6/26.
//

import Foundation

struct GitCommit: Identifiable, Codable, Equatable {
    let id: String       // short hash e.g. "a1b2c3d"
    let message: String  // commit message e.g. "add section 1 - header"
    let index: Int       // position in history (0 = oldest)
}
