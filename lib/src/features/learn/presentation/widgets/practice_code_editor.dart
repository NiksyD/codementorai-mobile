import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants/app_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color editorBg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);
    final Color gutterBg = isDark ? const Color(0xFF161B22) : const Color(0xFFEDF2F7);
    final Color gutterText = isDark ? const Color(0xFF6E7681) : const Color(0xFF94A3B8);
    final Color textColor = isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);
    final Color toolbarBg = isDark ? const Color(0xFF161B22) : const Color(0xFFE2E8F0);

    return Column(
      children: <Widget>[
        // Editor workspace with line numbers gutter
        Expanded(
          child: Container(
            color: editorBg,
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Line numbers column
                  Container(
                    width: 38.0,
                    padding: const EdgeInsets.only(top: 14.0, right: 8.0),
                    color: gutterBg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List<Widget>.generate(_lineCount, (int index) {
                        return Container(
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
                        );
                      }),
                    ),
                  ),

                  // Code input area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focusNode,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        inputFormatters: const <TextInputFormatter>[
                          AutoIndentTextInputFormatter(),
                        ],
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13.0,
                          height: 22.0 / 13.0,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
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
            ),
          ),
        ),

        // Quick-insert keyboard accessory toolbar
        Container(
          height: 42.0,
          color: toolbarBg,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
            itemCount: _accessoryKeys.length,
            separatorBuilder: (BuildContext context, int i) => const SizedBox(width: 6.0),
            itemBuilder: (BuildContext context, int i) {
              final String key = _accessoryKeys[i];
              return InkWell(
                onTap: () => _insertSymbol(key),
                borderRadius: BorderRadius.circular(6.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11.0),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF21262D) : Colors.white,
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Text(
                    key == 'tab' ? '⇥ tab' : key,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.primary : const Color(0xFF0F172A),
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
