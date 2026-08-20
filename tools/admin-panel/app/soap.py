"""SOAP client for the worldserver console.

AzerothCore exposes a single gSOAP method, `ns1:executeCommand`, over plain HTTP
with Basic auth (src/server/apps/worldserver/ACSoap/ACSoap.cpp). The calling
account must exist in acore_auth and have gmlevel >= 3 (SEC_ADMINISTRATOR).
"""

import html
import re

import httpx

from . import config

_ENVELOPE = (
    '<?xml version="1.0" encoding="utf-8"?>'
    '<SOAP-ENV:Envelope'
    ' xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/"'
    ' xmlns:ns1="urn:AC">'
    "<SOAP-ENV:Body>"
    "<ns1:executeCommand><command>{cmd}</command></ns1:executeCommand>"
    "</SOAP-ENV:Body></SOAP-ENV:Envelope>"
)

_RESULT_RE = re.compile(r"<result>(.*?)</result>", re.S)
_FAULT_RE = re.compile(r"<faultstring>(.*?)</faultstring>", re.S)


class SoapError(RuntimeError):
    pass


def configured() -> bool:
    return bool(config.SOAP_USER and config.SOAP_PASS)


def execute(command: str, timeout: float = 15.0) -> str:
    """Run a console command; return its output. Raises SoapError on failure."""
    if not configured():
        raise SoapError(
            "SOAP credentials are not set (ADMIN_SOAP_USER / ADMIN_SOAP_PASS). "
            "Needs an acore_auth account with gmlevel >= 3.")

    url = f"http://{config.SOAP_HOST}:{config.SOAP_PORT}/"
    body = _ENVELOPE.format(cmd=html.escape(command))
    try:
        resp = httpx.post(
            url,
            content=body.encode("utf-8"),
            headers={"Content-Type": "application/xml; charset=utf-8"},
            auth=(config.SOAP_USER, config.SOAP_PASS),
            timeout=timeout,
        )
    except httpx.HTTPError as exc:
        raise SoapError(f"worldserver unreachable at {url}: {exc}") from exc

    text = resp.text
    fault = _FAULT_RE.search(text)
    if fault:
        raise SoapError(html.unescape(fault.group(1).strip()))
    if resp.status_code != 200:
        raise SoapError(f"HTTP {resp.status_code}: {text[:400]}")

    match = _RESULT_RE.search(text)
    return html.unescape(match.group(1)).strip() if match else text.strip()


def reload_config() -> str:
    """Make the worldserver re-read module tables.

    `.reload config` fires WorldScript::OnAfterConfigLoad(reload=true), which is
    where mod-environmental-effects calls LoadRules().
    """
    return execute("reload config")


def ping() -> str:
    return execute("server info", timeout=5.0)
