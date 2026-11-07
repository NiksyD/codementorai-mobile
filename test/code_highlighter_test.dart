import 'package:flutter_test/flutter_test.dart';
import 'package:codementorai_mobile/src/features/learn/presentation/widgets/code_highlighter.dart';

List<String> kinds(String code, String lang) => tokenizeCode(code, lang)
    .map((CodeToken t) => '${t.kind.name}:${code.substring(t.start, t.end)}')
    .toList();

void main() {
  test('javascript: keywords, calls, strings, numbers, comments', () {
    expect(
      kinds("const x = add(1, 'a'); // hi", 'javascript'),
      <String>[
        'keyword:const',
        'function:add',
        'number:1',
        "string:'a'",
        'comment:// hi',
      ],
    );
  });

  test('python: hash comments, docstrings across lines, decorators', () {
    const String code = '@cache\ndef f(x):\n    """doc\n    more"""\n    return None  # end';
    final List<String> k = kinds(code, 'python');
    expect(k, contains('meta:@cache'));
    expect(k, contains('keyword:def'));
    expect(k, contains('function:f'));
    expect(k, contains('string:"""doc\n    more"""'));
    expect(k, contains('literal:None'));
    expect(k, contains('comment:# end'));
  });

  test('c: preprocessor is not a comment; // and /* */ are', () {
    const String code = '#include <stdio.h>\nint main() { /* a\nb */ return 0; }';
    final List<String> k = kinds(code, 'c');
    expect(k, contains('meta:#include'));
    expect(k, contains('type:int'));
    expect(k, contains('function:main'));
    expect(k, contains('comment:/* a\nb */'));
  });

  test('unterminated block comment and string do not throw', () {
    expect(kinds('/* open', 'java'), <String>['comment:/* open']);
    expect(kinds('"open', 'java'), <String>['string:"open']);
  });

  test('capitalized names are types, ALLCAPS are plain, unknown language is empty', () {
    expect(kinds('new Foo(MAX)', 'java'), <String>['keyword:new', 'type:Foo']);
    expect(tokenizeCode('x', 'brainf'), isEmpty);
  });

  test('php tags and variables', () {
    final List<String> k = kinds('<?php\n\$a = 1; # c', 'php');
    expect(k, contains('meta:<?php'));
    expect(k, contains('number:1'));
    expect(k, contains('comment:# c'));
  });
}
