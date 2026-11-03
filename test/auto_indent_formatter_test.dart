import 'package:codementorai_mobile/src/features/learn/presentation/widgets/practice_code_editor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const AutoIndentTextInputFormatter formatter = AutoIndentTextInputFormatter();

  group('AutoIndentTextInputFormatter with stale selections', () {
    test('typing a closing quote after a text swap (selection -1) does not throw', () {
      // Previous value as left behind by `controller.text = ...`: selection is -1.
      const TextEditingValue oldValue = TextEditingValue(
        text: 'x',
        selection: TextSelection.collapsed(offset: -1),
      );
      const TextEditingValue newValue = TextEditingValue(
        text: 'x"',
        selection: TextSelection.collapsed(offset: 2),
      );

      expect(() => formatter.formatEditUpdate(oldValue, newValue), returnsNormally);
    });

    test('backspace with a selection beyond the old text does not throw', () {
      const TextEditingValue oldValue = TextEditingValue(
        text: 'ab',
        selection: TextSelection.collapsed(offset: 40),
      );
      const TextEditingValue newValue = TextEditingValue(
        text: 'a',
        selection: TextSelection.collapsed(offset: 1),
      );

      expect(() => formatter.formatEditUpdate(oldValue, newValue), returnsNormally);
    });

    test('normal auto-closing and indentation still work', () {
      const TextEditingValue oldValue = TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
      const TextEditingValue typedBrace = TextEditingValue(
        text: '{',
        selection: TextSelection.collapsed(offset: 1),
      );
      final TextEditingValue result = formatter.formatEditUpdate(oldValue, typedBrace);
      expect(result.text, '{}');
      expect(result.selection.baseOffset, 1);
    });
  });
}
