//
//  Utils.swift
//  TeslaCamViewer
//
//  Created by Daniel Beard on 5/19/19.
//  Copyright © 2019 dbeard. All rights reserved.
//

import AppKit

// Constants
extension Notification.Name {
    static let openVideoFolder = NSNotification.Name(rawValue: "OpenVideoFolder")
}

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

// Callback is invoked with true when the user opts to remove videos.
func dialogRemoveVideos(countOfItems: Int, window: NSWindow, result: @escaping (Bool) -> Void) {
    let a = NSAlert()
    a.messageText = "Delete all loaded videos?"
    a.informativeText = "Are you sure you would like to delete the currently loaded videos?"
    a.addButton(withTitle: "Delete \(countOfItems) Videos")
    a.addButton(withTitle: "Cancel")
    a.alertStyle = .warning
    a.beginSheetModal(for: window) { (response) in
        result(response == NSApplication.ModalResponse.alertFirstButtonReturn)
    }
}


