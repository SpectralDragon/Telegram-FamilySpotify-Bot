//
//  Member.swift
//  App
//
//  Created by v.a.prusakov on 15/04/2019.
//

import Foundation
import FluentSQLite

final class Member: SQLiteModel {
    var id: Int?
    var langCode: String
    var debt: Double?
    
    let firstName: String
    let lastName: String
    
    var isOwner: Bool
    
    var parentId: Int?
    var houseId: String?
    
    init(id: Int? = nil, firstName: String, lastName: String, langCode: String, debt: Double? = nil, isOwner: Bool = false, parentId: Int? = nil, houseId: String? = nil) throws {
        guard !firstName.isEmpty, !lastName.isEmpty else {
            throw ASError("Can't create new member, because firstname or lastname is empty")
        }
        self.id = id
        self.langCode = langCode
        self.debt = debt
        self.lastName = lastName
        self.firstName = firstName
        self.isOwner = isOwner
        self.parentId = parentId
        self.houseId = houseId
    }
}

extension Member: Migration {}
