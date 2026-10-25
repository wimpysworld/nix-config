import json
import os
import sys

import dbus
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib


def emit(event, args):
    print(json.dumps({"event": event, "args": list(args)}), flush=True)


emit("start", sys.argv[1:])
if "--test-start-failure" in sys.argv:
    sys.exit(7)
if any(
    arg in ("--help", "-h", "--list-devices", "--list-models")
    or arg.startswith(("--transcribe-file", "-f"))
    for arg in sys.argv[1:]
):
    sys.exit(0)

with open(os.environ["HANDY_TEST_GATE"]) as gate:
    gate.read(1)

dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
name = dbus.service.BusName("com.pais.handy.SingleInstance", bus, do_not_queue=True)
loop = GLib.MainLoop()


class Instance(dbus.service.Object):
    @dbus.service.method("org.SingleInstance.DBus", in_signature="ass", out_signature="")
    def ExecuteCallback(self, argv, cwd):
        emit("forward", argv[1:])
        assert str(cwd) == os.getcwd()
        if "--test-exit" in argv:
            loop.quit()


instance = Instance(bus, "/com/pais/handy/SingleInstance")
emit("ready", [])
loop.run()
