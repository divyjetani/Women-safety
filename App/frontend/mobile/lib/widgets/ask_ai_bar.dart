import 'dart:async';
import 'package:flutter/material.dart';
import '../app/theme.dart';
import '../services/api_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class AskAIBar extends StatefulWidget {
  final int userId;
  final String username;

  const AskAIBar({
    super.key,
    required this.userId,
    required this.username,
  });

  @override
  State<AskAIBar> createState() => _AskAIBarState();
}

class _AskAIBarState extends State<AskAIBar> {
  final TextEditingController _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _askAI({required bool detailed}) async {
    final question = _ctrl.text.trim();
    if (question.isEmpty) return;

    setState(() => _sending = true);

    try {
      final res = await ApiService.askAI(
        userId: widget.userId,
        question: question,
        detailed: detailed,
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() => _sending = false);

      final shortAnswer = (res["short_answer"] ?? "").toString();
      final detailedAnswer = (res["detailed_answer"] ?? "").toString();
      final tips = (res["tips"] is List) ? List<String>.from(res["tips"]) : <String>[];

      _openAIAnswerSheet(
        question: question,
        shortAnswer: shortAnswer,
        detailedAnswer: detailedAnswer,
        tips: tips,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);

      _openAIErrorSheet(
        error: e.toString(),
        onRetry: () => _askAI(detailed: detailed),
      );
    }
  }

  void _openAIAnswerSheet({
    required String question,
    required String shortAnswer,
    required String detailedAnswer,
    required List<String> tips,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AIAnswerSheet(
        question: question,
        shortAnswer: shortAnswer,
        detailedAnswer: detailedAnswer,
        tips: tips,
        onGetDetailed: () async {
          Navigator.pop(context);
          await _askAI(detailed: true);
        },
      ),
    );
  }

  void _openAIErrorSheet({
    required String error,
    required VoidCallback onRetry,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AIErrorSheet(
        message: error,
        onRetry: onRetry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: AppTheme.accentColor),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: TextField(
              controller: _ctrl,
              enabled: !_sending,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _askAI(detailed: false),
              decoration: InputDecoration(
                hintText: "Ask AI for help… (safety, app, anything)",
                hintStyle: txt.bodyMedium?.copyWith(
                  color: txt.bodyMedium?.color?.withOpacity(0.55),
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
              ),
              style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),

          const SizedBox(width: 8),

          InkWell(
            onTap: _sending ? null : () => _askAI(detailed: false),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _sending ? Colors.grey.withOpacity(0.25) : AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _sending
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// ======================================================
/// ✅ Animated Answer Sheet
/// ======================================================
class _AIAnswerSheet extends StatefulWidget {
  final String question;
  final String shortAnswer;
  final String detailedAnswer;
  final List<String> tips;
  final VoidCallback onGetDetailed;

  const _AIAnswerSheet({
    required this.question,
    required this.shortAnswer,
    required this.detailedAnswer,
    required this.tips,
    required this.onGetDetailed,
  });

  @override
  State<_AIAnswerSheet> createState() => _AIAnswerSheetState();
}

class _AIAnswerSheetState extends State<_AIAnswerSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
    );
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final bool hasDetailed = widget.detailedAnswer.trim().isNotEmpty;

    // ✅ show only short answer if detailed not present
    final String displayShort = widget.shortAnswer.trim().isEmpty
        ? "No answer returned."
        : widget.shortAnswer.trim();

    return DraggableScrollableSheet(
      initialChildSize: hasDetailed ? 0.85 : 0.62,
      minChildSize: 0.40,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Container(
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 22,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // ✅ Drag handle
                    Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).textTheme.bodySmall!.color!.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),

                    // ✅ Header
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            // color: AppTheme.primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "AI Assistant",
                                style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.accentColor.withOpacity(0.18),
                                      AppTheme.primaryColor.withOpacity(0.14),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  hasDetailed ? "Detailed Answer" : "Quick Answer",
                                  style: txt.bodySmall?.copyWith(fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // ✅ Body scrollable (NO overflow)
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // ✅ Question
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              widget.question,
                              style: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ✅ Answer Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.accentColor.withOpacity(0.12),
                                  AppTheme.primaryColor.withOpacity(0.10),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.14),
                              ),
                            ),
                            child: hasDetailed
                                ? _MarkdownAnswer(text: widget.detailedAnswer.trim())
                                : Text(
                              displayShort,
                              style: txt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ✅ Tips Chips only in short mode
                          if (!hasDetailed && widget.tips.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: widget.tips.take(4).map((t) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).scaffoldBackgroundColor,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    t,
                                    style: txt.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                            ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    // ✅ Buttons
                    if (!hasDetailed)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: widget.onGetDetailed,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text("Detailed info"),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text("Done"),
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            minimumSize: const Size(double.infinity, 52),
                          ),
                          child: const Text("Done"),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MarkdownAnswer extends StatelessWidget {
  final String text;
  const _MarkdownAnswer({required this.text});

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return MarkdownBody(
      data: text,
      selectable: true, // ✅ user can copy text
      styleSheet: MarkdownStyleSheet(
        p: txt.bodyMedium?.copyWith(height: 1.35, fontWeight: FontWeight.w600),
        h1: txt.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        h2: txt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        h3: txt.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
        code: txt.bodySmall?.copyWith(
          fontFamily: "monospace",
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
        blockquoteDecoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.12)),
        ),
        blockquotePadding: const EdgeInsets.all(12),
        listBullet: txt.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
      softLineBreak: true,
    );
  }
}


/// ======================================================
/// ✅ Error sheet with Retry
/// ======================================================
class _AIErrorSheet extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AIErrorSheet({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: AppTheme.dangerColor, size: 44),
            const SizedBox(height: 10),
            Text(
              "AI request failed",
              style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: txt.bodySmall?.copyWith(color: txt.bodySmall?.color?.withOpacity(0.7)),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(
                        color: AppTheme.primaryColor,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // 👈 adjust radius here
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onRetry();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Retry"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
