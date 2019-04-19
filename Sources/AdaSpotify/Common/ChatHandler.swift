//
//  ChatHandler.swift
//  AdaSpotify
//
//  Created by v.a.prusakov on 19/04/2019.
//

import Foundation
import Telegrammer
import Vapor

class ChatHandler: Handler {
    
    typealias HandlerBlock = (_ result: Result, _ update: Update) throws -> Void
    
    var name: String
    
    public struct Options: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public static let newUsersAdded = Options(rawValue: 0 << 1)
        
        public static let userDidLeft = Options(rawValue: 1 << 1)
    }
    
    enum Result {
        case newUsersAdded([User])
        case userDidLeft(User)
    }
    
    private var options: Options
    private var callback: HandlerBlock
    
    init(name: String = String(describing: ChatHandler.self), options: Options = [], callback: @escaping HandlerBlock) {
        self.name = name
        self.options = options
        self.callback = callback
    }
    
    func check(update: Update) -> Bool {
        return true
    }
    
    func handle(update: Update, dispatcher: Dispatcher) throws {
        if let members = update.message?.newChatMembers, options.contains(.newUsersAdded) {
            try callback(.newUsersAdded(members), update)
        }
        
        if let user = update.message?.leftChatMember, options.contains(.userDidLeft) {
            try callback(.userDidLeft(user), update)
        }
        
    }
    
    
}
