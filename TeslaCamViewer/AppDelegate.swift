//
//  AppDelegate.swift
//  TeslaCamViewer
//
//  Created by Daniel Beard on 5/5/19.
//  Copyright © 2019 dbeard. All rights reserved.
//

import Cocoa
import Sentry
import SwiftUI

@main
struct TeslaCamViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject var dataSource = VideoDataSource()

    var body: some Scene {
        WindowGroup {
            MainView(dataSource: .constant(dataSource))
        }.commands {
            CommandGroup(after: CommandGroupPlacement.newItem) {
                Button("Open") {
                    appDelegate.openDocument()
                }.keyboardShortcut("o", modifiers: [])
            }
            CommandGroup(after: CommandGroupPlacement.newItem) {
                Button(dataSource.playing ? "Pause" : "Play") {
                    dataSource.playing.toggle()
                }.keyboardShortcut(.space, modifiers: [])

                Button("Rewind") {
                    dataSource.seek(toPercentage: 0)
                }.keyboardShortcut("r", modifiers: [])

                Button("Next Video") {
                    dataSource.nextVideo()
                }.keyboardShortcut("j", modifiers: [])

                Button("Previous Video") {
                    dataSource.previousVideo()
                }.keyboardShortcut("k", modifiers: [])

                Button("Toggle Video Gravity") {
                    dataSource.toggleVideoGravity()
                }.keyboardShortcut("t", modifiers: [])

                Button("Increase Playback Speed") {
                    dataSource.increasePlaybackSpeed()
                }.keyboardShortcut("l", modifiers: [])

                Button("Decrease Playback Speed") {
                    dataSource.decreasePlaybackSpeed()
                }.keyboardShortcut("h", modifiers: [])
            }

            CommandGroup(after: CommandGroupPlacement.newItem) {
                Button(dataSource.showVideoList ? "Hide video list" : "Show video list") {
                    dataSource.showVideoList.toggle()
                }.keyboardShortcut("a", modifiers: [])

                Button(dataSource.showDebugPanel ? "Hide debug panel" : "Show debug panel") {
                    dataSource.showDebugPanel.toggle()
                }.keyboardShortcut("d", modifiers: [])

                Button(dataSource.showSlider ? "Hide progress slider" : "Show progress slider") {
                    dataSource.showSlider.toggle()
                }.keyboardShortcut("s", modifiers: [])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        SentrySDK.start { options in
            options.dsn = "https://1ba3a17b63e5492bb577d60ff002ccda@o286260.ingest.sentry.io/1518726"
            // options.debug = true
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        openFolder(folder: urls.first!)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func openDocument() {
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

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        openFolder(folder: url)
        return true
    }

    func openFolder(folder: URL) {
        // Notify the data source
        NotificationCenter.default.post(name: .openVideoFolder, object: folder)
        // Mark as recently opened
        NSDocumentController.shared.noteNewRecentDocumentURL(folder)
    }
}

