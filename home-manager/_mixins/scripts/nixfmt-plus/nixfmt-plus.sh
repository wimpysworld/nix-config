#!/usr/bin/env bash

deadnix --edit
statix fix
nixfmt --verify .
