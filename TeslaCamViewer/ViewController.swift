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
    @IBOutlet weak var backPlayerView: AVPlayerView!
    var avPlayerViews = [AVPlayerView]()

    var leftAVPlayer: AVPlayer?
    var centerAVPlayer: AVPlayer?
    var rightAVPlayer: AVPlayer?
    var backAVPlayer: AVPlayer?
    var avPlayers = [AVPlayer]()

    //TODO: All this proeloading feels like it should be extracted out into a helper.
    // Find the commit that introduced this message.
    var isPreloadingFlag: Bool = false
    var preloadLeftAVPlayer: AVPlayer?
    var preloadCenterAVPlayer: AVPlayer?
    var preloadRightAVPlayer: AVPlayer?
    var preloadBackAVPlayer: AVPlayer?
    var preloadAVPlayers = [AVPlayer]() //not sure if I'll need this.

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
        backPlayerView.controlsStyle = .none

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
        guard let videoCount = videos?.videoDictionary.keys.count else {
            self.title = "No videos loaded"
            return
        }
        self.title = "Video \(currVideoIndex + 1)/\((videoCount))"
    }

    func firstNonNilAVPlayer() -> AVPlayer? {
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

        avPlayers = []
        leftAVPlayer = nil
        centerAVPlayer = nil
        rightAVPlayer = nil
        backAVPlayer = nil
        leftPlayerView.player = nil
        centerPlayerView.player = nil
        rightPlayerView.player = nil
        backPlayerView.player = nil
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

        // Try loading from cache here in the background, so we can try to load faster.
        if currentProgress >= 30 && !isPreloadingFlag {

            // Figure out next viedoes, if they exist, then set the preload avplayers.
            // next video, if we have one
            if currVideoIndex < (videos?.videoDictionary.keys.count ?? 0) - 1 {
                isPreloadingFlag = true
                let tmpCurrVideoIndex = currVideoIndex + 1
                let keys = self.videos?.videoDictionary.keys.sorted()
                let nextKey = keys?[tmpCurrVideoIndex]
                let nextVideo = self.videos?.videoDictionary[nextKey!]!

                self.preloadAVPlayers = preloadPlayers(for: nextVideo!)
            }

        }

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
                removeAllLoadedVideos(nil)
            }
        }
    }

    func preloadPlayers(for video: [TeslaCamVideo]) -> [AVPlayer] {

        let leftVideo = video.first(where: { $0.cameraType == .left })
        let centerVideo = video.first(where: { $0.cameraType == .front })
        let rightVideo = video.first(where: { $0.cameraType == .right })
        let backVideo = video.first(where: { $0.cameraType == .back })

        // Load the videos into AVPlayers
        preloadLeftAVPlayer = AVPlayer(url: leftVideo?.fileURL ?? URL(fileURLWithPath: ""))
        preloadCenterAVPlayer = AVPlayer(url: centerVideo?.fileURL ?? URL(fileURLWithPath: ""))
        preloadRightAVPlayer = AVPlayer(url: rightVideo?.fileURL ?? URL(fileURLWithPath: ""))
        preloadBackAVPlayer = AVPlayer(url: backVideo?.fileURL ?? URL(fileURLWithPath: ""))

        return [preloadLeftAVPlayer!, preloadCenterAVPlayer!, preloadRightAVPlayer!, preloadBackAVPlayer!]
    }

    func setVideoPlayers(to video: [TeslaCamVideo], playAutomatically: Bool) {

        progress = 0

        // remove any previous time observers if we had 'em
        tearDownTimersAndObservers()

        updateVideoWindowTitle()

        if preloadAVPlayers.count > 0 {
            leftAVPlayer = preloadLeftAVPlayer
            centerAVPlayer = preloadCenterAVPlayer
            rightAVPlayer = preloadRightAVPlayer
            backAVPlayer = preloadBackAVPlayer

            preloadLeftAVPlayer = nil
            preloadCenterAVPlayer = nil
            preloadRightAVPlayer = nil
            preloadBackAVPlayer = nil
            preloadAVPlayers.removeAll()

            isPreloadingFlag = false
        } else {

            let leftVideo = video.first(where: { $0.cameraType == .left })
            let centerVideo = video.first(where: { $0.cameraType == .front })
            let rightVideo = video.first(where: { $0.cameraType == .right })
            let backVideo = video.first(where: { $0.cameraType == .back })

            // Load the videos into AVPlayers
            leftAVPlayer = AVPlayer(url: leftVideo?.fileURL ?? URL(fileURLWithPath: ""))
            centerAVPlayer = AVPlayer(url: centerVideo?.fileURL ?? URL(fileURLWithPath: ""))
            rightAVPlayer = AVPlayer(url: rightVideo?.fileURL ?? URL(fileURLWithPath: ""))
            backAVPlayer = AVPlayer(url: backVideo?.fileURL ?? URL(fileURLWithPath: ""))

        }

        // Load into player views
        self.leftPlayerView.player = leftAVPlayer
        self.centerPlayerView.player = centerAVPlayer
        self.rightPlayerView.player = rightAVPlayer
        self.backPlayerView.player = backAVPlayer
        avPlayers = [leftAVPlayer!, centerAVPlayer!, rightAVPlayer!, backAVPlayer!]
        avPlayerViews = [leftPlayerView!, centerPlayerView!, rightPlayerView!, backPlayerView!]

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
        self.backAVPlayer = nil
        self.avPlayerViews.removeAll()
        self.leftPlayerView.player = nil
        self.centerPlayerView.player = nil
        self.rightPlayerView.player = nil
        self.backPlayerView.player = nil
        self.preloadAVPlayers.removeAll()
        self.preloadLeftAVPlayer = nil
        self.preloadCenterAVPlayer = nil
        self.preloadRightAVPlayer = nil
        self.preloadBackAVPlayer = nil
        self.isPreloadingFlag = false
        self.currVideoIndex = 0
        self.progressSlider.doubleValue = 0
        self.updateVideoWindowTitle()
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
        self.playButton.image = player.rate.isZero ? NSImage(named: "Play") : NSImage(named: "Pause")
        
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

