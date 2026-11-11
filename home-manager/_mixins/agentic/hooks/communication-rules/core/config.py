"""Load advisory detection data without permission or correction prompts."""

from __future__ import annotations

import argparse
import json

from core.detection import read_text_file

FALLBACK_RULES_TEXT = "Communication Rules were not loaded."

DEFAULT_POLICY = {
    "blockedCodepoints": [
        {"codepoint": "U+2014", "name": "em dash"},
        {"codepoint": "U+2013", "name": "en dash"},
    ],
    "hardGateBannedTerms": [
        "delve",
        "leverage",
        "tapestry",
        "robust",
        "seamless",
        "pivotal",
        "crucial",
        "testament",
        "cutting-edge",
        "multifaceted",
        "realm",
        "vibrant",
        "nuanced",
        "intricate",
        "showcasing",
        "streamline",
        "garnered",
        "underpinning",
        "underscores",
        "boasts",
    ],
}


class Config:
    def __init__(
        self,
        rules_text: str,
        reminder_prompt: str | None,
        block_message: str | None,
        policy: dict,
    ) -> None:
        self.rules_text = rules_text
        self.policy = policy


def normalise_loaded_config(value: object) -> dict:
    if not isinstance(value, dict):
        return {}
    if isinstance(value.get("agentic"), dict):
        value = value["agentic"]
    if isinstance(value.get("communicationRules"), dict):
        return value["communicationRules"]
    return value


def load_config(args: argparse.Namespace) -> Config | None:
    rules_text = FALLBACK_RULES_TEXT
    policy = dict(DEFAULT_POLICY)
    path = getattr(args, "policy_json", None)
    if path:
        raw = read_text_file(path)
        if raw is None:
            return None
        try:
            value = json.loads(raw)
        except (TypeError, ValueError):
            return None
        if not isinstance(value, dict):
            return None
        loaded = normalise_loaded_config(value)
        text = loaded.get("text", loaded.get("rulesText"))
        if isinstance(text, str):
            rules_text = text
        detection = loaded.get("detectionPolicy")
        if isinstance(detection, dict):
            for key in ("blockedCodepoints", "hardGateBannedTerms", "advisoryTerms"):
                if isinstance(detection.get(key), list):
                    policy[key] = detection[key]
    path = getattr(args, "rules", None)
    if path:
        text = read_text_file(path)
        if not text:
            return None
        rules_text = text.strip()
    return Config(rules_text, None, None, policy)
