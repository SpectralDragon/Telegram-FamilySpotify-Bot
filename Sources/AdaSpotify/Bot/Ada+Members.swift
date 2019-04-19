//
//  Ada+Members.swift
//  AdaSpotify
//
//  Created by v.a.prusakov on 19/04/2019.
//

import Foundation
import Telegrammer
import Vapor

// MARK: - Members

extension AdaSpotifyBot {
    
    func setupMembers(dispatcher: Dispatcher) throws {
        let statusCommandHandler = CommandHandler(commands: ["/get_status"], callback: statusHandler)
        dispatcher.add(handler: statusCommandHandler)
        
        let payCommandHandler = CommandHandler(commands: ["/pay"], callback: payHandler)
        dispatcher.add(handler: payCommandHandler)
    }
    
    // MARK: - Private
    
    private func statusHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from else { return }
        
        let problemMessage = { try? self.bot.sendMessage("We got a problem with your status info. Try again later.", chatId: message.chat.id) }
        
        worker.requestCachedConnection(to: .sqlite).do { connection in
            do {
                guard let response = try Member.query(on: connection)
                    .filter(\.id, .equal, Int(user.id))
                    .join(\Member.id, to: \Family.memberIds)
                    .join(\Family.houseId, to: \House.id)
                    .alsoDecode(Family.self)
                    .alsoDecode(House.self).first().safeWait() else {
                        try self.bot.sendMessage("Can't get status", chatId: message.chat.id)
                        return
                }
                
                
                let statusText = self.makeStatusText(member: response.0.0, family: response.0.1, house: response.1, locale: Locale(identifier: user.languageCode ?? "en"))
                let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: statusText)
                try self.bot.sendMessage(params: params)
            } catch {
                problemMessage()
            }
            
            }.catch { _ in problemMessage() }
        
    }
    
    private func makeStatusText(member: Member, family: Family, house: House, locale: Locale) -> String {
        return """
        You are:
        
        \(member.info(forLocale: locale))
        
        House:
        
        \(house.info(forLocale: locale))
        """
    }
    
    // MARK: Pay
    
    private func payHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from else { return }
        
        
    }
}
