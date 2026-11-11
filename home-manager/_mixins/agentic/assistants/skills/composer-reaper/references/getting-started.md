# Getting started

Use the existing REAPER installation. Do not install packages or extensions as an implicit part of this workflow.

1. Open `Options > Show REAPER resource path`.
2. Copy the required starter from this skill into a writable directory under `Scripts/`.
3. Open `Actions > Show action list > New action > Load ReaScript`.
4. Select the copied file, then run it when the user requests the action.

Start with `scripts/01_hello_list_tracks.lua`. It prints each track name without changing the project.
Load JSFX files from `Effects/` through the FX browser.
Compiled extensions belong in `UserPlugins/`, but these starters need none.

Lua needs no separate runtime inside REAPER. EEL2 is another native scripting language.
Use Python only when a required library justifies the separate REAPER runtime configuration.

ReaPack distributes community scripts and effects. SWS adds actions and API functions.
Neither extension is required for these starters. Check availability before using extension-specific functions.
On managed systems, request configuration changes through the existing package workflow rather than an upstream installer.
