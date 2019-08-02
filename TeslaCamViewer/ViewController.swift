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

    var leftAVPlayer: AVQueuePlayer?
    var centerAVPlayer: AVQueuePlayer?
    var rightAVPlayer: AVQueuePlayer?
    var avPlayers = [AVQueuePlayer]()

    var timeObserver: Any?
    var progress: Double = 0.0
//    var currVideoIndex: Int = 0

    //MARK: Reactive properties

    var videos: DataSource? {
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
        self.videos = notification.object as? DataSource
        if let videos = self.videos,
            let date = videos.videoDictionary.keys.sorted().first,
            let firstVideo = videos.videoDictionary[date] {
            setVideoPlayers(to: firstVideo, playAutomatically: false)
        }
    }

    func updateVideoWindowTitle() {
        guard let videoCount = videos?.videoDictionary.keys.count else {
            self.title = "No videos loaded"
            return
        }
        self.title = "Video \(videos?.currentIndex ?? 0 + 1)/\((videoCount))"
    }

    func firstNonNilAVPlayer() -> AVQueuePlayer? {
        var first = avPlayers.first(where: {
            $0.currentItem != nil &&
            ($0.currentItem?.duration.seconds ?? 0) > 1.0
        })
        if first == nil {
            first = avPlayers.first(where: { $0.currentItem != nil })
        }
        return first
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
        firstNonNilAVPlayer()?.removeObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem))

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

        guard let videos = videos else { return }

        let currentProgress = self.progress
//
//        // Try loading from cache here in the background, so we can try to load faster.
//        if currentProgress >= 30 && !isPreloadingFlag {
//
//            // Figure out next viedoes, if they exist, then set the preload avplayers.
//            // next video, if we have one
//            if currVideoIndex < (videos?.videoDictionary.keys.count ?? 0) - 1 {
//                isPreloadingFlag = true
//                let tmpCurrVideoIndex = currVideoIndex + 1
//                let keys = self.videos?.videoDictionary.keys.sorted()
//                let nextKey = keys?[tmpCurrVideoIndex]
//                let nextVideo = self.videos?.videoDictionary[nextKey!]!
//
//                self.preloadAVPlayers = preloadPlayers(for: nextVideo!)
//            }
//
//        }

        if currentProgress >= 100 {

            let savedIsPlaying = isPlaying

            resetQueuedVideos(index: videos.currentIndex + 1, count: 1)
            if savedIsPlaying {
                play()
            }

//            // Play next video, if we have one
//            if currVideoIndex < (videos?.videoDictionary.keys.count ?? 0) - 1 {
//                print("Boom")
//
//                currVideoIndex += 1
//                let keys = self.videos?.videoDictionary.keys.sorted()
//                let nextKey = keys?[currVideoIndex]
//                let nextVideo = self.videos?.videoDictionary[nextKey!]!
//                setVideoPlayers(to: nextVideo!, playAutomatically: true)
//                tableView.selectRowIndexes(IndexSet(integer: currVideoIndex), byExtendingSelection: false)
//            } else {
//                // tear down polling timers
//                tearDownTimersAndObservers()
//                removeAllLoadedVideos(nil)
//            }
        }
    }

    func resetQueuedVideos(index: Int, count: Int) {
        guard let videos = videos else { return }

        // Remove everything from current playlist queue
        avPlayers.forEach { $0.removeAllItems() }

        // Set next video immediately
        let tuple = videos.videoQueue(startIndex: index, count: 1)
        let (leftVideos, centerVideos, rightVideos) = tuple

        for leftVideo in leftVideos {
            leftAVPlayer?.insert(leftVideo, after: nil)
        }
        for centerVideo in centerVideos {
            centerAVPlayer?.insert(centerVideo, after: nil)
        }
        for rightVideo in rightVideos {
            rightAVPlayer?.insert(rightVideo, after: nil)
        }

        videos.currentIndex = index
    }

    func appendVideosToQueueIfWeHaveThem() {
        guard let videos = videos else { return }
        guard let lastLoadedAsset = firstNonNilAVPlayer()?.items().last else { return }
        guard let currMaxIndex = videos.indexFromAVPlayerItem(item: lastLoadedAsset) else { return }

        let nextIndex = currMaxIndex + 1

        print("Loading next 2 videos from cache at index \(nextIndex)")

        let tuple = videos.videoQueue(startIndex: nextIndex, count: 1)
        let (leftVideos, centerVideos, rightVideos) = tuple

        for leftVideo in leftVideos {
            leftAVPlayer?.insert(leftVideo, after: nil)
        }
        for centerVideo in centerVideos {
            centerAVPlayer?.insert(centerVideo, after: nil)
        }
        for rightVideo in rightVideos {
            rightAVPlayer?.insert(rightVideo, after: nil)
        }
    }

    func setVideoPlayers(to video: [TeslaCamVideo], playAutomatically: Bool) {

        progress = 0

        // remove any previous time observers if we had 'em
        tearDownTimersAndObservers()

        updateVideoWindowTitle()

        guard let videoQueueTuple = videos?.videoQueue(startIndex: 50, count: 4) else { return }
        videos?.currentIndex = 0
        let (leftVideos, centerVideos, rightVideos) = videoQueueTuple
        leftAVPlayer = AVQueuePlayer(items: leftVideos)
        centerAVPlayer = AVQueuePlayer(items: centerVideos)
        rightAVPlayer = AVQueuePlayer(items: rightVideos)

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
        firstNonNilAVPlayer()?.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem), options: [.initial, .new], context: nil)

        DispatchQueue.main.async {
            if playAutomatically { self.play() }
        }
    }

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async {
            guard let keyPath = keyPath else { return }
            switch keyPath {
            case #keyPath(AVPlayer.status):
                self.playerStatusChanged(player: object as? AVQueuePlayer)
            case #keyPath(AVPlayer.rate):
                self.updatePlayingState(player: object as? AVQueuePlayer)
            case #keyPath(AVPlayer.currentItem):
                self.playerItemChanged(player: object as? AVQueuePlayer)
            default:
                super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            }
        }
    }
}

