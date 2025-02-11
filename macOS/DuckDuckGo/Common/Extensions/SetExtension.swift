//
//  SetExtension.swift
//
//  Copyright © 2023 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import Common

extension Set where Element == String {

    func convertedToETLDPlus1(tld: TLD) -> Set<String> {
        var transformedSet = Set<String>()
        for domain in self {
            if let eTLDPlus1Domain = tld.eTLDplus1(domain) {
                transformedSet.insert(eTLDPlus1Domain)
            }
        }
        return transformedSet
    }

}

extension Set {

    @inlinable func intersects<S: Sequence>(_ other: S) -> Bool where Element == S.Element {
        !isDisjoint(with: other)
    }

}
