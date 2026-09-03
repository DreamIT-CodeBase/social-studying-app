import 'package:flutter/material.dart';
import 'package:social_study_app/shared/models/document.dart';

const List<String> _physicsTerms = [
  'quantum mechanics', 'thermodynamics', 'nuclear physics', 'magnetic field', 'electric current',
  // English
  'physics', 'force', 'gravity', 'motion', 'wave', 'energy', 'velocity',
  'mechanics', 'electricity', 'magnetism', 'quantum', 'optics',
  'friction', 'acceleration', 'kinematics',
  // Hindi
  'भौतिक विज्ञान', 'भौतिकी', 'भौतिक', 'गति के नियम', 'गुरुत्वाकर्षण', 'ऊर्जा', 'प्रकाश',
  // Spanish
  'física clásica', 'física', 'fisica', 'fuerza', 'gravedad', 'movimiento', 'onda',
  'energía', 'energia', 'velocidad', 'mecánica', 'mecanica', 'electricidad',
  // French
  'physique quantique', 'physique', 'gravité', 'gravite', 'mouvement', 'vitesse',
  // German
  'physik', 'kraft', 'gravitation', 'bewegung', 'welle', 'geschwindigkeit',
];

const List<String> _chemistryTerms = [
  'atomic structure', 'periodic table', 'chemical bond', 'chemical bonding',
  'mole concept', 'acids, bases and ph', 'acids and bases', 'chemical reaction',
  'chemical reactions', 'organic chemistry', 'inorganic chemistry',
  'ap chemistry', 'ap chem', 'general chemistry', 'gen chem', 'organic chem', 'orgo',
  'physical chemistry', 'analytical chemistry', 'chemical kinetics',
  'ionic bond', 'covalent bond', 'metallic bond', 'molar mass', 'avogadro',
  'atomic number', 'mass number', 'protons', 'electrons', 'neutrons',
  'single displacement', 'double displacement', 'decomposition reaction',
  'combination reaction', 'stoichiometry', 'titration', 'oxidation reduction',
  'रासायनिक अभिक्रियाएं', 'रासायनिक अभिक्रिया', 'रासायनिक समीकरण', 'आवर्त सारणी',
  'química inorgánica', 'quimica inorganica', 'química orgánica', 'chimie organique',
  // English
  'chemistry', 'chemical', 'atom', 'bond', 'molecule', 'molar',
  'reaction', 'element', 'compound', 'periodic', 'stoichiometry',
  'organic', 'acid', 'base', 'oxidation', 'valence',
  // Hindi
  'रसायन विज्ञान', 'रसायनशास्त्र', 'रसायनिक', 'रसायन', 'परमाणु', 'अणु', 'रासायनिक',
  // Spanish
  'química', 'quimica', 'químico', 'quimico', 'átomo', 'atomo', 'enlace',
  'molécula', 'molecula', 'reacción', 'reaccion', 'compuesto',
  // French
  'chimie', 'chimique', 'atome', 'liaison', 'molécule', 'molecule',
  'réaction', 'reaction', 'élément', 'element', 'composé', 'compose',
  // German
  'chemie', 'chemisch', 'bindung', 'molekül', 'molekuel', 'reaktion', 'verbindung',
];

const List<String> _biologyTerms = [
  'molecular biology', 'cell biology', 'cellular respiration', 'photosynthesis',
  'कोशिका संरचना', 'जीवविज्ञान', 'biología celular', 'biologie cellulaire',
  // English
  'biology', 'cell', 'gene', 'dna', 'rna', 'mitosis', 'meiosis',
  'organism', 'ecology', 'anatomy', 'physiology', 'evolution',
  'ecosystem', 'protein', 'bacteria', 'virus',
  // Hindi
  'कोशिका', 'जीन', 'जीव', 'पारिस्थितिकी', 'शरीर रचना',
  // Spanish
  'biología', 'biologia', 'célula', 'celula', 'gen', 'adn', 'ecología',
  'ecologia', 'anatomía', 'anatomia', 'fotosíntesis', 'fotosintesis',
  // French
  'biologie', 'cellule', 'gène', 'gene', 'écologie', 'ecologie', 'anatomie',
  'physiologie', 'photosynthèse', 'photosynthese',
  // German
  'biologie', 'zelle', 'gen', 'organismus', 'ökologie', 'oekologie',
];

