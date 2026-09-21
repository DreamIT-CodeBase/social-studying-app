import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_study_app/shared/models/document.dart';

void main() {
  test('parses backend document JSON', () {
    const rawJson = '''[
  {
    "id": "doc_698a90f58e684ad4863a66791d390050",
    "workspace_id": "wsp_self_usr_51b9f1d9f0274b37ae87f4b3ef0f301e",
    "filename": "Algebra_1_Massive_200_Equation_Practice_Quiz (1).pdf",
    "doc_type": "pdf",
    "status": "ready",
    "chunk_count": 5,
    "topic_tags": [
      {
        "name": "One-Step Equations",
        "confidence": 1.0,
        "source": "ai",
        "description": "Covers solving equations that require only one operation to isolate the variable.",
        "complexity_level": 1,
        "page_refs": [
          1,
          2,
          3
        ]
      }
    ],
    "moderation_flagged": false,
    "created_at": "2026-09-19T07:50:02.747188+00:00",
    "page_count": 13,
    "text_char_count": 8241,
    "languages": [],
    "processing_error": null,
    "category": "Algebra 1",
    "subcategory": null
  }
]''';
    final list = (jsonDecode(rawJson) as List)
        .map((d) => Document.fromJson(d as Map<String, dynamic>))
        .toList();
    expect(list.length, 1);
    expect(list.first.id, 'doc_698a90f58e684ad4863a66791d390050');
    expect(list.first.status, DocumentStatus.ready);
  });
}
