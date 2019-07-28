//
//  ViewController.swift
//  TeslaCamViewer
//
//  Created by Daniel Beard on 5/5/19.
//  Copyright © 2019 dbeard. All rights reserved.
//

import Cocoa
import AVKit

class ViewController: NSViewController {

    @IBOutlet weak var tableView: NSTableView!

    //MARK: Player support
    @IBOutlet weak var leftPlayerView: AVPlayerView!
    @IBOutlet weak var centerPlayerView: AVPlayerView!
    @IBOutlet weak var rightPlayerView: AVPlayerView!
    var avPlayerViews = [AVPlayerView]()

    var leftAVPlayer: AVPlayer?
    var centerAVPlayer: AVPlayer?
    var rightAVPlayer: AVPlayer?
    var avPlayers = [AVPlayer]()

    var timeObserver: Any?
    var progress: Double = 0.0
    var currVideoIndex: Int = 0

    //MARK: Reactive properties

    var videos: DirectoryCrawler? {
        didSet {
            tableView.reloadData()
        }
    }

    var isPlaying: Bool {
        return firstNonNilAVPlayer()?.rate ?? 0 != 0
    }

    var playbackRate: Float = 1.0 {
        didSet {
            if isPlaying {
                avPlayers.forEach({
                    $0.rate = playbackRate
                })
            }
        }
    }

    override var title: String? {
        didSet {
            self.view.window?.title = title ?? ""
        }
    }

    //MARK: UI
    @IBOutlet weak var playButton: NSButton!
    @IBOutlet weak var speedSegmentControl: NSSegmentedControl!
    @IBOutlet weak var progressSlider: NSSlider!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Table View setup
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClick(_:))


        // setup player control styles
        leftPlayerView.controlsStyle = .none
        centerPlayerView.controlsStyle = .none
        rightPlayerView.controlsStyle = .none

        // setup slider action
        progressSlider.target = self
        progressSlider.action = #selector(sliderDidMove(slider:))

        // Notifications
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didOpenVideoFolder(notification:)),
                                               name: didOpenVideoNotification,
                                               object: nil)

        // Setup video players
        if let videos = self.videos,
            let date = videos.videoDictionary.keys.sorted().first,
            let firstVideo = videos.videoDictionary[date] {
                setVideoPlayers(to: firstVideo, playAutomatically: false)
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updateVideoWindowTitle()
    }

    @objc func didOpenVideoFolder(notification: Notification) {
        self.videos = notification.object as? DirectoryCrawler
        if let videos = self.videos,
            let date = videos.videoDictionary.keys.sorted().first,
            let firstVideo = videos.videoDictionary[date] {
            setVideoPlayers(to: firstVideo, playAutomatically: false)
        }
    }

    func updateVideoWindowTitle() {
        self.title = "Video \(currVideoIndex + 1)/\((videos?.videoDictionary.keys.count ?? 0))"
    }

    func firstNonNilAVPlayer() -> AVPlayer? {
        return avPlayers.first(where: { $0.currentItem != nil })
    }

    // Adds a time observer for updating the progress bar
    func timeObserver(for player: AVPlayer) -> Any {
        // Invoke callback every half second
        let interval = CMTime(seconds: 0.5,
                              preferredTimescale: 9000)
        // Add time observer
        let timeObserverToken =
            player.addPeriodicTimeObserver(forInterval: interval, queue: nil) {
                [weak self] time in

                guard let self = self else { return }

                guard let duration = player.currentItem?.duration else {
                    self.progress = 0.0
                    return
                }
                self.progress = player.currentTime().seconds / duration.seconds * 100

                self.refreshProgressBar()
                self.pollCheckForEndOfVideo()
        }
        return timeObserverToken
    }

    func tearDownTimersAndObservers() {

        if let timeObserver = timeObserver {
            firstNonNilAVPlayer()?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

        firstNonNilAVPlayer()?.removeObserver(self, forKeyPath: #keyPath(AVPlayer.status))
        firstNonNilAVPlayer()?.removeObserver(self, forKeyPath: #keyPath(AVPlayer.rate))

        avPlayers = []
        leftAVPlayer = nil
        centerAVPlayer = nil
        rightAVPlayer = nil
        leftPlayerView.player = nil
        centerPlayerView.player = nil
        rightPlayerView.player = nil
    }

    func refreshProgressBar() {
        self.progressSlider.doubleValue = self.progress
    }

    func askToDeleteSeenVideos() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Do you want to delete all seen videos?"
        alert.informativeText = "This will delete the stuff you loaded yo."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Delete Videos")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    // Calculates if the sentinel video has ended.
    // move on to the next video in our list, if we've got one
    func pollCheckForEndOfVideo() {
        let currentProgress = self.progress
        if currentProgress >= 100 {

            // Play next video, if we have one
            if currVideoIndex < (videos?.videoDictionary.keys.count ?? 0) - 1 {
                print("Boom")

                currVideoIndex += 1
                let keys = self.videos?.videoDictionary.keys.sorted()
                let nextKey = keys?[currVideoIndex]
                let nextVideo = self.videos?.videoDictionary[nextKey!]!
                setVideoPlayers(to: nextVideo!, playAutomatically: true)
                tableView.selectRowIndexes(IndexSet(integer: currVideoIndex), byExtendingSelection: false)
            } else {
                // tear down polling timers
                tearDownTimersAndObservers()
                let shouldDeleteSeenVideos = askToDeleteSeenVideos()
                if shouldDeleteSeenVideos {
                    print("Deleting videos now")
                }
            }
        }
    }

    func setVideoPlayers(to video: [TeslaCamVideo], playAutomatically: Bool) {

        progress = 0

        let leftVideo = video.first(where: { $0.cameraType == .left })
        let centerVideo = video.first(where: { $0.cameraType == .front })
        let rightVideo = video.first(where: { $0.cameraType == .right })

        // remove any previous time observers if we had 'em
        tearDownTimersAndObservers()

        updateVideoWindowTitle()

        // Load the videos into AVPlayers
        leftAVPlayer = AVPlayer(url: leftVideo?.fileURL ?? URL(fileURLWithPath: ""))
        centerAVPlayer = AVPlayer(url: centerVideo?.fileURL ?? URL(fileURLWithPath: ""))
        rightAVPlayer = AVPlayer(url: rightVideo?.fileURL ?? URL(fileURLWithPath: ""))

        // Load into player views
        self.leftPlayerView.player = leftAVPlayer
        self.centerPlayerView.player = centerAVPlayer
        self.rightPlayerView.player = rightAVPlayer
        avPlayers = [leftAVPlayer!, centerAVPlayer!, rightAVPlayer!]
        avPlayerViews = [leftPlayerView!, centerPlayerView!, rightPlayerView!]

        // Set resize behavior
        avPlayerViews.forEach { $0.videoGravity = .resizeAspectFill }

        // Setup observers
        timeObserver = timeObserver(for: firstNonNilAVPlayer()!)
        firstNonNilAVPlayer()?.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.initial, .new], context: nil)
        firstNonNilAVPlayer()?.addObserver(self, forKeyPath: #keyPath(AVPlayer.rate), options: [.initial, .new], context: nil)

        DispatchQueue.main.async {
            if playAutomatically { self.play() }
        }
    }

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async {
            guard let keyPath = keyPath else { return }
            switch keyPath {
            case #keyPath(AVPlayer.status):
                self.playerStatusChanged(player: object as? AVPlayer)
            case #keyPath(AVPlayer.rate):
                self.updatePlayingState(player: object as? AVPlayer)
            default:
                super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            }
        }
    }
}

