class IeltsSections {
  static const String listening = 'listening';
  static const String reading = 'reading';
  static const String writing = 'writing';
  static const String speaking = 'speaking';

  static const List<String> values = <String>[
    listening,
    reading,
    writing,
    speaking,
  ];

  static bool isValid(String value) {
    return values.contains(value.toLowerCase());
  }

  static String normalize(String value, {String fallback = reading}) {
    final normalized = value.trim().toLowerCase();
    return isValid(normalized) ? normalized : fallback;
  }

  static String fromLegacyIndex(int index, {String fallback = reading}) {
    switch (index) {
      case 1:
        return reading;
      case 2:
        return listening;
      case 3:
        return writing;
      case 4:
        return speaking;
      default:
        return fallback;
    }
  }

  static String fromAny({
    dynamic section,
    dynamic legacyCategory,
    String fallback = reading,
  }) {
    if (section is String && section.trim().isNotEmpty) {
      return normalize(section, fallback: fallback);
    }
    if (legacyCategory is String && legacyCategory.trim().isNotEmpty) {
      return normalize(legacyCategory, fallback: fallback);
    }
    if (section is num) {
      return fromLegacyIndex(section.toInt(), fallback: fallback);
    }
    return fallback;
  }

  static int orderIndex(String section) {
    return values.indexOf(normalize(section));
  }

  static String toLegacyCategory(String section) {
    final normalized = normalize(section);
    return normalized[0].toUpperCase() + normalized.substring(1);
  }
}
