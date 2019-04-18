//
//  House.swift
//  AdaSpotify
//
//  Created by v.a.prusakov on 15/04/2019.
//

import Foundation
import FluentSQLite

final class House: SQLiteStringModel {
    var id: String?
    
    var streetName: String?
    var streetNumber: Int?
    var zipCode: Int?
    var city: String?
    
    init() {
        self.id = UUID().uuidString
    }
}

extension House: Migration {}
