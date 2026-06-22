import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/daemon_service.dart';
import '../../../providers/network_state_provider.dart';
import '../shared/widgets/stat_card.dart';
import 'widgets/smart_downloader.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<NetworkStateProvider>();
      p.fetchStats();
      p.startLogStream();
    });
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        context.read<NetworkStateProvider>().fetchStats();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NetworkStateProvider>();
    final stats = state.stats;

    return CustomScrollView(
      slivers: [
        // ── Header ────────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overview',
                      style: TextStyle(color: AppColors.textPrimary,
                        fontSize: 22, fontWeight: FontWeight.w700,
                        letterSpacing: -0.5)),
                    SizedBox(height: 3),
                    Text('Live telemetry from your local daemon.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                _StatusBadge(running: stats?.daemonRunning ?? false),
                const SizedBox(width: 10),
                _RefreshButton(onTap: () {
                  state.fetchStats();
                  state.startLogStream();
                }),
              ],
            ),
          ),
        ),

        // ── Divider ──────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 0),
            child: Divider(height: 1, color: AppColors.border1),
          ),
        ),

        // ── Smart Downloader ──────────────────────────────────────────────────
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(32, 24, 32, 0),
            child: SmartDownloader(),
          ),
        ),

        // ── Metrics Grid ─────────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
          sliver: state.statsLoading
              ? const SliverToBoxAdapter(
                  child: SizedBox(height: 180,
                    child: Center(child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppColors.accent))))
              : SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 2.6,
                  ),
                  delegate: SliverChildListDelegate([
                    StatCard(
                      title: 'Active Peers',
                      value: '${stats?.activePeers ?? 0}',
                      subValue: '${stats?.activePeers ?? 0} nodes in swarm',
                      icon: Icons.hub_outlined,
                      accentColor: AppColors.accent,
                    ),
                    StatCard(
                      title: 'Bandwidth Saved',
                      value: '${stats?.bandwidthSavedMB.toStringAsFixed(1) ?? 0} MB',
                      subValue: 'Diverted from origin server',
                      icon: Icons.data_usage_rounded,
                      accentColor: AppColors.info,
                    ),
                    StatCard(
                      title: 'Cache Chunks',
                      value: '${stats?.cacheChunks ?? 0}',
                      subValue: '${stats?.cacheChunks ?? 0} MB local disk',
                      icon: Icons.memory_rounded,
                      accentColor: AppColors.positive,
                    ),
                    StatCard(
                      title: 'P2P Hit Rate',
                      value: '${stats?.p2pHitRate.toStringAsFixed(1) ?? 0}%',
                      subValue: 'Swarm serving majority of requests',
                      icon: Icons.speed_rounded,
                      accentColor: AppColors.warning,
                    ),
                  ]),
                ),
        ),

        // ── Latency Bar ───────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
            child: _LatencyBar(latency: stats?.networkLatencyMs),
          ),
        ),

        // ── Live Transfer Feed ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
            child: _LiveTransferFeed(recent: stats?.recentDownloads ?? []),
          ),
        ),
      ],
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final bool running;
  const _StatusBadge({required this.running});

  @override
  Widget build(BuildContext context) {
    final color = running ? AppColors.positive : AppColors.danger;
    final faint = running ? AppColors.positiveFaint : AppColors.dangerFaint;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: faint,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _PulsingDot(color: color),
        const SizedBox(width: 7),
        Text(running ? 'Online' : 'Daemon Offline',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Pulsing Dot ───────────────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}
class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(width: 7, height: 7,
      decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)));
}

// ── Refresh Button ────────────────────────────────────────────────────────────
class _RefreshButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RefreshButton({required this.onTap});
  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}
class _RefreshButtonState extends State<_RefreshButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.bg3 : AppColors.bg2,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: _hovered ? AppColors.border2 : AppColors.border1),
          ),
          child: const Row(children: [
            Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 15),
            SizedBox(width: 6),
            Text('Refresh',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

// ── Latency Bar ───────────────────────────────────────────────────────────────
class _LatencyBar extends StatelessWidget {
  final double? latency;
  const _LatencyBar({this.latency});

  Color get _color {
    if (latency == null) return AppColors.textMuted;
    if (latency! < 30) return AppColors.positive;
    if (latency! < 80) return AppColors.warning;
    return AppColors.danger;
  }

  String get _label {
    if (latency == null) return 'Measuring…';
    if (latency! < 30) return 'Excellent';
    if (latency! < 80) return 'Fair';
    return 'Poor';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border1),
      ),
      child: Row(children: [
        Icon(Icons.bolt_rounded, color: _color, size: 17),
        const SizedBox(width: 10),
        const Text('Network Latency',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(width: 14),
        Text(
          latency != null ? '${latency!.toStringAsFixed(1)} ms' : '—',
          style: TextStyle(color: _color, fontSize: 13,
            fontWeight: FontWeight.w700, fontFamily: 'monospace')),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(_label,
            style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _LiveTransferFeed extends StatelessWidget {
  final List<RecentDownload> recent;
  const _LiveTransferFeed({required this.recent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg0,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: AppColors.border1)),
            ),
            child: const Text('Live Transfer Feed (Proof of Origin)',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No recent transfers.', style: TextStyle(color: AppColors.textMuted))),
            )
          else
            Column(
              children: recent.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                
                final isLocal = item.source.toLowerCase().contains('local cache');
                final isP2p = RegExp(r'^from \d+\.\d+\.\d+\.\d+').hasMatch(item.source);
                
                final badgeColor = isLocal ? AppColors.info : (isP2p ? AppColors.positive : AppColors.warning);
                final badgeText = isLocal ? 'LOCAL CACHE' : (isP2p ? 'P2P NETWORK' : 'ORIGIN SERVER');
                final timeStr = DateTime.tryParse(item.time)?.toLocal().toString().split('.').first ?? item.time;
                
                final row = Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.download_rounded, color: AppColors.textMuted, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.file, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Text('Chunk ${item.chunk} • ${item.source} • $timeStr', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(badgeText, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );

                if (i != recent.length - 1) {
                  return Column(children: [row, Divider(height: 1, color: AppColors.border1)]);
                }
                return row;
              }).toList(),
            ),
        ],
      ),
    );
  }
}
