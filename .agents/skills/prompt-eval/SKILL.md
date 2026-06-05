---
name: prompt-eval
description: Evaluates AI prompt quality by testing against diverse inputs and checking output consistency. Use when modifying question generation or topic extraction prompts.
disable-model-invocation: true
---

# Prompt Evaluation Skill

When evaluating or modifying an AI prompt in `mcp-server/prompts/`:

## Step 1: Understand the Prompt
Read the prompt file and identify what input variables it expects, what output format it should produce, and what constraints it enforces.

## Step 2: Create Test Inputs
Generate 5 diverse test inputs covering: (1) a straightforward, well-structured input (happy path), (2) a very short/minimal input (edge case), (3) a very long/complex input (stress test), (4) an input in a different subject area than the prompt was likely designed for, (5) an input with ambiguous or borderline content.

## Step 3: Evaluate Outputs
For each test input, check: does the output match the expected format (valid JSON, correct fields)? Does the output respect all constraints (difficulty, source-only, no hallucination)? Is the output quality acceptable for a student? Are MCQ distractors plausible but clearly wrong? Is the language appropriate for the target age group?

## Step 4: Report
Create a markdown report at `docs/prompt-evals/{prompt-name}-{date}.md` with prompt version tested, each test input and output, pass/fail per criterion, and recommendations for improvement.

## Ethos: Search Before Building
Before changing a prompt, check if the issue is the prompt or the retrieval. A perfect prompt fed garbage chunks produces garbage questions. Verify the input quality first.
