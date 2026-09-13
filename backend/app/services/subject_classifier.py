"""Multilingual Subject Classifier service.

Classifies documents and topics into core educational subjects
(Physics, Mathematics, Chemistry, Biology, Computer Science) with
multilingual keyword support across English, Hindi, Spanish, French,
and German.
"""

from __future__ import annotations

import unicodedata
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from app.models.document import Document

_PHYSICS_TERMS = [
    # Multi-word / specific terms first
    "quantum mechanics", "thermodynamics", "nuclear physics", "magnetic field", "electric current",
    "ap physics 1", "ap physics 2", "ap physics c", "ap physics", "classical mechanics",
    "electromagnetism", "special relativity", "general relativity", "fluid dynamics",
    # English
    "physics", "force", "gravity", "motion", "wave", "energy", "velocity",
    "mechanics", "electricity", "magnetism", "quantum", "optics",
    "friction", "acceleration", "kinematics", "astrophysics",
    # Hindi
    "भौतिक विज्ञान", "भौतिकी", "भौतिक", "गति के नियम", "गुरुत्वाकर्षण", "ऊर्जा", "प्रकाश",
    # Spanish
    "física clásica", "física", "fisica", "fuerza", "gravedad", "movimiento", "onda",
    "energía", "energia", "velocidad", "mecánica", "mecanica", "electricidad",
    # French
    "physique quantique", "physique", "gravité", "gravite", "mouvement", "vitesse",
    # German
    "physik", "kraft", "gravitation", "bewegung", "welle", "geschwindigkeit",
]

_CHEMISTRY_TERMS = [
    # Multi-word / specific terms first
    "atomic structure", "periodic table", "chemical bond", "chemical bonding",
    "mole concept", "acids, bases and ph", "acids and bases", "chemical reaction",
    "chemical reactions", "organic chemistry", "inorganic chemistry",
    "ap chemistry", "ap chem", "general chemistry", "gen chem", "organic chem", "orgo",
    "physical chemistry", "analytical chemistry", "chemical kinetics",
    "ionic bond", "covalent bond", "metallic bond", "molar mass", "avogadro",
    "atomic number", "mass number", "protons", "electrons", "neutrons",
    "single displacement", "double displacement", "decomposition reaction",
    "combination reaction", "stoichiometry", "titration", "oxidation reduction",
    "रासायनिक अभिक्रियाएं", "रासायनिक अभिक्रिया", "रासायनिक समीकरण", "आवर्त सारणी",
    "química inorgánica", "quimica inorganica", "química orgánica", "chimie organique",
    # English
    "chemistry", "chemical", "atom", "bond", "molecule", "molar",
    "reaction", "element", "compound", "periodic", "stoichiometry",
    "organic", "acid", "base", "oxidation", "valence", "titration", "ph",
    # Hindi
    "रसायन विज्ञान", "रसायनशास्त्र", "रसायनिक", "रसायन", "परमाणु", "अणु", "रासायनिक",
    # Spanish
    "química", "quimica", "químico", "quimico", "átomo", "atomo", "enlace",
    "molécula", "molecula", "reacción", "reaccion", "compuesto",
    # French
    "chimie", "chimique", "atome", "liaison", "molécule", "molecule",
    "réaction", "reaction", "élément", "element", "composé", "compose",
    # German
    "chemie", "chemisch", "bindung", "molekül", "molekuel", "reaktion", "verbindung",
]

_BIOLOGY_TERMS = [
    # Multi-word / specific terms first
    "molecular biology", "cell biology", "cellular respiration", "photosynthesis",
    "ap biology", "ap bio", "anatomy and physiology", "evolutionary biology",
    "कोशिका संरचना", "जीवविज्ञान", "biología celular", "biologie cellulaire",
    # English
    "biology", "cell", "gene", "dna", "rna", "mitosis", "meiosis",
    "organism", "ecology", "anatomy", "physiology", "evolution",
    "ecosystem", "protein", "bacteria", "virus", "genetics", "microbiology",
    "neuroscience", "botany", "zoology", "immunology",
    # Hindi
    "कोशिका", "जीन", "जीव", "पारिस्थितिकी", "शरीर रचना",
    # Spanish
    "biología", "biologia", "célula", "celula", "gen", "adn", "ecología",
    "ecologia", "anatomía", "anatomia", "fotosíntesis", "fotosintesis",
    # French
    "biologie", "cellule", "gène", "gene", "écologie", "ecologie", "anatomie",
    "physiologie", "photosynthèse", "photosynthese",
    # German
    "biologie", "zelle", "gen", "organismus", "ökologie", "oekologie",
]

