"""API versioning — Sprint 6.7.

Two pieces:

* :class:`VersionResponseMiddleware` — stamps every response with an
  ``X-API-Version`` header listing the version that served it. Lets a
  client confirm it talked to the version it asked for, and lets
  observability tools group request traffic by version without
  parsing paths.

* :data:`API_VERSIONS` — the canonical version table. A
  ``/api/versions`` discovery endpoint reads this list so clients can
  see what's live + what's deprecated without baking the routes into
  the client.

Why we don't use Accept-header negotiation
------------------------------------------
The project plan calls for "v1 prefix, version negotiation", and
the simplest implementation that satisfies both is path-based:
``/api/v1/...`` for v1, ``/api/v2/...`` when v2 ships. Path-based
versioning gives every version its own URL space, which makes
caching, routing, and grep-ability trivial. Accept-header
negotiation is the alternative ("``Accept: application/vnd.app+json;
version=2``" → server dispatches to v2 internally) but it requires
double-mounting handlers and a content-negotiation layer; both are
overhead the MVP doesn't need.

The middleware here therefore *announces* the version per response
without doing any routing magic — the prefix already did that.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response
from starlette.types import ASGIApp


@dataclass(frozen=True, slots=True)
class ApiVersion:
    """One row of :data:`API_VERSIONS`. Surfaced verbatim on the
    ``/api/versions`` endpoint so the wire shape doubles as the
    documentation."""

    version: str
    """The path prefix segment — ``"v1"``, ``"v2"``, etc."""

    status: Literal["stable", "preview", "deprecated"]
    """Lifecycle stage. ``deprecated`` versions stay reachable until
    their sunset date; clients should migrate before then."""

    sunset_date: str | None
    """ISO date the version will be removed, or ``None`` if no removal
    is planned. Only meaningful when ``status == "deprecated"``."""

    base_path: str
    """Full mount prefix — ``"/api/v1"``. Lets clients discover the
    base without templating the version into the URL themselves."""


# The authoritative list. Add a new entry when v2 ships; don't delete
# v1's entry until its sunset date.
API_VERSIONS: tuple[ApiVersion, ...] = (
    ApiVersion(
        version="v1",
        status="stable",
        sunset_date=None,
        base_path="/api/v1",
    ),
)


DEFAULT_VERSION: str = "v1"
"""Used by :class:`VersionResponseMiddleware` when the request path
doesn't carry a version prefix (e.g. ``/health``, ``/api/versions``).
Keeps the header set on every response without forcing the caller
to guess what to expect on un-versioned routes."""


class VersionResponseMiddleware(BaseHTTPMiddleware):
    """Stamps every response with the ``X-API-Version`` header.

    The version is parsed out of the request path — anything under
    ``/api/v1/`` is reported as ``v1``, etc. Un-versioned routes
    (``/health``, ``/api/versions``, ``/docs``) get the
    :data:`DEFAULT_VERSION`.

    Why parse the path instead of looking at the matched route
    --------------------------------------------------------------
    Starlette's middleware doesn't have access to the resolved route
    — that runs after the middleware chain. Path parsing is the
    cheap, correct alternative: the version is always the second
    segment when present, so the work is a single ``split``.
    """

    def __init__(self, app: ASGIApp) -> None:
        super().__init__(app)
        self._known = {v.version for v in API_VERSIONS}

    async def dispatch(self, request: Request, call_next) -> Response:
        version = _extract_version(request.url.path, known=self._known)
        response = await call_next(request)
        response.headers["X-API-Version"] = version or DEFAULT_VERSION
        return response


def _extract_version(path: str, *, known: set[str]) -> str | None:
    """Return the version segment from a path like ``/api/v1/...``.

    Returns ``None`` when the path doesn't start with ``/api/<known>``.
    The ``known`` filter prevents a request to ``/api/random-string``
    from being reported as ``random-string`` in the header.
    """
    if not path.startswith("/api/"):
        return None
    parts = path.split("/", 3)
    # Expect ['', 'api', '<version>', '<rest...>'] when present.
    if len(parts) < 3:
        return None
    candidate = parts[2]
    return candidate if candidate in known else None
