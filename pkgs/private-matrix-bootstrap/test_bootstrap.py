"""Run by checks.x86_64-linux.private-matrix through the package tests.

These checks cover API side effects that Nix evaluation cannot verify.
"""

import copy
import hashlib
import hmac
import os
import unittest
import urllib.parse

import bootstrap as b

ADMIN_ROOM = f"!admins:{b.SERVER}"
VALUES = {
    key: f"synthetic-{key}"
    for key in [*(f"MATRIX_PASSWORD_{name.upper()}" for name in b.USERS), b.SHARED_KEY]
}
SYNTHETIC_AVATARS = {
    name: (
        b"\x89PNG\r\n\x1a\n" if content_type == "image/png" else b"\xff\xd8\xff\xe0"
    )
    + f"synthetic-avatar-{name}".encode()
    for name, (_, content_type) in b.AVATARS.items()
}


def configured_avatars():
    if os.environ.get("PRIVATE_MATRIX_AVATARS_DIR"):
        return b.runtime_avatars()
    return copy.deepcopy(SYNTHETIC_AVATARS)


class FakeAPI:
    def __init__(self):
        self.users = {
            b.CONDUIT_USER: {
                "username": b.CONDUIT_USER,
                "displayname": b.CONDUIT_USER,
                "admin": True,
            }
        }
        self.rooms = {
            ADMIN_ROOM: {
                ("m.room.create", ""): {
                    "m.federate": False,
                    "room_version": "11",
                },
                ("m.room.canonical_alias", ""): {"alias": b.ADMIN_ALIAS},
                ("m.room.join_rules", ""): {"join_rule": "invite"},
                ("m.room.history_visibility", ""): {"history_visibility": "shared"},
                ("m.room.guest_access", ""): {"guest_access": "forbidden"},
                ("m.room.power_levels", ""): {
                    "users": {
                        b.user_id(b.CONDUIT_USER): 69420,
                        b.user_id("martin"): 100,
                    },
                },
                ("m.room.name", ""): {"name": f"{b.SERVER} Admin Room"},
                ("m.room.member", b.user_id(b.CONDUIT_USER)): {"membership": "join"},
                ("m.room.member", b.user_id("martin")): {"membership": "join"},
            }
        }
        self.aliases = {b.ADMIN_ALIAS: ADMIN_ROOM}
        self.media = {}
        self.calls = []
        self.fail_after: tuple[str, str] | None = None
        self.displayname_suffix = ""

    @property
    def events(self):
        return self.rooms[b.ROOM]

    def call(
        self,
        method,
        path,
        body=None,
        token=None,
        content_type="application/json",
        raw=False,
    ):
        self.calls.append((method, path, copy.deepcopy(body)))
        result = self.respond(method, path, body, token, content_type, raw)
        if self.fail_after == (method, path):
            self.fail_after = None
            raise b.Stop(
                "Synthetic connection failure after the server committed the request."
            )
        return result

    def respond(self, method, path, body, token, content_type, raw):
        if path == b.REGISTER:
            if method == "GET":
                return {"nonce": "synthetic-nonce"}
            user = body["username"]
            message = "\0".join(
                (
                    body["nonce"],
                    user,
                    body["password"],
                    "admin" if body["admin"] else "notadmin",
                )
            )
            assert (
                body["mac"]
                == hmac.new(
                    VALUES[b.SHARED_KEY].encode(), message.encode(), hashlib.sha1
                ).hexdigest()
            )
            assert body["inhibit_login"]
            if user in self.users:
                raise b.APIError(400, "M_USER_IN_USE")
            self.users[user] = copy.deepcopy(body)
            if self.displayname_suffix:
                self.users[user]["displayname"] += " " + self.displayname_suffix
            return {"user_id": b.user_id(user)}
        if path == b.CLIENT + "/login":
            user = body["identifier"]["user"].split(":")[0][1:]
            if (
                user == b.CONDUIT_USER
                or user not in self.users
                or self.users[user].get("password") != body["password"]
            ):
                raise b.APIError(403, "M_FORBIDDEN")
            assert body["device_id"] == f"PRIVATE_MATRIX_BOOTSTRAP_{user.upper()}"
            return {
                "user_id": b.user_id(user),
                "device_id": body["device_id"],
                "access_token": user,
            }
        assert token in self.users
        if path.startswith(b.MEDIA_UPLOAD + "?filename="):
            assert method == "POST"
            assert isinstance(body, bytes)
            filename = urllib.parse.unquote(path.split("?filename=", 1)[1])
            assert content_type == dict(b.AVATARS.values())[filename]
            media_id = f"media-{len(self.media) + 1}"
            self.media[media_id] = body
            return {"content_uri": f"mxc://{b.SERVER}/{media_id}"}
        if path.startswith(b.MEDIA_DOWNLOAD + "/"):
            assert method == "GET"
            assert raw
            media_id = urllib.parse.unquote(
                path.removeprefix(b.MEDIA_DOWNLOAD + "/")
            )
            if media_id not in self.media:
                raise b.APIError(404, "M_NOT_FOUND")
            return self.media[media_id]
        if path.startswith(b.CLIENT + "/profile/"):
            parts = path.removeprefix(b.CLIENT + "/profile/").split("/")
            target = urllib.parse.unquote(parts[0]).split(":")[0][1:]
            if len(parts) == 1:
                assert method == "GET"
                if target not in self.users:
                    raise b.APIError(404, "M_NOT_FOUND")
                profile = {}
                if "displayname" in self.users[target]:
                    profile["displayname"] = self.users[target]["displayname"]
                if "avatar_url" in self.users[target]:
                    profile["avatar_url"] = self.users[target]["avatar_url"]
                return profile
            field = parts[1]
            assert target == token
            if field == "displayname":
                if method == "PUT":
                    self.users[token]["displayname"] = body["displayname"]
                    return {}
                return {"displayname": self.users[token]["displayname"]}
            if field == "avatar_url":
                if method == "PUT":
                    self.users[token]["avatar_url"] = body["avatar_url"]
                    return {}
                if "avatar_url" not in self.users[token]:
                    return {}
                return {"avatar_url": self.users[token]["avatar_url"]}
        if path.startswith("/_synapse/admin/v1/users/"):
            assert token == b.USERS[0]
            target = urllib.parse.unquote(path.split("/")[-2]).split(":")[0][1:]
            return {"admin": self.users[target]["admin"]}
        if path.startswith("/_synapse/admin/v2/users/"):
            assert method == "PUT"
            assert token == b.USERS[0]
            target = urllib.parse.unquote(path.split("/")[-1]).split(":")[0][1:]
            assert target == b.CONDUIT_USER
            if "displayname" in body:
                self.users[target]["displayname"] = body["displayname"]
            if "avatar_url" in body:
                self.users[target]["avatar_url"] = body["avatar_url"]
            return {"name": b.user_id(target)}
        if path == b.CLIENT + "/logout":
            return {}
        if path.startswith(b.CLIENT + "/directory/room/"):
            alias = urllib.parse.unquote(
                path.removeprefix(b.CLIENT + "/directory/room/")
            )
            if alias not in self.aliases:
                raise b.APIError(404, "M_NOT_FOUND")
            return {"room_id": self.aliases[alias]}
        if path == b.CLIENT + "/createRoom":
            room_id = f"!{body['room_id']}:{b.SERVER}"
            if room_id in self.rooms:
                raise b.APIError(400, "M_ROOM_IN_USE")
            events = {
                (event["type"], event["state_key"]): event["content"]
                for event in body["initial_state"]
            }
            events.update(
                {
                    ("m.room.create", ""): {
                        **body["creation_content"],
                        "room_version": body["room_version"],
                    },
                    ("m.room.name", ""): {"name": body["name"]},
                    ("m.room.topic", ""): {"topic": body["topic"]},
                    ("m.room.power_levels", ""): body["power_level_content_override"],
                    ("m.room.member", b.user_id("martin")): {"membership": "join"},
                }
            )
            if "room_alias_name" in body:
                alias = f"#{body['room_alias_name']}:{b.SERVER}"
                assert alias not in self.aliases
                self.aliases[alias] = room_id
                events[("m.room.canonical_alias", "")] = {"alias": alias}
            self.rooms[room_id] = events
            return {"room_id": room_id}
        if path.startswith(b.CLIENT + "/rooms/"):
            rest = path.removeprefix(b.CLIENT + "/rooms/")
            room_id = urllib.parse.unquote(rest.split("/", 1)[0])
            suffix = "/" + rest.split("/", 1)[1]
            if room_id not in self.rooms:
                raise b.APIError(403, "M_FORBIDDEN")
            room_events = self.rooms[room_id]
            if suffix == "/state":
                if (
                    room_events.get(("m.room.member", b.user_id(token)), {}).get(
                        "membership"
                    )
                    != "join"
                ):
                    raise b.APIError(403, "M_FORBIDDEN")
                sender = (
                    b.user_id(b.CONDUIT_USER)
                    if room_id == ADMIN_ROOM
                    else b.user_id("martin")
                )
                return [
                    {
                        "type": kind,
                        "state_key": key,
                        "content": value,
                        "sender": sender,
                    }
                    for (kind, key), value in room_events.items()
                ]
            for state_kind in ("avatar", "name", "topic"):
                if suffix == f"/state/m.room.{state_kind}/":
                    assert method == "PUT"
                    assert token == b.USERS[0]
                    room_events[(f"m.room.{state_kind}", "")] = copy.deepcopy(body)
                    return {"event_id": f"$synthetic-room-{state_kind}"}
            if suffix == "/invite":
                assert token == b.USERS[0]
                room_events[("m.room.member", body["user_id"])] = {
                    "membership": "invite"
                }
                return {}
            if suffix == "/join":
                room_events[("m.room.member", b.user_id(token))] = {
                    "membership": "join"
                }
                return {"room_id": room_id}
        if "/directory/list/room/" in path:
            return {"visibility": "private"}
        raise AssertionError((method, path))


