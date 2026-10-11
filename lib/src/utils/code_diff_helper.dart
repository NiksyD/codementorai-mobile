enum DiffLineType {
  added,
  removed,
  unchanged,
}

class DiffLine {
  const DiffLine({
    required this.type,
    required this.content,
    this.oldLineNumber,
    this.newLineNumber,
  });

  final DiffLineType type;
  final String content;
  final int? oldLineNumber;
  final int? newLineNumber;
}

class CodeDiffHelper {
  /// Computes an LCS-based line diff between original and modified code strings.
  static List<DiffLine> computeLineDiff(
    String originalCode,
    String modifiedCode,
  ) {
    final List<String> origRaw =
        originalCode.isEmpty ? <String>[] : originalCode.split('\n');
    final List<String> origLines = origRaw.isNotEmpty && origRaw.last == ''
        ? origRaw.sublist(0, origRaw.length - 1)
        : origRaw;

    final List<String> modRaw =
        modifiedCode.isEmpty ? <String>[] : modifiedCode.split('\n');
    final List<String> modLines = modRaw.isNotEmpty && modRaw.last == ''
        ? modRaw.sublist(0, modRaw.length - 1)
        : modRaw;

    final int n = origLines.length;
    final int m = modLines.length;

    // LCS DP Matrix
    final List<List<int>> dp = List<List<int>>.generate(
      n + 1,
      (_) => List<int>.filled(m + 1, 0),
    );

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < m; j++) {
        if (origLines[i] == modLines[j]) {
          dp[i + 1][j + 1] = dp[i][j] + 1;
        } else {
          dp[i + 1][j + 1] =
              dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1];
        }
      }
    }

    // Backtrack to extract diff sequence
    final List<DiffLine> result = <DiffLine>[];
    int i = n;
    int j = m;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && origLines[i - 1] == modLines[j - 1]) {
        result.insert(
          0,
          DiffLine(
            type: DiffLineType.unchanged,
            content: origLines[i - 1],
            oldLineNumber: i,
            newLineNumber: j,
          ),
        );
        i--;
        j--;
      } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
        result.insert(
          0,
          DiffLine(
            type: DiffLineType.added,
            content: modLines[j - 1],
            newLineNumber: j,
          ),
        );
        j--;
      } else if (i > 0) {
        result.insert(
          0,
          DiffLine(
            type: DiffLineType.removed,
            content: origLines[i - 1],
            oldLineNumber: i,
          ),
        );
        i--;
      }
    }

    return result;
  }
}
