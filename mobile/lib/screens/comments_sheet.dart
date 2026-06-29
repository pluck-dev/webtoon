import 'package:flutter/material.dart';
import '../widgets/app_widgets.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../cloud.dart';
import '../config.dart';
import '../models.dart';

/// 댓글 바텀시트를 띄우고, 닫힐 때 최종 댓글 수를 돌려준다(피드 배지 갱신용).
Future<int?> showCommentsSheet(
  BuildContext context,
  String episodeId,
  int initialCount,
) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _CommentsSheet(episodeId: episodeId, count: initialCount),
  );
}

class _CommentsSheet extends StatefulWidget {
  final String episodeId;
  final int count;
  const _CommentsSheet({required this.episodeId, required this.count});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _input = TextEditingController();
  List<CommentItem>? _comments;
  String? _myId;
  bool _sending = false;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final mine = await Cloud.myUserId();
      final list = await Cloud.fetchComments(widget.episodeId);
      if (mounted) {
        setState(() {
          _myId = mine;
          _comments = list;
          _loadError = false;
        });
      }
    } catch (_) {
      // 에러와 빈 목록을 구분: 실패 시 _loadError 플래그 사용
      if (mounted) setState(() => _loadError = true);
    }
  }

  int get _count => _comments?.length ?? widget.count;

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final c = await Cloud.addComment(widget.episodeId, text);
      _input.clear();
      HapticFeedback.lightImpact();
      if (mounted) {
        setState(() {
          _comments = [...?_comments, c];
          _sending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        showAppToast(context, '댓글을 등록하지 못했어요.');
      }
    }
  }

  Future<void> _delete(CommentItem c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          '댓글 삭제',
          style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w900),
        ),
        content: Text(
          '이 댓글을 삭제할까요?',
          style: GoogleFonts.notoSansKr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w800,
                color: AppColors.muted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '삭제',
              style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w900,
                color: AppColors.coral,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _comments = _comments?.where((x) => x.id != c.id).toList());
    try {
      await Cloud.deleteComment(c.id);
      HapticFeedback.selectionClick();
    } catch (_) {
      if (mounted) _load();
    }
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '방금';
    if (d.inMinutes < 60) return '${d.inMinutes}분 전';
    if (d.inHours < 24) return '${d.inHours}시간 전';
    if (d.inDays < 7) return '${d.inDays}일 전';
    return '${t.year}.${t.month}.${t.day}';
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Text(
                    '댓글',
                    style: GoogleFonts.notoSansKr(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_count',
                    style: GoogleFonts.notoSansKr(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: AppColors.coral,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.lineSoft),
            Expanded(child: _list()),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (_loadError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: AppColors.faint,
            ),
            const SizedBox(height: 10),
            Text(
              '댓글을 불러오지 못했어요.',
              style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w800,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _comments = null;
                  _loadError = false;
                });
                _load();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                '다시 시도',
                style: GoogleFonts.notoSansKr(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      );
    }
    if (_comments == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.coral),
      );
    }
    if (_comments!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mode_comment_outlined,
              size: 40,
              color: AppColors.faint,
            ),
            const SizedBox(height: 10),
            Text(
              '첫 댓글을 남겨보세요!',
              style: GoogleFonts.notoSansKr(
                fontWeight: FontWeight.w800,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _comments!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, i) => _row(_comments![i]),
    );
  }

  Widget _row(CommentItem c) {
    final mine = c.userId == _myId;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.teal,
            shape: BoxShape.circle,
          ),
          child: Text(
            c.author.isEmpty ? '?' : c.author.characters.first,
            style: GoogleFonts.notoSansKr(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    c.author,
                    style: GoogleFonts.notoSansKr(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _ago(c.createdAt),
                    style: GoogleFonts.notoSansKr(
                      fontSize: 11.5,
                      color: AppColors.faint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                c.text,
                style: GoogleFonts.notoSansKr(fontSize: 14, height: 1.35),
              ),
            ],
          ),
        ),
        if (mine)
          IconButton(
            onPressed: () => _delete(c),
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AppColors.faint,
            ),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: EdgeInsets.zero,
          ),
      ],
    );
  }

  Widget _inputBar() => Container(
    padding: EdgeInsets.fromLTRB(
      12,
      8,
      12,
      8 + MediaQuery.of(context).padding.bottom,
    ),
    decoration: const BoxDecoration(
      color: AppColors.card,
      border: Border(top: BorderSide(color: AppColors.lineSoft)),
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _input,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: GoogleFonts.notoSansKr(fontSize: 14),
            decoration: InputDecoration(
              hintText: '댓글 달기…',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              filled: true,
              fillColor: AppColors.cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: AppColors.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: AppColors.line),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _send,
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
            ),
            child: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.paper,
                    ),
                  )
                : const Icon(
                    Icons.arrow_upward_rounded,
                    color: AppColors.gold,
                    size: 22,
                  ),
          ),
        ),
      ],
    ),
  );
}
