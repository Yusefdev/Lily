# Lily

![Lily Logo](logo.png)

Lily is a Flutter + Python project for forwarding phone notifications to your PC over your local network.

## 🚀 Features

- Forward your Android phone’s notifications to your PC  
- Detect your phone’s local IP address on the network  
- Python server binding to `0.0.0.0` for LAN accessibility  

---

## 🛠 Getting Started

### Prerequisites

- Flutter SDK (stable channel)  
- Python 3.7+  
- Android SDK & device or emulator  

> **⚠️ Warning**  
> Start the Flutter app **without any VPN** active so that IP detection works correctly. Once running, you can re-enable your VPN if needed. The same applies to the PC server (binding to `0.0.0.0`).

### Flutter App Setup

1. Clone the repo and navigate into it:
   ```bash
   git clone https://github.com/Yusefdev/lily.git
   cd lily
   ```

2. Add dependencies:
   ```bash
   flutter pub add http@^0.13.5
   flutter pub add network_info_plus@^6.1.4
   flutter pub add notification_listener@1.0.2+1
   flutter pub add notification_listener_service@^0.3.4
   flutter pub add permission_handler@^10.2.0
   flutter pub add installed_apps@^1.6.0
   ```

4. Fetch packages:
   ```bash
   flutter pub get
   ```

### PC Server Setup

1. Create and activate a Python virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

2. Install requirements (if you create `requirements.txt`):
   ```bash
   pip install -r requirements.txt
   ```

3. Run the server:
   ```bash
   python pc_server.py
   ```
   This will bind to all interfaces (`0.0.0.0`) on port 5000 by default.

---

## ▶️ Usage

1. Start the PC server.
2. Launch the Flutter app on your Android device/emulator.
3. Enjoy forwarded notifications on your PC.

---

## 📦 Building the APK

From project root:
```bash
flutter build apk --release
```

Output:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🎁 Release Builds

- **Android**: Get the latest `.apk` from the [Releases](https://github.com/Yusefdev/lily/releases) page.  
- **PC**: Download the latest server release from the same page.

---

## 🤝 Contributing

Feel free to fork, open issues, or submit PRs. You’re welcome to borrow or improve any code.

---

## 📄 License

This project is available under the GNU License. See [LICENSE](LICENSE) for details.

---

## 👤 Author

**Yusef Soleimanian**  
GitHub: [Yusefdev](https://github.com/Yusefdev)
