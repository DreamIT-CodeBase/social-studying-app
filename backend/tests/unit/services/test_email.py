"""Microsoft Graph transactional email tests."""

import json

import httpx
import pytest

from app.services.email import EmailPayload, MicrosoftGraphEmailSender


@pytest.mark.asyncio
async def test_graph_sender_acquires_token_and_sends_html_message():
    requests: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        if request.url.path.endswith("/oauth2/v2.0/token"):
            return httpx.Response(
                200,
                json={"access_token": "token_value", "expires_in": 3600},
            )
        return httpx.Response(202)

    sender = MicrosoftGraphEmailSender(
        tenant_id="tenant_id",
        client_id="client_id",
        client_secret="client_secret",
        sender_email="socials@socialstudying.ai",
        transport=httpx.MockTransport(handler),
    )
    sent = await sender.send(
        EmailPayload(
            to_email="student@example.com",
            subject="Workspace invitation",
            body_text="Plain invitation",
            body_html="<p>HTML invitation</p>",
        )
    )

    assert sent is True
    assert len(requests) == 2
    assert requests[1].headers["Authorization"] == "Bearer token_value"
    payload = json.loads(requests[1].content)
    assert payload["message"]["body"] == {
        "contentType": "HTML",
        "content": "<p>HTML invitation</p>",
    }
    assert payload["message"]["toRecipients"][0]["emailAddress"]["address"] == (
        "student@example.com"
    )
    assert payload["saveToSentItems"] is True


@pytest.mark.asyncio
async def test_graph_sender_returns_false_when_token_request_fails():
    sender = MicrosoftGraphEmailSender(
        tenant_id="tenant_id",
        client_id="client_id",
        client_secret="client_secret",
        sender_email="socials@socialstudying.ai",
        transport=httpx.MockTransport(lambda request: httpx.Response(401)),
    )

    sent = await sender.send(
        EmailPayload(
            to_email="student@example.com",
            subject="Invitation",
            body_text="Invitation",
        )
    )

    assert sent is False
