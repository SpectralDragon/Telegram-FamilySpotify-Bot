//
//  EchoBot.swift
//  EchoBot
//
//  Created by Givi Pataridze on 31.05.2018.
//

import Foundation
import Telegrammer
import Vapor

final class EchoBot: ServiceType {
    
    let bot: Bot
    var updater: Updater?
    var dispatcher: Dispatcher?
    
    /// Dictionary for user echo modes
    var userEchoModes: [Int64: Bool] = [:]
    
    ///Conformance to `ServiceType` protocol, fabric methhod
    static func makeService(for worker: Container) throws -> EchoBot {
        guard let token = Environment.get("TELEGRAM_BOT_TOKEN") else {
            throw CoreError(identifier: "Enviroment variables", reason: "Cannot find telegram bot token")
        }
        
        let settings = Bot.Settings(token: token, debugMode: true)
    
        /// Setting up webhooks https://core.telegram.org/bots/webhooks
        /// Internal server address (Local IP), where server will starts
        // settings.webhooksIp = "127.0.0.1"
        
        /// Internal server port, must be different from Vapor port
        // settings.webhooksPort = 8181
        
        /// External endpoint for your bot server
        // settings.webhooksUrl = "https://website.com/webhooks"
        
        /// If you are using self-signed certificate, point it's filename
        // settings.webhooksPublicCert = "public.pem"
        
        return try EchoBot(settings: settings)
    }
    
    init(settings: Bot.Settings) throws {
        self.bot = try Bot(settings: settings)
        let dispatcher = try configureDispatcher()
        self.dispatcher = dispatcher
        self.updater = Updater(bot: bot, dispatcher: dispatcher)
    }
    
    /// Initializing dispatcher, object that receive updates from Updater
    /// and pass them throught handlers pipeline
    func configureDispatcher() throws -> Dispatcher {
        ///Dispatcher - handle all incoming messages
        let dispatcher = Dispatcher(bot: bot)
        
        ///Creating and adding handler for command /echo
        let commandHandler = CommandHandler(commands: ["/echo"], callback: echoModeSwitch)
        dispatcher.add(handler: commandHandler)
        
        let statusHandler = CommandHandler(commands: ["/status"], callback: self.statusHandler)
        dispatcher.add(handler: statusHandler)
        
        let chatHandler = ChatHandler(name: "ChatHandler", options: [.userDidLeft, .newUsersAdded], callback: self.userHandler)
        dispatcher.add(handler: chatHandler)
        
        ///Creating and adding handler for ordinary text messages
        let echoHandler = MessageHandler(filters: Filters.text, callback: echoResponse)
        dispatcher.add(handler: echoHandler)
        
        return dispatcher
    }
}

extension EchoBot {
    
    func botAddedHandler(_ update: Update, _ context: BotContext?) throws {
        
    }
    
    func userHandler(_ result: ChatHandler.Result, _ update: Update) throws {
        switch result {
        case .newUsersAdded(let members):
            return
        case .userDidLeft(let user):
            return
        }
    }
    
    func statusHandler(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from else { return }
        
        let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: "You stats:")
        try bot.sendMessage(params: params)
    }
    
    ///Callback for Command handler, which send Echo mode status for user
    func echoModeSwitch(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from else { return }
        
        var onText = ""
        if let on = userEchoModes[user.id] {
            onText = on ? "OFF" : "ON"
            userEchoModes[user.id] = !on
        } else {
            onText = "ON"
            userEchoModes[user.id] = true
        }
        
        let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: "Echo mode turned \(onText)")
        try bot.sendMessage(params: params)
    }
    
    ///Callback for Message handler, which send echo message to user
    func echoResponse(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from,
            let on = userEchoModes[user.id],
            on == true else { return }
        let params = Bot.SendMessageParams(chatId: .chat(message.chat.id), text: message.text!)
        try bot.sendMessage(params: params)
    }
}

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
