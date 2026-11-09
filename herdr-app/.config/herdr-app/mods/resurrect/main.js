// Resurrect: save the spaces, tabs and terminals open now, and bring them
// back later as new spaces. Nothing running is closed on restore.
// Panes come back in a row: split directions aren't stored, folders and the
// programs are. Agents are only launched again when the box is ticked.

import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import {
  closeOverlay,
  exec,
  knownAgents,
  notify,
  panes,
  props,
  setShared,
  shared,
  spaces,
  terminals,
  theme,
} from "herdr";

const KEY = "resurrect.snapshot";

/** @typedef {{ cwd: string | null, argv: string[], shell: boolean, agent: string | null }} SavedPane */
/** @typedef {{ name: string | null, panes: SavedPane[] }} SavedTab */
/** @typedef {{ name: string | null, folder: string | null, machine: string | null, tabs: SavedTab[] }} SavedSpace */
/** @typedef {{ version: number, saved_at: number, spaces: SavedSpace[] }} Snapshot */

/** What is open now, with each terminal's folder and the program it runs. */
/** @returns {Snapshot} */
function snapshot() {
  const terms = new Map(terminals().map((t) => [t.address, t]));
  const all = panes();
  return {
    version: 1,
    saved_at: Date.now(),
    spaces: spaces().map((s) => ({
      name: s.named ? s.name : null,
      folder: s.folder || null,
      machine: s.machine ?? null,
      tabs: s.tabs.map((tab) => ({
        name: tab.named ? tab.name : null,
        panes: all
          .filter((p) => p.tab === tab.id && p.terminal)
          .map((p) => {
            const term = terms.get(p.terminal);
            return {
              cwd: p.cwd || s.folder || null,
              argv: Array.isArray(term?.argv) ? term.argv : [],
              // A shell is what spaces already start; anything else is a program.
              shell: p.program?.shell !== false,
              // Agents run inside the shell, so their launch argv is that shell;
              // the key is what lets a restore start the agent itself again.
              agent: p.program?.agent ? p.program.key : null,
            };
          }),
      })),
    })),
  };
}

/** @param {Snapshot | null} snap */
const tabCount = (snap) => (snap?.spaces ?? []).reduce((n, s) => n + s.tabs.length, 0);
/** @param {Snapshot | null} snap */
const termCount = (snap) =>
  (snap?.spaces ?? []).reduce(
    (n, s) => n + s.tabs.reduce((m, t) => m + Math.max(1, t.panes.length), 0),
    0,
  );

/** @param {number} ms */
function ago(ms) {
  const d = Math.max(0, Date.now() - ms) / 1000;
  if (d < 90) return "just now";
  if (d < 3600) return `${Math.round(d / 60)}m ago`;
  if (d < 86400) return `${Math.round(d / 3600)}h ago`;
  return `${Math.round(d / 86400)}d ago`;
}

export default class Resurrect extends View {
  /**
   * @param {any} _props
   * @param {import("gpui-kit").Context} cx
   */
  init(_props, cx) {
    this.handle = cx.focus_handle();
    this.handle.focus();
    this.relaunch = false;
    this.busy = false;
    this.error = "";
    this.done = "";
    this.agentRuns = new Map(); // machine ("" here) -> Promise<Map key, run[]>
  }

  /** The agents that can be started on a machine, by program key.
   * @param {string | null} machine */
  agentsOn(machine) {
    const key = machine ?? "";
    if (!this.agentRuns.has(key)) {
      this.agentRuns.set(
        key,
        knownAgents({ on: machine }).then(
          (list) => new Map(list.map((a) => [a.key, a.run])),
          () => new Map(),
        ),
      );
    }
    return this.agentRuns.get(key);
  }

  /** What brings a pane's program back, only when the box is ticked.
   * @param {SavedPane} p
   * @param {string | null} machine
   * @returns {Promise<string[]>} */
  async argv(p, machine) {
    if (!this.relaunch) return [];
    if (p.agent) {
      const run = (await this.agentsOn(machine)).get(p.agent);
      if (run) return run;
    }
    return p.shell === false && p.argv.length ? p.argv : [];
  }

  /** One app command through the CLI, which returns the ids it made.
   * @param {string} name
   * @param {Record<string, unknown>} args */
  async do(name, args) {
    const r = await exec("herdr-app", ["do", name, JSON.stringify(args ?? {})]);
    const text = (r.stdout || "").trim();
    /** @type {any} */
    let out = null;
    try {
      out = JSON.parse(text);
    } catch {
      out = null;
    }
    if (!out || out.error) throw new Error(out?.error || (r.stderr || text || `${name} failed`).trim());
    return out;
  }

  /**
   * @param {string} id
   * @param {string} label
   * @param {string} bg
   * @param {string} fg
   * @param {(e: any, cx: any) => void} onClick
   */
  button(id, label, bg, fg, onClick) {
    const t = theme();
    return h_flex()
      .id(id)
      .h(30)
      .px(12)
      .items_center()
      .rounded(7)
      .border_1()
      .border_color(id === "resurrect-forget" ? t.input : bg)
      .bg(bg)
      .text_color(fg)
      .cursor_pointer()
      .hover((s) => s.opacity(0.88))
      .on_click(onClick)
      .child(label);
  }

  /** @param {any} cx */
  save(cx) {
    setShared(KEY, snapshot());
    this.error = "";
    this.done = "Saved.";
    cx.notify();
  }

  /** @param {any} cx */
  forget(cx) {
    setShared(KEY, null);
    this.error = "";
    this.done = "Forgotten.";
    cx.notify();
  }

