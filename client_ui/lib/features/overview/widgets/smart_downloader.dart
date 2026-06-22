import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/daemon_lifecycle_manager.dart';

class SmartDownloader extends StatefulWidget {
  const SmartDownloader({super.key});

  @override
  State<SmartDownloader> createState() => _SmartDownloaderState();
}

class _SmartDownloaderState extends State<SmartDownloader> {
  final _urlController = TextEditingController();
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _downloadedFilePath;

  Future<void> _startDownload() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final proxyPort = context.read<DaemonLifecycleManager>().proxyPort ?? 8081;

    if (kIsWeb) {
      final proxyUrl = 'http://localhost:$proxyPort/?url=${Uri.encodeComponent(url)}';
      setState(() {
        _isDownloading = true;
        _progress = 0.5;
      });
      try {
        final request = http.Request('GET', Uri.parse(proxyUrl));
        await http.Client().send(request);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Triggered Backend via Web Bypass!')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Web download trigger failed: $e')));
        }
      } finally {
        setState(() {
          _isDownloading = false;
          _progress = 0.0;
        });
      }
      return;
    }

    final outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Download As',
      fileName: url.split('/').last.split('?').first.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_'),
    );

    if (outputFile == null) return; // User canceled

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _downloadedFilePath = null;
    });

    final proxyUrl = 'http://localhost:$proxyPort/?url=${Uri.encodeComponent(url)}';
    
    try {
      final request = http.Request('GET', Uri.parse(proxyUrl));
      final response = await http.Client().send(request);
      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final file = File(outputFile);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          setState(() {
            _progress = receivedBytes / totalBytes;
          });
        }
      }

      await sink.close();

      setState(() {
        _isDownloading = false;
        _progress = 1.0;
        _downloadedFilePath = outputFile;
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
  }

  void _showInFolder() {
    if (_downloadedFilePath != null && !kIsWeb) {
      Process.run('explorer.exe', ['/select,', _downloadedFilePath!]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_download_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 10),
              const Text('Smart Downloader', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Route downloads explicitly through the Micro-CDN daemon tollbooth.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Paste origin URL here...',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.bg0,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border1)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border1)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isDownloading ? null : _startDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Download', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          if (_isDownloading) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: AppColors.bg0,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text('Downloading... ${(_progress * 100).toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ] else if (_downloadedFilePath != null) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _showInFolder,
              icon: const Icon(Icons.folder_open_rounded, size: 16, color: AppColors.textPrimary),
              label: const Text('Show in Folder'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.border2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
