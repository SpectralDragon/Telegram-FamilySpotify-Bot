//
//  FamilyCreateContext.swift
//  AdaSpotify
//
//  Created by v.a.prusakov on 17/04/2019.
//

import Foundation
import Telegrammer
import Vapor
import FluentSQLite

final class FamilyCreateContext: BotFlowContext {
    
    private let bot: Bot
    private let worker: Container
    private let creatorId: Int64
    
    init(worker: Container, bot: Bot, creatorId: Int64) {
        self.worker = worker
        self.creatorId = creatorId
        self.bot = bot
    }
    
    private enum CheckAnswer: String {
        case ok = "OK"
        case cancel = "Cancel"
    }
    
    private enum MemberAnswer: String {
        case `continue` = "Continue"
        case finish = "Finish"
    }
    
    private enum Step: Int {
        case streetName = 0
        case streetNumber
        case city
        case zipCode
        case members
        case check
        case completed
        
        case cancelled = 100
    }
    
    private var house: House = House()
    private var members: [Member] = []
    private var currentStep = Step.streetName
    
    func prepare(chatId: Int64, user: User) throws {
         try bot.sendMessage("Welcome to family creation mode!\nPlease, sent me family street address from you Spotify.\n\nFor cancelling sent /cancel", chatId: chatId)
    }
    
    func handleMessageForCurrentState(_ message: Message) throws {
        
        let locale = Locale(identifier: message.from.flatMap { $0.languageCode } ?? "en")
        
        switch currentStep {
        case .streetName:
            house.streetName = try self.returnMessageIfIsNotEmptyOrNil(message)
            try bot.sendMessage("Okay, please sent your street number.", chatId: message.chat.id)
        case .streetNumber:
            guard let streetNumber = Int(try self.returnMessageIfIsNotEmptyOrNil(message)) else {
                throw ASError("Street number must contains numbers only")
            }
            house.streetNumber = streetNumber
            try bot.sendMessage("Please, sent your city name.", chatId: message.chat.id)
        case .city:
            house.city = try self.returnMessageIfIsNotEmptyOrNil(message)
            try bot.sendMessage("Please, sent your zip code.", chatId: message.chat.id)
        case .zipCode:
            guard let zipCode = Int(try self.returnMessageIfIsNotEmptyOrNil(message)) else {
                throw ASError("Zip code must contains numbers only")
            }
            house.zipCode = zipCode
            try bot.sendMessage("Okay. Sent member contact or mention person, who live with you or part of your family. (Max members 0 / 6).", chatId: message.chat.id)
        case .members:
            guard members.count < 6 else {
                try bot.sendMessage("You can have only 6 members in Family.", chatId: message.chat.id)
                break
            }
            
            if let answerText = try? self.returnMessageIfIsNotEmptyOrNil(message), let answer = MemberAnswer(rawValue: answerText) {
                switch answer {
                case .continue:
                    break
                case .finish:
                    try finishOfferMessage(chatId: message.chat.id, locale: locale)
                    break
                }
            }
            
            var member: Member!
            
            if let contact = message.contact {
                guard let userId = contact.userId else {
                    throw ASError("User must be using telegram")
                }
                
                let user = try self.getChatMember(forUserId: userId, chatId: .chat(message.chat.id)).user
                member = try self.makeMember(by: user, contact: contact)
            }
            
            if let entities = message.entities {
                for entity in entities {
                    switch entity.type {
                    case .textMention:
                        if let user = entity.user {
                            member = try self.makeMember(by: user, contact: nil)
                        }
                    default: continue
                    }
                }
            }
            
            guard let nonOptionalMember = member else { return }
            
            self.members.append(nonOptionalMember)
            
            if self.members.count < 6 {
                try bot.sendMessage("Member added: \n \(nonOptionalMember.info(forLocale: locale)) \nMembers available \(self.members.count) / 6.", chatId: message.chat.id)
                try bot.sendMessageWithReplyKeyboard("Do you wanna add somebody else?", chatId: message.chat.id, buttons: [MemberAnswer.continue.rawValue, MemberAnswer.finish.rawValue])
            } else {
                try finishOfferMessage(chatId: message.chat.id, locale: locale)
            }
            return
        case .check:
            let text = try returnMessageIfIsNotEmptyOrNil(message)
            guard let checkAnswer = CheckAnswer(rawValue: text) else { return }
            
            switch checkAnswer {
            case .ok:
                try bot.sendMessage("Congrats! You are create your family!", chatId: message.chat.id)
                try self.saveFamily(chatId: message.chat.id)
                break
            case .cancel:
                try bot.sendMessage("Okay. You can create your family in next time, just call me using /create command. Good luck!", chatId: message.chat.id)
                self.currentStep = .cancelled
                return
            }
        case .completed:
            return
        case .cancelled:
            return
        }
        
        self.levelUpStep()
    }
    
    // MARK: - Private
    
    private func makeMember(by user: User, contact: Contact?) throws -> Member {
        
        guard let lastName = contact?.lastName ?? user.lastName else {
            throw ASError("User \(user.username.orEmpty) must have last name")
        }
        
        return try Member(id: Int(user.id),
                            firstName: contact?.firstName ?? user.firstName, lastName: lastName,
                            langCode: user.languageCode ?? "ru",
                            isOwner: user.id == self.creatorId,
                            parentId: Int(creatorId),
                            houseId: self.house.id)
    }
    
