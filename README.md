# Video Player For iOS

A video player for iOS that supports cover image and/or placeholder views. A back button is also embedded in controls that fits full screen playing.

Usage:
```swift
VideoPlayerView(url: String, coverUrl: String?, coverThumbnailUrl: String?, showBackButton: Bool, backButtonAction: @escaping (() -> Void), disabled: Binding<Bool>, loadingView: (() -> any View), placeholderView: (() -> any View)?, failedView: (() -> any View)?, disabledView: (() -> any View)?)  
```