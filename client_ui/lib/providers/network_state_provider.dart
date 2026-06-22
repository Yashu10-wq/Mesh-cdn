import 'dart:async';
import 'package:flutter/material.dart';
import '../core/services/daemon_service.dart';

class NetworkStateProvider extends ChangeNotifier {
  final DaemonService _service;

  NetworkStateProvider(this._service);

  // ── Overview ──────────────────────────────────────────────────────────────
  DaemonStats? _stats;
  bool _statsLoading = false;
  DaemonStats? get stats => _stats;
  bool get statsLoading => _statsLoading;

  // ── Peers ─────────────────────────────────────────────────────────────────
  List<PeerNode> _peers = [];
  bool _peersLoading = false;
  List<PeerNode> get peers => _peers;
  bool get peersLoading => _peersLoading;

  // ── Cache ─────────────────────────────────────────────────────────────────
  List<CacheChunk> _chunks = [];
  bool _chunksLoading = false;
  List<CacheChunk> get chunks => _chunks;
  bool get chunksLoading => _chunksLoading;

  // ── Logs ──────────────────────────────────────────────────────────────────
  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);
  StreamSubscription<LogEntry>? _logSub;

  // ── Settings ──────────────────────────────────────────────────────────────
  bool autoReconnect = true;
  bool heartbeatEnabled = true;
  int proxyPort = 8081;
  int daemonPort = 9000;

  // ─── Fetch Methods ───────────────────────────────────────────────────────

  Future<void> fetchStats() async {
    _statsLoading = true;
    notifyListeners();
    _stats = await _service.fetchStats();
    _statsLoading = false;
    notifyListeners();
  }

  Future<void> fetchPeers() async {
    _peersLoading = true;
    notifyListeners();
    _peers = await _service.fetchPeers();
    _peersLoading = false;
    notifyListeners();
  }

  Future<void> fetchChunks() async {
    _chunksLoading = true;
    notifyListeners();
    _chunks = await _service.fetchCacheChunks();
    _chunksLoading = false;
    notifyListeners();
  }

  void startLogStream() {
    _logSub?.cancel();
    _logSub = _service.streamLogs().listen((entry) {
      _logs.insert(0, entry); // newest on top
      notifyListeners();
    });
  }

  void updateSetting(String key, dynamic value) {
    switch (key) {
      case 'autoReconnect':     autoReconnect    = value as bool; break;
      case 'heartbeatEnabled':  heartbeatEnabled = value as bool; break;
      case 'proxyPort':         proxyPort        = value as int;  break;
      case 'daemonPort':        daemonPort       = value as int;  break;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _logSub?.cancel();
    super.dispose();
  }
}