    private func returnMessageIfIsNotEmptyOrNil(_ message: Message) throws -> String {
        guard let textMessage = message.text?.trimmed, !textMessage.isEmpty else {
            throw ASError("Message can't be empty")
        }
        
        return textMessage
    }
    
    private func finishOfferMessage(chatId: Int64, locale: Locale) throws {
        
        self.currentStep = .check
        
        try bot.sendMessage("Congrats! You are fill information about your family. Please, check data and press *OK* button to finish.", chatId: chatId)
        
        let members = self.members.reduce(String()) { result, member in
            return result + member.info(forLocale: locale) + "\n"
        }
        
        let familyInfo = """
        House:
        
        \(self.house.info(forLocale: locale))
        
        Members

        \(members)
        
        It's correct?
        """
        
        try bot.sendMessageWithReplyKeyboard(familyInfo, chatId: chatId, buttons: [CheckAnswer.ok.rawValue, CheckAnswer.cancel.rawValue])
    }
    
    private func levelUpStep() {
        guard let newStep = Step(rawValue: self.currentStep.rawValue + 1) else { return }
        self.currentStep = newStep
    }
    
    private func getChatMember(forUserId userId: Int64, chatId: ChatId) throws -> ChatMember {
        let params = Bot.GetChatMemberParams(chatId: chatId, userId: userId)
        return try self.bot.getChatMember(params: params).safeWait()
    }
    
    private func getChat(username: String) throws -> Chat {
        let params = Bot.GetChatParams(chatId: .username(username))
        return try bot.getChat(params: params).safeWait()
    }
    
    private func saveFamily(chatId: Int64) throws {
        guard let houseId = self.house.id else {
            throw ASError("Can't save family, because we've a problem. Please, try again.")
        }
        
        guard !self.members.isEmpty else {
            throw ASError("You don't set are members. Please, try again.")
        }
        
        worker.requestCachedConnection(to: .sqlite).do { [weak self] connection in
            guard let `self` = self else { return }
            
            do {
                let ids: [Int] = try self.members.compactMap {
                    let savedMember = try $0.create(on: connection).safeWait()
                    return savedMember.id
                }
                
                let family = Family(chatId: Int(chatId), houseId: houseId, membersIds: Set(ids))
                _ = try family.create(on: connection).safeWait()
            } catch { try? self.bot.sendMessage("Something went wrong", chatId: chatId) }
            
            }.catch { _ in
                try? self.bot.sendMessage("Something went wrong", chatId: chatId)
        }
    }
}

extension House {
    func info(forLocale locale: Locale) -> String {
        return """
        Street name: \(self.streetName ?? "Empty")
        Street number: \(self.streetNumber.flatMap { String($0) } ?? "Empty")
        City: \(self.city ?? "Empty")
        Zip Code: \(self.zipCode.flatMap { String($0) } ?? "Empty")
        """
    }
}

extension Member {
    func info(forLocale locale: Locale) -> String {
        return """
        First name \(self.firstName)
        Last name: \(self.lastName)
        Language code: \(self.langCode)
        Is owner: \(self.isOwner ? "Yes" : "No")
        """
    }
}

extension Optional where Wrapped == String {
    var orEmpty: String {
        return self ?? String()
    }
}

extension String {
    var trimmed: String {
        return self.trimmingCharacters(in: .whitespaces)
    }
}

extension Bot {
    func sendMessage(_ message: String, chatId: Int64) throws {
        let params = SendMessageParams(chatId: .chat(chatId), text: message)
        try self.sendMessage(params: params)
    }
    
    func sendMessageWithReplyKeyboard(_ message: String, chatId: Int64, buttons buttonsTitle: [String]) throws {
        let buttons = buttonsTitle.map { KeyboardButton(text: $0) }
        let keyboard = ReplyKeyboardMarkup(keyboard: [buttons])
        let params = SendMessageParams(chatId: .chat(chatId), text: message, replyMarkup: .replyKeyboardMarkup(keyboard))
        try self.sendMessage(params: params)
    }
}

protocol Localizable {
    func lozalized(for locale: Locale) -> String
}

extension String: Localizable {
    func lozalized(for locale: Locale) -> String {
        return NSLocalizedString(self, tableName: "\(locale.languageCode.orEmpty)-localized", bundle: .main, value: self, comment: "")
    }
}

@discardableResult
public func sync<T>(block: (_ finishHandler: @escaping ResultHandler<T>) -> Void) throws -> T {
    var result: Result<T, Error> = nil
    let semaphore = DispatchSemaphore(value: 0)
    block() { blockResult in
        result = blockResult
        semaphore.signal()
    }
    semaphore.wait()
    return try result.get()
}

extension EventLoopFuture {
    func safeWait() throws -> T {
        return try sync { result in
            self.do{ value in
                    result(.success(value))
                }
                .catch { error in
                    result(.failure(error))
            }
        }
    }
}
