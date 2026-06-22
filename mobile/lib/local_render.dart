import 'dart:io';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart'
    show consolidateHttpClientResponseBytes;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'config.dart';

/// 온디바이스 렌더용 한 줄(컷+대사+녹음)
class RenderLine {
  final String imageUrl;
  final String speaker;
  final String direction;
  final String text;
  final Color color;
  final String audioPath;
  final int durationMs;

  RenderLine({
    required this.imageUrl,
    required this.speaker,
    required this.direction,
    required this.text,
    required this.color,
    required this.audioPath,
    required this.durationMs,
  });
}

/// 폰에서 직접 장면 이미지 + 자막 + 녹음을 합쳐 mp4 생성 (ffmpeg)
class LocalRender {
  static const int w = 720;
  static const int h = 1280;

  /// onProgress: 0~1
  static Future<String> render(
    List<RenderLine> lines, {
    void Function(double)? onProgress,
  }) async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory(
      '${tmp.path}/render_${DateTime.now().millisecondsSinceEpoch}',
    );
    await dir.create();

    final imageCache = <String, ui.Image?>{};
    final segs = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      // 1) 프레임 PNG 합성 (Flutter 캔버스)
      final scene = imageCache.containsKey(line.imageUrl)
          ? imageCache[line.imageUrl]
          : (imageCache[line.imageUrl] = await _loadImage(line.imageUrl));
      final framePath = '${dir.path}/frame_$i.png';
      await _composeFrame(line, scene, framePath);

      // 2) PNG + 녹음 → mp4 세그먼트
      final seg = '${dir.path}/seg_$i.mp4';
      final dur = (line.durationMs / 1000).clamp(0.4, 60.0);
      final cmd =
          "-y -loop 1 -i '$framePath' -i '${line.audioPath}' "
          "-t $dur -r 24 -c:v mpeg4 -q:v 4 -pix_fmt yuv420p "
          "-c:a aac -b:a 128k -ar 44100 -shortest '$seg'";
      final ok = await _run(cmd);
      if (!ok) {
        throw Exception('세그먼트 $i 생성 실패');
      }
      segs.add(seg);
      onProgress?.call((i + 1) / (lines.length + 1));
    }

    // 3) 세그먼트 이어붙이기
    final listFile = File('${dir.path}/list.txt');
    await listFile.writeAsString(segs.map((s) => "file '$s'").join('\n'));
    final out = '${dir.path}/dubbingo.mp4';
    var ok = await _run(
      "-y -f concat -safe 0 -i '${listFile.path}' -c copy '$out'",
    );
    if (!ok) {
      // copy 실패 시 재인코딩으로 이어붙이기
      ok = await _run(
        "-y -f concat -safe 0 -i '${listFile.path}' "
        "-c:v mpeg4 -q:v 4 -pix_fmt yuv420p -c:a aac -b:a 128k '$out'",
      );
      if (!ok) throw Exception('이어붙이기 실패');
    }
    onProgress?.call(1.0);
    return out;
  }

  static Future<bool> _run(String cmd) async {
    final session = await FFmpegKit.execute(cmd);
    final rc = await session.getReturnCode();
    return ReturnCode.isSuccess(rc);
  }

  static Future<ui.Image?> _loadImage(String url) async {
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close();
      final bytes = await consolidateHttpClientResponseBytes(resp);
      client.close();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _composeFrame(
    RenderLine line,
    ui.Image? scene,
    String outPath,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    );
    final size = Size(w.toDouble(), h.toDouble());

    // 배경
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.deviceDark);

    // 장면 이미지 (cover)
    if (scene != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        scene.width.toDouble(),
        scene.height.toDouble(),
      );
      final fitted = _coverRect(
        Size(scene.width.toDouble(), scene.height.toDouble()),
        size,
      );
      canvas.drawImageRect(scene, src, fitted, Paint());
    }

    // 하단 그라데이션 스크림
    final scrim = Rect.fromLTWH(0, h * 0.45, w.toDouble(), h * 0.55);
    canvas.drawRect(
      scrim,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.45),
          Offset(0, h.toDouble()),
          const [Color(0x00000000), Color(0xCC000000), Color(0xF2000000)],
          const [0.0, 0.5, 1.0],
        ),
    );

    // 자막 블록 (하단)
    const pad = 48.0;
    final maxTextW = w - pad * 2;
    var y = h - 70.0;

    // 메인 대사 (아래에서부터 쌓기 위해 높이 계산)
    final textTp = _tp(
      line.text,
      const TextStyle(
        color: Colors.white,
        fontSize: 46,
        fontWeight: FontWeight.w900,
        height: 1.25,
        shadows: [
          Shadow(color: Colors.black, blurRadius: 12, offset: Offset(0, 2)),
        ],
      ),
      maxTextW,
      TextAlign.center,
    );
    final speakerTp = _tp(
      line.speaker,
      const TextStyle(
        color: AppColors.gold,
        fontSize: 24,
        fontWeight: FontWeight.w900,
        shadows: [Shadow(color: Colors.black, blurRadius: 8)],
      ),
      maxTextW,
      TextAlign.center,
    );
    final dirTp = line.direction.isEmpty
        ? null
        : _tp(
            line.direction,
            const TextStyle(
              color: Colors.white70,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              height: 1.3,
              shadows: [Shadow(color: Colors.black, blurRadius: 6)],
            ),
            maxTextW,
            TextAlign.center,
            maxLines: 2,
          );

    // 아래→위 순서로 배치: [대사] 위에 [지문] 위에 [화자]
    y -= textTp.height;
    textTp.paint(canvas, Offset((w - textTp.width) / 2, y));
    if (dirTp != null) {
      y -= dirTp.height + 14;
      dirTp.paint(canvas, Offset((w - dirTp.width) / 2, y));
    }
    y -= speakerTp.height + 14;
    speakerTp.paint(canvas, Offset((w - speakerTp.width) / 2, y));

    final pic = recorder.endRecording();
    final image = await pic.toImage(w, h);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(outPath).writeAsBytes(png!.buffer.asUint8List());
  }

  static TextPainter _tp(
    String text,
    TextStyle style,
    double maxW,
    TextAlign align, {
    int? maxLines,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines != null ? '…' : null,
    )..layout(maxWidth: maxW);
    return tp;
  }

  static Rect _coverRect(Size src, Size dst) {
    final scaleW = dst.width / src.width;
    final scaleH = dst.height / src.height;
    final s = scaleW > scaleH ? scaleW : scaleH;
    final dw = src.width * s;
    final dh = src.height * s;
    final dx = (dst.width - dw) / 2;
    final dy = (dst.height - dh) / 2;
    return Rect.fromLTWH(dx, dy, dw, dh);
  }
}