// MARK: Observers

extension ViewController {
    func playerStatusChanged(player: AVPlayer?) {
        guard let player = player else { return }
        switch player.status {
        case .readyToPlay:
            if isPlaying {
                player.rate = self.playbackRate
            }
        default: break
        }
    }

    func updatePlayingState(player: AVPlayer?) {
        guard let player = player else { return }
        self.playButton.title = !player.rate.isZero ? "\u{f04c}" : "\u{f04b}"

        // Debug only
        print("Player state did change to: \(player.rate.isZero ? "paused" : "playing") - \(player)")

        // Sync other players
        avPlayers.forEach {
            guard $0 != player else { return }
            $0.rate = player.rate
        }
    }
}

//MARK: AVPlayer Functions

extension ViewController {

    func play() {
        firstNonNilAVPlayer()?.play()
        firstNonNilAVPlayer()?.rate = playbackRate
    }

    func pause() {
        firstNonNilAVPlayer()?.pause()
    }

    func seek(toPercentage percentage: Double) {
        let duration = firstNonNilAVPlayer()?.currentItem?.duration.seconds ?? 0
        let seekTime = duration * (percentage / 100)
        let cmTime = CMTimeMakeWithSeconds(Float64(Float(seekTime)), preferredTimescale: 9000)
        avPlayers.forEach { $0.seek(to: cmTime) }
    }
}

//MARK: IBActions

extension ViewController {

    @objc func sliderDidMove(slider: NSSlider) {
        seek(toPercentage: slider.doubleValue)
    }

    @IBAction func playButtonWasTapped(_ sender: NSButton) {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    @IBAction func playbackSpeedControlTapped(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0: playbackRate = 1
        case 1: playbackRate = 2
        case 2: playbackRate = 5
        case 3: playbackRate = 10
        case 4: playbackRate = 20
        default: break
        }
    }
}

// Mark: Table View Support

extension ViewController {
    @objc func tableViewDoubleClick(_ sender:AnyObject) {
        guard tableView.selectedRow >= 0 else {
                return
        }
        guard let videoDict = videos?.videoDictionary else { return }
        let sortedKeys = videoDict.keys.sorted()
        let rowIndex = sortedKeys[tableView.selectedRow]
        currVideoIndex = tableView.selectedRow
        guard let nextVideo = videoDict[rowIndex] else { return }
        setVideoPlayers(to: nextVideo, playAutomatically: true)
    }
}

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return videos?.videoDictionary.keys.count ?? 0
    }
}

extension ViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        var text: String = ""
        var cellIdentifier: String = ""
        guard let videoDict = videos?.videoDictionary else { return nil }
        let sortedKeys = videoDict.keys.sorted()
        let rowIndex = sortedKeys[row]

        guard let item = videoDict[rowIndex] else {
            return nil
        }

        if tableColumn == tableView.tableColumns[0] {
            text = item.first?.genericFileName() ?? ""
            cellIdentifier = "VideoCellID"
        }

        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }
        return nil
    }
}

