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

    # Azure AI Document Intelligence (formerly Form Recognizer)
    document_intelligence_endpoint: str = ""
    document_intelligence_key: str = ""

    # Azure Service Bus
    service_bus_connection: str = ""


settings = Settings()
