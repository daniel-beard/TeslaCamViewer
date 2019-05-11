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
    var avPlayers: [AVPlayer]?

    var leftTimeObserver: Any?
    var centerTimeObserver: Any?
    var rightTimeObserver: Any?

    var progressDict = [AVPlayer: Double]()
    var leftProgress: CMTime?
    var centerProgress: CMTime?
    var rightProgress: CMTime?

    var videoKeysRemaining: [Date]?
    var videos: DirectoryCrawler?

    //MARK: Reactive properties
    var isPlaying: Bool = false {
        didSet {
            self.playButton.title = isPlaying ? "⏸" : "▶️"
        }
    }
    var playbackRate: Float = 1.0 {
        didSet {
            avPlayers?.forEach({ $0.rate = playbackRate })
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
        // for testing
        let prefixedVideoKeys = videos!.videoDictionary.keys.sorted().dropFirst(8)

        let earliestDate = prefixedVideoKeys.last!
        self.videoKeysRemaining = prefixedVideoKeys.dropLast()
        let firstVideo = videos!.videoDictionary[earliestDate]!
        setVideoPlayers(to: firstVideo, playAutomatically: false)
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

    func refreshProgressBar() {
        // Take the largest of all, since some videos may not load in triplets.
        self.progressBar.doubleValue = self.progressDict.values.max() ?? 0
    }

    // Calculates if any of the three videos have ended, and if so,
    // move on to the next video in our list, if we've got one
    func pollCheckForEndOfVideo() {
        let currentProgress = self.progressDict.values.max() ?? 0
        if currentProgress >= 100 {

            // Play next video, if we have one
            if (self.videoKeysRemaining?.count ?? 0) > 0 {
                print("Boom")
                let earliestNextDate = self.videoKeysRemaining!.last!
                self.videoKeysRemaining = self.videoKeysRemaining?.dropLast()
                let firstVideo = videos!.videoDictionary[earliestNextDate]!

                self.progressDict = [AVPlayer: Double]()

                setVideoPlayers(to: firstVideo, playAutomatically: true)
            } else {
                //TODO: here's where we should tear down the polling timers.
            }

        }
    }

    func setVideoPlayers(to video: [TeslaCamVideo], playAutomatically: Bool) {
        let leftVideo = video.first(where: { $0.cameraType == .left })
        let centerVideo = video.first(where: { $0.cameraType == .front })
        let rightVideo = video.first(where: { $0.cameraType == .right })

        // remove any previous time observers if we had 'em
        leftAVPlayer?.removeTimeObserver(leftTimeObserver as Any)
        centerAVPlayer?.removeTimeObserver(centerTimeObserver as Any)
        rightAVPlayer?.removeTimeObserver(rightTimeObserver as Any)

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

        guard playAutomatically == true else { return }
        avPlayers?.forEach({ [weak self] (avPlayer: AVPlayer) in
            avPlayer.play()
            avPlayer.rate = self?.playbackRate ?? 0
        })
    }

}

//MARK: IBActions

extension ViewController {

    @IBAction func playButtonWasTapped(_ sender: NSButton) {
        if !isPlaying {
            avPlayers?.forEach({ $0.play() })
        } else {
            avPlayers?.forEach({ $0.pause() })
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

