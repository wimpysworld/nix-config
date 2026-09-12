import importlib

import addon_utils
import bpy


def _start_bridge():
    try:
        if not any(
            repo.module == "user_default" and repo.enabled
            for repo in bpy.context.preferences.extensions.repos
        ):
            raise RuntimeError("Enable the user_default extension repository")

        module = "bl_ext.user_default.claude_blender"
        if not addon_utils.check(module)[1]:
            if addon_utils.enable(module, default_set=True, persistent=True) is None:
                raise RuntimeError("The Blender Agent Bridge extension could not be enabled")

        script_runner = importlib.import_module(f"{module}.script_runner")
        result = script_runner.approve_external_script_trust_window(bpy.context, session=True)
        if not result["ok"]:
            raise RuntimeError(result["message"])

        bridge = importlib.import_module(f"{module}.bridge_server")
        if not bridge.is_running():
            result = bridge.start_bridge(host="127.0.0.1", port=8765, auth_token="")
            if not result["ok"]:
                raise RuntimeError(result["message"])
    except Exception as error:
        print(f"Blender Agent Bridge automatic startup failed: {error}")
    return None


def register():
    if not bpy.app.background and not bpy.app.timers.is_registered(_start_bridge):
        # Extension repositories initialise after startup modules register.
        bpy.app.timers.register(_start_bridge, first_interval=0.1, persistent=True)


def unregister():
    if bpy.app.timers.is_registered(_start_bridge):
        bpy.app.timers.unregister(_start_bridge)
