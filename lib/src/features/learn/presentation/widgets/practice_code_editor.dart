import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants/app_colors.dart';

/// Specialized controller providing syntax highlighting (Monaco/VS Code parity)
class SyntaxHighlightingTextEditingController extends TextEditingController {
  SyntaxHighlightingTextEditingController({
    super.text,
    this.language = 'java',
    this.isDark = true,
  });

  String language;
  bool isDark;

  static final RegExp _tokenRegex = RegExp(
    r'(//[^\n]*|/\*[\s\S]*?\*/|#[^\n]*)' // Group 1: Comments
    r'|("(?:\\.|[^"\\])*"|' r"'(?:\\.|[^'\\])*')" // Group 2: Strings
    r'|\b(\d+(?:\.\d+)?)\b' // Group 3: Numbers
    r'|\b(public|private|protected|class|interface|enum|extends|implements|static|final|abstract|void|return|if|else|switch|case|default|for|while|do|break|continue|new|try|catch|finally|throw|throws|import|package|def|lambda|from|as|async|await|yield|function|const|let|var|typeof|instanceof|struct|typedef)\b' // Group 4: Keywords
    r'|\b(int|boolean|bool|char|float|double|long|short|byte|String|Integer|Boolean|Character|Double|Float|Long|List|Map|Set|ArrayList|HashMap|System|Math|Arrays|Scanner|Console|Object|true|false|True|False|None|null|nil|this|super)\b', // Group 5: Types / Built-ins
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final TextStyle baseStyle = style ??
        GoogleFonts.jetBrainsMono(
          fontSize: 13.0,
          height: 22.0 / 13.0,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        );

    final String text = value.text;
    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    // Design Token Color Palette (Charcoal, Zinc & Emerald mint - no blue)
    final Color commentColor = isDark ? const Color(0xFF6E7681) : const Color(0xFF94A3B8);
    final Color stringColor = isDark ? const Color(0xFFE5C07B) : const Color(0xFFB45309);
    final Color numberColor = isDark ? const Color(0xFFF97316) : const Color(0xFFEA580C);
    final Color keywordColor = isDark ? AppColors.primary : AppColors.primaryVariant;
    final Color typeColor = isDark ? const Color(0xFFFFA657) : const Color(0xFFD97706);

    final List<TextSpan> spans = <TextSpan>[];
    int lastEnd = 0;

    for (final Match match in _tokenRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      TextStyle tokenStyle = baseStyle;
      if (match.group(1) != null) {
        // Comment
        tokenStyle = baseStyle.copyWith(
          color: commentColor,
          fontStyle: FontStyle.italic,
        );
      } else if (match.group(2) != null) {
        // String
        tokenStyle = baseStyle.copyWith(
          color: stringColor,
        );
      } else if (match.group(3) != null) {
        // Number
        tokenStyle = baseStyle.copyWith(
          color: numberColor,
        );
      } else if (match.group(4) != null) {
        // Keyword
        tokenStyle = baseStyle.copyWith(
          color: keywordColor,
          fontWeight: FontWeight.w700,
        );
      } else if (match.group(5) != null) {
        // Type / Built-in
        tokenStyle = baseStyle.copyWith(
          color: typeColor,
          fontWeight: FontWeight.w600,
        );
      }

      spans.add(TextSpan(
        text: match.group(0),
        style: tokenStyle,
      ));

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans, style: baseStyle);
  }
}

class PracticeCodeEditor extends StatefulWidget {
  const PracticeCodeEditor({
    super.key,
    required this.controller,
    required this.language,
    this.onChanged,
  });

  final TextEditingController controller;
  final String language;
  final ValueChanged<String>? onChanged;

  @override
  State<PracticeCodeEditor> createState() => _PracticeCodeEditorState();
}

class _PracticeCodeEditorState extends State<PracticeCodeEditor> {
  final FocusNode _focusNode = FocusNode();
  int _lineCount = 1;

