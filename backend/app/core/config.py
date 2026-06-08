from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    environment: str = "development"
    allowed_origins: list[str] = ["http://localhost:3000"]

    # Flutter web (`flutter run -d chrome`) binds a *random* localhost port on
    # every run, so a fixed allowed_origins entry can't keep up. In non-prod we
    # additionally allow any localhost / 127.0.0.1 port via this regex (wired in
    # main.py). With allow_credentials=True the matched origin is echoed back
    # verbatim — never "*" — so credentialed requests still work. Applied ONLY
    # when environment != "production" (see main.py), so prod keeps the explicit
    # allowed_origins allowlist and nothing else.
    allowed_origin_regex: str = r"http://(localhost|127\.0\.0\.1)(:\d+)?"

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

    # Dev-auth bypass — lets the Flutter demo login exercise the *real*
    # backend without a full Entra interactive sign-in (MSAL is not wired
    # yet; auth_repository.dart is still mocked). When a request arrives
    # bearing exactly ``dev_auth_token``, auth.get_current_user resolves it
    # to the seeded demo user (``dev_auth_user_id`` in tenant
    # ``dev_auth_tenant_id``) instead of validating a JWT.
    #
    # DOUBLE-GATED so it can never weaken production: the bypass is active
    # only when ``environment != "production"`` AND ``dev_auth_token`` is
    # non-empty. The default empty token means the bypass is OFF unless an
    # operator explicitly sets it (we set it on ca-api-dev only). Blast
    # radius if the token leaks is limited to the isolated demo tenant's
    # Cosmos database. Seed the demo identity with scripts/seed_demo_tenant.py.
    dev_auth_token: str = ""
    dev_auth_tenant_id: str = "ten_demo_001"
    dev_auth_user_id: str = "usr_demo_001"

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
    service_bus_vectorization_queue: str = "vectorization"

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

    # Sprint 2.9 — vectorization (embeddings + Azure AI Search push).
    # text-embedding-3-small: 1536 dims, 8191-token cap per input, ~$0.02/1M
    # input tokens. Plenty for K-12 educational content retrieval; reserve
    # text-embedding-3-large (3072 dims, 6x cost) for if/when we measure
    # retrieval quality gaps that justify the spend.
    azure_openai_embedding_deployment: str = "text-embedding-3-small"
    # Azure caps embedding requests at 16 inputs per call by default. Stay
    # under that so we don't have to handle 400s mid-document.
    azure_openai_embedding_batch_size: int = 16
    # Vector dimensionality. MUST match the deployed model — if the deployment
    # changes, AI Search index has to be rebuilt because the field's
    # `dimensions` is fixed at index creation time.
    azure_openai_embedding_dim: int = 1536

    # Per-tenant Azure AI Search index naming. Format: `{prefix}-{sanitized
    # tenant_id}` — tenant ids contain underscores (e.g. `ten_<uuid>`) which
    # AI Search rejects in index names, so the service replaces underscores
    # with dashes at lookup time. See ``azure_ai_search.index_name_for``.
    search_chunks_index_prefix: str = "chunks"

    # Sprint 5.6 — Azure Notification Hubs. Connection string carries
    # the SAS key + endpoint (``Endpoint=sb://...;SharedAccessKeyName=...;
    # SharedAccessKey=...``). Empty in dev → the notification service
    # falls back to ``LoggingSender`` so local development never tries
    # to call a non-existent ANH. Hub name is the per-environment
    # ``study-app-<env>`` from ``infra/bicep/modules/notification-hub.bicep``.
    notification_hub_connection_string: str = ""
    notification_hub_name: str = ""


settings = Settings()