_MATH_TERMS = [
    # Multi-word / specific terms first
    "differential calculus", "integral calculus", "quadratic equation",
    "ap calculus ab", "ap calculus bc", "ap calculus", "ap calc", "ap statistics", "ap stats",
    "multivariable calculus", "linear algebra", "differential equations", "discrete math",
    "discrete mathematics", "vector calculus", "abstract algebra", "precalculus", "pre-calculus",
    "त्रिकोणमिति", "समीकरण", "बीजगणित", "ज्यामिति",
    # English
    "math", "maths", "mathematics", "algebra", "geometry", "calculus",
    "equation", "probability", "statistics", "trigonometry", "arithmetic",
    "fraction", "matrix", "differential", "integral", "polynomial", "derivative",
    # Hindi
    "गणित", "कलन", "प्रायिकता", "रेखागणित",
    # Spanish
    "matemáticas", "matematicas", "álgebra", "algebra", "geometría", "geometria",
    "cálculo", "calculo", "ecuación", "ecuacion", "trigonometría", "trigonometria",
    # French
    "mathématiques", "mathematiques", "algèbre", "algebre", "géométrie", "geometrie",
    "calcul", "équation", "equation", "trigonométrie", "trigonometrie",
    # German
    "mathematik", "mathe", "geometrie", "gleichung", "wahrscheinlichkeitsrechnung",
]

_CS_TERMS = [
    # Multi-word / specific terms first
    "computer science", "artificial intelligence", "machine learning", "data structure",
    "data structures", "ap computer science", "ap csa", "ap csp", "deep learning",
    "software engineering", "object oriented", "computer systems", "web development",
    # English / Universal
    "computer", "software", "program", "coding", "algorithm", "database",
    "cloud", "azure", "microsoft", "copilot", "github", "agent",
    "foundry", "network", "cyber", "cybersecurity", "api", "python", "java", "javascript",
    "sql", "compiler", "operating system",
    # Hindi
    "संगणक", "कंप्यूटर", "सॉफ्टवेयर", "प्रोग्रामिंग",
    # Spanish
    "informática", "informatica", "computación", "computacion", "programacion",
    # French
    "informatique", "programmation", "algorithme",
    # German
    "informatik", "programmierung",
]

_ENGINEERING_TERMS = [
    "aerospace engineering", "biomedical engineering", "chemical engineering", "civil engineering",
    "electrical engineering", "mechanical engineering", "computer engineering", "industrial engineering",
    "robotics engineering", "circuits and systems", "materials science", "fluid mechanics",
    "engineering", "engineer", "robotics", "circuit", "circuits", "transistor", "statics",
    "dynamics", "microcontroller", "arduino", "solidworks", "schematic", "thermodynamic cycle",
]

_HISTORY_TERMS = [
    "us history", "united states history", "world history", "european history", "american history",
    "ancient history", "medieval history", "modern history", "ap us history", "apush", "ap world",
    "ap euro", "cold war", "world war i", "world war ii", "world war", "civil war",
    "american revolution", "french revolution", "industrial revolution", "great depression",
    "history", "historical", "civilization", "dynasty", "empire", "colonial", "monarchy",
    "renaissance", "reconstruction", "treaty", "confederacy", "holocaust", "imperialism",
]

_GOVERNMENT_TERMS = [
    "us government", "american government", "political science", "comparative politics",
    "international relations", "constitutional law", "ap government", "ap gov", "public policy",
    "supreme court", "bill of rights", "executive branch", "legislative branch",
    "government", "politics", "political", "constitution", "congress", "senate", "judiciary",
    "democracy", "federalism", "civics", "diplomacy", "sovereignty", "electoral", "voting rights",
]