class BootstrapTests(unittest.TestCase):
    def setUp(self):
        self.api = FakeAPI()
        self.avatars = configured_avatars()

    def run_bootstrap(self, avatars=None):
        return b.Bootstrap(
            self.api, VALUES, self.avatars if avatars is None else avatars
        ).run()

    def media_bytes(self, uri):
        prefix = f"mxc://{b.SERVER}/"
        self.assertTrue(uri.startswith(prefix))
        return self.api.media[uri.removeprefix(prefix)]

    def writes(self):
        return [
            (method, path)
            for method, path, _ in self.api.calls
            if method in ("POST", "PUT")
            and path not in (b.CLIENT + "/login", b.CLIENT + "/logout")
        ]

    def test_initial_creation_and_rerun(self):
        self.api.displayname_suffix = "💕"
        self.assertEqual(self.run_bootstrap(), b.ROOM)
        for name, (_, content_type) in b.AVATARS.items():
            header = b"\x89PNG\r\n\x1a\n" if content_type == "image/png" else b"\xff\xd8\xff"
            self.assertTrue(self.avatars[name].startswith(header))
        for user in b.USERS:
            self.assertEqual(
                self.api.users[user]["displayname"], b.DISPLAY_NAMES[user]
            )
            self.assertEqual(self.api.users[user]["admin"], user == "martin")
            self.assertEqual(
                self.media_bytes(self.api.users[user]["avatar_url"]),
                self.avatars[user],
            )
            self.assertEqual(
                self.api.events[("m.room.member", b.user_id(user))]["membership"],
                "join",
            )
        self.assertEqual(
            self.api.users[b.CONDUIT_USER]["displayname"],
            b.CONDUIT_DISPLAY_NAME,
        )
        self.assertEqual(
            self.media_bytes(self.api.users[b.CONDUIT_USER]["avatar_url"]),
            self.avatars[b.CONDUIT_USER],
        )
        self.assertEqual(
            self.api.rooms[ADMIN_ROOM][("m.room.name", "")]["name"],
            b.ADMIN_ROOM_NAME,
        )
        self.assertEqual(
            self.api.rooms[ADMIN_ROOM][("m.room.topic", "")]["topic"],
            b.ADMIN_ROOM_TOPIC,
        )
        self.assertEqual(
            self.media_bytes(
                self.api.rooms[ADMIN_ROOM][("m.room.avatar", "")]["url"]
            ),
            self.avatars["admins"],
        )
        self.assertEqual(
            self.api.events[("m.room.name", "")]["name"],
            b.ROOM_NAME,
        )
        self.assertEqual(
            self.api.events[("m.room.topic", "")]["topic"],
            b.ROOM_TOPIC,
        )
        self.assertEqual(
            self.media_bytes(self.api.events[("m.room.avatar", "")]["url"]),
            self.avatars["the-cauldron"],
        )
        self.api.calls.clear()
        self.assertEqual(self.run_bootstrap(), b.ROOM)
        self.assertEqual(self.writes(), [])
        self.assertEqual(
            sum(path.endswith("/logout") for _, path, _ in self.api.calls), len(b.USERS)
        )

    def test_metadata_reconciliation_upgrades_legacy_names_and_topic(self):
        self.run_bootstrap()
        for user in b.USERS:
            self.api.users[user]["displayname"] = user
        self.api.users[b.CONDUIT_USER]["displayname"] = b.CONDUIT_USER
        self.api.rooms[ADMIN_ROOM][("m.room.name", "")] = {"name": "admins"}
        del self.api.rooms[ADMIN_ROOM][("m.room.topic", "")]
        self.api.events[("m.room.name", "")] = {"name": "the-cauldron"}
        del self.api.events[("m.room.topic", "")]
        self.api.calls.clear()
        self.assertEqual(self.run_bootstrap(), b.ROOM)
        for user in b.USERS:
            self.assertEqual(
                self.api.users[user]["displayname"], b.DISPLAY_NAMES[user]
            )
        self.assertEqual(
            self.api.users[b.CONDUIT_USER]["displayname"],
            b.CONDUIT_DISPLAY_NAME,
        )
        self.assertEqual(
            self.api.rooms[ADMIN_ROOM][("m.room.name", "")],
            {"name": b.ADMIN_ROOM_NAME},
        )
        self.assertEqual(
            self.api.rooms[ADMIN_ROOM][("m.room.topic", "")],
            {"topic": b.ADMIN_ROOM_TOPIC},
        )
        self.assertEqual(
            self.api.events[("m.room.name", "")],
            {"name": b.ROOM_NAME},
        )
        self.assertEqual(
            self.api.events[("m.room.topic", "")],
            {"topic": b.ROOM_TOPIC},
        )
        self.assertEqual(
            self.writes(),
            [
                *(
                    ("PUT", f"{b.CLIENT}/profile/{b.quoted(b.user_id(user))}/displayname")
                    for user in b.USERS
                ),
                (
                    "PUT",
                    f"/_synapse/admin/v2/users/{b.quoted(b.user_id(b.CONDUIT_USER))}",
                ),
                ("PUT", f"{b.CLIENT}/rooms/{b.quoted(ADMIN_ROOM)}/state/m.room.name/"),
                ("PUT", f"{b.CLIENT}/rooms/{b.quoted(ADMIN_ROOM)}/state/m.room.topic/"),
                ("PUT", f"{b.CLIENT}/rooms/{b.quoted(b.ROOM)}/state/m.room.name/"),
                ("PUT", f"{b.CLIENT}/rooms/{b.quoted(b.ROOM)}/state/m.room.topic/"),
            ],
        )
        self.api.calls.clear()
        self.assertEqual(self.run_bootstrap(), b.ROOM)
        self.assertEqual(self.writes(), [])

    def test_avatar_reconciliation_updates_only_mismatched_or_missing_media(self):
        self.run_bootstrap()
        skrye_old_uri = self.api.users["skrye"]["avatar_url"]
        self.api.media[skrye_old_uri.removeprefix(f"mxc://{b.SERVER}/")] = b"stale-image"
        self.api.events[("m.room.avatar", "")] = {
            "url": f"mxc://{b.SERVER}/missing-room-media"
        }
        martin_uri = self.api.users["martin"]["avatar_url"]
        self.api.calls.clear()
        self.assertEqual(self.run_bootstrap(), b.ROOM)
        self.assertEqual(self.api.users["martin"]["avatar_url"], martin_uri)
        self.assertNotEqual(self.api.users["skrye"]["avatar_url"], skrye_old_uri)
        self.assertEqual(
            self.media_bytes(self.api.users["skrye"]["avatar_url"]),
            self.avatars["skrye"],
        )
        self.assertEqual(
            self.media_bytes(self.api.events[("m.room.avatar", "")]["url"]),
            self.avatars["the-cauldron"],
        )
        self.assertEqual(
            self.writes(),
            [
                ("POST", f"{b.MEDIA_UPLOAD}?filename=skrye.jpg"),
                ("PUT", f"{b.CLIENT}/profile/{b.quoted(b.user_id('skrye'))}/avatar_url"),
                ("POST", f"{b.MEDIA_UPLOAD}?filename=the-cauldron.jpg"),
                ("PUT", f"{b.CLIENT}/rooms/{b.quoted(b.ROOM)}/state/m.room.avatar/"),
            ],
        )

    def test_retry_after_uncertain_creation_does_not_duplicate(self):
        for path in (b.REGISTER, b.CLIENT + "/createRoom"):
            with self.subTest(path=path):
                self.api = FakeAPI()
                self.api.displayname_suffix = "💕"
                self.api.fail_after = ("POST", path)
                with self.assertRaises(b.Stop):
                    self.run_bootstrap()
                if path == b.REGISTER:
                    self.assertEqual(
                        self.api.users["martin"]["displayname"], "Martin 💕"
                    )
                self.assertEqual(self.run_bootstrap(), b.ROOM)
                for user in b.USERS:
                    self.assertEqual(
                        self.api.users[user]["displayname"], b.DISPLAY_NAMES[user]
                    )
                posts = [
                    body
                    for method, endpoint, body in self.api.calls
                    if method == "POST" and endpoint == path
                ]
                if path == b.REGISTER:
                    self.assertEqual(
                        len([body for body in posts if body["username"] == "martin"]), 1
                    )
                else:
                    self.assertEqual(len(posts), 1)

    def test_existing_password_is_not_reset(self):
        self.run_bootstrap()
        changed = VALUES["MATRIX_PASSWORD_SKRYE"] + "-changed"
        self.api.users["skrye"]["password"] = changed
        self.api.calls.clear()
        with self.assertRaises(b.APIError):
            self.run_bootstrap()
        self.assertEqual(self.api.users["skrye"]["password"], changed)
        self.assertNotIn(("POST", b.CLIENT + "/createRoom"), self.writes())

    def test_conflicting_privileges_or_room_policy_are_not_overwritten(self):
        self.run_bootstrap()
        self.api.users["skrye"]["admin"] = True
        self.api.calls.clear()
        with self.assertRaises(b.Stop):
            self.run_bootstrap()
        self.assertEqual(self.writes(), [])
        self.api.users["skrye"]["admin"] = False
        self.api.aliases[b.ADMIN_ALIAS] = b.ROOM
        self.api.calls.clear()
        with self.assertRaises(b.Stop):
            self.run_bootstrap()
        self.assertEqual(self.writes(), [])
        self.api.aliases[b.ADMIN_ALIAS] = ADMIN_ROOM
        self.api.rooms[ADMIN_ROOM][("m.room.power_levels", "")] = {
            "users": {b.user_id("martin"): 100}
        }
        self.api.calls.clear()
        with self.assertRaises(b.Stop):
            self.run_bootstrap()
        self.assertEqual(self.writes(), [])
        self.api.rooms[ADMIN_ROOM][("m.room.power_levels", "")] = {
            "users": {
                b.user_id(b.CONDUIT_USER): 69420,
                b.user_id("martin"): 100,
            }
        }
        self.api.events[("m.room.join_rules", "")] = {"join_rule": "public"}
        self.api.calls.clear()
        with self.assertRaises(b.Stop):
            self.run_bootstrap()
        self.assertEqual(self.writes(), [])


if __name__ == "__main__":
    unittest.main()
