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
        self.users = {}
        self.events = {}
        self.media = {}
        self.alias = None
        self.calls = []
        self.fail_after: tuple[str, str] | None = None
        self.displayname_suffix = ""

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
                user not in self.users
                or self.users[user]["password"] != body["password"]
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
        if path.endswith("/displayname"):
            target = urllib.parse.unquote(path.split("/")[-2]).split(":")[0][1:]
            assert target == token
            if method == "PUT":
                self.users[token]["displayname"] = body["displayname"]
                return {}
            return {"displayname": self.users[token]["displayname"]}
        if path.endswith("/avatar_url"):
            target = urllib.parse.unquote(path.split("/")[-2]).split(":")[0][1:]
            assert target == token
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
        if path == b.CLIENT + "/logout":
            return {}
        if path == b.CLIENT + "/directory/room/" + b.quoted(b.ALIAS):
            if self.alias is None:
                raise b.APIError(404, "M_NOT_FOUND")
            return {"room_id": self.alias}
        if path == b.CLIENT + "/createRoom":
            assert self.alias is None
            assert body["room_id"] == "the-cauldron"
            self.alias = b.ROOM
            self.events = {
                (event["type"], event["state_key"]): event["content"]
                for event in body["initial_state"]
            }
            self.events.update(
                {
                    ("m.room.create", ""): {
                        **body["creation_content"],
                        "room_version": body["room_version"],
                    },
                    ("m.room.canonical_alias", ""): {"alias": b.ALIAS},
                    ("m.room.name", ""): {"name": body["name"]},
                    ("m.room.power_levels", ""): body["power_level_content_override"],
                    ("m.room.member", b.user_id("martin")): {"membership": "join"},
                }
            )
            return {"room_id": b.ROOM}
        if path.endswith("/state"):
            return [
                {
                    "type": kind,
                    "state_key": key,
                    "content": value,
                    "sender": b.user_id("martin"),
                }
                for (kind, key), value in self.events.items()
            ]
        if path.endswith("/state/m.room.avatar/"):
            assert method == "PUT"
            assert token == b.USERS[0]
            self.events[("m.room.avatar", "")] = copy.deepcopy(body)
            return {"event_id": "$synthetic-room-avatar"}
        if "/directory/list/room/" in path:
            return {"visibility": "private"}
        if path.endswith("/invite"):
            assert token == b.USERS[0]
            self.events[("m.room.member", body["user_id"])] = {"membership": "invite"}
            return {}
        if path.endswith("/join"):
            self.events[("m.room.member", b.user_id(token))] = {"membership": "join"}
            return {"room_id": b.ROOM}
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
            self.assertEqual(self.api.users[user]["displayname"], user)
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
            self.media_bytes(self.api.events[("m.room.avatar", "")]["url"]),
            self.avatars["the-cauldron"],
        )
        self.api.calls.clear()
        self.assertEqual(self.run_bootstrap(), b.ROOM)
        self.assertEqual(self.writes(), [])
        self.assertEqual(
            sum(path.endswith("/logout") for _, path, _ in self.api.calls), len(b.USERS)
        )

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
                        self.api.users["martin"]["displayname"], "martin 💕"
                    )
                self.assertEqual(self.run_bootstrap(), b.ROOM)
                for user in b.USERS:
                    self.assertEqual(self.api.users[user]["displayname"], user)
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
        self.api.events[("m.room.join_rules", "")] = {"join_rule": "public"}
        self.api.calls.clear()
        with self.assertRaises(b.Stop):
            self.run_bootstrap()
        self.assertEqual(self.writes(), [])


if __name__ == "__main__":
    unittest.main()
