//
//  sync.swift
//  AdaSpotify
//
//  Created by v.a.prusakov on 17/04/2019.
//

import Foundation

@discardableResult
public func sync<T>(block: (_ finishHandler: @escaping ResultHandler<T>) throws -> Void) throws -> T {
    var result: Result<T, Error> = nil
    let semaphore = DispatchSemaphore(value: 0)
    try block() { blockResult in
        result = blockResult
        semaphore.signal()
    }
    semaphore.wait()
    return try result.get()
}
