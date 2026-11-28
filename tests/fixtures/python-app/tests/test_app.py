import os
import socket
from urllib.parse import urlparse

import pytest

from app.main import health


def test_health():
    assert health() == {"status": "ok"}


@pytest.mark.skipif(not os.environ.get("TEST_REDIS_URL"), reason="no Redis service configured")
def test_redis_service_answers():
    # The workflow starts the redis service and exposes TEST_REDIS_URL with REQUIRE_SERVICES=1.
    assert os.environ.get("REQUIRE_SERVICES") == "1"
    url = urlparse(os.environ["TEST_REDIS_URL"])
    with socket.create_connection((url.hostname, url.port), timeout=5) as conn:
        conn.sendall(b"PING\r\n")
        assert conn.recv(16) == b"+PONG\r\n"
