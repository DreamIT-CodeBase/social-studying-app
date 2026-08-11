/// Derives a display subject from a topic generated from an uploaded document.
///
/// This is intentionally deterministic: the same topic must be labelled the
/// same way everywhere in the app. Unknown topics use the neutral `Study`
/// label instead of being assigned a random science subject.
String subjectForTopic(String topic) {
  final value = topic.toLowerCase();

  bool hasAny(Iterable<String> terms) => terms.any(value.contains);

  if (hasAny(const [
    'computer',
    'software',
    'program',
    'coding',
    'algorithm',
    'database',
    'cloud',
    'azure',
    'microsoft',
    'copilot',
    'github',
    'agent',
    'foundry',
    'artificial intelligence',
    'machine learning',
    'network',
    'cyber',
    'api',
  ])) {
    return 'Computer Science';
  }
  if (hasAny(const [
    'biology',
    'cell',
    'gene',
    'dna',
    'mitosis',
    'organism',
    'ecology',
    'anatomy',
    'physiology',
  ])) {
    return 'Biology';
  }
  if (hasAny(const [
    'chemistry',
    'chemical',
    'atom',
    'bond',
    'molecule',
    'molar',
    'reaction',
    'element',
    'compound',
  ])) {
    return 'Chemistry';
  }
  if (hasAny(const [
    'physics',
    'force',
    'gravity',
    'motion',
    'wave',
    'energy',
    'velocity',
    'mechanics',
    'electricity',
  ])) {
    return 'Physics';
  }
  if (hasAny(const [
    'math',
    'algebra',
    'geometry',
    'calculus',
    'equation',
    'probability',
    'statistics',
    'trigonometry',
  ])) {
    return 'Mathematics';
  }
  return 'Study';
}