  static const List<String> _accessoryKeys = <String>[
    'tab',
    '{',
    '}',
    '(',
    ')',
    '[',
    ']',
    ';',
    '"',
    "'",
    '=',
    ':',
    '.',
    '+',
    '-',
    '*',
    '/',
    '<',
    '>',
  ];

  @override
  void initState() {
    super.initState();
    _updateLineCount();
    widget.controller.addListener(_updateLineCount);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateLineCount);
    _focusNode.dispose();
    super.dispose();
  }

  void _updateLineCount() {
    final int count = '\n'.allMatches(widget.controller.text).length + 1;
    if (count != _lineCount && mounted) {
      setState(() {
        _lineCount = count;
      });
    }
  }

  static const Map<String, String> _pairMap = <String, String>{
    '{': '}',
    '(': ')',
    '[': ']',
    '"': '"',
    "'": "'",
  };

  void _insertSymbol(String symbol) {
    HapticFeedback.selectionClick();
    final TextEditingController controller = widget.controller;
    final TextSelection selection = controller.selection;

    final int start =
        selection.start >= 0 ? selection.start : controller.text.length;
    final int end = selection.end >= 0 ? selection.end : controller.text.length;

    // 1. Tab insertion (2 spaces)
    if (symbol == 'tab') {
      const String spaces = '  ';
      final String newText = controller.text.replaceRange(start, end, spaces);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + spaces.length),
      );
      widget.onChanged?.call(newText);
      _focusNode.requestFocus();
      return;
    }

    // 2. Selection wrapping (Monaco/VS Code standard: wraps selected text)
    if (start != end && _pairMap.containsKey(symbol)) {
      final String selectedText = controller.text.substring(start, end);
      final String closing = _pairMap[symbol]!;
      final String wrapped = '$symbol$selectedText$closing';
      final String newText = controller.text.replaceRange(start, end, wrapped);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: start + 1,
          extentOffset: start + 1 + selectedText.length,
        ),
      );
      widget.onChanged?.call(newText);
      _focusNode.requestFocus();
      return;
    }

    // 3. Skip-over existing closing character
    const Set<String> closingChars = <String>{'}', ')', ']', '"', "'"};
    if (closingChars.contains(symbol) &&
        start == end &&
        start < controller.text.length &&
        controller.text[start] == symbol) {
      controller.selection = TextSelection.collapsed(offset: start + 1);
      _focusNode.requestFocus();
      return;
    }

    // 4. Auto-closing pair insertion (Monaco standard: inserts both, places cursor in middle)
    if (_pairMap.containsKey(symbol)) {
      final String closing = _pairMap[symbol]!;
      final String pair = '$symbol$closing';
      final String newText = controller.text.replaceRange(start, end, pair);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + 1),
      );
      widget.onChanged?.call(newText);
      _focusNode.requestFocus();
      return;
    }

    // 5. Default single symbol insertion
    final String newText = controller.text.replaceRange(start, end, symbol);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + symbol.length),
    );

    widget.onChanged?.call(newText);
    _focusNode.requestFocus();
  }

  List<double> _calculateLineHeights(double availableWidth, TextStyle style) {
    if (availableWidth <= 0) {
      return List<double>.filled(_lineCount, 22.0);
    }
    final List<String> lines = widget.controller.text.split('\n');
    final List<double> heights = <double>[];
    for (final String line in lines) {
      if (line.isEmpty) {
        heights.add(22.0);
        continue;
      }
      final TextPainter tp = TextPainter(
        text: TextSpan(text: line, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: availableWidth);
      heights.add(tp.height > 22.0 ? tp.height : 22.0);
    }
    return heights;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color editorBg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color gutterBg = editorBg; // Seamless unified canvas, no contrasting card block
    final Color gutterText = isDark ? const Color(0xFF6E7681) : const Color(0xFF94A3B8);
    final Color gutterDivider = isDark
        ? AppColors.darkBorder.withValues(alpha: 0.35)
        : AppColors.lightBorder.withValues(alpha: 0.6);
    final Color textColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color toolbarBg = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    final TextStyle codeStyle = GoogleFonts.jetBrainsMono(
      fontSize: 13.0,
      height: 22.0 / 13.0,
      color: textColor,
      fontWeight: FontWeight.w500,
    );

    // Sync theme & language to controller if using SyntaxHighlightingTextEditingController
    if (widget.controller is SyntaxHighlightingTextEditingController) {
      final SyntaxHighlightingTextEditingController ctrl =
          widget.controller as SyntaxHighlightingTextEditingController;
      ctrl.isDark = isDark;
      ctrl.language = widget.language;
    }

    return Column(
      children: <Widget>[
        // Editor workspace with line numbers gutter (seamless hollow canvas with soft wrapping)
        Expanded(
          child: Container(
            color: editorBg,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const double gutterWidth = 38.0;
                const double horizontalPadding = 10.0;
                final double availableCodeWidth =
                    constraints.maxWidth - gutterWidth - (horizontalPadding * 2);
                final List<String> lines = widget.controller.text.split('\n');
                final List<double> lineHeights = _calculateLineHeights(
                  availableCodeWidth,
                  codeStyle,
                );

                return SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Line numbers column
                      Container(
                        width: gutterWidth,
                        padding: const EdgeInsets.only(top: 14.0, right: 8.0),
                        decoration: BoxDecoration(
                          color: gutterBg,
                          border: Border(
                            right: BorderSide(
                              color: gutterDivider,
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List<Widget>.generate(lines.length, (int index) {
                            final double h =
                                index < lineHeights.length ? lineHeights[index] : 22.0;
                            return Container(
                              height: h,
                              alignment: Alignment.topRight,
                              child: Container(
                                height: 22.0,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${index + 1}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12.0,
                                    color: gutterText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      // Code input area with automatic soft line wrapping
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
                          child: TextField(
                            controller: widget.controller,
                            focusNode: _focusNode,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            cursorColor: AppColors.primary,
                            cursorWidth: 2.0,
                            inputFormatters: const <TextInputFormatter>[
                              AutoIndentTextInputFormatter(),
                            ],
                            style: codeStyle,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(top: 14.0, bottom: 20.0),
                              isDense: true,
                            ),
                            onChanged: widget.onChanged,
                            autocorrect: false,
                            enableSuggestions: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // Quick-insert keyboard accessory toolbar (Hollow, uncarded design)
        Container(
          height: 40.0,
          decoration: BoxDecoration(
            color: toolbarBg,
            border: Border(
              top: BorderSide(color: gutterDivider, width: 1.0),
            ),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.5),
            itemCount: _accessoryKeys.length,
            separatorBuilder: (BuildContext context, int i) => const SizedBox(width: 5.0),
            itemBuilder: (BuildContext context, int i) {
              final String key = _accessoryKeys[i];
              final bool isTab = key == 'tab';
              return InkWell(
                onTap: () => _insertSymbol(key),
                borderRadius: BorderRadius.circular(6.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isTab
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04)),
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: isTab
                          ? AppColors.primary.withValues(alpha: 0.3)
                          : gutterDivider,
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    isTab ? '⇥ tab' : key,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12.0,
                      fontWeight: isTab ? FontWeight.w700 : FontWeight.w600,
                      color: isTab
                          ? AppColors.primary
                          : textColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class AutoIndentTextInputFormatter extends TextInputFormatter {
  const AutoIndentTextInputFormatter({this.indent = '    '});

  final String indent;

  static const Map<String, String> _pairMap = <String, String>{
    '{': '}',
    '(': ')',
    '[': ']',
    '"': '"',
    "'": "'",
  };

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. Single character insertion checks
    if (newValue.text.length == oldValue.text.length + 1 &&
        newValue.selection.isCollapsed &&
        newValue.selection.baseOffset > 0) {
      final int insertPos = newValue.selection.baseOffset;
      final String insertedChar = newValue.text[insertPos - 1];

      // A. Enter / Newline Auto-Indentation & Split
      if (insertedChar == '\n') {
        final int prevLineEnd = insertPos - 1;
        final int prevLineStart =
            newValue.text.lastIndexOf('\n', prevLineEnd - 1) + 1;
        final String prevLine =
            newValue.text.substring(prevLineStart, prevLineEnd);

        final Match? leadingMatch = RegExp(r'^[ \t]*').firstMatch(prevLine);
        String currentIndent =
            leadingMatch != null ? leadingMatch.group(0)! : '';

        final String trimmedPrev = prevLine.trim();
        final bool shouldIncreaseIndent = trimmedPrev.endsWith('{') ||
            trimmedPrev.endsWith('(') ||
            trimmedPrev.endsWith('[') ||
            trimmedPrev.endsWith(':');

        // Check if user pressed Enter right between brackets like {|}
        final bool isBetweenBraces = trimmedPrev.endsWith('{') &&
            insertPos < newValue.text.length &&
            newValue.text[insertPos] == '}';

        if (isBetweenBraces) {
          final String innerIndent = currentIndent + indent;
          final String additionalText = '$innerIndent\n$currentIndent';
          final String updatedText =
              newValue.text.replaceRange(insertPos, insertPos, additionalText);
          return TextEditingValue(
            text: updatedText,
            selection: TextSelection.collapsed(
              offset: insertPos + innerIndent.length,
            ),
          );
        }

        if (shouldIncreaseIndent) {
          currentIndent += indent;
        }

        if (currentIndent.isNotEmpty) {
          final String updatedText =
              newValue.text.replaceRange(insertPos, insertPos, currentIndent);
          return TextEditingValue(
            text: updatedText,
            selection: TextSelection.collapsed(
              offset: insertPos + currentIndent.length,
            ),
          );
        }
      }

      // B. Skip-over existing closing character on typing
      if (_pairMap.containsValue(insertedChar) &&
          oldValue.selection.isCollapsed &&
          oldValue.selection.baseOffset < oldValue.text.length &&
          oldValue.text[oldValue.selection.baseOffset] == insertedChar) {
        return TextEditingValue(
          text: oldValue.text,
          selection: TextSelection.collapsed(
            offset: oldValue.selection.baseOffset + 1,
          ),
        );
      }

      // C. Auto-closing pair insertion on typing opening symbol
      if (_pairMap.containsKey(insertedChar)) {
        final String closing = _pairMap[insertedChar]!;
        final String updatedText =
            newValue.text.replaceRange(insertPos, insertPos, closing);
        return TextEditingValue(
          text: updatedText,
          selection: TextSelection.collapsed(offset: insertPos),
        );
      }
    }

    // 2. Backspace: delete closing pair if backspacing opening character of pair
    if (newValue.text.length == oldValue.text.length - 1 &&
        oldValue.selection.isCollapsed &&
        oldValue.selection.baseOffset > 0) {
      final int deletedCharPos = oldValue.selection.baseOffset - 1;
      final String deletedChar = oldValue.text[deletedCharPos];

      if (_pairMap.containsKey(deletedChar) &&
          deletedCharPos < oldValue.text.length - 1) {
        final String expectedClosing = _pairMap[deletedChar]!;
        if (oldValue.text[deletedCharPos + 1] == expectedClosing) {
          final int newPos = newValue.selection.baseOffset;
          final String updatedText =
              newValue.text.replaceRange(newPos, newPos + 1, '');
          return TextEditingValue(
            text: updatedText,
            selection: TextSelection.collapsed(offset: newPos),
          );
        }
      }
    }

    return newValue;
  }
}
