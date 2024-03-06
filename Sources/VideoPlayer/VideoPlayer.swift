import Foundation
import SwiftUI
import AVKit
import UIKit

import HorizontalProgressBarView

public struct VideoPlayerView: View {
    var url: String
    var coverUrl: String? = nil
    var coverThumbnailUrl: String? = nil
    var showBackButton: Bool = true
    var backButtonAction: (() -> Void) = {}
    var disabled: Binding<Bool>
    
    @State private var loadingViewBuilder: (() -> any View)? = nil
    @State private var placeholderViewBuilder: (() -> any View)? = nil
    @State private var failedViewBuilder: (() -> any View)? = nil
    @State private var disabledViewBuilder: (() -> any View)? = nil
    
    @ViewBuilder private var loadingView: some View { self.buildView(self.loadingViewBuilder, defaultText: "Loading") }
    @ViewBuilder private var placeholderView: some View { self.buildView(self.placeholderViewBuilder, defaultText: "Video") }
    @ViewBuilder private var failedView: some View { self.buildView(self.failedViewBuilder, defaultText: "Failed to load video") }
    @ViewBuilder private var disabledView: some View { self.buildView(self.disabledViewBuilder, defaultText: "Disabled") }
    
    @State private var showControls: Bool = true
    @State private var showVolumeSlider: Bool = false
    @State private var progressValue: Double = 0
    @State private var volumeValue: Double = 1.0
    @State private var controlsDismissTask: DispatchWorkItem? = nil

    @StateObject private var contentPlayer: ContentPlayer

    enum ContentPlayerStatus: Int {
        case readyToPlay
        case failed
        case playing
        case paused
    }
    
    public init(url: String, coverUrl: String? = nil, coverThumbnailUrl: String? = nil, showBackButton: Bool = true, backButtonAction: @escaping (() -> Void) = {}, disabled: Binding<Bool>, loadingView: (() -> any View)? = nil, placeholderView: (() -> any View)? = nil, failedView: (() -> any View)? = nil, disabledView: (() -> any View)? = nil) {
        self.url = url
        self.coverUrl = coverUrl
        self.coverThumbnailUrl = coverThumbnailUrl
        self.showBackButton = showBackButton
        self.backButtonAction = backButtonAction
        self.disabled = disabled
        self._loadingViewBuilder = State(initialValue: loadingView)
        self._placeholderViewBuilder = State(initialValue: placeholderView)
        self._failedViewBuilder = State(initialValue: failedView)
        self._disabledViewBuilder = State(initialValue: disabledView)
        self._contentPlayer = StateObject(wrappedValue: ContentPlayer(url: url))
    }
    
