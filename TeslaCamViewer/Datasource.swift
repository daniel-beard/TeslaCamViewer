//
//  DirectoryCrawler.swift
//  TeslaCamViewer
//
//  Created by Daniel Beard on 5/5/19.
//  Copyright © 2019 dbeard. All rights reserved.
//

import AVFoundation
import AVKit
import Combine
import Foundation
import SwiftUI

// Walks an input directory searching for teslaCam recordings.
// Returns an ordered list of recordings containing left, front, right, back repeater video
// if the left and right repeater files are not found, they are not used here.

enum CameraAngle: String {
    case front
    case left
    case right
    case back

    func rawValue() -> String {
        switch self {
        case .front:            return "front"
        case .right:            return "right_repeater"
        case .left:             return "left_repeater"
        case .back:             return "back"
        }
    }

    static func from(_ rawValue: String) -> CameraAngle? {
        switch rawValue {
            case "front":           return .front
            case "right_repeater":  return .right
            case "left_repeater":   return .left
            case "back":            return .back
            default:
                print("Unknown camera angle type: \(String(describing: rawValue))")
                return nil
        }
    }
}

struct CameraAngleVideo: Equatable, Hashable {
    var cameraAngle: CameraAngle
    var fileURL: URL
    var creationDate: Date
    var canonicalVideoName: String

    init?(fileURL: URL) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        guard let nameComponents = components(forVideoURL: fileURL),
              let cameraAngle = CameraAngle.from(nameComponents.cameraAngle),
              let creationDate = dateFormatter.date(from: nameComponents.dateTime) else {
            return nil
        }

        self.fileURL = fileURL
        self.cameraAngle = cameraAngle
        self.creationDate = creationDate
        self.canonicalVideoName = nameComponents.canonicalName
    }
}

struct TeslaCamVideo: Equatable, Hashable, Identifiable {
    var id: String { name }

    var creationDate: Date
    var name: String
    var videos = [CameraAngleVideo]()

    var leftVideo: CameraAngleVideo?
    var rightVideo: CameraAngleVideo?
    var frontVideo: CameraAngleVideo?
    var backVideo: CameraAngleVideo?

    init(creationDate: Date,
         name: String,
         videos: [CameraAngleVideo]) {
        self.creationDate = creationDate
        self.name = name
        self.videos = videos
        self.leftVideo  = self.videos.first(where: { $0.cameraAngle == .left })
        self.rightVideo = self.videos.first(where: { $0.cameraAngle == .right })
        self.frontVideo = self.videos.first(where: { $0.cameraAngle == .front })
        self.backVideo  = self.videos.first(where: { $0.cameraAngle == .back })
    }
}

enum PlaybackSpeed: Float, CaseIterable {
    case x0 = 0, x0_25 = 0.25, x0_5 = 0.5, x1 = 1, x2 = 2, x5 = 5, x10 = 10, x20 = 20
}

enum AlertableAction {
    case none
    case play
    case pause
    case increasePlaybackSpeed
    case decreasePlaybackSpeed
    case nextVideo
    case previousVideo
    case restartVideo

    var toastLayout: ToastLayout {
        switch self {
            case .none:     return .none
            case .play:     return .image(Image(systemName: "play.circle"))
            case .pause:    return .image(Image(systemName: "pause.circle"))
            case .increasePlaybackSpeed: return .image(Image(systemName: "plus.circle"))
            case .decreasePlaybackSpeed: return .image(Image(systemName: "minus.circle"))
            case .nextVideo:             return .image(Image(systemName: "forward.end"))
            case .previousVideo:         return .image(Image(systemName: "backward.end"))
            case .restartVideo:          return .image(Image(systemName: "arrow.uturn.backward.circle"))
        }
    }
}

internal typealias DirectoryCrawlerCompletion = () -> Void

class VideoDataSource: ObservableObject {

    @Published var videos = [TeslaCamVideo]() {
        didSet {
            currentVideo = nil
            currentIndex = 0
        }
    }
    @Published var currentVideo: TeslaCamVideo?

    private var timeObserver: Any? = nil

