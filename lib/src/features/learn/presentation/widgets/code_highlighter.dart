/// Small, dependency-free syntax tokenizer for the languages the app can run
/// (JavaScript, Python, Java, C, C++, C#, PHP).
///
/// It is not a parser. It splits source into comments, strings, numbers,
/// keywords, literals, types, function calls and a few language-specific
/// extras (decorators, preprocessor lines, PHP tags). It tolerates unfinished
/// code, because the editor re-runs it on every keystroke.
enum CodeTokenKind {
  plain,
  comment,
  string,
  number,
  keyword,
  literal,
  type,
  function,
  meta,
}

class CodeToken {
  const CodeToken(this.start, this.end, this.kind);

  final int start;
  final int end;
  final CodeTokenKind kind;
}

class _LanguageSpec {
  _LanguageSpec({
    required this.keywords,
    required this.literals,
    required this.types,
    required this.lineComments,
    this.blockComments = true,
    this.tripleQuotes = false,
    this.templateStrings = false,
    this.preprocessor = false,
    this.decorators = false,
    this.phpTags = false,
  }) {
    final StringBuffer comment = StringBuffer();
    if (blockComments) comment.write(r'/\*[\s\S]*?(?:\*/|(?![\s\S]))|');
    comment.write(
      lineComments.map((String c) => '${RegExp.escape(c)}[^\\n]*').join('|'),
    );

    final StringBuffer string = StringBuffer();
    if (tripleQuotes) {
      string.write(r'"""[\s\S]*?(?:"""|(?![\s\S]))' '|' r"'''[\s\S]*?(?:'''|(?![\s\S]))" '|');
    }
    if (templateStrings) string.write(r'`(?:\\[\s\S]|[^`\\])*`?|');
    string.write(r'"(?:\\.|[^"\\\n])*"?' '|' r"'(?:\\.|[^'\\\n])*'?");

    final List<String> meta = <String>[];
    if (preprocessor) meta.add(r'^[ \t]*#[ \t]*[a-z_]+');
    if (decorators) meta.add(r'@[A-Za-z_][\w.]*');
    if (phpTags) meta.add(r'<\?php|<\?=|\?>');

    final String pattern = <String>[
      '(?<comment>$comment)',
      '(?<string>$string)',
      '(?<meta>${meta.isEmpty ? '(?!)' : meta.join('|')})',
      r'(?<number>\b(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?)[uUlLfFdDmM]*\b)',
      r'(?<word>[A-Za-z_$][\w$]*)',
    ].join('|');

    regex = RegExp(pattern, multiLine: true);
  }

  final Set<String> keywords;
  final Set<String> literals;
  final Set<String> types;
  final List<String> lineComments;
  final bool blockComments;
  final bool tripleQuotes;
  final bool templateStrings;
  final bool preprocessor;
  final bool decorators;
  final bool phpTags;
  late final RegExp regex;
}

Set<String> _words(String s) => s.split(RegExp(r'\s+')).toSet();

const String _cKeywords =
    'auto break case const continue default do else enum extern for goto if '
    'inline register restrict return sizeof static struct switch typedef union '
    'volatile while';
const String _cTypes =
    'int char float double long short unsigned signed void size_t bool FILE '
    'int8_t int16_t int32_t int64_t uint8_t uint16_t uint32_t uint64_t';

