import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── Data Models ─────────────────────────────────────────────────────────────

class RecentDownload {
  final String file;
  final int chunk;
  final String source;
  final String time;

  const RecentDownload({
    required this.file,
    required this.chunk,
    required this.source,
    required this.time,
  });

  factory RecentDownload.fromJson(Map<String, dynamic> json) {
    return RecentDownload(
      file: json['file'] as String,
      chunk: json['chunk'] as int,
      source: json['source'] as String,
      time: json['time'] as String,
    );
  }
}

class DaemonStats {
  final int activePeers;
  final double bandwidthSavedMB;
  final int cacheChunks;
  final double networkLatencyMs;
  final bool daemonRunning;
  final double p2pHitRate;
  final List<RecentDownload> recentDownloads;

  const DaemonStats({
    required this.activePeers,
    required this.bandwidthSavedMB,
    required this.cacheChunks,
    required this.networkLatencyMs,
    required this.daemonRunning,
    required this.p2pHitRate,
    required this.recentDownloads,
  });
}

class PeerNode {
  final String peerId;
  final String ip;
  final int daemonPort;
  final int chunksHeld;
  final double latencyMs;
  final String status;

  const PeerNode({
    required this.peerId,
    required this.ip,
    required this.daemonPort,
    required this.chunksHeld,
    required this.latencyMs,
    required this.status,
  });
}

class CacheChunk {
  final String cacheKey;
  final int chunkIndex;
  final String fileLabel;
  final double sizeMB;
  final DateTime cachedAt;
  final String hash;

  const CacheChunk({
    required this.cacheKey,
    required this.chunkIndex,
    required this.fileLabel,
    required this.sizeMB,
    required this.cachedAt,
    required this.hash,
  });
}

class LogEntry {
  final DateTime timestamp;
  final String level; // INFO, SUCCESS, P2P, WARN, ERROR
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });
}

// ─── Daemon Service ───────────────────────────────────────────────────────────
/// DaemonService is the single source of truth for backend communication.
///
/// INTEGRATION HOOK: Replace the dummy data in the methods below with real
/// HTTP and WebSocket calls to the local Node.js daemon.
///
/// REST endpoint:    http://127.0.0.1:8082/api/stats
/// WebSocket:        ws://127.0.0.1:8080
///
/// Example swap for fetchStats():
///   final response = await http.get(Uri.parse('http://127.0.0.1:8082/api/stats'));
///   return DaemonStats.fromJson(jsonDecode(response.body));
class DaemonService {
  final int apiPort;
  
  DaemonService({this.apiPort = 8082});

  // ── INTEGRATION HOOK: Initialize your HTTP client and WebSocket here ──────
  // final _httpClient = http.Client();
  // WebSocketChannel? _wsChannel;

  /// Fetches top-level daemon metrics.
  /// REPLACE with: GET http://127.0.0.1:8082/api/stats
  Future<DaemonStats> fetchStats() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:$apiPort/api/stats')).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final recentList = (data['recentDownloads'] as List<dynamic>?)
            ?.map((e) => RecentDownload.fromJson(e))
            .toList() ?? [];

        return DaemonStats(
          activePeers: data['activePeers'] ?? 0,
          bandwidthSavedMB: ((data['bandwidthSavedBytes'] ?? 0) / (1024 * 1024)).toDouble(),
          cacheChunks: data['cacheChunks'] ?? 0,
          networkLatencyMs: 14.2, // Stubbed until backend supports it
          daemonRunning: true,
          p2pHitRate: (data['p2pHitRate'] ?? 0.0).toDouble(),
          recentDownloads: recentList,
        );
      }
    } catch (e) {
      // Return default error state if daemon is offline
    }

    return const DaemonStats(
      activePeers: 0,
      bandwidthSavedMB: 0.0,
      cacheChunks: 0,
      networkLatencyMs: 0.0,
      daemonRunning: false,
      p2pHitRate: 0.0,
      recentDownloads: [],
    );
  }

  /// Fetches list of known peers from the tracker.
  /// REPLACE with: GET http://127.0.0.1:8082/api/peers
  Future<List<PeerNode>> fetchPeers() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:$apiPort/api/peers')).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => PeerNode(
          peerId: e['peerId'],
          ip: e['ip'],
          daemonPort: e['daemonPort'],
          chunksHeld: e['chunksHeld'],
          latencyMs: (e['latencyMs'] as num).toDouble(),
          status: e['status'],
        )).toList();
      }
    } catch (e) {
      // Ignored
    }
    return [];
  }

  /// Fetches all locally cached chunks.
  /// REPLACE with: GET http://127.0.0.1:8082/api/cache
  Future<List<CacheChunk>> fetchCacheChunks() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:$apiPort/api/cache')).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => CacheChunk(
          cacheKey: e['cacheKey'],
          chunkIndex: e['chunkIndex'],
          fileLabel: e['fileLabel'],
          sizeMB: (e['sizeMB'] as num).toDouble(),
          cachedAt: DateTime.parse(e['cachedAt']),
          hash: e['hash'],
        )).toList();
      }
    } catch (e) {
      // Ignored
    }
    return [];
  }

  /// Streams real-time log entries via WebSocket.
  /// REPLACE with: StreamSubscription to ws://localhost:8080 message events.
  Stream<LogEntry> streamLogs() {
    return const Stream.empty(); // Return empty stream until backend supports it
  }
}

// ─── Extensions ───────────────────────────────────────────────────────────────
extension StreamDelay<T> on Stream<T> {
  Stream<T> delay(Duration d) => asyncExpand((e) => Future.delayed(d, () => e).asStream());
}
