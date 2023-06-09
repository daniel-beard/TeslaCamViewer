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
                .frame(minWidth: 600, minHeight: 500)
        }
        .windowResizability(.contentSize)

        .commands {
            CommandGroup(after: .newItem) {
                Button("Open") {
                    appDelegate.openDocument()
                }.keyboardShortcut("o", modifiers: [])

                Menu("Open Recent") {
                    ForEach(NSDocumentController.shared.recentDocumentURLs, id: \.self) { folderURL in
                        Button(action: {
                            appDelegate.openFolder(folder: folderURL)
                        }, label: {
                            Text(folderURL.path(percentEncoded: false))
                        })
                    }
                }
                Divider()
            }
            CommandGroup(after: .newItem) {
                Button(dataSource.playing ? "Pause" : "Play") {
                    dataSource.playing.toggle()
                }.keyboardShortcut(.space, modifiers: [])

                Button("Rewind") {
                    dataSource.restartVideo()
                }.keyboardShortcut("r", modifiers: [])

                Button("Next Video") {
                    dataSource.nextVideo()
                }.keyboardShortcut("j", modifiers: [])

                Button("Previous Video") {
                    dataSource.previousVideo()
                }.keyboardShortcut("k", modifiers: [])

                Button("Increase Playback Speed") {
                    dataSource.increasePlaybackSpeed()
                }.keyboardShortcut("l", modifiers: [])

                Button("Decrease Playback Speed") {
                    dataSource.decreasePlaybackSpeed()
                }.keyboardShortcut("h", modifiers: [])

                Divider()
            }

            CommandGroup(after: .toolbar) {
                Button(dataSource.showVideoList ? "Hide video list" : "Show video list") {
                    dataSource.showVideoList.toggle()
                }.keyboardShortcut("a", modifiers: [])

                Button(dataSource.showDebugPanel ? "Hide debug panel" : "Show debug panel") {
                    dataSource.showDebugPanel.toggle()
                }.keyboardShortcut("d", modifiers: [])

                Button(dataSource.showSlider ? "Hide progress slider" : "Show progress slider") {
                    dataSource.showSlider.toggle()
                }.keyboardShortcut("s", modifiers: [])

                Button("Toggle Video Gravity") {
                    dataSource.toggleVideoGravity()
                }.keyboardShortcut("t", modifiers: [])

                Divider()
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        SentrySDK.start { options in
            options.dsn = "https://1ba3a17b63e5492bb577d60ff002ccda@o286260.ingest.sentry.io/1518726"
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
        NotificationCenter.default.post(name: .openVideoFolder, object: folder)
    }
}

