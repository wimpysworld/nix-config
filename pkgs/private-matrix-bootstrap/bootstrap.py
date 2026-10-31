"""Reconcile the private Matrix accounts and room during NixOS deployment."""

import hashlib
import hmac
import json
import os
import resource
import stat
import sys
import urllib.error
import urllib.parse
import urllib.request
from http.client import HTTPException
from pathlib import Path

SERVER = "matrix.wimpys.world"
USERS = ("martin", "skrye", "zannah", "traya")
ALIAS = f"#the-cauldron:{SERVER}"
ROOM = f"!the-cauldron:{SERVER}"
CLIENT = "/_matrix/client/v3"
REGISTER = "/_synapse/admin/v1/register"
SHARED_KEY = "MATRIX_REGISTRATION_SHARED_SECRET"


class Stop(Exception):
    pass


class APIError(Stop):
    def __init__(self, status, code):
        super().__init__(
            "Matrix rejected provisioning. Check the service configuration."
        )
        self.status, self.code = status, code


def user_id(name):
    return f"@{name}:{SERVER}"


def quoted(value):
    return urllib.parse.quote(value, safe="")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class API:
    def __init__(self):
        self.opener = urllib.request.build_opener(
            urllib.request.ProxyHandler({}), NoRedirect()
        )

    def call(self, method, path, body=None, token=None):
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        request = urllib.request.Request(
            "http://127.0.0.1:6167" + path,
            data=None if body is None else json.dumps(body).encode(),
            headers=headers,
            method=method,
        )
        try:
            with self.opener.open(request, timeout=20) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            try:
                with error:
                    code = json.load(error).get("errcode")
            except (OSError, ValueError, AttributeError, HTTPException):
                code = None
            raise APIError(error.code, code) from None
        except (OSError, ValueError, HTTPException):
            raise Stop(
                "Matrix provisioning did not complete. Existing accounts and room are preserved."
            ) from None


def runtime_secrets():
    values = {}
    for key in [*(f"MATRIX_PASSWORD_{name.upper()}" for name in USERS), SHARED_KEY]:
        with (Path("/run/secrets") / key).open("rb") as stream:
            info = os.fstat(stream.fileno())
            if (
                info.st_uid != 0
                or stat.S_IMODE(info.st_mode) != 0o400
                or not stat.S_ISREG(info.st_mode)
            ):
                raise Stop(
                    "Matrix credentials must be root-owned files with mode 0400."
                )
            value = stream.read(4097).decode().rstrip("\n")
        if not value or "\0" in value or len(value.encode()) > 512:
            raise Stop("A Matrix credential is invalid.")
        values[key] = value
    return values


def powers():
    return {
        "users": {user_id("martin"): 100},
        "users_default": 0,
        "events_default": 0,
        "state_default": 100,
        "events": {},
        "invite": 100,
        "kick": 100,
        "ban": 100,
        "redact": 100,
        "notifications": {"room": 100},
    }


def room_body():
    return {
        "visibility": "private",
        "room_alias_name": "the-cauldron",
        "name": "the-cauldron",
        "preset": "private_chat",
        # Tuwunel's supported custom ID removes any cross-host provisioning handoff.
        "room_version": "11",
        "room_id": "the-cauldron",
        "creation_content": {"m.federate": False},
        "power_level_content_override": powers(),
        "initial_state": [
            {
                "type": "m.room.guest_access",
                "state_key": "",
                "content": {"guest_access": "forbidden"},
            },
            {
                "type": "m.room.history_visibility",
                "state_key": "",
                "content": {"history_visibility": "joined"},
            },
            {
                "type": "m.room.join_rules",
                "state_key": "",
                "content": {"join_rule": "invite"},
            },
        ],
    }


