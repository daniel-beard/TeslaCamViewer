//
//  VideoNameMatching.swift
//  TeslaCamViewer
//
//  Created by Daniel Beard on 5/17/23.
//  Copyright © 2023 dbeard. All rights reserved.
//

import Foundation
import RegexBuilder

struct NameComponents: Equatable {
    var canonicalName: String
    var dateTime:      String
    var cameraAngle:   String
}

func components(forVideoURL videoURL: URL) -> NameComponents? {
    // Group1: DateTime match
    // Group2: Date match
    // Group3: Time match
    // Group4: CameraAngle match
    let nameRegex = /((\d{4}-\d{2}-\d{2})_(\d{2}-\d{2}-\d{2}))-(\w+).mp4/
    let fileName = videoURL.lastPathComponent

    guard let match = fileName.firstMatch(of: nameRegex) else {
        return nil
    }

    let dateTime = String(match.1)
    let canonicalName = "\(dateTime).mp4"

    return NameComponents(
        canonicalName: canonicalName,
        dateTime:      dateTime,
        cameraAngle:   String(match.4)
    )
}
