# The package installCheckPhase runs these offline rendering checks.
import ctypes as c
import math
from pathlib import Path
import sys


library = c.CDLL(sys.argv[1])
root = Path(sys.argv[2])


def bind(name, result, *arguments):
    function = getattr(library, f"sfizz_{name}")
    function.restype = result
    function.argtypes = arguments
    return function


pointer = c.c_void_p
create = bind("create_synth", pointer)
free = bind("free", None, pointer)
load = bind("load_file", c.c_bool, pointer, c.c_char_p)
sample_rate = bind("set_sample_rate", None, pointer, c.c_float)
block_size = bind("set_samples_per_block", None, pointer, c.c_int)
freewheel = bind("enable_freewheeling", None, pointer)
note_on = bind("send_note_on", None, pointer, c.c_int, c.c_int, c.c_int)
note_off = bind("send_note_off", None, pointer, c.c_int, c.c_int, c.c_int)
cc = bind("send_cc", None, pointer, c.c_int, c.c_int, c.c_int)
stop = bind("all_sound_off", None, pointer)
render = bind(
    "render_block", None, pointer, c.POINTER(c.POINTER(c.c_float)), c.c_int, c.c_int
)
frames = 1024
left = (c.c_float * frames)()
right = (c.c_float * frames)()
channels = (c.POINTER(c.c_float) * 2)(left, right)


def open_program(path):
    synth = create()
    sample_rate(synth, 48000)
    block_size(synth, frames)
    freewheel(synth)
    assert load(synth, str(path).encode()), path
    return synth


def capture(synth, blocks=16):
    result = []
    for _ in range(blocks):
        render(synth, channels, 2, frames)
        result.extend(left)
        result.extend(right)
    assert all(math.isfinite(value) for value in result)
    return result


def peak(values):
    return max(abs(value) for value in values)


def hit(synth, note, velocity):
    stop(synth)
    capture(synth, 1)
    note_on(synth, 0, note, velocity)
    result = capture(synth)
    note_off(synth, 0, note, 0)
    return result


for program in sorted((root / "Programs-sfizz").glob("[0-9]*.sfz")):
    synth = open_program(program)
    try:
        notes = [42, 44, 46] if program.name.startswith("01-") else [42, 44, 46, 90, 92, 94]
        for note in notes:
            for velocity in [20, 70, 120]:
                assert peak(hit(synth, note, velocity)) > 1e-8, (program, note, velocity)
    finally:
        free(synth)

program = root / "Programs-sfizz/02-full-kit.sfz"
for closer in [42, 44, 90, 94]:
    outputs = []
    for mode in ["both", "close", "open"]:
        synth = open_program(program)
        try:
            if mode != "close":
                note_on(synth, 0, 46, 120)
            capture(synth, 8)
            if mode != "open":
                note_on(synth, 0, closer, 100)
            capture(synth, 48)
            outputs.append(capture(synth))
        finally:
            free(synth)
    both, closed, opened = outputs
    assert peak(opened) > 1e-8, closer
    assert peak([a - b for a, b in zip(both, closed)]) < 1e-8, closer

original = open_program(root / "Programs/02-full-kit.sfz")
compatible = open_program(program)
try:
    for synth in [original, compatible]:
        for controller in [101, 103, 105, 107, 109, 111]:
            cc(synth, 0, controller, 0)
        assert peak(hit(synth, 38, 100)) == 0
    for microphone in [101, 103, 105, 107, 109, 111]:
        for synth in [original, compatible]:
            for controller in [101, 103, 105, 107, 109, 111]:
                cc(synth, 0, controller, 127 if controller == microphone else 0)
        for controller, values, note in [(21, [0, 127], 38), (1, [0, 64, 127], 96)]:
            audible = False
            for value in values:
                for synth in [original, compatible]:
                    cc(synth, 0, controller, value)
                before = hit(original, note, 100)
                after = hit(compatible, note, 100)
                audible |= peak(after) > 1e-8
                assert before == after, (microphone, controller, value)
            assert audible, (microphone, controller)
finally:
    free(original)
    free(compatible)

print("sfizz hi-hat, choke, microphone and snare controls passed")
