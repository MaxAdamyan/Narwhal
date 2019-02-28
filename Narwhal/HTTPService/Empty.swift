//
//  Empty.swift
//  Narwhal
//
//  Created by Max Adamyan on 3/1/19.
//

import Foundation
import ObjectMapper

public enum Empty {}

extension Empty: Mappable {
    public init?(map: Map) { return nil }
    mutating public func mapping(map: Map) { }
}
