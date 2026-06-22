import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
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
          const SizedBox(height: 14),
          Text(
            '마이페이지에서 다시 볼 수 있어요.',
            style: GoogleFonts.notoSansKr(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
