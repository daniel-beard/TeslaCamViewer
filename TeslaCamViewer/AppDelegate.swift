//
//  AppDelegate.swift
//  TeslaCamViewer
//
//  Created by Daniel Beard on 5/5/19.
//  Copyright © 2019 dbeard. All rights reserved.
//

import Cocoa
import Sentry

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        // Crash reporting setup
        do {
            Client.shared = try Client(dsn: "https://1ba3a17b63e5492bb577d60ff002ccda@sentry.io/1518726")
            try Client.shared?.startCrashHandler()
        } catch let error {
            print("\(error)")
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        openFolder(folder: urls.first!)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    @IBAction func openDocument(_ sender: Any?) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = false
        openPanel.begin { (result) -> Void in
            if result == NSApplication.ModalResponse.OK {
                guard let openedURL = openPanel.url else { return }
                self.openFolder(folder: openedURL)
            }
        }
    }

    func openFolder(folder: URL) {
        let directoryCrawler = DataSource(fileURL: folder)
        if directoryCrawler.hasVideos {
            // Notify our controller.
            NotificationCenter.default.post(name: didOpenVideoNotification,
                                            object: directoryCrawler)
            // Mark as recently opened
            NSDocumentController.shared.noteNewRecentDocumentURL(folder)
        } else {
            let _ = dialogOK(messageText: "Could not find any tesla cam videos in selected folder",
                             infoText: "Try opening a different folder")
        }
    }
}

