import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/daemon_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/navigation_provider.dart';
import 'providers/network_state_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:window_manager/window_manager.dart';
import 'features/shell/root_shell.dart';
import 'core/services/daemon_lifecycle_manager.dart';

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Boot up the bundled Node.js daemon
  final lifecycleManager = DaemonLifecycleManager();
  await lifecycleManager.startDaemon();

  // 2. Initialize Window Manager for graceful exit
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    title: 'Bharat-Acadamia Micro-CDN',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    WindowListenerApp(lifecycleManager: lifecycleManager),
  );
}

class WindowListenerApp extends StatefulWidget {
  final DaemonLifecycleManager lifecycleManager;
  const WindowListenerApp({Key? key, required this.lifecycleManager}) : super(key: key);

  @override
  State<WindowListenerApp> createState() => _WindowListenerAppState();
}

class _WindowListenerAppState extends State<WindowListenerApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // 3. Gracefully kill the daemon when window closes
    widget.lifecycleManager.stopDaemon();
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppNavigationProvider()),
        Provider.value(value: widget.lifecycleManager),
        Provider(create: (_) => DaemonService(apiPort: widget.lifecycleManager.apiPort ?? 8082)),
        ChangeNotifierProxyProvider<DaemonService, NetworkStateProvider>(
          create: (ctx) => NetworkStateProvider(ctx.read<DaemonService>()),
          update: (_, svc, prev) => prev ?? NetworkStateProvider(svc),
        ),
      ],
      child: const MicroCdnApp(),
    );
  }
}

class MicroCdnApp extends StatelessWidget {
  const MicroCdnApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bharat-Acadamia | Micro-CDN Monitor',
      debugShowCheckedModeBanner: false,
      scrollBehavior: MyCustomScrollBehavior(),
      theme: AppTheme.dark,
      home: const RootShell(),
    );
  }
}
