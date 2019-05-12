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

    //MARK: Player support
    @IBOutlet weak var leftPlayerView: AVPlayerView!
    @IBOutlet weak var centerPlayerView: AVPlayerView!
    @IBOutlet weak var rightPlayerView: AVPlayerView!

    var leftAVPlayer: AVPlayer?
    var centerAVPlayer: AVPlayer?
    var rightAVPlayer: AVPlayer?
    var avPlayers = [AVPlayer]()

    var leftTimeObserver: Any?
    var centerTimeObserver: Any?
    var rightTimeObserver: Any?
    var timeObservers = [Any]()

    var progressDict = [AVPlayer: Double]()
    var leftProgress: CMTime?
    var centerProgress: CMTime?
    var rightProgress: CMTime?

    var videos: DirectoryCrawler?
    var currVideoIndex: Int = 0

    //MARK: Reactive properties
    var isPlaying: Bool = false {
        didSet {
            self.playButton.title = isPlaying ? "⏸" : "▶️"
        }
    }
    var playbackRate: Float = 1.0 {
        didSet {
            avPlayers.forEach({ $0.rate = playbackRate })
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
    @IBOutlet weak var progressBar: NSProgressIndicator!

    override func viewDidLoad() {
        super.viewDidLoad()

        // setup player control styles
        leftPlayerView.controlsStyle = .none
        centerPlayerView.controlsStyle = .none
        rightPlayerView.controlsStyle = .none

        self.videos = DirectoryCrawler()

        //TODO: No crash operator
        let firstVideo = videos!.videoDictionary[videos!.videoDictionary.keys.sorted().first!]!
        setVideoPlayers(to: firstVideo, playAutomatically: false)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updateVideoWindowTitle()
    }

    func updateVideoWindowTitle() {
        self.title = "Video \(currVideoIndex + 1)/\((videos?.videoDictionary.keys.count ?? 0))"
    }

    // Adds a time observer for updating the progress bar
    func timeObserver(for player: AVPlayer) -> Any {
        // Invoke callback every half second
        let interval = CMTime(seconds: 0.5,
                              preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        // Queue on which to invoke the callback
        let mainQueue = DispatchQueue.main
        // Add time observer
        let timeObserverToken =
            player.addPeriodicTimeObserver(forInterval: interval, queue: mainQueue) {
                [weak self] time in

                if let duration = player.currentItem?.duration {
                    self?.progressDict[player] = player.currentTime().seconds / duration.seconds * 100
                } else {
                    self?.progressDict[player] = 0.0
                }
                self?.refreshProgressBar()
                self?.pollCheckForEndOfVideo()
        }
        return timeObserverToken
    }

    func tearDownPollingTimers() {
        for (player, observer) in zip(avPlayers, timeObservers) {
            player.removeTimeObserver(observer)
        }
    }

    func refreshProgressBar() {
        // Take the largest of all, since some videos may not load in triplets.
        self.progressBar.doubleValue = self.progressDict.values.max() ?? 0
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

    // Calculates if any of the three videos have ended, and if so,
    // move on to the next video in our list, if we've got one
    func pollCheckForEndOfVideo() {
        let currentProgress = self.progressDict.values.max() ?? 0
        if currentProgress >= 100 {

            // Play next video, if we have one
            if currVideoIndex < (videos?.videoDictionary.keys.count ?? 0) - 1 {
                print("Boom")

                currVideoIndex += 1
                let keys = self.videos?.videoDictionary.keys.sorted()
                let nextKey = keys?[currVideoIndex]
                let nextVideo = self.videos?.videoDictionary[nextKey!]!
                self.progressDict = [AVPlayer: Double]()

                setVideoPlayers(to: nextVideo!, playAutomatically: true)

            } else {
                // tear down polling timers
                tearDownPollingTimers()
                let shouldDeleteSeenVideos = askToDeleteSeenVideos()
                if shouldDeleteSeenVideos {
                    print("Deleting videos now")
                }
            }

        }
    }

    func setVideoPlayers(to video: [TeslaCamVideo], playAutomatically: Bool) {
        let leftVideo = video.first(where: { $0.cameraType == .left })
        let centerVideo = video.first(where: { $0.cameraType == .front })
        let rightVideo = video.first(where: { $0.cameraType == .right })

        // remove any previous time observers if we had 'em
        tearDownPollingTimers()

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

        // setup new time observers
        leftTimeObserver = timeObserver(for: leftAVPlayer!)
        centerTimeObserver = timeObserver(for: centerAVPlayer!)
        rightTimeObserver = timeObserver(for: rightAVPlayer!)
        timeObservers = [leftTimeObserver!, centerTimeObserver!, rightTimeObserver!]

        guard playAutomatically == true else { return }
        avPlayers.forEach({ [weak self] (avPlayer: AVPlayer) in
            avPlayer.play()
            avPlayer.rate = self?.playbackRate ?? 0
        })
    }

}

//MARK: IBActions

extension ViewController {

    @IBAction func playButtonWasTapped(_ sender: NSButton) {
        if !isPlaying {
            avPlayers.forEach({ $0.play() })
        } else {
            avPlayers.forEach({ $0.pause() })
        }
        isPlaying = !isPlaying
    }

    @IBAction func playbackSpeedControlTapped(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0: playbackRate = 1
        case 1: playbackRate = 2
        case 2: playbackRate = 5
        case 3: playbackRate = 10
        default: break
        }
    }

}