const List<String> _mathTerms = [
  'differential calculus', 'integral calculus', 'quadratic equation',
  'त्रिकोणमिति', 'समीकरण', 'बीजगणित', 'ज्यामिति',
  // English
  'math', 'maths', 'mathematics', 'algebra', 'geometry', 'calculus',
  'equation', 'probability', 'statistics', 'trigonometry', 'arithmetic',
  'fraction', 'matrix', 'differential', 'integral', 'polynomial',
  // Hindi
  'गणित', 'कलन', 'प्रायिकता', 'रेखागणित',
  // Spanish
  'matemáticas', 'matematicas', 'álgebra', 'algebra', 'geometría', 'geometria',
  'cálculo', 'calculo', 'ecuación', 'ecuacion', 'trigonometría', 'trigonometria',
  // French
  'mathématiques', 'mathematiques', 'algèbre', 'algebre', 'géométrie', 'geometrie',
  'calcul', 'équation', 'equation', 'trigonométrie', 'trigonometrie',
  // German
  'mathematik', 'mathe', 'geometrie', 'gleichung', 'wahrscheinlichkeitsrechnung',
];

const List<String> _csTerms = [
  'computer science', 'artificial intelligence', 'machine learning', 'data structure',
  // English / Universal
  'computer', 'software', 'program', 'coding', 'algorithm', 'database',
  'cloud', 'azure', 'microsoft', 'copilot', 'github', 'agent',
  'foundry', 'network', 'cyber', 'api', 'python', 'java', 'javascript',
  // Hindi
  'संगणक', 'कंप्यूटर', 'सॉफ्टवेयर', 'प्रोग्रामिंग',
  // Spanish
  'informática', 'informatica', 'computación', 'computacion', 'programacion',
  // French
  'informatique', 'programmation', 'algorithme',
  // German
  'informatik', 'programmierung',
];

const List<String> _engineeringTerms = [
  'aerospace engineering', 'biomedical engineering', 'chemical engineering', 'civil engineering',
  'electrical engineering', 'mechanical engineering', 'computer engineering', 'industrial engineering',
  'robotics engineering', 'circuits and systems', 'materials science', 'fluid mechanics',
  'engineering', 'engineer', 'robotics', 'circuit', 'circuits', 'transistor', 'statics',
  'dynamics', 'microcontroller', 'arduino', 'solidworks', 'schematic', 'thermodynamic cycle',
];

const List<String> _historyTerms = [
  'us history', 'united states history', 'world history', 'european history', 'american history',
  'ancient history', 'medieval history', 'modern history', 'ap us history', 'apush', 'ap world',
  'ap euro', 'cold war', 'world war i', 'world war ii', 'world war', 'civil war',
  'american revolution', 'french revolution', 'industrial revolution', 'great depression',
  'history', 'historical', 'civilization', 'dynasty', 'empire', 'colonial', 'monarchy',
  'renaissance', 'reconstruction', 'treaty', 'confederacy', 'holocaust', 'imperialism',
];

const List<String> _governmentTerms = [
  'us government', 'american government', 'political science', 'comparative politics',
  'international relations', 'constitutional law', 'ap government', 'ap gov', 'public policy',
  'supreme court', 'bill of rights', 'executive branch', 'legislative branch',
  'government', 'politics', 'political', 'constitution', 'congress', 'senate', 'judiciary',
  'democracy', 'federalism', 'civics', 'diplomacy', 'sovereignty', 'electoral', 'voting rights',
];

const List<String> _economicsTerms = [
  'microeconomics', 'macroeconomics', 'ap microeconomics', 'ap macroeconomics', 'ap micro',
  'ap macro', 'supply and demand', 'monetary policy', 'fiscal policy', 'financial accounting',
  'corporate finance', 'econometrics', 'gross domestic product', 'market equilibrium',
  'economics', 'economy', 'economic', 'inflation', 'deflation', 'interest rate', 'elasticity',
  'monopoly', 'oligopoly', 'opportunity cost', 'gdp', 'consumer surplus', 'producer surplus',
  'finance', 'fiscal', 'taxation', 'investment',
];

const List<String> _psychologyTerms = [
  'cognitive psychology', 'developmental psychology', 'abnormal psychology', 'social psychology',
  'clinical psychology', 'behavioral psychology', 'behavioral neuroscience', 'ap psychology',
  'ap psych', 'mental health', 'central nervous system', 'classical conditioning',
  'psychology', 'psychological', 'psychologist', 'cognition', 'neuroscience', 'behavior',
  'behaviour', 'perception', 'conditioning', 'pavlov', 'skinner', 'freud', 'memory',
  'neurotransmitter', 'dopamine', 'serotonin', 'synapse', 'cortex', 'psychopathology', 'therapy',
];

