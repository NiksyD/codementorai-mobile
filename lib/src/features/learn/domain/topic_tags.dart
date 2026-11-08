/// Topic tags: the fixed list of programming concepts a challenge can assess.
///
/// Mirror of codementorai-web/lib/competency/topicTags.ts. Keep the ids and
/// labels identical. Ids are stored; labels are only for display.
library;

const int minTopicTags = 1;
const int maxTopicTags = 3;

class TopicTag {
  const TopicTag(this.id, this.label, this.group);

  final String id;
  final String label;
  final String group;
}

const Map<String, String> topicGroupLabels = <String, String>{
  'fundamentals': 'Programming Fundamentals',
  'control': 'Control Structures',
  'functions': 'Functions and Modularity',
  'arrays_strings': 'Arrays and Strings',
  'data_structures': 'Data Structures',
  'search_sort': 'Searching and Sorting',
  'techniques': 'Algorithmic Techniques',
};

const List<TopicTag> topicTags = <TopicTag>[
  TopicTag('variables', 'Variables', 'fundamentals'),
  TopicTag('data_types', 'Data Types', 'fundamentals'),
  TopicTag('operators', 'Operators', 'fundamentals'),
  TopicTag('input_output', 'Input/Output', 'fundamentals'),
  TopicTag('type_conversion', 'Type Conversion', 'fundamentals'),
  TopicTag('conditionals', 'Conditional Statements', 'control'),
  TopicTag('for_loops', 'For Loops', 'control'),
  TopicTag('while_loops', 'While Loops', 'control'),
  TopicTag('nested_loops', 'Nested Loops', 'control'),
  TopicTag('functions', 'Functions', 'functions'),
  TopicTag('parameters', 'Parameters', 'functions'),
  TopicTag('return_values', 'Return Values', 'functions'),
  TopicTag('recursion', 'Recursion', 'functions'),
  TopicTag('scope', 'Scope', 'functions'),
  TopicTag('arrays', 'Arrays', 'arrays_strings'),
  TopicTag('multidimensional_arrays', 'Multidimensional Arrays', 'arrays_strings'),
  TopicTag('string_manipulation', 'String Manipulation', 'arrays_strings'),
  TopicTag('linked_lists', 'Linked Lists', 'data_structures'),
  TopicTag('stacks', 'Stacks', 'data_structures'),
  TopicTag('queues', 'Queues', 'data_structures'),
  TopicTag('hash_tables', 'Hash Tables', 'data_structures'),
  TopicTag('trees', 'Trees', 'data_structures'),
  TopicTag('graphs', 'Graphs', 'data_structures'),
  TopicTag('sets', 'Sets', 'data_structures'),
  TopicTag('linear_search', 'Linear Search', 'search_sort'),
  TopicTag('binary_search', 'Binary Search', 'search_sort'),
  TopicTag('bubble_sort', 'Bubble Sort', 'search_sort'),
  TopicTag('selection_sort', 'Selection Sort', 'search_sort'),
  TopicTag('insertion_sort', 'Insertion Sort', 'search_sort'),
  TopicTag('merge_sort', 'Merge Sort', 'search_sort'),
  TopicTag('quick_sort', 'Quick Sort', 'search_sort'),
  TopicTag('brute_force', 'Brute Force', 'techniques'),
  TopicTag('divide_and_conquer', 'Divide and Conquer', 'techniques'),
  TopicTag('greedy', 'Greedy Algorithms', 'techniques'),
  TopicTag('dynamic_programming', 'Dynamic Programming', 'techniques'),
  TopicTag('backtracking', 'Backtracking', 'techniques'),
];

final Map<String, TopicTag> _byId = <String, TopicTag>{
  for (final TopicTag t in topicTags) t.id: t,
};
final Map<String, TopicTag> _byLabel = <String, TopicTag>{
  for (final TopicTag t in topicTags) t.label.toLowerCase(): t,
};

String topicTagLabel(String id) => _byId[id]?.label ?? id;

/// Keeps known tags only (ids or labels), drops duplicates, caps at 3.
List<String> sanitizeTopicTags(dynamic input) {
  if (input is! List) return const <String>[];
  final List<String> out = <String>[];
  for (final dynamic raw in input) {
    if (raw is! String) continue;
    final String key = raw.trim();
    final TopicTag? tag = _byId[key] ?? _byLabel[key.toLowerCase()];
    if (tag != null && !out.contains(tag.id)) out.add(tag.id);
    if (out.length == maxTopicTags) break;
  }
  return out;
}
