// Leader: ctrl+b, then one key, for the app's own commands. Every other key
// stays the terminal program's, which is what a prefix gives you.
// Unknown keys and Esc close it; ctrl+b again cancels.

import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { run, theme, props, closeOverlay } from "herdr";

/** @typedef {import("gpui-kit").KeyEvent} KeyEvent */
/** @typedef {import("gpui-kit").Context} Context */

/** One row: the keys that run it, the chip it shows, what it runs.
 * @typedef {{ chip: string, keys: string[], label: string, command: string,
 *   args?: Record<string, unknown>, index?: boolean }} Item */
/** @typedef {{ title: string, items: Item[] }} Group */

// The old herdr prefix map, as the columns it is shown in. `keys` are the
// spellings a key event can arrive as (GPUI names punctuation: "-" is "minus",
// "?" is shift-slash); `chip` is what the row shows.
/** @type {Group[]} */
const GROUPS = [
  {
    title: "panes",
    items: [
      { chip: "h", keys: ["h", "left"], label: "focus left", command: "pane.go", args: { direction: "left" } },
      { chip: "j", keys: ["j", "down"], label: "focus down", command: "pane.go", args: { direction: "down" } },
      { chip: "k", keys: ["k", "up"], label: "focus up", command: "pane.go", args: { direction: "up" } },
      { chip: "l", keys: ["l", "right"], label: "focus right", command: "pane.go", args: { direction: "right" } },
      { chip: "v", keys: ["v"], label: "split right", command: "pane.split", args: { direction: "right" } },
      { chip: "-", keys: ["-", "minus"], label: "split down", command: "pane.split", args: { direction: "down" } },
      { chip: "x", keys: ["x"], label: "close pane", command: "pane.close" },
      { chip: "z", keys: ["z"], label: "zoom pane", command: "pane.zoom" },
      { chip: "b", keys: ["b"], label: "sidebar", command: "layout.toggle", args: { id: "sidebar" } },
    ],
  },
  {
    title: "tabs",
    items: [
      { chip: "c", keys: ["c"], label: "new tab", command: "tab.new" },
      { chip: "T", keys: ["shift-t"], label: "rename tab", command: "tab.rename" },
      { chip: "X", keys: ["shift-x"], label: "close tab", command: "tab.close" },
      { chip: "n", keys: ["n"], label: "next tab", command: "tab.next" },
      { chip: "p", keys: ["p"], label: "previous tab", command: "tab.prev" },
      { chip: "1-9", keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9"], label: "select tab", command: "tab.select", index: true },
    ],
  },
  {
    title: "spaces",
    items: [
      { chip: "N", keys: ["shift-n"], label: "new space", command: "space.new" },
      { chip: "W", keys: ["shift-w"], label: "rename space", command: "space.rename" },
      { chip: "D", keys: ["shift-d"], label: "close space", command: "space.close" },
    ],
  },
  {
    title: "app",
    items: [
      { chip: "w", keys: ["w"], label: "go to…", command: "mod.open", args: { name: "picker" } },
      { chip: "g", keys: ["g"], label: "commands", command: "app.palette" },
      { chip: "s", keys: ["s"], label: "settings", command: "app.settings" },
      { chip: "?", keys: ["?", "shift-slash"], label: "help", command: "app.help" },
      { chip: "q", keys: ["q"], label: "hide window", command: "app.hide" },
    ],
  },
];

// Every spelling of every key, to the row it runs.
/** @type {Map<string, Item>} */
const RUNS = new Map();
for (const g of GROUPS)
  for (const item of g.items) for (const k of item.keys) RUNS.set(k, item);

/**
 * A key event's spellings, most exact first: the chord, the character it types,
 * then the bare key. An uppercase character only offers its shift form.
 * @param {KeyEvent} e
 * @returns {string[]}
 */
function spellings(e) {
  /** @type {string[]} */
  const out = [];
  /** @param {string} s */
  const add = (s) => {
    if (typeof s === "string" && s && !out.includes(s)) out.push(s.toLowerCase());
  };
  add(e.keystroke);
  const ch = e.key_char;
  if (typeof ch === "string" && ch.length === 1) {
    if (/[A-Z]/.test(ch)) add(`shift-${ch.toLowerCase()}`);
    else add(ch === " " ? "space" : ch);
  }
  const k = typeof e.key === "string" ? e.key.toLowerCase() : "";
  add(k);
  if (e.modifiers?.shift && /^[a-z]$/.test(k)) add(`shift-${k}`);
  return out;
}

export default class Leader extends View {
  /**
   * @param {any} _props
   * @param {Context} cx
   */
  init(_props, cx) {
    this.handle = cx.focus_handle();
    this.handle.focus();
    this.done = false;
  }

  close() {
    closeOverlay(props().overlay);
  }

  /**
   * One key per open: the first one that means something runs, the rest closes.
   * @param {KeyEvent} event
   */
  press(event) {
    if (this.done) return;
    this.done = true;
    const keys = spellings(event);
    this.close();
    if (keys.includes("ctrl-b") || keys.includes("escape")) return;
    for (const k of keys) {
      const item = RUNS.get(k);
      if (!item) continue;
      return run(item.command, item.index ? { index: Number(k) } : item.args ?? {});
    }
  }

  /**
   * @param {Item} item
   * @param {any} t
   */
  row(item, t) {
    return h_flex()
      .h(21)
      .gap(9)
      .items_center()
      .child(div().w(42).flex_none().text_size(12).font_semibold().text_color(t.accent).child(item.chip))
      .child(div().flex_1().truncate().text_size(12).text_color(t.foreground).child(item.label));
  }

  /**
   * @param {Group} group
   * @param {any} t
   */
  group(group, t) {
    return v_flex()
      .flex_1()
      .gap(1)
      .child(div().mb(3).text_size(10).font_semibold().text_color(t.dim).child(group.title.toUpperCase()))
      .children(group.items.map((item) => this.row(item, t)));
  }

  render() {
    // theme() hands out color strings; the element builders type colors as hex literals.
    const /** @type {any} */ t = theme();
    return v_flex()
      .id("leader")
      .track_focus(this.handle)
      .size_full()
      .min_h(0)
      .p(16)
      .gap(10)
      .rounded(8)
      .bg(t.popover)
      .text_size(13)
      .on_key_down((e, cx) => {
        cx.stop_propagation();
        this.press(e);
      })
      .child(
        h_flex()
          .items_center()
          .justify_between()
          .child(div().text_size(14).font_semibold().text_color(t.foreground).child("Leader"))
          .child(div().text_size(11).text_color(t.dim).child("one key · Esc cancels")),
      )
      .child(h_flex().items_start().gap(14).children(GROUPS.map((g) => this.group(g, t))));
  }
}
