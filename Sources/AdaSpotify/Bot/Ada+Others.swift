//
//  Ada+Others.swift
//  AdaSpotify
//
//  Created by v.a.prusakov on 19/04/2019.
//

import Foundation
import Telegrammer
import Vapor

// MARK: - Others

extension AdaSpotifyBot {
    
    func setupOthers(dispatcher: Dispatcher) throws {
        //        let chatHandler = ChatHandler(name: "ChatHandler", options: [.userDidLeft, .newUsersAdded], callback: self.userHandler)
        //        dispatcher.add(handler: chatHandler)
    }
    
    // MARK: - Private
    
    private func userHandler(_ result: ChatHandler.Result, _ update: Update) throws {
        switch result {
        case .newUsersAdded(let members):
            return
        case .userDidLeft(let user):
            return
        }
    }
}
