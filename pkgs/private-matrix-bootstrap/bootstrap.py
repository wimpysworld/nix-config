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
AGENTS = USERS[1:]
CONDUIT_USER = "conduit"
CONDUIT_DISPLAY_NAME = "Holocron"
DISPLAY_NAMES = {
    "martin": "Martin",
    "skrye": "Skrye",
    "zannah": "Zannah",
    "traya": "Traya",
}
ADMIN_ALIAS = f"#admins:{SERVER}"
ADMIN_ROOM_NAME = "Malak Admin"
ADMIN_ROOM_TOPIC = (
    f"Tuwunel homeserver administration and server notices for {SERVER}."
)
ALIAS = f"#the-cauldron:{SERVER}"
ROOM = f"!the-cauldron:{SERVER}"
ROOM_NAME = "The Cauldron"
ROOM_TOPIC = (
    "Sith Triumvirate council room for research, architecture, and planning with "
    f"Martin (@martin:{SERVER}), Traya (@traya:{SERVER}), "
    f"Skrye (@skrye:{SERVER}), and Zannah (@zannah:{SERVER})."
)
DM_TOPICS = {
    "skrye": (
        f"Direct channel between Martin (@martin:{SERVER}) and "
        f"Skrye (@skrye:{SERVER}) for systems and implementation work."
    ),
    "zannah": (
        f"Direct channel between Martin (@martin:{SERVER}) and "
        f"Zannah (@zannah:{SERVER}) for adversarial review and failure analysis."
    ),
    "traya": (
        f"Direct channel between Martin (@martin:{SERVER}) and "
        f"Traya (@traya:{SERVER}) for architecture and synthesis."
    ),
}
CLIENT = "/_matrix/client/v3"
MEDIA_UPLOAD = "/_matrix/media/v3/upload"
MEDIA_DOWNLOAD = f"/_matrix/client/v1/media/download/{SERVER}"
REGISTER = "/_synapse/admin/v1/register"
SHARED_KEY = "MATRIX_REGISTRATION_SHARED_SECRET"
AVATARS = {
    "admins": ("admins.png", "image/png"),
    "conduit": ("conduit.png", "image/png"),
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


def dm_room_id(agent):
    return f"!dm-martin-{agent}:{SERVER}"


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


def base_room_body(room_id, name, topic, preset="private_chat"):
    return {
        "visibility": "private",
        "name": name,
        "topic": topic,
        "preset": preset,
        # Tuwunel's supported custom ID removes any cross-host provisioning handoff.
        "room_version": "11",
        "room_id": room_id,
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


def room_body():
    return {
        **base_room_body("the-cauldron", ROOM_NAME, ROOM_TOPIC),
        "room_alias_name": "the-cauldron",
    }


def dm_room_body(agent):
    return {
        **base_room_body(
            f"dm-martin-{agent}",
            DISPLAY_NAMES[agent],
            DM_TOPICS[agent],
            preset="trusted_private_chat",
        ),
        "is_direct": True,
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
                        "displayname": DISPLAY_NAMES[user],
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
            displayname = DISPLAY_NAMES[user]
            profile_base = CLIENT + "/profile/" + quoted(user_id(user))
            profile_path = profile_base + "/displayname"
            profile = self.call("GET", profile_path, user=user)
            if profile.get("displayname") != displayname:
                self.call("PUT", profile_path, {"displayname": displayname}, user=user)
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
        conduit_id = user_id(CONDUIT_USER)
        try:
            conduit_profile = self.call(
                "GET", f"{CLIENT}/profile/{quoted(conduit_id)}"
            )
        except APIError as error:
            if error.code != "M_NOT_FOUND":
                raise
            conduit_profile = {}
        current_avatar = conduit_profile.get("avatar_url")
        avatar = self.avatar_uri(CONDUIT_USER, current_avatar)
        if (
            conduit_profile.get("displayname") != CONDUIT_DISPLAY_NAME
            or avatar is not None
        ):
            self.call(
                "PUT",
                f"/_synapse/admin/v2/users/{quoted(conduit_id)}",
                {
                    "displayname": CONDUIT_DISPLAY_NAME,
                    "avatar_url": avatar or current_avatar,
                },
            )

    def reconcile_room_metadata(self, prefix, state, name, topic, avatar_key):
        def content(kind):
            return state.get(("m.room." + kind, ""), {}).get("content", {})

        if content("name").get("name") != name:
            self.call("PUT", prefix + "/state/m.room.name/", {"name": name})
        if content("topic").get("topic") != topic:
            self.call("PUT", prefix + "/state/m.room.topic/", {"topic": topic})
        avatar = self.avatar_uri(avatar_key, content("avatar").get("url"))
        if avatar is not None:
            self.call("PUT", prefix + "/state/m.room.avatar/", {"url": avatar})

    def admin_room(self):
        room = self.call(
            "GET", CLIENT + "/directory/room/" + quoted(ADMIN_ALIAS)
        )["room_id"]
        prefix = CLIENT + "/rooms/" + quoted(room)
        events = self.call("GET", prefix + "/state")
        state = {(event["type"], event["state_key"]): event for event in events}

        def content(kind):
            return state.get(("m.room." + kind, ""), {}).get("content", {})

        conduit_id = user_id(CONDUIT_USER)
        admin_id = user_id("martin")
        create = content("create")
        power_users = content("power_levels").get("users", {})
        members = {
            key: event["content"].get("membership")
            for (kind, key), event in state.items()
            if kind == "m.room.member"
        }
        if (
            ("m.room.encryption", "") in state
            or ("m.room.tombstone", "") in state
            or state.get(("m.room.create", ""), {}).get("sender") != conduit_id
            or create.get("room_version") != "11"
            or create.get("additional_creators", [])
            or content("canonical_alias").get("alias") != ADMIN_ALIAS
            or content("join_rules").get("join_rule") != "invite"
            or content("guest_access").get("guest_access") != "forbidden"
            or content("history_visibility").get("history_visibility") != "shared"
            or not isinstance(power_users, dict)
            or type(power_users.get(conduit_id)) is not int
            or power_users[conduit_id] < 100
            or type(power_users.get(admin_id)) is not int
            or power_users[admin_id] != 100
            or any(uid not in (conduit_id, admin_id) for uid in power_users)
            or members.get(conduit_id) != "join"
            or members.get(admin_id) != "join"
            or any(
                uid not in (conduit_id, admin_id) and membership != "leave"
                for uid, membership in members.items()
            )
        ):
            raise Stop(
                "Existing Matrix admin room settings conflict. No room state was overwritten."
            )
        self.reconcile_room_metadata(
            prefix, state, ADMIN_ROOM_NAME, ADMIN_ROOM_TOPIC, "admins"
        )

    def check_private_room(self, room, state, participants, alias=None):
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
            or content("canonical_alias").get("alias") != alias
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
        allowed = set(map(user_id, participants))
        if members.get(user_id("martin")) != "join" or any(
            uid not in allowed and membership != "leave"
            for uid, membership in members.items()
        ):
            raise Stop("Unexpected Matrix room membership.")
        prefix = CLIENT + "/rooms/" + quoted(room)
        for user in participants[1:]:
            membership = members.get(user_id(user))
            if membership == "join":
                continue
            if membership not in (None, "leave", "invite"):
                raise Stop("A Matrix participant has conflicting membership.")
            if membership != "invite":
                self.call("POST", prefix + "/invite", {"user_id": user_id(user)})
            self.call("POST", prefix + "/join", {}, user=user)

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
        self.check_private_room(room, state, USERS, alias=ALIAS)
        self.reconcile_room_metadata(
            prefix, state, ROOM_NAME, ROOM_TOPIC, "the-cauldron"
        )
        return room

    def reconcile_direct_account_data(self, user, expected_peers):
        path = f"{CLIENT}/user/{quoted(user_id(user))}/account_data/m.direct"
        try:
            direct = self.call("GET", path, user=user)
        except APIError as error:
            if error.code != "M_NOT_FOUND":
                raise
            direct = {}
        if not isinstance(direct, dict):
            raise Stop("Existing Matrix direct message account data is invalid.")
        updated = {}
        changed = False
        for peer, rooms in direct.items():
            if (
                not isinstance(peer, str)
                or not isinstance(rooms, list)
                or not all(isinstance(item, str) for item in rooms)
            ):
                raise Stop("Existing Matrix direct message account data is invalid.")
            updated[peer] = list(rooms)
        for peer_id, dm_room in expected_peers.items():
            rooms = updated.setdefault(peer_id, [])
            if dm_room not in rooms:
                rooms.append(dm_room)
                changed = True
        if changed:
            self.call("PUT", path, updated, user=user)

    def dm_rooms(self):
        for agent in AGENTS:
            room = dm_room_id(agent)
            prefix = CLIENT + "/rooms/" + quoted(room)
            try:
                events = self.call("GET", prefix + "/state")
            except APIError as error:
                if error.code not in ("M_FORBIDDEN", "M_NOT_FOUND"):
                    raise
                created = self.call(
                    "POST", CLIENT + "/createRoom", dm_room_body(agent)
                ).get("room_id")
                if created != room:
                    raise Stop(
                        "Matrix returned an unexpected direct message room."
                    ) from None
                events = self.call("GET", prefix + "/state")
            state = {(event["type"], event["state_key"]): event for event in events}
            self.check_private_room(room, state, ("martin", agent))
            self.reconcile_room_metadata(
                prefix, state, DISPLAY_NAMES[agent], DM_TOPICS[agent], agent
            )
            self.reconcile_direct_account_data(
                agent, {user_id("martin"): room}
            )
        self.reconcile_direct_account_data(
            "martin", {user_id(agent): dm_room_id(agent) for agent in AGENTS}
        )

    def run(self):
        try:
            self.accounts()
            self.admin_room()
            room = self.room()
            self.dm_rooms()
            return room
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