_ECONOMICS_TERMS = [
    "microeconomics", "macroeconomics", "ap microeconomics", "ap macroeconomics", "ap micro",
    "ap macro", "supply and demand", "monetary policy", "fiscal policy", "financial accounting",
    "corporate finance", "econometrics", "gross domestic product", "market equilibrium",
    "economics", "economy", "economic", "inflation", "deflation", "interest rate", "elasticity",
    "monopoly", "oligopoly", "opportunity cost", "gdp", "consumer surplus", "producer surplus",
    "finance", "fiscal", "taxation", "investment",
]

_PSYCHOLOGY_TERMS = [
    "cognitive psychology", "developmental psychology", "abnormal psychology", "social psychology",
    "clinical psychology", "behavioral psychology", "behavioral neuroscience", "ap psychology",
    "ap psych", "mental health", "central nervous system", "classical conditioning",
    "psychology", "psychological", "psychologist", "cognition", "neuroscience", "behavior",
    "behaviour", "perception", "conditioning", "pavlov", "skinner", "freud", "memory",
    "neurotransmitter", "dopamine", "serotonin", "synapse", "cortex", "psychopathology", "therapy",
]

_ENGLISH_LITERATURE_TERMS = [
    "english literature", "american literature", "british literature", "world literature",
    "english language", "ap english", "ap literature", "ap lit", "ap lang", "creative writing",
    "rhetorical analysis", "literary analysis", "close reading", "short story",
    "literature", "poetry", "poem", "poet", "essay", "grammar", "rhetoric", "metaphor",
    "simile", "symbolism", "sonnet", "prose", "stanza", "syntax", "fiction", "novel",
    "narrative", "protagonist", "antagonist", "shakespeare", "literary", "comprehension",
]

_EARTH_SPACE_TERMS = [
    "earth science", "environmental science", "ap environmental science", "apes", "space science",
    "planetary science", "plate tectonics", "climate change", "solar system", "milky way",
    "geology", "geological", "meteorology", "oceanography", "astronomy", "mineral", "volcano",
    "earthquake", "atmosphere", "stratosphere", "biodiversity", "fossil", "glacier", "telescope",
    "planet", "galaxy", "asteroid",
]

_SOCIOLOGY_ANTHROPOLOGY_TERMS = [
    "cultural anthropology", "physical anthropology", "social anthropology", "social structure",
    "social sciences", "social studies", "gender studies", "ethnic studies",
    "sociology", "sociological", "anthropology", "anthropological", "culture", "ethnography",
    "archaeology", "stratification", "socialization", "demographics", "inequality", "criminology",
]

_PHILOSOPHY_TERMS = [
    "introduction to philosophy", "political philosophy", "moral philosophy", "philosophy of science",
    "philosophy of mind", "critical thinking",
    "philosophy", "philosophical", "philosopher", "ethics", "ethical", "morality", "epistemology",
    "metaphysics", "existentialism", "utilitarianism", "kant", "socrates", "plato", "aristotle",
    "nietzsche", "syllogism", "rationalism", "empiricism",
]

_BUSINESS_TERMS = [
    "business administration", "business management", "organizational behavior", "supply chain management",
    "human resources", "business law", "market research",
    "business", "management", "marketing", "entrepreneurship", "commerce", "strategy", "leadership",
    "logistics", "advertising", "venture", "startup", "revenue", "branding", "stakeholder",
]

_ART_MUSIC_TERMS = [
    "art history", "ap art history", "music theory", "music appreciation", "visual arts",
    "graphic design", "studio art", "fine arts",
    "art", "music", "musical", "painting", "sculpture", "composition", "harmony", "melody",
    "rhythm", "chord", "scale", "symphony", "theatre", "theater", "film studies", "photography",
]

_HEALTH_MEDICINE_TERMS = [
    "health science", "public health", "sports medicine", "kinesiology", "human anatomy",
    "medical terminology",
    "medicine", "medical", "nursing", "nutrition", "pharmacology", "pathology", "pediatrics",
    "epidemiology", "diagnosis", "clinic", "clinical", "hospital", "wellness",
]

_WORLD_LANGUAGES_TERMS = [
    "foreign language", "world languages", "spanish language", "french language", "german language",
    "latin language", "mandarin chinese", "japanese language", "language acquisition",
    "linguistics", "conjugation", "phonetics", "espanol", "español", "français", "deutsch", "translation",
]

