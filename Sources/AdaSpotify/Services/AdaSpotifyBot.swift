//
//  AdaSpotifyBot.swift
//  AdaSpotifyBot
//
//  Created by Vladislav Prusakov on 12.04.2019.
//

import Foundation
import Telegrammer
import Vapor
import FluentSQLite

final class AdaSpotifyBot: ServiceType {
    
    let bot: Bot
    let worker: Container
    var updater: Updater?
    var dispatcher: Dispatcher?
    
    /// Dictionary for user echo modes
    var userEchoModes: [Int64: Bool] = [:]
    
    var familyContexts: [Int64: FamilyCreateContext] = [:]
    
    ///Conformance to `ServiceType` protocol, fabric methhod
    static func makeService(for worker: Container) throws -> AdaSpotifyBot {
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
        
        return try AdaSpotifyBot(settings: settings, worker: worker)
    }
    
    init(settings: Bot.Settings, worker: Container) throws {
        self.bot = try Bot(settings: settings)
        self.worker = worker
        let dispatcher = try configureDispatcher()
        self.dispatcher = dispatcher
        self.updater = Updater(bot: bot, dispatcher: dispatcher)
    }
    
    /// Initializing dispatcher, object that receive updates from Updater
    /// and pass them throught handlers pipeline
    func configureDispatcher() throws -> Dispatcher {
        ///Dispatcher - handle all incoming messages
        
        let dispatcher = Dispatcher(bot: bot)
        
        // Others
        
        let helpHandler = CommandHandler(commands: ["/start", "/help"], callback: self.helpHandler)
        dispatcher.add(handler: helpHandler)
        
        let statusHandler = CommandHandler(commands: ["/status"], callback: self.statusHandler)
        dispatcher.add(handler: statusHandler)
        
//        let chatHandler = ChatHandler(name: "ChatHandler", options: [.userDidLeft, .newUsersAdded], callback: self.userHandler)
//        dispatcher.add(handler: chatHandler)
        
        // Family
        
        let createFamilyHandler = CommandHandler(commands: ["/create"], callback: self.createFamily)
        dispatcher.add(handler: createFamilyHandler)
        
        let familyCreateContextHandlers = [MessageHandler(filters: Filters.text, callback: createFamilyContextResponse),
                                           MessageHandler(filters: Filters.contact, callback: createFamilyContextResponse),
                                           MessageHandler(filters: Filters.entity(types: [.mention, .textMention]), callback: createFamilyContextResponse)]
        familyCreateContextHandlers.forEach { dispatcher.add(handler: $0) }
        
        return dispatcher
    }
}

extension AdaSpotifyBot {
    
    func userHandler(_ result: ChatHandler.Result, _ update: Update) throws {
        switch result {
        case .newUsersAdded(let members):
            return
        case .userDidLeft(let user):
            return
        }
    }
    
    func helpHandler(_ update: Update, _ context: BotContext?) throws {
        
        guard let message = update.message, let user = message.from else { return }
        
        let identifier = DatabaseIdentifier<SQLiteDatabase>(UUID().uuidString)
        let connection = try worker.requestPooledConnection(to: identifier).syncResolve()
        let query = Family.query(on: connection)
            .join(\Family.memberIds, to: \Member.id)
            .alsoDecode(Member.self)
        let filters = query.filter(\Member.id == Int(user.id))
        
        try worker.releasePooledConnection(connection, to: identifier)
        
        var userIsOwner: Bool = false
        
        if let response = try filters.first().syncResolve() {
            userIsOwner = response.0.chatId == Int(message.chat.id) && response.1.isOwner
        }
        
        let ownerPart = """
        For owners:
        
        Remove family: /remove_family
        Add new member: /add_member
        Delete member: /delete_member
        Set monthly price: /set_pay - price will devide only 5 members
        """
        
        let help = """
        Welcome to Ada Spotify Family Bot.

        Ada can help you manage your subscription and paayments using telegram.
        You don't need access to Spotify, only chat with members in your family.

        If you wanna create your family sent me: /create
        \(userIsOwner ? "\n\(ownerPart)\n" : "")
        For members:
        
        Get status of debt and info about home: /status
        Pay now: /pay

        Good luck and have a nice playlists!
        """
        
        try bot.sendMessage(help, chatId: message.chat.id)
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
    
    // MARK: - Family
    
    func createFamily(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from else { return }
        
        let context = FamilyCreateContext(worker: self.worker, bot: self.bot, creatorId: user.id)
        self.familyContexts[user.id] = context
        
        try bot.sendMessage("Welcome to family creation mode. Please, sent me family street address from you Spotify", chatId: message.chat.id)
    }
    
    func createFamilyContextResponse(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message,
            let user = message.from,
            let familyContext = self.familyContexts[user.id] else { return }
        
        do {
            try familyContext.handleMessageForCurrentState(message)
        } catch {
            try bot.sendMessage(error.localizedDescription, chatId: message.chat.id)
            throw error
        }
        
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
