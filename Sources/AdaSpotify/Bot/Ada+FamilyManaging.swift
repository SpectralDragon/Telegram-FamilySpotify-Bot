//
//  Ada+FamilyManaging.swift
//  AdaSpotify
//
//  Created by v.a.prusakov on 19/04/2019.
//

import Foundation
import Telegrammer
import Vapor
import FluentSQLite

// MARK: - Family managing

extension AdaSpotifyBot {
    
///    Remove family: /remove_family +
///    Add new member: /add_member
///    Delete member: /delete_member
///    Set monthly price: /set_pay - price will devide only 5 members
    
    func setupFamilyManaging(dispatcher: Dispatcher) throws {
        let createFamilyHandler = CommandHandler(commands: ["/create"], callback: createFamily)
        dispatcher.add(handler: createFamilyHandler)
        
        let removeFamilyHandler = CommandHandler(commands: ["/remove_family"], callback: removeFamily)
        dispatcher.add(handler: removeFamilyHandler)
        
        let familyCreateContextHandlers = [MessageHandler(filters: Filters.text, callback: createFamilyContextResponse),
                                           MessageHandler(filters: Filters.contact, callback: createFamilyContextResponse),
                                           MessageHandler(filters: Filters.entity(types: [.mention, .textMention]), callback: createFamilyContextResponse)]
        familyCreateContextHandlers.forEach { dispatcher.add(handler: $0) }
        
        let familyDeleteContextHandler = MessageHandler(filters: .text, callback: deleteFamilyContextResponse)
        dispatcher.add(handler: familyDeleteContextHandler)
    }
    
    // MARK: - Private
    // MARK: Create
    
    private func createFamily(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from else { return }
        
        let context = FamilyCreateContext(worker: self.worker, bot: self.bot, creatorId: user.id)
        self.familyCreateContexts[user.id] = context
        try context.prepare(chatId: message.chat.id, user: user)
    }
    
    private func createFamilyContextResponse(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from,
            let context = self.familyCreateContexts[user.id] else { return }
        
        if message.text == "/cancel" {
            self.familyCreateContexts.removeValue(forKey: user.id)
            try bot.sendMessage("Cancelled! See you next time.", chatId: message.chat.id)
            return
        }
        
        do {
            try context.handleMessageForCurrentState(message)
        } catch {
            try bot.sendMessage(error.localizedDescription, chatId: message.chat.id)
            throw error
        }
    }
    
    // MARK: Remove
    
    private func removeFamily(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message, let user = message.from else { return }
        
        worker.requestCachedConnection(to: .sqlite).do { connection in
            let deleteContext = FamilyDeleteContext(connection: connection, bot: self.bot)
            self.familyDeleteContexts[user.id] = deleteContext
            do {
                try deleteContext.prepare(chatId: message.chat.id, user: user)
            } catch {
                try? self.bot.sendMessage(error.localizedDescription, chatId: message.chat.id)
            }
        }.catch { error in
            try? self.bot.sendMessage("Something went wrong", chatId: message.chat.id)
            print(error.localizedDescription)
        }
    }
    
    private func deleteFamilyContextResponse(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from,
            let context = self.familyDeleteContexts[user.id] else { return }
        
        do {
            try context.handleMessageForCurrentState(message)
        } catch {
            try bot.sendMessage(error.localizedDescription, chatId: message.chat.id)
            throw error
        }
    }
    
}