    @ViewBuilder private func buildView(_ builder: (() -> any View)? = nil, defaultText: String) -> some View {
        if let builder = builder {
            AnyView(builder())
        } else {
            DefaultView(text: defaultText)
        }
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            AVPlayerControllerRepresented(player: self.contentPlayer.player).frame(maxWidth: .infinity, maxHeight: .infinity)
            ZStack {
                if self.disabled.wrappedValue {
                    self.disabledView
                } else {
                    switch self.contentPlayer.status {
                        case .failed: self.failedView
                        case .readyToPlay:
                            if let coverThumbnail = self.coverThumbnailUrl, let coverUrl = URL(string: coverThumbnail) {
                                AsyncImage(url: coverUrl, content: { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                }, placeholder: { self.loadingView })
                            } else {
                                self.placeholderView
                            }
                        case .none: self.loadingView
                        default: EmptyView()
                    }
                }

                ZStack {
                    HStack {
                        Spacer()
                        ControlButton(imageName: "gobackward.10", size: 26, action: {
                            self.scheduleControlsDismissTask()
                            self.contentPlayer.player?.seek(to: CMTime(seconds: max(0, self.contentPlayer.currentTime - 10), preferredTimescale: CMTimeScale(NSEC_PER_SEC)), toleranceBefore: CMTime(seconds: max(0, self.contentPlayer.currentTime - 9.5), preferredTimescale: CMTimeScale(NSEC_PER_SEC)), toleranceAfter: CMTime(seconds: max(0, self.contentPlayer.currentTime - 10.5), preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                        }).opacity(self.contentPlayer.currentTime >= self.contentPlayer.duration ? 0 : 0.8)
                        Spacer()
                        ControlButton(imageName: self.contentPlayer.player?.timeControlStatus == .playing ? "pause.fill" : (self.contentPlayer.currentTime >= self.contentPlayer.duration ? "arrow.counterclockwise" : "play.fill"), size: 46, action: {
                            self.scheduleControlsDismissTask()
                            switch self.contentPlayer.player?.timeControlStatus {
                                case .playing: self.contentPlayer.player?.pause()
                                default:
                                    if self.contentPlayer.currentTime >= self.contentPlayer.duration {
                                        self.contentPlayer.player?.seek(to: CMTime.zero, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero, completionHandler: { success in
                                            if success {
                                                self.contentPlayer.player?.play()
                                            }
                                        })
                                    } else {
                                        self.contentPlayer.player?.play()
                                    }
                            }
                        })
                        Spacer()
                        ControlButton(imageName: "goforward.10", size: 26, action: {
                            self.scheduleControlsDismissTask()
                            self.contentPlayer.player?.seek(to: CMTime(seconds: min(self.contentPlayer.duration, self.contentPlayer.currentTime + 10), preferredTimescale: CMTimeScale(NSEC_PER_SEC)), toleranceBefore: CMTime(seconds: min(self.contentPlayer.currentTime + 9.5, self.contentPlayer.duration), preferredTimescale: CMTimeScale(NSEC_PER_SEC)), toleranceAfter: CMTime(seconds: min(self.contentPlayer.duration, self.contentPlayer.currentTime + 10.5), preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
                        }).opacity(self.contentPlayer.currentTime >= self.contentPlayer.duration ? 0 : 0.8)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .opacity((!self.disabled.wrappedValue && self.contentPlayer.status != .failed) ? 1 : 0)

                    VStack {
                        HStack(alignment: .top) {
                            if self.showBackButton {
                                Button(action: self.backButtonAction, label: {
                                    Image(systemName: "chevron.left").foregroundColor(Color.white)
                                }).padding(15).shadow(color: .black.opacity(0.5), radius: 1, x: 1, y: 1)
                            }
                            Spacer()
                            HStack(spacing: 0) {
                                Button(action: {
                                    self.controlsDismissTask?.cancel()
                                    if self.showVolumeSlider {
                                        self.contentPlayer.setMuted(!self.contentPlayer.muted)
                                        if self.contentPlayer.muted {
                                            self.volumeValue = 0
                                        } else {
                                            self.volumeValue = Double(self.contentPlayer.player?.volume ?? 0.1)
                                        }
                                    } else {
                                        withAnimation {
                                            if self.contentPlayer.muted {
                                                self.contentPlayer.setMuted(false)
                                                self.volumeValue = Double(self.contentPlayer.player?.volume ?? 0.1)
                                            }
                                            self.showVolumeSlider = true
                                        }
                                    }
                                    self.scheduleControlsDismissTask()
                                }, label: {
                                    Image(systemName: (self.contentPlayer.player?.isMuted ?? false) ? "speaker.slash.fill" : "speaker.fill").foregroundColor(Color.white)
                                }).padding(15).padding(.trailing, -5).shadow(color: .black.opacity(0.5), radius: 1, x: 1, y: 1)

                                HorizontalProgressBarView(progressValue: self.$volumeValue, height: 6, cornerRadius: 2, scaleFactorOnDrag: 1.5, foregroundColor: Color.white.opacity(0.8), onDragging: { value in
                                    self.controlsDismissTask?.cancel()
                                    self.contentPlayer.setMuted(value <= 0)

                                    self.contentPlayer.player?.volume = Float(value) }, onDraggingEnded: { value in
                                        self.volumeValue = value
                                        self.scheduleControlsDismissTask()
                                    }).frame(maxWidth: self.showVolumeSlider ? 100 : 0).padding(.trailing, 15)
                            }
                            .opacity((!self.disabled.wrappedValue && self.contentPlayer.status != .failed) ? 1 : 0)
                            .transition(AnyTransition.slide.animation(.easeInOut(duration: 1)))
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack {
                        Spacer()
                        HStack(alignment: .center, spacing: 10) {
                            Text("\(self.getTimeRepresentation(value: self.contentPlayer.currentTime == Double.infinity ? 0 : Int(self.contentPlayer.currentTime)))").frame(minWidth: 50)

                            HorizontalProgressBarView(progressValue: self.$progressValue, height: 15, foregroundColor: Color.white.opacity(0.7), backgroundColor: Color.white.opacity(0.2), onDragging: { value in
                                self.contentPlayer.player?.pause()
                                self.controlsDismissTask?.cancel()
                                self.controlsDismissTask = nil

                                self.progressValue = value
                                if self.contentPlayer.duration != Double.infinity {
                                    self.contentPlayer.currentTime = self.progressValue * self.contentPlayer.duration
                                }
                            }, onDraggingEnded: { value in
                                self.scheduleControlsDismissTask()
                                self.progressValue = value
                                if self.contentPlayer.duration != Double.infinity {
                                    let time = CMTime(seconds: self.progressValue * self.contentPlayer.duration, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
                                    self.contentPlayer.player?.seek(to: time, toleranceBefore: time, toleranceAfter: time, completionHandler: { success in
                                        if success {
                                            self.contentPlayer.player?.play()
                                        }
                                    })
                                }
                            })

                            Text(self.contentPlayer.duration != Double.infinity ? "\(self.getTimeRepresentation(value: Int(self.contentPlayer.duration)))" : "--:--").frame(minWidth: 50)
                        }
                        .font(.system(size: 10))
                        .padding()
                    }
                    .opacity((!self.disabled.wrappedValue && self.contentPlayer.status != .failed) ? 1 : 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.linearGradient(Gradient(colors: [.black.opacity(0.6), .black.opacity(0.4), .black.opacity(0.2), .black.opacity(0.4), .black.opacity(0.6)]), startPoint: .top, endPoint: .bottom))
                .opacity(self.showControls ? 1 : 0)
                .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.3)))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .statusBar(hidden: true)
        .onDisappear {
            self.contentPlayer.player?.pause()
            self.controlsDismissTask?.cancel()
        }
        .onChange(of: self.contentPlayer.currentTime, perform: { newValue in
            if self.contentPlayer.duration != Double.infinity {
                self.progressValue = Double(newValue / self.contentPlayer.duration)
            }
        })
        .onChange(of: self.disabled.wrappedValue, perform: { newValue in
            if newValue {
                self.contentPlayer.player?.pause()
            }
        })
        .onTapGesture {
            withAnimation {
                self.showControls = !self.showControls
                self.showVolumeSlider = false
            }
            if self.showControls {
                self.scheduleControlsDismissTask()
            }
        }
    }

    private func scheduleControlsDismissTask() {
        self.controlsDismissTask?.cancel()
        self.controlsDismissTask = DispatchWorkItem {
            self.showControls = false
            self.showVolumeSlider = false
            self.controlsDismissTask = nil
        }
        if let task = self.controlsDismissTask {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: task)
        }
    }

    private func getTimeRepresentation(value: Int) -> String {
        var string: String = ""
        var remaining = value
        if value > 3600 {
            let hour = Int(value / 3600)
            string += String(hour) + ":"
            remaining = value - hour * 3600
        }
        let minutes = Int(remaining / 60)
        string += String(format: "%.2d", minutes) + ":" + String(format: "%.2d", remaining % 60)
        return string
    }

    private struct ControlButton: View {
        var imageName: String
        var size: CGFloat
        var action: (() -> Void)

        var body: some View {
            Button(action: self.action, label: {
                Image(systemName: self.imageName).font(.system(size: self.size)).foregroundColor(.white).shadow(color: .gray, radius: 5)
            })
        }
    }

    private struct DefaultView: View {
        var text: String

        var body: some View {
            Text(self.text).frame(maxWidth: .infinity, maxHeight: .infinity).foregroundColor(.white).background(Color.black)
        }
    }

    private struct AVPlayerControllerRepresented: UIViewControllerRepresentable {
        var player: AVPlayer? = nil

        func makeUIViewController(context: Context) -> some AVPlayerViewController {
            let controller = AVPlayerViewController()
            if let player = self.player {
                controller.player = player
            }
            controller.showsPlaybackControls = false
            controller.entersFullScreenWhenPlaybackBegins = true
            controller.exitsFullScreenWhenPlaybackEnds = false
            return controller
        }

        func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        }
    }

    private class ContentPlayer: NSObject, ObservableObject {
        var player: AVPlayer? = nil

        @Published var muted: Bool = false
        @Published var duration: Double = Double.infinity
        @Published var currentTime: Double = 0
        @Published var status: ContentPlayerStatus? = .none

        // Key-value observing context
        private var playerStatusContext = 0
        private var playerTimeControlStatusContext = 0
        private var playerCurrentItemDurationContext = 0

        enum ContentPlayerStatus: Int {
            case readyToPlay
            case failed
            case playing
            case paused
        }

        init(url: String) {
            super.init()
            if let url = URL(string: url) {
                self.player = AVPlayer(url: url)
            }
            self.player?.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.old, .new], context: &self.playerStatusContext)
            self.player?.addObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus), options: [.old, .new], context: &self.playerTimeControlStatusContext)
            self.player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)), queue: .main, using: { value in
                self.currentTime = value.seconds
            })
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == #keyPath(AVPlayer.status) {
                if let statusInt = (change?[.newKey] as? NSNumber)?.intValue {
                    switch AVPlayer.Status(rawValue: statusInt) {
                        case .readyToPlay: self.status = .readyToPlay; self.player?.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.duration), context: &self.playerCurrentItemDurationContext)
                        case .failed: self.status = .failed
                        default: self.status = .none
                    }
                }
            } else if keyPath == #keyPath(AVPlayer.timeControlStatus) {
                if let statusInt = (change?[.newKey] as? NSNumber)?.intValue {
                    switch AVPlayer.TimeControlStatus(rawValue: statusInt) {
                        case .playing: self.status = .playing
                        case .paused: self.status = .paused
                        case .waitingToPlayAtSpecifiedRate: self.status = .paused
                        case .none: self.status = .none
                        @unknown default: self.status = .paused
                    }
                }
            } else if keyPath == #keyPath(AVPlayer.currentItem.duration) {
                if let seconds = self.player?.currentItem?.duration.seconds {
                    self.duration = seconds
                }
            } else {
                super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            }
        }

        func setMuted(_ value: Bool) {
            self.player?.isMuted = value
            self.muted = self.player?.isMuted ?? false
        }
    }
}
