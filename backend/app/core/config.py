from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    environment: str = "development"
    allowed_origins: list[str] = ["http://localhost:3000"]

    # Azure Cosmos DB (MongoDB API)
    # replaced by Azure connection string in prod
    cosmos_connection_string: str = "mongodb://localhost:27017"

    # Azure AI Search
    search_endpoint: str = ""
    search_key: str = ""

    # Azure OpenAI (via AI Foundry)
    azure_openai_endpoint: str = ""
    azure_openai_key: str = ""
    azure_openai_deployment: str = "gpt-4o"

    # Azure AD B2C
    b2c_tenant_id: str = ""
    b2c_client_id: str = ""
    b2c_policy_name: str = "B2C_1_signupsignin"

    # Redis
    redis_url: str = "redis://localhost:6379"

    # Azure Blob Storage
    storage_connection_string: str = ""
    storage_container: str = "documents"

    # Azure AI Document Intelligence (formerly Form Recognizer)
    document_intelligence_endpoint: str = ""
    document_intelligence_key: str = ""

    # Azure AI Content Safety
    # Profile: "educational lenient" — strict on Hate/SelfHarm/Sexual (≥2 flags),
    # lenient on Violence (≥4 flags) so historical content (wars, conflicts)
    # doesn't trip the scanner. See knowledge.md §10.
    # Severities use the FOUR_SEVERITY_LEVELS scale: 0, 2, 4, 6.
    content_safety_endpoint: str = ""
    content_safety_key: str = ""
    content_safety_hate_threshold: int = 2
    content_safety_self_harm_threshold: int = 2
    content_safety_sexual_threshold: int = 2
    content_safety_violence_threshold: int = 4

    # Azure Service Bus
    service_bus_connection: str = ""
    service_bus_documents_queue: str = "document-ingestion"
    service_bus_topics_queue: str = "topic-extraction"
    service_bus_chunks_queue: str = "chunking"

    # Sprint 2.8 — chunker tuning. Character-based for simplicity (no
    # tokenizer dependency). 2000 chars ≈ 500 tokens at the GPT-4o
    # ~4-char/token average for English educational content.
    chunk_target_chars: int = 2_000
    chunk_overlap_chars: int = 200
    chunk_min_chars: int = 200      # below this and we'd be emitting too-small chunks

    # Azure OpenAI tuning knobs for topic extraction (Sprint 2.5).
    # Token cap protects against runaway prompts; very long textbooks get
    # auto-summarized to ~60K chars before the call (see topic_extraction.py).
    openai_topic_extraction_max_input_chars: int = 60_000
    openai_topic_extraction_max_output_tokens: int = 4_000


settings = Settings()
