import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../config.dart';

void showVideoSheet(BuildContext context, String url) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.panelDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _VideoSheet(url: url),
  );
}

class _VideoSheet extends StatefulWidget {
  final String url;
  const _VideoSheet({required this.url});

  @override
  State<_VideoSheet> createState() => _VideoSheetState();
}

class _VideoSheetState extends State<_VideoSheet> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  bool get _isLocal => !widget.url.startsWith('http');

  Future<void> _init() async {
    final c = _isLocal
        ? VideoPlayerController.file(File(widget.url))
        : VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      if (mounted) {
        setState(() {
          _controller = c;
          _ready = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      String filePath;
      if (_isLocal) {
        filePath = widget.url; // 폰에서 만든 로컬 파일 그대로 공유
      } else {
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/dubbingo_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse(widget.url));
        final resp = await req.close();
        final sink = file.openWrite();
        await resp.pipe(sink);
        client.close();
        filePath = file.path;
      }
      await Share.shareXFiles([
        XFile(filePath, mimeType: 'video/mp4'),
      ], text: '더빙고로 만든 내 더빙 영상 🎬');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('영상을 준비하지 못했어요. 잠시 후 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            children: [
              Text(
                '완성된 영상 🎬',
                style: GoogleFonts.notoSansKr(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: Container(
                color: Colors.black,
                child: !_ready
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      )
                    : _controller != null && _controller!.value.isInitialized
                    ? GestureDetector(
                        onTap: () => setState(() {
                          _controller!.value.isPlaying
                              ? _controller!.pause()
                              : _controller!.play();
                        }),
                        child: VideoPlayer(_controller!),
                      )
                    : const Center(
                        child: Text(
                          '영상을 불러오지 못했어요.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sharing ? null : _share,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.ink,
                minimumSize: const Size.fromHeight(52),
              ),
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.ink,
                      ),
                    )
                  : const Icon(Icons.ios_share_rounded, size: 20),
              label: Text(
                _sharing ? '준비 중…' : '공유 · 저장',
                style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '보관함에서 언제든 다시 볼 수 있어요.',
            style: GoogleFonts.notoSansKr(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
