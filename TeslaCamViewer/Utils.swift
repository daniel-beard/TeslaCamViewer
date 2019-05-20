//
//  Utils.swift
//  TeslaCamViewer
//
//  Created by Daniel Beard on 5/19/19.
//  Copyright © 2019 dbeard. All rights reserved.
//

import AppKit

// Constants
let didOpenVideoNotification = NSNotification.Name(rawValue: "DidOpenVideoFolder")

func dialogOKCancel(question: String, text: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = question
    alert.informativeText = text
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    return alert.runModal() == .alertFirstButtonReturn
}

func dialogOK(messageText: String, infoText: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = messageText
    alert.informativeText = infoText
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    return alert.runModal() == .alertFirstButtonReturn
}