final Map<String, _LanguageSpec> _specs = <String, _LanguageSpec>{
  'javascript': _LanguageSpec(
    keywords: _words(
      'as async await break case catch class const continue debugger default '
      'delete do else export extends finally for from function get if import '
      'in instanceof let new of return set static super switch this throw try '
      'typeof var void while with yield',
    ),
    literals: _words('true false null undefined NaN Infinity'),
    types: _words('console'),
    lineComments: <String>['//'],
    templateStrings: true,
  ),
  'python': _LanguageSpec(
    keywords: _words(
      'and as assert async await break case class continue def del elif else '
      'except finally for from global if import in is lambda match nonlocal '
      'not or pass raise return try while with yield',
    ),
    literals: _words('True False None'),
    types: _words(
      'int float str bool list dict set tuple bytes object self cls',
    ),
    lineComments: <String>['#'],
    blockComments: false,
    tripleQuotes: true,
    decorators: true,
  ),
  'java': _LanguageSpec(
    keywords: _words(
      'abstract assert break case catch class const continue default do else '
      'enum extends final finally for goto if implements import instanceof '
      'interface native new package permits private protected public record '
      'return sealed static strictfp super switch synchronized this throw '
      'throws transient try var volatile while yield',
    ),
    literals: _words('true false null'),
    types: _words('boolean byte char double float int long short void'),
    lineComments: <String>['//'],
  ),
  'c': _LanguageSpec(
    keywords: _words(_cKeywords),
    literals: _words('true false NULL'),
    types: _words(_cTypes),
    lineComments: <String>['//'],
    preprocessor: true,
  ),
  'cpp': _LanguageSpec(
    keywords: _words(
      '$_cKeywords alignas alignof and auto catch class concept constexpr '
      'const_cast co_await co_return co_yield decltype delete dynamic_cast '
      'explicit export final friend mutable namespace new noexcept not '
      'operator or override private protected public reinterpret_cast '
      'requires static_assert static_cast template this throw try typeid '
      'typename using virtual',
    ),
    literals: _words('true false nullptr NULL'),
    types: _words(
      '$_cTypes string vector map set unordered_map unordered_set pair std '
      'wchar_t',
    ),
    lineComments: <String>['//'],
    preprocessor: true,
  ),
  'csharp': _LanguageSpec(
    keywords: _words(
      'abstract as async await base break case catch checked class const '
      'continue default delegate do else enum event explicit extern finally '
      'fixed for foreach get goto if implicit in init interface internal is '
      'lock namespace new operator out override params private protected '
      'public readonly record ref return sealed set sizeof stackalloc static '
      'struct switch this throw try typeof unchecked unsafe using var '
      'virtual volatile where while yield',
    ),
    literals: _words('true false null'),
    types: _words(
      'bool byte char decimal double dynamic float int long object sbyte '
      'short string uint ulong ushort void',
    ),
    lineComments: <String>['//'],
    preprocessor: true,
  ),
  'php': _LanguageSpec(
    keywords: _words(
      'abstract and as break callable case catch class clone const continue '
      'declare default do echo else elseif empty extends final finally fn for '
      'foreach function global if implements include include_once instanceof '
      'insteadof interface isset list match namespace new or print private '
      'protected public readonly require require_once return static switch '
      'throw trait try unset use var while xor yield',
    ),
    literals: _words('true false null TRUE FALSE NULL'),
    types: _words(
      'int float string bool array object mixed void iterable callable self '
      'parent',
    ),
    lineComments: <String>['//', '#'],
    phpTags: true,
  ),
};

const Map<String, String> _aliases = <String, String>{
  'js': 'javascript',
  'node': 'javascript',
  'typescript': 'javascript',
  'ts': 'javascript',
  'py': 'python',
  'python3': 'python',
  'c++': 'cpp',
  'c#': 'csharp',
  'cs': 'csharp',
};

_LanguageSpec? _specFor(String language) {
  final String key = language.toLowerCase().trim();
  return _specs[_aliases[key] ?? key];
}

final RegExp _capitalized = RegExp(r'^[A-Z][A-Za-z0-9_]*[a-z]');

/// Splits [code] into highlight tokens. Gaps between tokens are plain text.
List<CodeToken> tokenizeCode(String code, String language) {
  final _LanguageSpec? spec = _specFor(language);
  if (spec == null || code.isEmpty) return const <CodeToken>[];

  final List<CodeToken> tokens = <CodeToken>[];
  for (final RegExpMatch m in spec.regex.allMatches(code)) {
    final CodeTokenKind kind;
    if (m.namedGroup('comment') != null) {
      kind = CodeTokenKind.comment;
    } else if (m.namedGroup('string') != null) {
      kind = CodeTokenKind.string;
    } else if (m.namedGroup('meta') != null) {
      kind = CodeTokenKind.meta;
    } else if (m.namedGroup('number') != null) {
      kind = CodeTokenKind.number;
    } else {
      final String word = m.namedGroup('word')!;
      if (spec.keywords.contains(word)) {
        kind = CodeTokenKind.keyword;
      } else if (spec.literals.contains(word)) {
        kind = CodeTokenKind.literal;
      } else if (spec.types.contains(word) || _capitalized.hasMatch(word)) {
        kind = CodeTokenKind.type;
      } else if (_isCall(code, m.end)) {
        kind = CodeTokenKind.function;
      } else {
        continue;
      }
    }
    tokens.add(CodeToken(m.start, m.end, kind));
  }
  return tokens;
}

bool _isCall(String code, int from) {
  int i = from;
  while (i < code.length && (code[i] == ' ' || code[i] == '\t')) {
    i++;
  }
  return i < code.length && code[i] == '(';
}
