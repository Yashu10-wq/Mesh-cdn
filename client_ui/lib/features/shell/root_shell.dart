import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/navigation_provider.dart';
import '../../features/overview/overview_page.dart';
import '../../features/network_map/network_map_page.dart';
import '../../features/storage_cache/storage_cache_page.dart';
import '../../features/settings/settings_page.dart';
import '../../providers/network_state_provider.dart';

class RootShell extends StatelessWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg1,
      body: Row(
        children: [
          const _Sidebar(),
          VerticalDivider(width: 1, color: AppColors.border1),
          const Expanded(child: _PageContent()),
        ],
      ),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  const _Sidebar();

  static const _items = [
    _NavItem(page: NavPage.overview,     icon: Icons.grid_view_rounded,  label: 'Overview'),
    _NavItem(page: NavPage.networkMap,   icon: Icons.hub_outlined,       label: 'Network Map'),
    _NavItem(page: NavPage.storageCache, icon: Icons.storage_rounded,    label: 'Storage Cache'),
    _NavItem(page: NavPage.settings,     icon: Icons.settings_outlined,  label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<AppNavigationProvider>();
    final networkState = context.watch<NetworkStateProvider>();
    final isOnline = networkState.stats?.daemonRunning ?? false;
    final color = isOnline ? AppColors.positive : AppColors.danger;

    return Container(
      width: 236,
      color: AppColors.bg2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.share_rounded,
                  color: Colors.white, size: 16),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bharat-Acadamia',
                    style: TextStyle(color: AppColors.textPrimary,
                      fontSize: 13, fontWeight: FontWeight.w600,
                      letterSpacing: -0.2)),
                  SizedBox(height: 1),
                  Text('Micro-CDN Monitor',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ]),
          ),
          Divider(height: 1, color: AppColors.border1),
          const SizedBox(height: 8),
          // ── Nav Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: _items.map((item) => _SidebarTile(
                item: item,
                isActive: nav.currentPage == item.page,
              )).toList(),
            ),
          ),
          const Spacer(),
          Divider(height: 1, color: AppColors.border1),
          // ── Footer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppColors.positiveFaint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline_rounded,
                  color: AppColors.positive, size: 15),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Local Node',
                  style: TextStyle(color: AppColors.textSecondary,
                    fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Row(children: [
                  _Dot(color: color),
                  const SizedBox(width: 5),
                  Text(isOnline ? 'Online' : 'Offline',
                    style: TextStyle(color: color, fontSize: 11)),
                ]),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 6, height: 6,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

class _NavItem {
  final NavPage page;
  final IconData icon;
  final String label;
  const _NavItem({required this.page, required this.icon, required this.label});
}

class _SidebarTile extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  const _SidebarTile({required this.item, required this.isActive});
  @override
  State<_SidebarTile> createState() => _SidebarTileState();
}

class _SidebarTileState extends State<_SidebarTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => context.read<AppNavigationProvider>().navigate(widget.item.page),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.accentFaint
                : _hovered ? AppColors.bg3 : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: widget.isActive
                  ? AppColors.accent.withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(children: [
            Icon(widget.item.icon, size: 16,
              color: widget.isActive ? AppColors.accentLight
                   : _hovered ? AppColors.textSecondary
                   : AppColors.textMuted),
            const SizedBox(width: 10),
            Text(widget.item.label,
              style: TextStyle(
                color: widget.isActive ? AppColors.accentLight
                     : _hovered ? AppColors.textPrimary
                     : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
              )),
          ]),
        ),
      ),
    );
  }
}

// ── Page Content ──────────────────────────────────────────────────────────────
class _PageContent extends StatelessWidget {
  const _PageContent();

  @override
  Widget build(BuildContext context) {
    final page = context.watch<AppNavigationProvider>().currentPage;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.01, 0), end: Offset.zero).animate(anim),
          child: child),
      ),
      child: _buildPage(page),
    );
  }

  Widget _buildPage(NavPage page) {
    switch (page) {
      case NavPage.overview:     return const OverviewPage(key: ValueKey('overview'));
      case NavPage.networkMap:   return const NetworkMapPage(key: ValueKey('network'));
      case NavPage.storageCache: return const StorageCachePage(key: ValueKey('cache'));
      case NavPage.settings:     return const SettingsPage(key: ValueKey('settings'));
    }
  }
}
