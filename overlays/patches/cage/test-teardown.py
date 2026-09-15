#!/usr/bin/env python3
"""Test patched Cage callbacks with no compositor or graphical session."""

import pathlib
import subprocess
import sys
import tempfile


def function(source, name):
    start = source.index(f"\n{name}(") + 1
    end = source.index("\n}", start) + 2
    return source[start:end]


source = pathlib.Path(sys.argv[1])
patch = pathlib.Path(__file__).with_name("teardown-order.patch")
with tempfile.TemporaryDirectory(prefix="cage-teardown-test-") as temporary:
    directory = pathlib.Path(temporary)
    for name in ("cage.c", "output.c", "server.h"):
        (directory / name).write_text((source / name).read_text())
    subprocess.run(
        ["patch", "-p1", "-i", str(patch.resolve())], cwd=directory, check=True
    )
    cage = (directory / "cage.c").read_text()
    output = (directory / "output.c").read_text()
    cleanup = cage[cage.index("\nend:") :]
    assert cleanup.index("server.shutting_down = true") < cleanup.index(
        "wlr_backend_destroy(server.backend)"
    )
    assert cleanup.index("wlr_backend_destroy(server.backend)") < cleanup.index(
        "seat_destroy(server.seat)"
    )
    assert cleanup.index("seat_destroy(server.seat)") < cleanup.index(
        "wl_display_destroy(server.wl_display)"
    )

    harness = r"""
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
struct wl_list { struct wl_list *prev, *next; };
struct wl_listener { struct wl_list link; };
static void wl_list_init(struct wl_list *l) { l->prev = l->next = l; }
static void wl_list_insert(struct wl_list *l, struct wl_list *n) {
    n->next = l->next; n->prev = l; l->next->prev = n; l->next = n;
}
static void wl_list_remove(struct wl_list *l) {
    l->prev->next = l->next; l->next->prev = l->prev;
}
static bool wl_list_empty(struct wl_list *l) { return l->next == l; }
#define wl_container_of(ptr, sample, member) \
    ((__typeof__(sample))((char *)(ptr) - offsetof(__typeof__(*sample), member)))
#define CAGE_MULTI_OUTPUT_MODE_LAST 1
struct cg_seat { struct wl_listener new_input; };
struct cg_server {
    bool shutting_down;
    int output_mode;
    void *backend;
    struct cg_seat *seat;
    struct wl_listener backend_destroy, new_output;
    struct wl_list outputs;
};
struct fake_output { void *data; };
struct cg_output {
    struct cg_server *server;
    struct fake_output *wlr_output;
    struct wl_listener destroy, commit, request_state, frame;
    struct wl_list link;
    bool nested;
};
static int removed, enabled, positioned, terminated;
static bool is_nested_output(struct cg_output *o) { return o->nested; }
static void output_layout_remove(struct cg_output *o) { (void)o; removed++; }
static void output_enable(struct cg_output *o) { (void)o; enabled++; }
static void view_position_all(struct cg_server *s) { (void)s; positioned++; }
static void server_terminate(struct cg_server *s) { (void)s; terminated++; }
"""
    harness += "\nstatic void\n" + function(output, "output_destroy")
    harness += "\nstatic void\n" + function(cage, "handle_backend_destroy")
    harness += r"""
static void test_output(bool shutdown, bool nested, bool remaining, int mode) {
    struct cg_server s = {.shutting_down = shutdown, .output_mode = mode};
    wl_list_init(&s.outputs);
    struct cg_output previous = {0};
    if (remaining) wl_list_insert(&s.outputs, &previous.link);
    struct fake_output w = {0};
    struct cg_output *o = calloc(1, sizeof(*o));
    assert(o);
    o->server = &s; o->wlr_output = &w; o->nested = nested; w.data = o;
    wl_list_init(&o->destroy.link); wl_list_init(&o->commit.link);
    wl_list_init(&o->request_state.link); wl_list_init(&o->frame.link);
    wl_list_insert(&s.outputs, &o->link);
    removed = enabled = positioned = terminated = 0;
    output_destroy(o);
    assert(w.data == NULL);
    assert(wl_list_empty(&s.outputs) == !remaining);
    assert(removed == !shutdown);
    assert(enabled == (!shutdown && remaining && mode == CAGE_MULTI_OUTPUT_MODE_LAST));
    assert(positioned == enabled);
    assert(terminated == (!shutdown && !remaining && nested));
}
static void test_backend(bool with_seat) {
    struct cg_seat seat;
    struct cg_server s = {.backend = &s, .seat = with_seat ? &seat : NULL};
    struct wl_list destroy, outputs, inputs;
    wl_list_init(&destroy); wl_list_init(&outputs); wl_list_init(&inputs);
    wl_list_insert(&destroy, &s.backend_destroy.link);
    wl_list_insert(&outputs, &s.new_output.link);
    if (with_seat) wl_list_insert(&inputs, &seat.new_input.link);
    terminated = 0;
    handle_backend_destroy(&s.backend_destroy, NULL);
    assert(s.shutting_down && s.backend == NULL && terminated == 1);
    assert(wl_list_empty(&destroy) && wl_list_empty(&outputs) && wl_list_empty(&inputs));
    assert(wl_list_empty(&s.new_output.link));
    if (with_seat) {
        assert(wl_list_empty(&seat.new_input.link));
        wl_list_remove(&seat.new_input.link);
    }
}
int main(void) {
    for (int shutdown = 0; shutdown < 2; shutdown++)
        for (int nested = 0; nested < 2; nested++)
            for (int remaining = 0; remaining < 2; remaining++)
                for (int mode = 0; mode < 2; mode++)
                    test_output(shutdown, nested, remaining, mode);
    test_backend(false);
    test_backend(true);
}
"""
    (directory / "test.c").write_text(harness)
    subprocess.run(
        ["cc", "-std=gnu11", "-Wall", "-Werror", "test.c", "-o", "test"],
        cwd=directory,
        check=True,
    )
    subprocess.run([str(directory / "test")], check=True)
    print("PASS: cleanup ordering, 16 output cases, and 2 backend listener cases")
