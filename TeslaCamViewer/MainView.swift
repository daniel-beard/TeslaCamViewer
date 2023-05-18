//
//  MainView.swift
//  TeslaCamViewer
//
//  Created by Daniel Beard on 5/16/23.
//  Copyright © 2023 dbeard. All rights reserved.
//

import AVFoundation
import AVKit
import Cocoa
import Combine
import SwiftUI

extension AVPlayerView {
    // Don't allow any user interaction
    override open var acceptsFirstResponder: Bool { false }
}

struct AVPlayerControllerRepresented: NSViewRepresentable {

    @Binding var player : AVPlayer?
    @Binding var videoGravity: AVLayerVideoGravity
    @Binding var playing: Bool
    @Binding var playbackSpeed: PlaybackSpeed

    init(player: Binding<AVPlayer?>, playing: Binding<Bool>, playbackSpeed: Binding<PlaybackSpeed>, videoGravity: Binding<AVLayerVideoGravity>) {
        self._player = player
        self._playing = playing
        self._playbackSpeed = playbackSpeed
        self._videoGravity = videoGravity
    }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.player = player
        view.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ playerView: AVPlayerView, context: Context) {
        if playerView.player != player {
            playerView.player = player
        }
        if playerView.videoGravity != videoGravity {
            playerView.videoGravity = videoGravity
        }
        if playerView.player?.rate != playbackSpeed.rawValue {
            playerView.player?.rate = playbackSpeed.rawValue
        }
        if !playing && playerView.player?.timeControlStatus != .paused {
            playerView.player?.pause()
        }
    }
}

struct MainView: View {

    @Binding var dataSource: VideoDataSource

    init(dataSource: Binding<VideoDataSource>) {
        self._dataSource = dataSource
    }

    var body: some View {
        ZStack {

            VStack {
                GeometryReader { geo in
                    HStack {
                        // Video panel side
                        VStack {
                            HStack {
                                AVPlayerControllerRepresented(player: $dataSource.frontAVPlayer,
                                                              playing: $dataSource.playing,
                                                              playbackSpeed: $dataSource.playbackSpeed,
                                                              videoGravity: $dataSource.videoGravity)
                            }
                            HStack {
                                AVPlayerControllerRepresented(player: $dataSource.leftAVPlayer,
                                                              playing: $dataSource.playing,
                                                              playbackSpeed: $dataSource.playbackSpeed,
                                                              videoGravity: $dataSource.videoGravity)

                                AVPlayerControllerRepresented(player: $dataSource.backAVPlayer,
                                                              playing: $dataSource.playing,
                                                              playbackSpeed: $dataSource.playbackSpeed,
                                                              videoGravity: $dataSource.videoGravity)

                                AVPlayerControllerRepresented(player: $dataSource.rightAVPlayer,
                                                              playing: $dataSource.playing,
                                                              playbackSpeed: $dataSource.playbackSpeed,
                                                              videoGravity: $dataSource.videoGravity)
                            }
                        }
                        .padding(0)

                        // Video List
                        if dataSource.showVideoList {
                            List(dataSource.videos.indices, id: \.self) { index in
                                let video = dataSource.videos[index]
                                HStack {
                                    Text(video.name)
                                }
                                .onTapGesture(count: 2) {
                                    dataSource.currentIndex = index
                                }
                                .background(index == dataSource.currentIndex ? .blue : .clear)
                            }
                            .frame(maxWidth: geo.size.width * 0.2)
                        }
                    }
                }
                // Progress slider
                if dataSource.showSlider {
                    Slider(value: Binding(get: {
                        self.dataSource.progress
                    }, set: { (newValue) in
                        self.dataSource.progress = newValue
                        self.dataSource.seek(toPercentage: newValue)
                    }))
                }
            }

            // Debug Panel
            if dataSource.showDebugPanel {
                VStack {
                    HStack {
                        DebugPanel(dataSource: $dataSource)
                        Spacer()
                    }
                    Spacer()
                }.padding(40)
            }
        }
        .navigationTitle(dataSource.windowTitle)
    }
}

struct DebugPanel: View {
    @Binding var dataSource: VideoDataSource

    var body: some View {
        VStack {
            Text("Playing? \(dataSource.playing ? "YES" : "NO")")
            Text("Rate: \(dataSource.playbackSpeedString)")
            Text("Rate Setting: \(dataSource.playbackSpeedUserSettingString)")
            Text("Progress: \(dataSource.progressString)")
        }
        .font(.title)
        .padding(10)
        .frame(maxWidth: 230)
        .foregroundStyle(.secondary)
        .background(.ultraThinMaterial)
        .clipShape(Capsule(style: .continuous))
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            MainView(dataSource: .constant(VideoDataSource()))
        }
    }
}