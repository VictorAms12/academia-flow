String normalizeSearchText(String value) {
  var text = value.toLowerCase().trim();
  const replacements = <String, String>{
    'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
    'ç': 'c', 'ñ': 'n',
  };
  replacements.forEach((from, to) => text = text.replaceAll(from, to));
  return text.replaceAll(RegExp(r'\s+'), ' ');
}

List<String> searchTokens(String query) => normalizeSearchText(query)
    .split(' ')
    .map((token) => token.trim())
    .where((token) => token.isNotEmpty)
    .toSet()
    .toList();

int searchScore(String query, List<String> fields, {int titleField = 0}) {
  final tokens = searchTokens(query);
  if (tokens.isEmpty) return 0;

  final normalizedFields = fields.map(normalizeSearchText).toList();
  final haystack = normalizedFields.join(' ');
  if (!tokens.every(haystack.contains)) return -1;

  var score = 0;
  final normalizedQuery = normalizeSearchText(query);
  final title = titleField >= 0 && titleField < normalizedFields.length
      ? normalizedFields[titleField]
      : '';

  if (title == normalizedQuery) score += 120;
  if (title.startsWith(normalizedQuery)) score += 70;
  if (title.contains(normalizedQuery)) score += 45;
  if (haystack.contains(normalizedQuery)) score += 20;

  for (final token in tokens) {
    if (title == token) score += 35;
    if (title.startsWith(token)) score += 24;
    if (title.contains(token)) score += 16;
    for (var i = 0; i < normalizedFields.length; i++) {
      if (normalizedFields[i].contains(token)) score += i == titleField ? 8 : 3;
    }
  }
  return score;
}

bool matchesSearch(String query, List<String> fields) => searchScore(query, fields) >= 0;
