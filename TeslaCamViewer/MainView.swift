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
                            .scrollContentBackground(.hidden)
                            .background(Colors.defaultBackground)
                            .frame(maxWidth: geo.size.width * 0.2)
                        }
                    }
                }
                // Progress slider
                if dataSource.showSlider {
//                    Slider(value: Binding(get: {
//                        self.dataSource.progress
//                    }, set: { (newValue) in
//                        self.dataSource.progress = newValue
//                        self.dataSource.seek(toPercentage: newValue)
//                    }))
//                }
                    CustomSlider(value: Binding(get: {
                        self.dataSource.progress
                    }, set: { (newValue) in
                        self.dataSource.progress = newValue
                        self.dataSource.seek(toPercentage: newValue)
                    }), range: (0, 1)) { modifiers in
                        ZStack {
                            LinearGradient(gradient: .init(colors: [.red, .orange, .pink]), startPoint: .leading, endPoint: .trailing)
                            ZStack {
                                Circle().fill(Color.white)
                                Circle().stroke(Color.black.opacity(0.2), lineWidth: 2)
                                // TODODB: Crash is because of below commented out code. Not sure why, but just replace this with an image
                                // Create your own SVG that is like https://fontawesome.com/icons/car-side-bolt?f=classic&s=solid and bolt.car.circle.fill
                                Image("car_thumb")
                                    .resizable(resizingMode: .stretch)
//                                    .frame(width: 44, height: 44)
                                    .foregroundColor(.red)
//                                    .padding(1)
//                                    .scaledToFill()
                            }
                            .padding([.top, .bottom], 1)
                            .modifier(modifiers.knob)
                        }
                        .cornerRadius(15)
                    }
                    .padding(3)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
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
        .background(Colors.defaultBackground)
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
