//
//  Family.swift
//  AdaSpotify
//
//  Created by v.a.prusakov on 17/04/2019.
//

import Foundation
import FluentSQLite

final class Family: SQLiteStringModel {
    
    var id: String?
    
    private(set) var chatId: Int
    private(set) var houseId: String 
    private(set) var memberIds: Set<Int>
    
    init(chatId: Int, houseId: String, membersIds: Set<Int> = []) {
        self.id = UUID().uuidString
        self.chatId = chatId
        self.houseId = houseId
        self.memberIds = membersIds
    }
    
    func removeUser(byId id: Int) throws {
        self.memberIds.remove(id)
    }
    
    func addUser(withId id: Int) throws {
        self.memberIds.insert(id)
    }
    
}

extension Family: Migration {}
