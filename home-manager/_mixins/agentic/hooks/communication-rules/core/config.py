"""Config load, policy merge, and the canonical post-detection fallback.

This module owns the runtime config object and how it is built from the
generated ``policy.json`` or the ``--rules`` text. It holds the one canonical
fallback copy of the post-detection lists (post text keys, post tool terms,
external target keys), so extractors and TS shims read them from one place
instead of each baking its own copy.

This module is config only. It holds no strike logic and no prose detection;
those live in ``core.state`` and ``core.detection``.
"""

from __future__ import annotations

import argparse
import json
import os

from core.detection import read_text_file


FALLBACK_RULES_TEXT = "Communication Rules were not loaded."

# Baked correction-prompt fallback, byte-identical to the old Bash
# ``tripwire_emit_correction`` heredoc, used when no correction-prompt file and
# no policy ``correctionPrompt`` are available.
FALLBACK_CORRECTION_PROMPT = "Revise the previous response to follow the Communication Rules. Return only the corrected response."

DEFAULT_POLICY = {
    "blockedCodepoints": [
        {"codepoint": 'U+2014', "name": 'em dash'},
        {"codepoint": 'U+2013', "name": 'en dash'},
    ],
    "hardGateBannedTerms": [
        'delve',
        'leverage',
        'tapestry',
        'robust',
        'seamless',
        'pivotal',
        'crucial',
        'testament',
        'cutting-edge',
        'multifaceted',
        'realm',
        'vibrant',
        'nuanced',
        'intricate',
        'showcasing',
        'streamline',
        'garnered',
        'underpinning',
        'underscores',
    ],
}

# The one canonical fallback copy of the post-detection lists. fragment.nix is
# the source of record and flows into policy.json; these baked copies apply
# only when no policy.json is loaded, such as in the fixture harnesses. Keep
# this the only fallback in the codebase: extractors and TS shims read these
# via the loaded config, not their own copies.
FALLBACK_POST_TEXT_KEYS = (
    'body',
    'comment',
    'comments',
    'content',
    'description',
    'message',
    'messages',
    'note',
    'notes',
    'review',
    'summary',
    'text',
    'title',
)

FALLBACK_POST_TOOL_TERMS = (
    'comment',
    'create',
    'edit',
    'post',
    'publish',
    'reply',
    'review',
    'send',
    'submit',
    'update',
    'write',
)

FALLBACK_EXTERNAL_TARGET_KEYS = (
    'url',
    'pull_number',
    'issue_number',
    'number',
    'pullRequestId',
    'issueId',
    'discussionId',
    'id',
    'path',
    'repo',
    'repository',
    'owner',
)


class Config:
    def __init__(
        self,
        rules_text: str,
        reminder_prompt: str | None,
        block_message: str | None,
        policy: dict,
        post_text_keys: tuple[str, ...] = FALLBACK_POST_TEXT_KEYS,
        post_tool_terms: tuple[str, ...] = FALLBACK_POST_TOOL_TERMS,
        external_target_keys: tuple[str, ...] = FALLBACK_EXTERNAL_TARGET_KEYS,
        correction_prompt: str | None = None,
    ) -> None:
        self.rules_text = rules_text
        self.reminder_prompt = reminder_prompt or format_reminder(rules_text)
        self.block_message = block_message or format_block_message(rules_text)
        self.policy = policy
        self.post_text_keys = post_text_keys
        self.post_tool_terms = post_tool_terms
        self.external_target_keys = external_target_keys
        # The correction prompt is the UserPromptSubmit re-issue text, distinct
        # from the reminder. Resolve it the way the old Bash
        # ``tripwire_emit_correction`` did: the TRIPWIRE_CORRECTION_PROMPT file
        # first, then the policy ``correctionPrompt``, then the baked fallback.
        self.correction_prompt = resolve_correction_prompt(correction_prompt)


def resolve_correction_prompt(policy_correction: str | None) -> str:
    """Resolve the UserPromptSubmit re-issue text, mirroring the old adapter.

    Order, matching the Bash ``tripwire_emit_correction``: the
    ``TRIPWIRE_CORRECTION_PROMPT`` file if readable, then the policy
    ``correctionPrompt`` text, then the baked fallback. The env file wins so a
    fixture or operator override applies without rebuilding the policy.
    """
    env_path = os.environ.get("TRIPWIRE_CORRECTION_PROMPT")
    if env_path:
        text = read_text_file(env_path)
        if text is not None:
            return text
    if policy_correction:
        return policy_correction
    return FALLBACK_CORRECTION_PROMPT


