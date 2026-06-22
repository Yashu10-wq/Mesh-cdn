import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/network_state_provider.dart';
import '../../../core/services/daemon_service.dart';

class NetworkMapPage extends StatefulWidget {
  const NetworkMapPage({super.key});

  @override
  State<NetworkMapPage> createState() => _NetworkMapPageState();
}

class _NetworkMapPageState extends State<NetworkMapPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NetworkStateProvider>().fetchPeers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NetworkStateProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Network Map',
            style: TextStyle(color: AppColors.textPrimary,
              fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 3),
          const Text('All peers currently visible to the central tracker.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 20),
          Divider(height: 1, color: AppColors.border1),
          const SizedBox(height: 20),
          state.peersLoading
              ? const Expanded(child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppColors.accent)))
              : Expanded(child: _PeerTable(peers: state.peers)),
        ],
      ),
    );
  }
}

class _PeerTable extends StatelessWidget {
  final List<PeerNode> peers;
  const _PeerTable({required this.peers});

  Color _statusColor(String s) {
    switch (s) {
      case 'online':   return AppColors.positive;
      case 'degraded': return AppColors.warning;
      default:         return AppColors.offline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border1),
      ),
      child: Column(children: [
        // Header Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border(bottom: BorderSide(color: AppColors.border1)),
          ),
          child: const Row(children: [
            Expanded(flex: 3, child: _H('PEER ID')),
            Expanded(flex: 2, child: _H('IP ADDRESS')),
            Expanded(flex: 1, child: _H('PORT')),
            Expanded(flex: 1, child: _H('CHUNKS')),
            Expanded(flex: 1, child: _H('LATENCY')),
            Expanded(flex: 1, child: _H('STATUS')),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: peers.length,
            itemBuilder: (_, i) => _PeerRow(
              peer: peers[i],
              statusColor: _statusColor(peers[i].status),
              isLast: i == peers.length - 1,
            ),
          ),
        ),
      ]),
    );
  }
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(color: AppColors.textDisabled, fontSize: 10,
      fontWeight: FontWeight.w700, letterSpacing: 0.8));
}

class _PeerRow extends StatefulWidget {
  final PeerNode peer;
  final Color statusColor;
  final bool isLast;
  const _PeerRow({required this.peer, required this.statusColor, required this.isLast});
  @override
  State<_PeerRow> createState() => _PeerRowState();
}
class _PeerRowState extends State<_PeerRow> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final latencyColor = widget.peer.latencyMs < 30 ? AppColors.positive
        : widget.peer.latencyMs < 80 ? AppColors.warning : AppColors.danger;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? AppColors.bg3 : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(children: [
          Expanded(flex: 3, child: Text(widget.peer.peerId,
            style: const TextStyle(color: AppColors.textSecondary,
              fontFamily: 'monospace', fontSize: 12))),
          Expanded(flex: 2, child: Text(widget.peer.ip,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
          Expanded(flex: 1, child: Text('${widget.peer.daemonPort}',
            style: const TextStyle(color: AppColors.textMuted,
              fontFamily: 'monospace', fontSize: 12))),
          Expanded(flex: 1, child: Text('${widget.peer.chunksHeld}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
          Expanded(flex: 1, child: Text('${widget.peer.latencyMs} ms',
            style: TextStyle(color: latencyColor, fontFamily: 'monospace',
              fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(flex: 1, child: Row(children: [
            Container(width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: widget.statusColor)),
            const SizedBox(width: 8),
            Text(widget.peer.status,
              style: TextStyle(color: widget.statusColor,
                fontSize: 12, fontWeight: FontWeight.w500)),
          ])),
        ]),
      ),
    );
  }
}
