//
//  ASError.swift
//  AdaSpotify
//
//  Created by v.a.prusakov on 17/04/2019.
//

import Foundation

struct ASError: LocalizedError {
    
    private let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var errorDescription: String? {
        return self.text
    }
}
