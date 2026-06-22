import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class DaemonLifecycleManager {
  Process? _daemonProcess;
  
  // Dynamically allocated ports
  int? proxyPort;
  int? apiPort;
  int? daemonPort;

  /// Starts the embedded Node.js daemon with automatically assigned free ports
  Future<void> startDaemon() async {
    try {
      // 1. Find 3 free ports dynamically
      proxyPort = await _getFreePort();
      apiPort = await _getFreePort();
      daemonPort = await _getFreePort();

      print('[LIFECYCLE] Found free ports -> Proxy: $proxyPort, API: $apiPort, Daemon: $daemonPort');

      // 2. Extract daemon.exe from assets to the OS temp/support directory
      final supportDir = await getApplicationSupportDirectory();
      final daemonExePath = '${supportDir.path}\\daemon.exe';
      final cacheDirPath = '${supportDir.path}\\MeshCache';

      final File exeFile = File(daemonExePath);
      
      // Always extract to ensure we have the latest bundled version
      final ByteData data = await rootBundle.load('assets/daemon.exe');
      await exeFile.writeAsBytes(data.buffer.asUint8List(), flush: true);

      print('[LIFECYCLE] Extracted daemon to $daemonExePath');

      // 3. Start the process
      _daemonProcess = await Process.start(
        daemonExePath,
        [
          '--proxy=$proxyPort',
          '--api=$apiPort',
          '--daemon=$daemonPort',
          '--cache=$cacheDirPath',
          '--tracker=wss://mesh-cdn.onrender.com'
        ],
        mode: ProcessStartMode.normal,
      );

      print('[LIFECYCLE] Daemon started with PID ${_daemonProcess?.pid}');

      // Log daemon output for debugging
      _daemonProcess?.stdout.listen((event) {
        print(String.fromCharCodes(event));
      });
      _daemonProcess?.stderr.listen((event) {
        print('[DAEMON ERROR] ${String.fromCharCodes(event)}');
      });

    } catch (e) {
      print('[LIFECYCLE ERROR] Failed to start daemon: $e');
    }
  }

  /// Gracefully kills the background daemon
  void stopDaemon() {
    if (_daemonProcess != null) {
      print('[LIFECYCLE] Terminating daemon process ${_daemonProcess?.pid}...');
      _daemonProcess?.kill();
      _daemonProcess = null;
    }
  }

  /// Helper to get a guaranteed free port from the OS
  Future<int> _getFreePort() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }
}
