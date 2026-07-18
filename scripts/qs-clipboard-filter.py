#!/usr/bin/env python3
"""Best-effort credential filter for Elephant clipboard events."""

from __future__ import annotations

import math
import re
import subprocess
import sys
from collections import Counter


LABELED_SECRET = re.compile(
    r"(?im)\b(?:password|passwd|passphrase|pwd|username|user(?:\s*name)?|login|"
    r"account(?:\s*(?:id|name))?|auth(?:entication)?(?:\s*token)?|access[_ -]?token|"
    r"refresh[_ -]?token|bearer|api[_ -]?key|client[_ -]?secret|secret|otp|"
    r"one[_ -]?time[_ -]?(?:password|code)|verification[_ -]?code|recovery[_ -]?code)\b"
    r"\s*(?:=|:|is)\s*[^\s]{3,}"
)
EMAIL = re.compile(r"(?i)(?<![\w.+-])[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+\b")
PRIVATE_KEY = re.compile(r"-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----")
AUTH_HEADER = re.compile(r"(?im)^\s*(?:authorization|proxy-authorization)\s*:\s*\S+")
URI_CREDENTIAL = re.compile(r"(?i)\b[a-z][a-z0-9+.-]*://[^\s/:]+:[^\s/@]+@")
JWT = re.compile(r"\beyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\b")
KNOWN_TOKEN = re.compile(
    r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|"
    r"glpat-[A-Za-z0-9_-]{20,}|sk-(?:proj-)?[A-Za-z0-9_-]{20,}|"
    r"xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16})\b"
)
OTP = re.compile(r"^\s*\d{4,8}\s*$")
RECOVERY_CODES = re.compile(
    r"(?im)^(?:\s*[A-Z0-9]{4,}(?:-[A-Z0-9]{4,})+\s*(?:\r?\n|$)){2,}"
)
OPAQUE = re.compile(r"^[A-Za-z0-9_+/.=-]{20,}$")


def _entropy(value: str) -> float:
    counts = Counter(value)
    length = len(value)
    return -sum((count / length) * math.log2(count / length) for count in counts.values())


def is_sensitive(text: str) -> bool:
    value = text.strip()
    if not value:
        return False
    if any(pattern.search(text) for pattern in (
        LABELED_SECRET, EMAIL, PRIVATE_KEY, AUTH_HEADER, URI_CREDENTIAL,
        JWT, KNOWN_TOKEN, RECOVERY_CODES,
    )):
        return True
    if OTP.fullmatch(text):
        return True
    # Catch standalone, random-looking secrets without treating ordinary prose,
    # paths, or identifiers such as "alex123" as credentials.
    if OPAQUE.fullmatch(value):
        classes = sum(bool(re.search(pattern, value)) for pattern in (r"[a-z]", r"[A-Z]", r"\d", r"[^A-Za-z0-9]"))
        return classes >= 3 and _entropy(value) >= 3.5
    return False


def main() -> int:
    check_only = len(sys.argv) == 2 and sys.argv[1] == "--check"
    command = sys.argv[1:]
    payload = sys.stdin.buffer.read()
    try:
        text = payload.decode("utf-8")
    except UnicodeDecodeError:
        text = ""  # Preserve non-text clipboard history such as images.

    sensitive = bool(text) and is_sensitive(text)
    if check_only:
        return 1 if sensitive else 0
    if sensitive:
        return 0
    if not command:
        return 2
    return subprocess.run(command, input=payload, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
