# 🌐 Bharat-Acadamia Micro-CDN

A zero-configuration, peer-to-peer (P2P) Content Delivery Network built for desktop. **Micro-CDN** completely abstracts away backend complexity by embedding a full Node.js P2P networking daemon directly inside a beautiful Flutter Windows application.

![Architecture Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen?style=for-the-badge) ![Flutter](https://img.shields.io/badge/Flutter-Desktop-02569B?style=for-the-badge&logo=flutter) ![Node.js](https://img.shields.io/badge/Node.js-Daemon-339933?style=for-the-badge&logo=node.js) 

---

## ✨ Features

- **Zero-Config Install:** The user just double-clicks the `.exe`. The Flutter app extracts the backend, dynamically assigns free system ports, and invisibly bridges the UI to the backend. No terminals, no `.env` files, no Node.js installation required.
- **Peer-to-Peer Swarming:** Automatically detects peers on the network downloading the same files and streams binary chunks from them instead of the Origin Server to save bandwidth.
- **Smart Tollbooth Proxy:** A local HTTP proxy intercepts outgoing download requests, computes SHA-256 hashes, and streams content simultaneously from local cache, peers, and the origin server.
- **Live Telemetry:** A gorgeous, responsive Flutter dashboard showing real-time network graphs, active swarm peers, P2P hit rates, and chunk-by-chunk download verification.

---

## 🏗 Architecture

The system is split into three main components:

### 1. 🖥️ Client UI (`/client_ui`)
The beautiful frontend dashboard built in Flutter. Upon launching, it uses `DaemonLifecycleManager` to extract the embedded `daemon.exe`, spawn it invisibly in the background, and connect to its telemetry port.

### 2. ⚙️ Local Daemon (`/local-daemon`)
A Node.js backend compiled into a standalone Windows executable using `pkg`. It runs entirely in the background and operates three distinct servers simultaneously:
- **Proxy Server:** Intercepts outgoing file downloads.
- **P2P Server (gRPC):** Streams cached chunks directly to other computers on the network.
- **API Server (REST):** Serves real-time telemetry back to the Flutter UI.

### 3. 📡 Central Tracker (`/tracker-server`)
A lightweight WebSocket server hosted in the cloud. It acts as the "matchmaker" for the network, keeping an O(1) in-memory ledger of exactly which peers hold which chunks so that computers can discover each other over the internet.

> **🟢 Live Tracker Server:** `wss://mesh-cdn.onrender.com`

---

## 🚀 How It Works (The Workflow)

1. **Boot Sequence:** The user opens the Flutter App. It binds to random free ports (e.g., `57408`, `57409`, `57410`) and launches `daemon.exe`.
2. **Tracker Registration:** The daemon reaches out to the live cloud tracker (`wss://mesh-cdn.onrender.com`) and registers its IP and P2P port.
3. **The Download:** The user pastes a download URL into the Flutter UI (e.g., `http://example.com/video.mp4`).
4. **The Interception:** The UI routes the GET request through the local Proxy Server (`http://localhost:57408/?url=...`).
5. **The Swarm:** 
   - The Proxy asks the Central Tracker: *"Does anyone else have chunk 0 of video.mp4?"*
   - If YES, it connects directly to the peer via gRPC and downloads it instantly.
   - If NO, it downloads the chunk from the origin server, saves it to its local `.mesh_cache`, and broadcasts to the tracker that it is now a seeder for that chunk!

---

## 🛠 Setup & Development

### Developing the Flutter UI
1. `cd client_ui`
2. `flutter pub get`
3. `flutter run -d windows`

### Re-compiling the Daemon
If you make changes to the Node.js networking logic, you must re-bundle the executable for the Flutter app:
1. `cd local-daemon`
2. `npm install`
3. `npx pkg . --target node18-win-x64 -o daemon.exe`
4. Copy `daemon.exe` into the `client_ui/assets/` folder.

### Running the Tracker Locally
1. `cd tracker-server`
2. `npm install`
3. `npm start` (Runs on port 8080)

---
*Built with ❤️ for Bharat-Acadamia.*
