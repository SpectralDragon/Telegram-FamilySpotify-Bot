//
//  FamilyDeleteContext.swift
//  AdaSpotify
//
//  Created by v.a.prusakov on 19/04/2019.
//

import Foundation
import Telegrammer
import Vapor
import FluentSQLite

final class FamilyDeleteContext: BotFlowContext {
    
    private let bot: Bot
    private let connection: SQLiteDatabase.Connection
    
    private enum DeleteAnswer: String {
        case deleteNow = "Delete"
        case cancel = "Cancel"
    }
    
    private var family: Family?
    
    init(connection: SQLiteDatabase.Connection, bot: Bot) {
        self.connection = connection
        self.bot = bot
    }
    
    func prepare(chatId: Int64, user: User) throws {
        let query = Family.query(on: connection)
            .filter(\Family.chatId, .equal, Int(chatId)).join(\Family.memberIds, to: \Member.id).alsoDecode(Member.self).filter(\Member.id, .equal, Int(user.id))
        
        guard let response = try query.first().safeWait() else {
            throw ASError("Can't get info")
        }
        
        guard response.1.isOwner else {
            throw ASError("You don't have permission for removing family.")
        }
        
        self.family = response.0
        
        try bot.sendMessageWithReplyKeyboard("Are you sure?\nThis action will delete family immediately.", chatId: chatId, buttons: [DeleteAnswer.deleteNow.rawValue, DeleteAnswer.cancel.rawValue])
    }
    
    func handleMessageForCurrentState(_ message: Message) throws {
        
        if message.text == "/cancel" {
            try bot.sendMessage("Okay!", chatId: message.chat.id)
            connection.close()
            return
        }
        
        guard let family = self.family else { return }
        guard let text = message.text, let answer = DeleteAnswer(rawValue: text) else { return }
        
        switch answer {
        case .deleteNow:
            try Family.query(on: connection)
                .join(\Family.memberIds, to: \Member.id)
                .join(\Family.houseId, to: \House.id)
                .filter(\Family.id, .equal, family.id)
                .delete().safeWait()
            try bot.sendMessage("You family was deleted. See you next time.", chatId: message.chat.id)
        case .cancel:
            try bot.sendMessage("Okay. I will not delete your family now. Thanks!", chatId: message.chat.id)
        }
        
        connection.close()
    }
    
}
