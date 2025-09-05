# 🎬 VideoShorts

**VideoShorts** is a Flutter app inspired by **TikTok, Instagram Reels, and YouTube Shorts** – designed to deliver **ultra-smooth video playback** with smart caching and controller management.

---

## 🚀 Why VideoShorts?

Unlike generic video players, **VideoShorts** is optimized for **short-form vertical video feeds** with a **buttery scrolling experience**.  
We achieve this using:

- ⚡ **Video Preloading + Smart Caching**
    - Videos are downloaded & stored in cache using **flutter_cache_manager**.
    - Once cached, videos play instantly without buffering.

- 🧵 **Background Isolates for Downloads**
    - Heavy cache downloads run in **separate isolates**, ensuring the main UI thread stays smooth.

- 🎥 **Controller Pool Management**
    - Only the **current video plays**.
    - Previous and next videos are **preloaded**.
    - Far-away videos are **disposed** to save memory.

- 🔊 **No Background Noise**
    - Only the visible video has audio – background videos stay paused.

- 🎯 **Optimized for 60 FPS**
    - Scroll through videos with **zero frame drops**.

---

## 🏗️ Tech Highlights

- **Framework:** Flutter (latest SDK, 2025)
- **Language:** Dart
- **State Management:** GetX (Reactive + MVVM)
- **Video Engine:** [video_player](https://pub.dev/packages/video_player) + caching layer
- **Caching:** [flutter_cache_manager](https://pub.dev/packages/flutter_cache_manager) + isolates
- **Architecture:** LayerX

---

## 📱 Features

✅ Infinite scrolling vertical feed (like TikTok/Reels/Shorts)  
✅ Video caching → play from file, not just stream  
✅ Preloading (next 2–3 videos always ready)  
✅ Isolate-based background caching (no UI lag)  
✅ Smart controller disposal → no memory leaks  
✅ Only current video audio plays (no overlapping sounds)  
✅ Shimmer loader until cache ready

---

## 🧠 How It Works

1. **User scrolls** → controller checks cache for the next video.
2. If not cached → isolate starts background download → save in cache.
3. **VideoPlayerController** plays from cached file instead of direct URL.
4. Current video **auto-plays**, neighbors preload, far ones get disposed.

This ensures the experience is just like **TikTok / YT Shorts / Insta Reels** – **instant, smooth, and distraction-free**.

---

## 🚀 Getting Started

Clone the repo and run:

```bash
git clone https://github.com/your-username/videoshorts.git
cd videoshorts
flutter pub get
flutter run