const List<String> _englishLiteratureTerms = [
  'english literature', 'american literature', 'british literature', 'world literature',
  'english language', 'ap english', 'ap literature', 'ap lit', 'ap lang', 'creative writing',
  'rhetorical analysis', 'literary analysis', 'close reading', 'short story',
  'literature', 'poetry', 'poem', 'poet', 'essay', 'grammar', 'rhetoric', 'metaphor',
  'simile', 'symbolism', 'sonnet', 'prose', 'stanza', 'syntax', 'fiction', 'novel',
  'narrative', 'protagonist', 'antagonist', 'shakespeare', 'literary', 'comprehension',
];

const List<String> _earthSpaceTerms = [
  'earth science', 'environmental science', 'ap environmental science', 'apes', 'space science',
  'planetary science', 'plate tectonics', 'climate change', 'solar system', 'milky way',
  'geology', 'geological', 'meteorology', 'oceanography', 'astronomy', 'mineral', 'volcano',
  'earthquake', 'atmosphere', 'stratosphere', 'biodiversity', 'fossil', 'glacier', 'telescope',
  'planet', 'galaxy', 'asteroid',
];

const List<String> _sociologyAnthropologyTerms = [
  'cultural anthropology', 'physical anthropology', 'social anthropology', 'social structure',
  'social sciences', 'social studies', 'gender studies', 'ethnic studies',
  'sociology', 'sociological', 'anthropology', 'anthropological', 'culture', 'ethnography',
  'archaeology', 'stratification', 'socialization', 'demographics', 'inequality', 'criminology',
];

const List<String> _philosophyTerms = [
  'introduction to philosophy', 'political philosophy', 'moral philosophy', 'philosophy of science',
  'philosophy of mind', 'critical thinking',
  'philosophy', 'philosophical', 'philosopher', 'ethics', 'ethical', 'morality', 'epistemology',
  'metaphysics', 'existentialism', 'utilitarianism', 'kant', 'socrates', 'plato', 'aristotle',
  'nietzsche', 'syllogism', 'rationalism', 'empiricism',
];

const List<String> _businessTerms = [
  'business administration', 'business management', 'organizational behavior', 'supply chain management',
  'human resources', 'business law', 'market research',
  'business', 'management', 'marketing', 'entrepreneurship', 'commerce', 'strategy', 'leadership',
  'logistics', 'advertising', 'venture', 'startup', 'revenue', 'branding', 'stakeholder',
];

const List<String> _artMusicTerms = [
  'art history', 'ap art history', 'music theory', 'music appreciation', 'visual arts',
  'graphic design', 'studio art', 'fine arts',
  'art', 'music', 'musical', 'painting', 'sculpture', 'composition', 'harmony', 'melody',
  'rhythm', 'chord', 'scale', 'symphony', 'theatre', 'theater', 'film studies', 'photography',
];

const List<String> _healthMedicineTerms = [
  'health science', 'public health', 'sports medicine', 'kinesiology', 'human anatomy',
  'medical terminology',
  'medicine', 'medical', 'nursing', 'nutrition', 'pharmacology', 'pathology', 'pediatrics',
  'epidemiology', 'diagnosis', 'clinic', 'clinical', 'hospital', 'wellness',
];

const List<String> _worldLanguagesTerms = [
  'foreign language', 'world languages', 'spanish language', 'french language', 'german language',
  'latin language', 'mandarin chinese', 'japanese language', 'language acquisition',
  'linguistics', 'conjugation', 'phonetics', 'espanol', 'español', 'français', 'deutsch', 'translation',
];

const List<MapEntry<String, List<String>>> _subjectConfigs = [
  MapEntry('Computer Science', _csTerms),
  MapEntry('Engineering', _engineeringTerms),
  MapEntry('Government & Politics', _governmentTerms),
  MapEntry('History', _historyTerms),
  MapEntry('Economics', _economicsTerms),
  MapEntry('Psychology', _psychologyTerms),
  MapEntry('English & Literature', _englishLiteratureTerms),
  MapEntry('Earth & Space Science', _earthSpaceTerms),
  MapEntry('Sociology & Anthropology', _sociologyAnthropologyTerms),
  MapEntry('Philosophy', _philosophyTerms),
  MapEntry('Business', _businessTerms),
  MapEntry('Art & Music', _artMusicTerms),
  MapEntry('Health & Medicine', _healthMedicineTerms),
  MapEntry('World Languages', _worldLanguagesTerms),
  MapEntry('Chemistry', _chemistryTerms),
  MapEntry('Biology', _biologyTerms),
  MapEntry('Physics', _physicsTerms),
  MapEntry('Mathematics', _mathTerms),
];