class Bootstrap:
    def __init__(self, api, values):
        self.api, self.values = api, values
        self.tokens = {}

    def call(self, method, path, body=None, user="martin"):
        return self.api.call(method, path, body, self.tokens.get(user))

    def login(self, user):
        device = f"PRIVATE_MATRIX_BOOTSTRAP_{user.upper()}"
        result = self.api.call(
            "POST",
            CLIENT + "/login",
            {
                "type": "m.login.password",
                "identifier": {"type": "m.id.user", "user": user_id(user)},
                "password": self.values[f"MATRIX_PASSWORD_{user.upper()}"],
                "device_id": device,
            },
        )
        if (
            result.get("user_id") != user_id(user)
            or result.get("device_id") != device
            or not result.get("access_token")
        ):
            raise Stop("Matrix returned an unexpected login identity.")
        self.tokens[user] = result["access_token"]

    def accounts(self):
        for user in USERS:
            try:
                self.login(user)
            except APIError as error:
                if error.code != "M_FORBIDDEN":
                    raise
                nonce = self.api.call("GET", REGISTER)["nonce"]
                password = self.values[f"MATRIX_PASSWORD_{user.upper()}"]
                message = "\0".join(
                    (nonce, user, password, "admin" if user == "martin" else "notadmin")
                )
                mac = hmac.new(
                    self.values[SHARED_KEY].encode(), message.encode(), hashlib.sha1
                ).hexdigest()
                # Existing usernames are rejected by Tuwunel, never overwritten.
                self.api.call(
                    "POST",
                    REGISTER,
                    {
                        "nonce": nonce,
                        "username": user,
                        "password": password,
                        "displayname": user,
                        "admin": user == "martin",
                        "mac": mac,
                        "inhibit_login": True,
                    },
                )
                self.login(user)
            admin = self.call(
                "GET", f"/_synapse/admin/v1/users/{quoted(user_id(user))}/admin"
            ).get("admin")
            if type(admin) is not bool or admin != (user == "martin"):
                raise Stop(
                    "Existing Matrix account privileges conflict. No credentials or privileges were changed."
                )
            profile_path = CLIENT + "/profile/" + quoted(user_id(user)) + "/displayname"
            profile = self.call("GET", profile_path, user=user)
            if profile.get("displayname") != user:
                self.call("PUT", profile_path, {"displayname": user}, user=user)

    def room(self):
        try:
            room = self.call("GET", CLIENT + "/directory/room/" + quoted(ALIAS))[
                "room_id"
            ]
        except APIError as error:
            if error.code != "M_NOT_FOUND":
                raise
            # Both alias and custom ID are unique. A retry cannot create a second room.
            room = self.call("POST", CLIENT + "/createRoom", room_body())["room_id"]
        if room != ROOM:
            raise Stop("The Matrix room alias points to an unexpected room.")
        prefix = CLIENT + "/rooms/" + quoted(room)
        events = self.call("GET", prefix + "/state")
        state = {(event["type"], event["state_key"]): event for event in events}

        def content(kind):
            return state.get(("m.room." + kind, ""), {}).get("content", {})

        create = content("create")
        if (
            ("m.room.encryption", "") in state
            or ("m.room.tombstone", "") in state
            or state.get(("m.room.create", ""), {}).get("sender") != user_id("martin")
            or create.get("room_version") != "11"
            or create.get("additional_creators", [])
            or type(create.get("m.federate")) is not bool
            or create["m.federate"]
            or content("power_levels") != powers()
            or content("canonical_alias").get("alias") != ALIAS
            or content("name").get("name") != "the-cauldron"
            or content("join_rules").get("join_rule") != "invite"
            or content("guest_access").get("guest_access") != "forbidden"
            or content("history_visibility").get("history_visibility") != "joined"
            or self.call("GET", CLIENT + "/directory/list/room/" + quoted(room)).get(
                "visibility"
            )
            != "private"
        ):
            raise Stop(
                "Existing Matrix room settings conflict. No room state was overwritten."
            )
        members = {
            key: event["content"].get("membership")
            for (kind, key), event in state.items()
            if kind == "m.room.member"
        }
        if members.get(user_id("martin")) != "join" or any(
            uid not in map(user_id, USERS) and membership != "leave"
            for uid, membership in members.items()
        ):
            raise Stop("Unexpected Matrix room membership.")
        for user in USERS[1:]:
            membership = members.get(user_id(user))
            if membership == "join":
                continue
            if membership not in (None, "leave", "invite"):
                raise Stop("A Matrix participant has conflicting membership.")
            if membership != "invite":
                self.call("POST", prefix + "/invite", {"user_id": user_id(user)})
            self.call("POST", prefix + "/join", {}, user=user)
        return room

    def run(self):
        try:
            self.accounts()
            return self.room()
        finally:
            for user in self.tokens:
                try:
                    self.call("POST", CLIENT + "/logout", {}, user=user)
                except Stop:
                    print(
                        "Could not close a temporary Matrix provisioning session.",
                        file=sys.stderr,
                    )
            self.tokens.clear()


def main():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    os.umask(0o077)
    try:
        if os.geteuid() != 0:
            raise Stop("Matrix provisioning requires root.")
        print(Bootstrap(API(), runtime_secrets()).run())
        return 0
    except Stop as error:
        print(str(error), file=sys.stderr)
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        print(
            "Matrix provisioning failed. No credentials are included in this log.",
            file=sys.stderr,
        )
    return 1


if __name__ == "__main__":
    sys.exit(main())