  /** @param {import("gpui-kit").Context} cx */
  restore(cx) {
    if (this.busy) return;
    const snap = shared(KEY);
    if (!snap?.spaces?.length) return;
    this.busy = true;
    this.error = "";
    this.done = "";
    cx.notify();
    cx.spawn(async (cx) => {
      try {
        const made = await this.rebuild(snap);
        this.busy = false;
        cx.notify();
        notify({ title: "Resurrected", body: made, level: "success" });
        closeOverlay(props().overlay);
      } catch (error) {
        this.busy = false;
        this.error = error instanceof Error ? error.message : String(error);
        cx.notify();
      }
    });
  }

  /** @param {Snapshot} snap */
  async rebuild(snap) {
    const n = { spaces: 0, tabs: 0, terminals: 0 };
    for (const s of snap.spaces) {
      const tabs = s.tabs.length
        ? s.tabs
        : [{ name: null, panes: [{ cwd: s.folder, argv: [], shell: true }] }];
      const head = tabs[0];
      const first = head.panes[0] ?? { cwd: s.folder, argv: [], shell: true };
      const argv = await this.argv(first, s.machine);
      const space = await this.do("space.new", {
        ...(s.name ? { name: s.name } : {}),
        ...(head.name ? { tab: head.name } : {}),
        ...(first.cwd ? { folder: first.cwd } : {}),
        ...(s.machine ? { machine: s.machine } : {}),
        ...(argv.length ? { argv } : {}),
      });
      n.spaces += 1;
      n.tabs += 1;
      n.terminals += 1;
      if (space.terminal) await this.do("pane.focus", { terminal: space.terminal });
      await this.more(head, n, s.machine);
      for (const tab of tabs.slice(1)) {
        const pane = tab.panes[0] ?? { cwd: s.folder, argv: [], shell: true };
        const argv = await this.argv(pane, s.machine);
        const made = await this.do("tab.new", {
          space: space.space,
          ...(tab.name ? { name: tab.name } : {}),
          ...(pane.cwd ? { folder: pane.cwd } : {}),
          ...(argv.length ? { argv } : {}),
        });
        n.tabs += 1;
        n.terminals += 1;
        if (made.tab) await this.do("tab.select", { id: made.tab });
        if (made.terminal) await this.do("pane.focus", { terminal: made.terminal });
        await this.more(tab, n, s.machine);
      }
    }
    return `${n.spaces} spaces · ${n.tabs} tabs · ${n.terminals} terminals`;
  }

  /**
   * @param {SavedTab} tab
   * @param {{ spaces: number, tabs: number, terminals: number }} n
   * @param {string | null} machine
   */
  async more(tab, n, machine) {
    for (const p of tab.panes.slice(1)) {
      const argv = await this.argv(p, machine);
      const made = await this.do("terminal.open", {
        place: "right",
        ...(p.cwd ? { folder: p.cwd } : {}),
        ...(argv.length ? { argv } : {}),
      });
      n.terminals += 1;
      if (made.pane) await this.do("pane.focus", { pane: made.pane });
    }
  }

  render(cx) {
    const t = theme();
    const snap = shared(KEY);
    const saved = snap?.spaces?.length
      ? `${snap.spaces.length} spaces · ${tabCount(snap)} tabs · ${termCount(snap)} terminals — ${ago(snap.saved_at)}`
      : "nothing saved yet";
    const note = this.error || this.done;
    return v_flex()
      .id("resurrect")
      .track_focus(this.handle)
      .on_key_down((e, cx) => {
        if (e.key === "s") this.save(cx);
        else if (e.key === "r") this.restore(cx);
        else if (e.key === "f") this.forget(cx);
        else if (e.key === "escape") closeOverlay(props().overlay);
        else return;
        cx.stop_propagation();
      })
      .size_full()
      .min_h(0)
      .p(18)
      .gap(10)
      .rounded(8)
      .bg(t.popover)
      .text_size(13)
      .child(
        h_flex()
          .items_center()
          .justify_between()
          .child(div().text_size(15).font_semibold().text_color(t.foreground).child("Resurrect"))
          .child(div().text_size(11).text_color(t.dim).child("Esc")),
      )
      .child(div().text_color(t.muted).child(saved))
      .child(
        h_flex()
          .id("resurrect-relaunch")
          .gap(8)
          .items_center()
          .cursor_pointer()
          .on_click((_e, cx) => {
            this.relaunch = !this.relaunch;
            cx.notify();
          })
          .child(
            div()
              .w(14)
              .h(14)
              .rounded(3)
              .border_1()
              .border_color(t.input)
              .bg(this.relaunch ? t.accent : t.background),
          )
          .child(
            div()
              .text_color(t.muted)
              .child(this.relaunch ? "relaunch programs, agents included" : "shells only, in the saved folders"),
          ),
      )
      .child(
        h_flex()
          .gap(8)
          .text_size(12)
          .child(this.button("resurrect-save", "Save", t.raised, t.foreground, (_e, cx) => this.save(cx)))
          .child(
            this.button(
              "resurrect-restore",
              this.busy ? "restoring…" : "Restore",
              t.solid,
              t.solid_foreground,
              (_e, cx) => this.restore(cx),
            ),
          )
          .child(
            this.button("resurrect-forget", "Forget", t.background, t.muted, (_e, cx) => this.forget(cx)),
          )
          .when(this.busy, (el) =>
            el.child(div().text_size(11).text_color(t.dim).child("keep the window open")),
          ),
      )
      .when(Boolean(note), (el) =>
        el.child(
          div()
            .text_size(12)
            .text_color(this.error ? t.blocked : t.done)
            .child(note),
        ),
      )
      .child(div().flex_1())
      .child(
        div()
          .text_size(11)
          .text_color(t.dim)
          .child("Restore opens new spaces; nothing running is closed. s save · r restore · f forget"),
      );
  }
}