/// Derives a display subject from a topic generated from an uploaded document.
///
/// This is intentionally deterministic: the same topic must be labelled the
/// same way everywhere in the app. Unknown topics use the neutral `Study`
/// label instead of being assigned a random science subject.
String subjectForTopic(String topic) {
  final value = topic.toLowerCase();

  final scores = <String, int>{};
  for (final entry in _subjectConfigs) {
    var score = 0;
    for (final term in entry.value) {
      if (value.contains(term)) {
        score += term.length * term.length;
      }
    }
    if (score > 0) {
      scores[entry.key] = score;
    }
  }

  if (scores.isEmpty) {
    return 'Study';
  }

  // Pick the subject with the highest weighted score
  var bestSubject = 'Study';
  var maxScore = -1;
  for (final entry in scores.entries) {
    if (entry.value > maxScore) {
      maxScore = entry.value;
      bestSubject = entry.key;
    }
  }

  return bestSubject;
}

/// Derives the primary subject of a Document from its filename or topic tags.
String subjectForDocument(Document doc) {
  // 1. Check filename
  final fromFilename = subjectForTopic(doc.filename);
  if (fromFilename != 'Study') {
    return fromFilename;
  }

  // 2. Check topic tags
  for (final tag in doc.topicTags) {
    final fromTag = subjectForTopic(tag.name);
    if (fromTag != 'Study') {
      return fromTag;
    }
  }

  return 'Study';
}

/// Returns a friendly icon/emoji for the subject.
String subjectEmoji(String? subject) {
  if (subject == null) return '📚';
  switch (subject.toLowerCase()) {
    case 'physics':
      return '⚛️';
    case 'mathematics':
    case 'maths':
    case 'math':
      return '📐';
    case 'chemistry':
      return '🧪';
    case 'biology':
      return '🧬';
    case 'computer science':
      return '💻';
    case 'engineering':
      return '⚙️';
    case 'history':
      return '📜';
    case 'government & politics':
    case 'government':
    case 'politics':
      return '🏛️';
    case 'economics':
      return '📈';
    case 'psychology':
      return '🧠';
    case 'english & literature':
    case 'english':
    case 'literature':
      return '📚';
    case 'earth & space science':
    case 'earth science':
      return '🌍';
    case 'sociology & anthropology':
    case 'sociology':
    case 'anthropology':
      return '👥';
    case 'philosophy':
      return '💭';
    case 'business':
    case 'business & management':
      return '💼';
    case 'art & music':
    case 'art':
    case 'music':
      return '🎨';
    case 'health & medicine':
    case 'medicine':
      return '🩺';
    case 'world languages':
    case 'foreign languages':
      return '🗣️';
    default:
      return '📖';
  }
}

/// Returns an accent color for the subject.
Color subjectColor(String? subject) {
  if (subject == null) return const Color(0xFF6366F1); // Indigo
  switch (subject.toLowerCase()) {
    case 'physics':
      return const Color(0xFF8B5CF6); // Violet / Purple
    case 'mathematics':
    case 'maths':
    case 'math':
      return const Color(0xFF06B6D4); // Cyan
    case 'chemistry':
      return const Color(0xFFF59E0B); // Amber
    case 'biology':
      return const Color(0xFF10B981); // Emerald
    case 'computer science':
      return const Color(0xFF3B82F6); // Blue
    case 'engineering':
      return const Color(0xFF64748B); // Slate
    case 'history':
      return const Color(0xFFD97706); // Warm Amber / Bronze
    case 'government & politics':
    case 'government':
    case 'politics':
      return const Color(0xFF4F46E5); // Indigo / Navy
    case 'economics':
      return const Color(0xFF0D9488); // Teal
    case 'psychology':
      return const Color(0xFFEC4899); // Pink / Magenta
    case 'english & literature':
    case 'english':
    case 'literature':
      return const Color(0xFFE11D48); // Rose / Crimson
    case 'earth & space science':
    case 'earth science':
      return const Color(0xFF0284C7); // Sky Blue
    case 'sociology & anthropology':
    case 'sociology':
    case 'anthropology':
      return const Color(0xFF7C3AED); // Purple
    case 'philosophy':
      return const Color(0xFF78716C); // Stone
    case 'business':
    case 'business & management':
      return const Color(0xFF2563EB); // Royal Blue
    case 'art & music':
    case 'art':
    case 'music':
      return const Color(0xFFA855F7); // Fuchsia
    case 'health & medicine':
    case 'medicine':
      return const Color(0xFFEF4444); // Red
    case 'world languages':
    case 'foreign languages':
      return const Color(0xFF059669); // Green
    default:
      return const Color(0xFF6366F1); // Indigo
  }
}