_SUBJECT_CONFIGS = [
    # Most specific compound domains first
    ("Computer Science", _CS_TERMS),
    ("Engineering", _ENGINEERING_TERMS),
    ("Government & Politics", _GOVERNMENT_TERMS),
    ("History", _HISTORY_TERMS),
    ("Economics", _ECONOMICS_TERMS),
    ("Psychology", _PSYCHOLOGY_TERMS),
    ("English & Literature", _ENGLISH_LITERATURE_TERMS),
    ("Earth & Space Science", _EARTH_SPACE_TERMS),
    ("Sociology & Anthropology", _SOCIOLOGY_ANTHROPOLOGY_TERMS),
    ("Philosophy", _PHILOSOPHY_TERMS),
    ("Business", _BUSINESS_TERMS),
    ("Art & Music", _ART_MUSIC_TERMS),
    ("Health & Medicine", _HEALTH_MEDICINE_TERMS),
    ("World Languages", _WORLD_LANGUAGES_TERMS),
    ("Chemistry", _CHEMISTRY_TERMS),
    ("Biology", _BIOLOGY_TERMS),
    ("Physics", _PHYSICS_TERMS),
    ("Mathematics", _MATH_TERMS),
]


def _normalize(text: str) -> str:
    return unicodedata.normalize("NFKC", text).casefold()


def classify_subject_from_text(text: str) -> str:
    """Classify a subject name from a topic, document filename, or text string.

    Uses weighted longest-matching scoring across domains so specific terms
    (like 'chemical kinetics', 'us history', 'differential equations') win over
    generic subwords.

    Returns one of standard US school & college subjects or 'Study'.
    """
    normalized = _normalize(text)

    scores: dict[str, int] = {}
    for subject, terms in _SUBJECT_CONFIGS:
        score = 0
        for term in terms:
            if term in normalized:
                # Longer matches indicate much higher domain specificity
                score += len(term) ** 2
        if score > 0:
            scores[subject] = score

    if not scores:
        return "Study"

    # Return the subject with highest match weight
    return max(scores.items(), key=lambda item: item[1])[0]


def classify_document_subject(doc: Document) -> str:
    """Classify the subject of a document using LLM-evaluated category, filename, and topic tags."""
    # 0. Test LLM-evaluated category first (e.g. novel name, Bible, specific book/subject)
    if doc.category and doc.category.strip():
        return doc.category.strip()

    # 1. Test filename
    from_filename = classify_subject_from_text(doc.filename)
    if from_filename != "Study":
        return from_filename

    # 2. Test topic tags
    if doc.topic_tags:
        for tag in doc.topic_tags:
            from_tag = classify_subject_from_text(tag.name)
            if from_tag != "Study":
                return from_tag

    return "Study"


async def classify_subject_with_llm(text: str, filename: str = "") -> str:
    """Judge the subject, novel title, or book name using LLM.

    If the material is a novel (e.g. 'The Great Gatsby', 'To Kill a Mockingbird'),
    religious text (e.g. 'The Holy Bible'), or specific work, the LLM will return
    the exact title as the subject name.
    """
    if not text and not filename:
        return "Study"

    try:
        from app.services import azure_openai

        snippet = text[:4000] if text else ""
        system_prompt = (
            "You are an expert curriculum and literature analyst. Identify and judge the exact overarching "
            "Subject or Book/Novel/Text Title of this study material (e.g. 'The Great Gatsby', 'The Holy Bible', "
            "'To Kill a Mockingbird', 'Organic Chemistry', 'World History'). If it is a novel, religious text, "
            "or literary work, return the specific title as the subject. "
            "Output strict JSON matching: {\"subject\": \"Title or Subject\"}"
        )
        user_prompt = f"Filename: {filename}\n\nContent snippet:\n{snippet}\n\nIdentify the subject or novel/book title."
        resp = await azure_openai.chat_json(
            system_prompt=system_prompt,
            user_prompt=user_prompt,
            max_output_tokens=100,
        )
        subject = resp.get("subject")
        if isinstance(subject, str) and subject.strip():
            return subject.strip()
    except Exception:
        pass

    # Fallback to static matching
    from_fn = classify_subject_from_text(filename)
    if from_fn != "Study":
        return from_fn
    return classify_subject_from_text(text)

