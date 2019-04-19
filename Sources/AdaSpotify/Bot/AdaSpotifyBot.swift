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
    
    var familyCreateContexts: [Int64: FamilyCreateContext] = [:]
    var familyDeleteContexts: [Int64: FamilyDeleteContext] = [:]
    
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
        
        try setupHelps(dispatcher: dispatcher)
        try setupFamilyManaging(dispatcher: dispatcher)
        try setupMembers(dispatcher: dispatcher)
        try setupOthers(dispatcher: dispatcher)
        
        return dispatcher
    }
}