    @Published var currentIndex: Int = 0 {
        didSet {
            updateWindowTitle()
            progress = 0

            // Remove and cancel existing observers, if any exist
            removeObservers()

            guard currentIndex < videos.count else {
                return
            }
            let currentVideo = videos[currentIndex]
            self.currentVideo = currentVideo

            self.leftAVPlayer  = avPlayer(forURL: currentVideo.leftVideo?.fileURL)
            self.rightAVPlayer = avPlayer(forURL: currentVideo.rightVideo?.fileURL)
            self.frontAVPlayer = avPlayer(forURL: currentVideo.frontVideo?.fileURL)
            self.backAVPlayer  = avPlayer(forURL: currentVideo.backVideo?.fileURL)

            playing = playing

            addObservers()
        }
    }
    @Published var leftAVPlayer:  AVPlayer?
    @Published var frontAVPlayer: AVPlayer?
    @Published var rightAVPlayer: AVPlayer?
    @Published var backAVPlayer:  AVPlayer?

    @Published var playing: Bool = false {
        didSet {
            if playing {
                playbackSpeed = playbackSpeedUserSetting
                lastAction = .play
            } else {
                playbackSpeed = .x0
                lastAction = .pause
            }
        }
    }
    @Published var videoGravity: AVLayerVideoGravity = .resizeAspectFill

    @Published var playbackSpeedUserSetting: PlaybackSpeed = .x1 {
        didSet {
            playbackSpeedUserSettingString = "\(formatter.string(from: playbackSpeedUserSetting.rawValue as NSNumber)!)x"
        }
    }
    @Published var playbackSpeed: PlaybackSpeed = .x1 {
        didSet {
            playbackSpeedString = "\(formatter.string(from: playbackSpeed.rawValue as NSNumber)!)x"
        }
    }
    /// 0...1
    @Published var progress: Double = 0 {
        didSet {
            progressString = formatter.string(from: progress as NSNumber) ?? "unknown"
        }
    }
    @Published var progressString: String = "unknown"
    @Published var playbackSpeedString: String = "1x"
    @Published var playbackSpeedUserSettingString: String = "1x"

    @AppStorage("showVideoList") var showVideoList: Bool = true
    @AppStorage("showDebugPanel") var showDebugPanel: Bool = true
    @AppStorage("showSlider") var showSlider: Bool = true

    @Published var windowTitle: String = "No videos loaded"

    @Published var lastAction: AlertableAction = .none

    private var cancellables: Set<AnyCancellable> = []
    private var formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    // We'll just attach observers to the first AVPlayer in this array
    // This will be stable for the current 'video'
    var avPlayers: [AVPlayer] {
        [leftAVPlayer, frontAVPlayer, rightAVPlayer, backAVPlayer].compactMap { $0 }
    }

    init() {
        NotificationCenter.default.publisher(for: .openVideoFolder)
            .compactMap { $0.object as? URL }
            .sink { folderURL in
                self.fetchFiles(folderURL: folderURL, withExtension: "mp4")
            }
            .store(in: &cancellables)
    }

