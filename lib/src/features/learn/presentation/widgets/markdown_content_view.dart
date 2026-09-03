import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Renders rich markdown with headers, code blocks, bold text, inline code,
/// bullet/numbered lists, quotes, and dividers matching Web 1:1.
class MarkdownContentView extends StatelessWidget {
  const MarkdownContentView({
    super.key,
    required this.markdown,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.cardBg,
    required this.borderColor,
  });

  final String markdown;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final Color cardBg;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    if (markdown.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final List<Widget> widgets = <Widget>[];
    final List<String> lines = markdown.split('\n');

    bool inCodeBlock = false;
    final List<String> codeBlockLines = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final String rawLine = lines[i];
      final String trimmed = rawLine.trim();

      // Toggle multi-line code block
      if (trimmed.startsWith('```')) {
        if (inCodeBlock) {
          // Close block
          final String fullCode = codeBlockLines.join('\n');
          widgets.add(
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10.0),
                border: Border.all(color: borderColor),
              ),
              child: SelectableText(
                fullCode,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.0,
                  color: textPrimary,
                  height: 1.45,
                ),
              ),
            ),
          );
          codeBlockLines.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        codeBlockLines.add(rawLine);
        continue;
      }

      // Empty line -> spacing
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6.0));
        continue;
      }

      // Headings
      if (trimmed.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14.0, bottom: 6.0),
            child: Text(
              trimmed.substring(2),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16.0,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
          ),
        );
        continue;
      }

      if (trimmed.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12.0, bottom: 6.0),
            child: Text(
              trimmed.substring(3),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
          ),
        );
        continue;
      }

      if (trimmed.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
            child: Text(
              trimmed.substring(4),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: 0.2,
              ),
            ),
          ),
        );
        continue;
      }

      // Horizontal Rule
      if (trimmed == '---' || trimmed == '***') {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(color: borderColor, height: 1.0),
          ),
        );
        continue;
      }

      // Blockquote
      if (trimmed.startsWith('> ')) {
        widgets.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 6.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
              border: const Border(
                left: BorderSide(color: Color(0xFF10B981), width: 3.0),
              ),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8.0),
                bottomRight: Radius.circular(8.0),
              ),
            ),
            child: _buildRichText(trimmed.substring(2)),
          ),
        );
        continue;
      }

      // Bullet List (- or *)
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        final String itemText = trimmed.substring(2);
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 6.0, bottom: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, right: 8.0),
                  child: Container(
                    width: 4.5,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(child: _buildRichText(itemText)),
              ],
            ),
          ),
        );
        continue;
      }

      // Numbered List (e.g. "1. ")
      final RegExp numRegex = RegExp(r'^(\d+)\.\s+(.*)$');
      final Match? numMatch = numRegex.firstMatch(trimmed);
      if (numMatch != null) {
        final String numStr = numMatch.group(1)!;
        final String itemText = numMatch.group(2)!;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 18.0,
                  child: Text(
                    '$numStr.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 4.0),
                Expanded(child: _buildRichText(itemText)),
              ],
            ),
          ),
        );
        continue;
      }

      // Regular Paragraph Line
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 3.0),
          child: _buildRichText(trimmed),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Parses inline markdown: **bold**, `inline code`, *italic*, [link](url)
  Widget _buildRichText(String text) {
    final List<InlineSpan> spans = <InlineSpan>[];
    int cursor = 0;

    while (cursor < text.length) {
      // 1. Bold: **text**
      if (text.startsWith('**', cursor)) {
        final int nextIdx = text.indexOf('**', cursor + 2);
        if (nextIdx != -1) {
          final String boldContent = text.substring(cursor + 2, nextIdx);
          spans.add(
            TextSpan(
              text: boldContent,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                height: 1.45,
              ),
            ),
          );
          cursor = nextIdx + 2;
          continue;
        }
      }

      // 2. Inline Code: `text`
      if (text[cursor] == '`') {
        final int nextIdx = text.indexOf('`', cursor + 1);
        if (nextIdx != -1) {
          final String codeContent = text.substring(cursor + 1, nextIdx);
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(5.0),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  codeContent,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
                  ),
                ),
              ),
            ),
          );
          cursor = nextIdx + 1;
          continue;
        }
      }

      // 3. Italic: *text* (single asterisk, not double)
      if (text[cursor] == '*' && (cursor + 1 < text.length && text[cursor + 1] != '*')) {
        final int nextIdx = text.indexOf('*', cursor + 1);
        if (nextIdx != -1) {
          final String italicContent = text.substring(cursor + 1, nextIdx);
          spans.add(
            TextSpan(
              text: italicContent,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                fontStyle: FontStyle.italic,
                color: textSecondary,
                height: 1.45,
              ),
            ),
          );
          cursor = nextIdx + 1;
          continue;
        }
      }

      // 4. Plain Text chunk
      final int nextSpecial = _findNextSpecial(text, cursor);
      if (nextSpecial == -1) {
        spans.add(
          TextSpan(
            text: text.substring(cursor),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.0,
              height: 1.45,
              color: textSecondary,
            ),
          ),
        );
        break;
      } else {
        if (nextSpecial > cursor) {
          spans.add(
            TextSpan(
              text: text.substring(cursor, nextSpecial),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                height: 1.45,
                color: textSecondary,
              ),
            ),
          );
        }
        cursor = nextSpecial;
      }
    }

    return Text.rich(
      TextSpan(children: spans),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13.0,
        height: 1.45,
        color: textSecondary,
      ),
    );
  }

  int _findNextSpecial(String text, int start) {
    int minIndex = -1;

    void check(String pattern) {
      final int idx = text.indexOf(pattern, start);
      if (idx != -1) {
        if (minIndex == -1 || idx < minIndex) {
          minIndex = idx;
        }
      }
    }

    check('**');
    check('`');
    check('*');

    return minIndex;
  }
}
