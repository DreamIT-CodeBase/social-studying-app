---
globs: "mcp-server/prompts/**/*.txt"
---

# AI Prompt Rules

## Ethos: Every Prompt Is a Product
A prompt that generates a bad question is worse than no question at all. A student seeing a confusing, factually wrong, or off-topic question loses trust in the entire app. Treat prompt engineering with the same rigor as production code. Test it, version it, measure it.

## Structure
Every prompt file starts with a version comment: `# v1.0 — 2026-04-29 — initial`. System prompt and user prompt sections clearly separated. Variables use {{double_braces}} syntax: `{{topic}}`, `{{difficulty}}`, `{{source_content}}`.

## Question Generation
Always constrain to source material: "Generate questions ONLY based on the provided content." Specify output format explicitly as JSON with exact field names. Include negative constraints: "Do NOT reference information outside the provided content." For MCQs: require exactly 4 options, specify that distractors must be plausible but unambiguously wrong. For math: specify notation format (LaTeX or plain text). Include difficulty calibration language: "This question should be {{difficulty}} level."

## Anti-Slop for Prompts
No vague instructions ("generate a good question"). Be specific about what "good" means. No open-ended output formats — always specify exact JSON schema. No prompts that work "most of the time" — if a prompt fails on 1 in 20 inputs, it needs fixing. Track regeneration rate per prompt — if >5%, the prompt needs work, not a bigger safety net. Test every prompt change against 5+ diverse inputs before committing. Log prompt versions in generated question metadata for debugging.
