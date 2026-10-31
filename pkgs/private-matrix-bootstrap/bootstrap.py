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
MEDIA_UPLOAD = "/_matrix/media/v3/upload"
MEDIA_DOWNLOAD = f"/_matrix/client/v1/media/download/{SERVER}"
REGISTER = "/_synapse/admin/v1/register"
SHARED_KEY = "MATRIX_REGISTRATION_SHARED_SECRET"
AVATARS = {
    "martin": ("martin.png", "image/png"),
    "skrye": ("skrye.jpg", "image/jpeg"),
    "zannah": ("zannah.jpg", "image/jpeg"),
    "traya": ("traya.jpg", "image/jpeg"),
    "the-cauldron": ("the-cauldron.jpg", "image/jpeg"),
}


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

    def call(
        self,
        method,
        path,
        body=None,
        token=None,
        content_type="application/json",
        raw=False,
    ):
        headers = {"Content-Type": content_type}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        request = urllib.request.Request(
            "http://127.0.0.1:6167" + path,
            data=(
                body
                if body is None or isinstance(body, bytes)
                else json.dumps(body).encode()
            ),
            headers=headers,
            method=method,
        )
        try:
            with self.opener.open(request, timeout=20) as response:
                if raw:
                    data = response.read(1048577)
                    if len(data) > 1048576:
                        raise Stop("Matrix returned an oversized media response.")
                    return data
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


def runtime_avatars():
    directory = os.environ.get("PRIVATE_MATRIX_AVATARS_DIR")
    if not directory:
        raise Stop("Matrix avatar directory is not configured.")
    root = Path(directory)
    avatars = {}
    for name, (filename, _) in AVATARS.items():
        data = (root / filename).read_bytes()
        if not data or len(data) > 1048576:
            raise Stop("A Matrix avatar file is invalid.")
        avatars[name] = data
    return avatars


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
    def __init__(self, api, values, avatars=None):
        self.api, self.values = api, values
        self.avatars = runtime_avatars() if avatars is None else avatars
        self.tokens = {}

    def call(
        self,
        method,
        path,
        body=None,
        user="martin",
        content_type="application/json",
        raw=False,
    ):
        return self.api.call(
            method, path, body, self.tokens.get(user), content_type, raw
        )

    def avatar_uri(self, name, current_uri, user="martin"):
        filename, content_type = AVATARS[name]
        expected = self.avatars[name]
        prefix = f"mxc://{SERVER}/"
        if isinstance(current_uri, str) and current_uri.startswith(prefix):
            media_id = current_uri.removeprefix(prefix)
            if media_id and "/" not in media_id:
                try:
                    actual = self.call(
                        "GET",
                        f"{MEDIA_DOWNLOAD}/{quoted(media_id)}",
                        user=user,
                        raw=True,
                    )
                    if actual == expected:
                        return None
                except APIError as error:
                    if error.code != "M_NOT_FOUND":
                        raise
        uri = self.call(
            "POST",
            f"{MEDIA_UPLOAD}?filename={quoted(filename)}",
            expected,
            user=user,
            content_type=content_type,
        ).get("content_uri")
        if (
            not isinstance(uri, str)
            or not uri.startswith(prefix)
            or not uri.removeprefix(prefix)
            or "/" in uri.removeprefix(prefix)
        ):
            raise Stop("Matrix returned an unexpected media URI.")
        return uri

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
            profile_base = CLIENT + "/profile/" + quoted(user_id(user))
            profile_path = profile_base + "/displayname"
            profile = self.call("GET", profile_path, user=user)
            if profile.get("displayname") != user:
                self.call("PUT", profile_path, {"displayname": user}, user=user)
            avatar_path = profile_base + "/avatar_url"
            try:
                current_avatar = self.call("GET", avatar_path, user=user).get(
                    "avatar_url"
                )
            except APIError as error:
                if error.code != "M_NOT_FOUND":
                    raise
                current_avatar = None
            avatar = self.avatar_uri(user, current_avatar, user=user)
            if avatar is not None:
                self.call("PUT", avatar_path, {"avatar_url": avatar}, user=user)

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
        avatar = self.avatar_uri("the-cauldron", content("avatar").get("url"))
        if avatar is not None:
            self.call("PUT", prefix + "/state/m.room.avatar/", {"url": avatar})
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
