"""MCP server — AI pipeline for question generation and topic extraction."""
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("social-study-ai-pipeline")


@mcp.tool()
async def generate_questions(
    source_content: str,
    topic: str,
    difficulty: str,
    count: int = 5,
) -> dict:
    """Generate MCQ questions from source material."""
    raise NotImplementedError("Implement with Azure OpenAI")


@mcp.tool()
async def extract_topics(source_content: str) -> list[str]:
    """Extract study topics from uploaded document content."""
    raise NotImplementedError("Implement with Azure OpenAI")
