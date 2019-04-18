//
//  Result.swift
//  AdaSpotify
//
//  Created by v.a.prusakov on 17/04/2019.
//

import Foundation


public typealias ResultHandler<T> = (Result<T, Error>) -> Void

// MARK: - Nil initialization

extension Result: ExpressibleByNilLiteral where Failure == Error {
    public init(nilLiteral: ()) {
        self = .failure(NSError(domain: "\(Result.self)", code: 404, userInfo: [NSLocalizedDescriptionKey: "Result was initialized with 'nil' and wasn't mutated"]))
    }
}
