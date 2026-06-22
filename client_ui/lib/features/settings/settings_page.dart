import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/network_state_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NetworkStateProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settings',
              style: TextStyle(color: AppColors.textPrimary,
                fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            const SizedBox(height: 3),
            const Text('Configure daemon and proxy behavior.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 20),
            Divider(height: 1, color: AppColors.border1),
            const SizedBox(height: 28),

            // ── Network ──────────────────────────────────────────────────────
            _SectionLabel('Network'),
            const SizedBox(height: 12),
            _Toggle(
              label: 'Auto-Reconnect to Tracker',
              description: 'Re-attempt tracker connection every 5 s on drop.',
              value: state.autoReconnect,
              onChanged: (v) => state.updateSetting('autoReconnect', v),
            ),
            const SizedBox(height: 8),
            _Toggle(
              label: 'Heartbeat / Zombie Detection',
              description: 'Ping-pong every 30 s to evict stale peer connections.',
              value: state.heartbeatEnabled,
              onChanged: (v) => state.updateSetting('heartbeatEnabled', v),
            ),
            const SizedBox(height: 28),

            // ── Ports ────────────────────────────────────────────────────────
            _SectionLabel('Ports'),
            const SizedBox(height: 12),
            _InfoRow(label: 'HTTP Proxy Port',
              value: '${state.proxyPort}',
              hint: 'PROXY_PORT env var'),
            const SizedBox(height: 8),
            _InfoRow(label: 'gRPC Daemon Port',
              value: '${state.daemonPort}',
              hint: 'DAEMON_PORT env var'),
            const SizedBox(height: 28),

            // ── Integration ──────────────────────────────────────────────────
            _SectionLabel('Backend Integration'),
            const SizedBox(height: 12),
            _InfoRow(label: 'Tracker WebSocket',
              value: 'ws://localhost:8080',
              hint: 'TRACKER_URL env var'),
            const SizedBox(height: 8),
            _InfoRow(label: 'Stats REST Endpoint',
              value: 'http://localhost:8082/stats',
              hint: 'Wire to DaemonService.fetchStats()'),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border1),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                    color: AppColors.textMuted, size: 15),
                  SizedBox(width: 10),
                  Expanded(child: Text(
                    'To connect to the real daemon, open lib/core/services/daemon_service.dart '
                    'and replace the dummy Future.delayed() blocks with real http.get() '
                    'and WebSocketChannel calls. All hooks are documented in that file.',
                    style: TextStyle(color: AppColors.textMuted,
                      fontSize: 12, height: 1.65))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
    style: const TextStyle(color: AppColors.textDisabled, fontSize: 10,
      fontWeight: FontWeight.w700, letterSpacing: 1.0));
}

class _Toggle extends StatelessWidget {
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.label, required this.description,
    required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border1),
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textPrimary,
              fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(description, style: const TextStyle(
              color: AppColors.textMuted, fontSize: 12, height: 1.4)),
          ],
        )),
        const SizedBox(width: 24),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  const _InfoRow({required this.label, required this.value, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border1),
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textPrimary,
              fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(hint, style: const TextStyle(
              color: AppColors.textMuted, fontSize: 12)),
          ],
        )),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.bg4,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.border2),
          ),
          child: Text(value,
            style: const TextStyle(color: AppColors.textSecondary,
              fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
