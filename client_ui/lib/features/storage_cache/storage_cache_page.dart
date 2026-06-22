import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/network_state_provider.dart';
import '../../../core/services/daemon_service.dart';

class StorageCachePage extends StatefulWidget {
  const StorageCachePage({super.key});

  @override
  State<StorageCachePage> createState() => _StorageCachePageState();
}

class _StorageCachePageState extends State<StorageCachePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NetworkStateProvider>().fetchChunks();
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
          Row(
            children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Storage Cache',
                  style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                SizedBox(height: 3),
                Text('Locally stored 1 MB chunks in .mesh_cache.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ]),
              const Spacer(),
              _CountBadge(count: state.chunks.length),
            ],
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: AppColors.border1),
          const SizedBox(height: 20),
          state.chunksLoading
              ? const Expanded(child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppColors.accent)))
              : Expanded(child: _ChunkTable(chunks: state.chunks)),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.bg3,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppColors.border1),
    ),
    child: Text('$count chunks  ·  $count MB',
      style: const TextStyle(color: AppColors.textSecondary,
        fontSize: 12, fontWeight: FontWeight.w500)));
}

class _ChunkTable extends StatelessWidget {
  final List<CacheChunk> chunks;
  const _ChunkTable({required this.chunks});

  @override
  Widget build(BuildContext context) {
    if (chunks.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_rounded, color: AppColors.textDisabled, size: 40),
        SizedBox(height: 10),
        Text('Cache is empty.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ]));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border1),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border(bottom: BorderSide(color: AppColors.border1)),
          ),
          child: const Row(children: [
            Expanded(flex: 3, child: _H('FILE')),
            Expanded(flex: 2, child: _H('CACHE KEY')),
            Expanded(flex: 1, child: _H('CHUNK')),
            Expanded(flex: 1, child: _H('SIZE')),
            Expanded(flex: 2, child: _H('CACHED')),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: chunks.length,
            itemBuilder: (_, i) => _ChunkRow(chunk: chunks[i]),
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

class _ChunkRow extends StatefulWidget {
  final CacheChunk chunk;
  const _ChunkRow({required this.chunk});
  @override
  State<_ChunkRow> createState() => _ChunkRowState();
}
class _ChunkRowState extends State<_ChunkRow> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(widget.chunk.cachedAt);
    final ageStr = age.inMinutes < 60 ? '${age.inMinutes}m ago' : '${age.inHours}h ago';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered ? AppColors.bg3 : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(children: [
          Expanded(flex: 3, child: Row(children: [
            const Icon(Icons.play_circle_outline_rounded,
              color: AppColors.textMuted, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.chunk.fileLabel,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              overflow: TextOverflow.ellipsis)),
          ])),
          Expanded(flex: 2, child: Text(widget.chunk.cacheKey,
            style: const TextStyle(color: AppColors.textMuted,
              fontFamily: 'monospace', fontSize: 11))),
          Expanded(flex: 1, child: Container(
            width: 40,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentFaint,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('#${widget.chunk.chunkIndex}',
              style: const TextStyle(color: AppColors.accentLight,
                fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600)))),
          Expanded(flex: 1, child: Text('${widget.chunk.sizeMB} MB',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(flex: 2, child: Text(ageStr,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12))),
        ]),
      ),
    );
  }
}
