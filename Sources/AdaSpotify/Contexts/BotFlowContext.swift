//
//  BotFlowContext.swift
//  AdaSpotify
//
//  Created by v.a.prusakov on 19/04/2019.
//

import Foundation
import Telegrammer

protocol BotFlowContext {
    func prepare(chatId: Int64, user: User) throws
    func handleMessageForCurrentState(_ message: Message) throws
}