    func fetchFiles(folderURL: URL, withExtension fileExtension:String) {
        // For collecting all the videos, we'll key them by their canonical names
        // we'll transform this into a `[TeslaCamVideo]` sorted by creation date when done.
        var cameraAngleVideos = [String: [CameraAngleVideo]]()

        do {
            let resourceKeys: [URLResourceKey] = [.creationDateKey, .isDirectoryKey]
            let enumerator = FileManager.default.enumerator(at: folderURL,
                                                            includingPropertiesForKeys: resourceKeys,
                                                            options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
                                                                print("directoryEnumerator error at \(url): ", error)
                                                                return true
            })!

            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                guard resourceValues.isDirectory! == false, fileURL.absoluteString.hasSuffix(fileExtension) else {
                    continue
                }

                if let video = CameraAngleVideo(fileURL: fileURL) {
                    cameraAngleVideos[video.canonicalVideoName, default: []].append(video)
                }
            }
        } catch {
            print(error)
        }

        var result = [TeslaCamVideo]()
        for (key, value) in cameraAngleVideos {
            guard let firstVideo = value.first else { continue }
            result.append(
               TeslaCamVideo(creationDate: firstVideo.creationDate,
                             name: key,
                             videos: value)
            )
        }

        if !result.isEmpty {
            NSDocumentController.shared.noteNewRecentDocumentURL(folderURL)
        }

        self.videos = result.sorted(by: { $0.creationDate < $1.creationDate })
        self.currentIndex = 0
    }

    func updateWindowTitle() {
        windowTitle = "Video \(currentIndex + 1)/\((videos.count))"
    }

    func toggleVideoGravity() {
        videoGravity = videoGravity == .resizeAspectFill ? .resizeAspect : .resizeAspectFill
    }

    func previousVideo() {
        guard currentIndex - 1 >= 0 else { return }
        currentIndex -= 1
    }

    func nextVideo() {
        guard currentIndex + 1 < videos.count else { return }
        currentIndex += 1
    }

    func increasePlaybackSpeed() {
        let playbackSpeeds = PlaybackSpeed.allCases
        let currentPlaybackSpeedIndex = playbackSpeeds.firstIndex(of: playbackSpeedUserSetting)!
        let nextIndex = currentPlaybackSpeedIndex.advanced(by: 1)
        guard playbackSpeeds.indices.contains(nextIndex) else { return }
        playbackSpeedUserSetting = playbackSpeeds[nextIndex]
        lastAction = .increasePlaybackSpeed
        if playing {
            playbackSpeed = playbackSpeedUserSetting
        }
    }

    func decreasePlaybackSpeed() {
        let playbackSpeeds = PlaybackSpeed.allCases
        let currentPlaybackSpeedIndex = playbackSpeeds.firstIndex(of: playbackSpeedUserSetting)!
        let nextIndex = currentPlaybackSpeedIndex.advanced(by: -1)
        guard playbackSpeeds.indices.contains(nextIndex) else { return }
        playbackSpeedUserSetting = playbackSpeeds[nextIndex]
        lastAction = .decreasePlaybackSpeed
        if playing {
            playbackSpeed = playbackSpeedUserSetting
        }
    }

    func restartVideo() {
        seek(toPercentage: 0)
        lastAction = .restartVideo
    }

    func avPlayer(forURL url: URL?) -> AVPlayer? {
        guard let url else { return nil }
        return AVPlayer(playerItem: AVPlayerItem(url: url))
    }

    func seek(toPercentage percentage: Double) {
        let duration = avPlayers.first?.currentItem?.duration.seconds ?? 0
        let seekTime = duration * percentage
        //TODODB: Why is this 9000?
        let cmTime = CMTimeMakeWithSeconds(Float64(Float(seekTime)), preferredTimescale: 9000)
        avPlayers.forEach { $0.seek(to: cmTime) }
    }

    func addObservers() {
        removeObservers()
        timeObserver = timeObserver(for: avPlayers.first)
    }

    func removeObservers() {
        if let timeObserver {
            avPlayers.first?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    // Adds a time observer for updating the progress bar
    func timeObserver(for player: AVPlayer?) -> Any? {
        guard let player else { return nil }
        // Invoke callback every half second
        let interval = CMTime(value: 1, timescale: 2)
        // Add time observer
        let timeObserverToken =
            player.addPeriodicTimeObserver(forInterval: interval, queue: nil) { [weak self] time in
                guard let self = self else { return }
                guard let duration = player.currentItem?.duration else {
                    self.progress = 0.0
                    return
                }
                self.progress = player.currentTime().seconds / duration.seconds
                self.pollCheckForEndOfVideo()
        }
        return timeObserverToken
    }

    // Calculates if the sentinel video has ended.
    // move on to the next video in our list, if we've got one
    func pollCheckForEndOfVideo() {
        let currentProgress = self.progress

        //TODODB: Consider using `AVQueuePlayer`, although it gets tricky to manage with multiple videos / queues.
        // I also kinda like the black flash when transitioning between videos to indicate a video boundary.
        // Here would be where we'd preload the next video for each queue.

        // Play next video, if we have one
        if currentProgress >= 1 {
            if currentIndex < videos.count - 1 {
                currentIndex += 1
            } else {
                removeObservers()
            }
        }
    }
}
