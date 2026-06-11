import re
from pathlib import Path

def main():
    path = Path("backend/tests/unit/services/test_answer_evaluation.py")
    content = path.read_text(encoding="utf-8")
    
    # Replace assert await evaluate(...).is_correct with assert (await evaluate(...)).is_correct
    content = re.sub(r"assert await evaluate\(([^)]+)\)\.([a-zA-Z_]+)", r"assert (await evaluate(\1)).\2", content)
    
    # Replace assert await evaluate(...).rubric_score with assert (await evaluate(...)).rubric_score
    content = re.sub(r"await evaluate\(([^)]+)\)\.rubric_score", r"(await evaluate(\1)).rubric_score", content)

    path.write_text(content, encoding="utf-8")
    print("Fixed await syntax in test_answer_evaluation.py")

if __name__ == "__main__":
    main()