// MARK: Utils

extension ViewController {
    func resetUIToInitialState() {
        tearDownTimersAndObservers()
        self.progress = 0
        self.videos = nil
        self.avPlayers.removeAll()
        self.leftAVPlayer = nil
        self.centerAVPlayer = nil
        self.rightAVPlayer = nil
        self.avPlayerViews.removeAll()
        self.leftPlayerView.player = nil
        self.centerPlayerView.player = nil
        self.rightPlayerView.player = nil
//        self.preloadAVPlayers.removeAll()
//        self.preloadLeftAVPlayer = nil
//        self.preloadCenterAVPlayer = nil
//        self.preloadRightAVPlayer = nil
//        self.isPreloadingFlag = false
        //TODO: Fixme
//        self.currVideoIndex = 0
        self.progressSlider.doubleValue = 0
        self.updateVideoWindowTitle()
    }
}

// MARK: Observers

extension ViewController {

    func playerItemChanged(player: AVQueuePlayer?) {
        guard let player = player else { return }
        guard let videos = videos else { return }

        // Update datasource, tableView indexes
        if let currentAsset = player.currentItem, let currIndex = videos.indexFromAVPlayerItem(item: currentAsset) {
            videos.currentIndex = currIndex
            tableView.selectRowIndexes(IndexSet(integer: currIndex), byExtendingSelection: false)
        }

        appendVideosToQueueIfWeHaveThem()

        if player.currentItem == nil {
            appendVideosToQueueIfWeHaveThem()
            print("Got to end of queue")
        } else {
            print("Player item changed.")
        }

    }

    func playerStatusChanged(player: AVQueuePlayer?) {
        guard let player = player else { return }
        switch player.status {
        case .readyToPlay:
            if isPlaying {
                player.rate = self.playbackRate
            }
        default: break
        }
    }

    func updatePlayingState(player: AVQueuePlayer?) {
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

    @IBAction func removeAllLoadedVideos(_ sender: Any?) {

        guard let videos = videos, videos.videoDictionary.keys.count > 0 else {
            let _ = dialogOK(
                messageText: "No videos currently loaded.",
                infoText: "Can not remove videos"
            )
            return
        }

        dialogRemoveVideos(countOfItems: videos.allAngleVideoCount(), window: self.view.window!) { [weak self] (shouldRemoveVideos) in
            guard shouldRemoveVideos == true else { return }
            videos.removeAllLoadedVideos {
                DispatchQueue.main.async {
                    self?.resetUIToInitialState()
                    print("Done removing videos!")
                }
            }
        }
    }
}

// Mark: Table View Support

extension ViewController {
    @objc func tableViewDoubleClick(_ sender:AnyObject) {
        guard tableView.selectedRow >= 0 else {
                return
        }
        guard let videos = videos else { return }

        resetQueuedVideos(index: tableView.selectedRow, count: 1)
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

