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

    //MARK: Reactive properties
    var isPlaying: Bool = false {
        didSet {
            print("isPlaying changed to: \(isPlaying)")
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

    override func viewDidLoad() {
        super.viewDidLoad()

        // setup player control styles
        leftPlayerView.controlsStyle = .none
        centerPlayerView.controlsStyle = .none
        rightPlayerView.controlsStyle = .none

        let videos = DirectoryCrawler()

        //TODO: No crash operator
        let firstVideo = videos.first!.value
        setVideoPlayers(to: firstVideo, playAutomatically: false)

    }

    func setVideoPlayers(to video: [TeslaCamVideo], playAutomatically: Bool) {
        let leftVideo = video.first(where: { $0.cameraType == .left })
        let centerVideo = video.first(where: { $0.cameraType == .front })
        let rightVideo = video.first(where: { $0.cameraType == .right })

        // Load the videos into AVPlayers
        leftAVPlayer = AVPlayer(url: leftVideo?.fileURL ?? URL(fileURLWithPath: ""))
        centerAVPlayer = AVPlayer(url: centerVideo?.fileURL ?? URL(fileURLWithPath: ""))
        rightAVPlayer = AVPlayer(url: rightVideo?.fileURL ?? URL(fileURLWithPath: ""))

        // Load into player views
        self.leftPlayerView.player = leftAVPlayer
        self.centerPlayerView.player = centerAVPlayer
        self.rightPlayerView.player = rightAVPlayer
        avPlayers = [leftAVPlayer!, centerAVPlayer!, rightAVPlayer!]

        guard playAutomatically == true else { return }
        self.leftAVPlayer?.play()
        self.centerAVPlayer?.play()
        self.rightAVPlayer?.play()
    }


    @IBAction func playbackSpeedControlTapped(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
            case 0: playbackRate = 1
            case 1: playbackRate = 2
            case 2: playbackRate = 5
            default: break
        }
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


}

