//
//  Ada+Help.swift
//  AdaSpotify
//
//  Created by v.a.prusakov on 19/04/2019.
//

import Foundation
import Telegrammer
import Vapor

// MARK: - Help and Start

extension AdaSpotifyBot {
    
    func setupHelps(dispatcher: Dispatcher) throws {
        let helpHandler = CommandHandler(commands: ["/start", "/help"], callback: self.helpHandler)
        dispatcher.add(handler: helpHandler)
    }
    
    // MARK: - Private
    
    private func helpHandler(_ update: Update, _ context: BotContext?) throws {
        
        guard let message = update.message else { return }
        
        let help = """
        Welcome to Ada Spotify Family Bot.

        Ada can help you manage your subscription and paayments using telegram.
        You don't need access to Spotify, only chat with members in your family.

        If you wanna create your family sent me: /create
        
        For owners:
        
        Remove family: /remove_family
        Add new member: /add_member
        Delete member: /delete_member
        Set monthly price: /set_pay - price will devide only 5 members

        For members:
        
        Get status of debt and info about home: /status
        Pay now: /pay

        Good luck and have a nice playlists!
        """
        
        try bot.sendMessage(help, chatId: message.chat.id)
    }
}