def format_reminder(rules_text: str) -> str:
    return (
        "Reminder: Follow the Communication Rules for any prose you produce or write.\n\n"
        f"Communication Rules:\n{rules_text}"
    )


def format_block_message(rules_text: str) -> str:
    return (
        "Blocked. Revise this prose to follow the Communication Rules.\n\n"
        f"Communication Rules:\n{rules_text}"
    )


def normalise_loaded_config(value: object) -> dict:
    if not isinstance(value, dict):
        return {}
    if isinstance(value.get("agentic"), dict):
        agentic = value["agentic"]
        if isinstance(agentic.get("communicationRules"), dict):
            return agentic["communicationRules"]
    if isinstance(value.get("communicationRules"), dict):
        return value["communicationRules"]
    return value


def load_post_detection(detection_policy: dict) -> dict[str, tuple[str, ...]]:
    # Read the canonical post-detection lists from the loaded detection policy.
    # The keys live under detectionPolicy -> postDetection in policy.json. Any
    # list that is absent or malformed keeps its baked fallback copy.
    result: dict[str, tuple[str, ...]] = {
        "postTextKeys": FALLBACK_POST_TEXT_KEYS,
        "postToolTerms": FALLBACK_POST_TOOL_TERMS,
        "externalTargetKeys": FALLBACK_EXTERNAL_TARGET_KEYS,
    }
    node = detection_policy.get("postDetection")
    if not isinstance(node, dict):
        return result
    for key in ("postTextKeys", "postToolTerms", "externalTargetKeys"):
        value = node.get(key)
        if isinstance(value, list) and all(isinstance(item, str) for item in value):
            result[key] = tuple(value)
    return result


def load_config(args: argparse.Namespace) -> Config | None:
    rules_text = FALLBACK_RULES_TEXT
    reminder_prompt = None
    block_message = None
    correction_prompt = None
    policy = dict(DEFAULT_POLICY)
    post_detection = {
        "postTextKeys": FALLBACK_POST_TEXT_KEYS,
        "postToolTerms": FALLBACK_POST_TOOL_TERMS,
        "externalTargetKeys": FALLBACK_EXTERNAL_TARGET_KEYS,
    }

    if getattr(args, "policy_json", None):
        raw_json = read_text_file(args.policy_json)
        if raw_json is None:
            return None
        try:
            loaded = normalise_loaded_config(json.loads(raw_json))
        except json.JSONDecodeError:
            return None

        loaded_text = loaded.get("text") or loaded.get("rulesText")
        if isinstance(loaded_text, str):
            rules_text = loaded_text

        if isinstance(loaded.get("reminderPrompt"), str):
            reminder_prompt = loaded["reminderPrompt"]
        if isinstance(loaded.get("blockMessage"), str):
            block_message = loaded["blockMessage"]
        if isinstance(loaded.get("correctionPrompt"), str):
            correction_prompt = loaded["correctionPrompt"]
        if isinstance(loaded.get("detectionPolicy"), dict):
            policy = merge_policy(policy, loaded["detectionPolicy"])
            post_detection = load_post_detection(loaded["detectionPolicy"])

    if getattr(args, "rules", None):
        loaded_rules = read_text_file(args.rules)
        if loaded_rules is None:
            return None
        rules_text = loaded_rules.strip()
        if reminder_prompt is None:
            reminder_prompt = format_reminder(rules_text)
        if block_message is None:
            block_message = format_block_message(rules_text)

    return Config(
        rules_text,
        reminder_prompt,
        block_message,
        policy,
        post_text_keys=post_detection["postTextKeys"],
        post_tool_terms=post_detection["postToolTerms"],
        external_target_keys=post_detection["externalTargetKeys"],
        correction_prompt=correction_prompt,
    )


def merge_policy(default_policy: dict, loaded_policy: dict) -> dict:
    merged = dict(default_policy)
    if isinstance(loaded_policy.get("blockedCodepoints"), list):
        merged["blockedCodepoints"] = loaded_policy["blockedCodepoints"]
    if isinstance(loaded_policy.get("hardGateBannedTerms"), list):
        merged["hardGateBannedTerms"] = loaded_policy["hardGateBannedTerms"]
    return merged
