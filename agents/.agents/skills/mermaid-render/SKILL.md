---
name: mermaid-render
description: |
  Render Mermaid diagrams as readable ASCII art, GUI viewer, or save to files.
  
  Use when:
  - User asks to "show", "display", or "render" a mermaid diagram
  - User wants visual output of flowcharts in terminal (ASCII art)
  - User needs to generate mermaid diagram images (PNG, SVG, PDF)
  - Converting mermaid code to visual output without leaving the terminal
  
  Triggers: "render mermaid", "show diagram", "display flowchart", "visualize graph", "mermaid terminal", "ascii diagram"
---

# Mermaid Render

Render Mermaid diagrams as readable ASCII art (default) or open in GUI viewer.

## Quick Start

```bash
# Render ASCII art (default) - readable text labels, flowcharts only
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh "graph LR; A[Start] --> B[End]"

# Output:
# +-------+     +-----+
# | Start | --> | End |
# +-------+     +-----+

# Open in GUI viewer (eog) - RECOMMENDED for non-flowcharts
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh -f view "sequenceDiagram; A->>B: Hello"

# Inline image with Kitty graphics (Ghostty, Kitty, WezTerm)
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh -f image "graph TD; A-->B"

# Save as PNG file
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh -f png -o diagram.png diagram.mmd
```

## Formats

| Format | Output | Diagram Types | Text Readable |
|--------|--------|---------------|---------------|
| `ascii` (default) | ASCII art in terminal | Flowcharts/graphs only | ✅ Yes |
| `view` | Opens in GUI viewer (eog) | All types | ✅ Yes |
| `image` | Inline terminal image (Kitty graphics) | All types | ✅ Yes (in supported terminals) |
| `png` / `svg` / `pdf` | File | All types | ✅ Yes (external viewer) |

## ASCII Art (Default)

Uses `graph-easy` to render flowcharts as readable ASCII box diagrams:

```bash
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh "graph LR; A[Start] --> B{Decision}; B -->|Yes| C[Process]; B -->|No| D[Skip]; C --> E[End]; D --> E"
```

Output:
```
+-------+     +----------+  Yes   +---------+     +-----+
| Start | --> | Decision | -----> | Process | --> | End |
+-------+     +----------+        +---------+     +-----+
                |                                   ^
                | No                                |
                v                                   |
              +----------+                          |
              |   Skip   | -------------------------+
              +----------+
```

### Supported Node Shapes (ASCII)

| Mermaid Syntax | ASCII Shape |
|----------------|-------------|
| `A[Label]` | Rectangle |
| `A{Label}` | Diamond (decision) |
| `A((Label))` | Circle |
| `A(Label)` | Ellipse |

### Supported Edge Labels

```bash
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh "graph LR; A -->|Yes| B; A -->|No| C"
```

## Inline Images (Kitty Graphics Protocol)

For terminals that support Kitty graphics protocol (Ghostty, Kitty, WezTerm), diagrams render inline with full quality:

```bash
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh -f image "sequenceDiagram; A->>B: Hello; B-->>A: Hi"
```

**Supported terminals:**
- Ghostty ✅
- Kitty ✅
- WezTerm ✅
- tmux (with passthrough) ✅
- Other terminals → falls back to Unicode symbols

## GUI Viewer (Recommended for Non-Flowcharts)

For sequence diagrams, state diagrams, ER diagrams, etc., use `view` format to open in Eye of GNOME (eog) or system default viewer:

```bash
# Sequence diagram
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh -f view "sequenceDiagram; A->>B: Hello; B-->>A: Hi"

# State diagram (multiline via stdin)
cat <<'EOF' | ~/.agents/skills/mermaid-render/scripts/mermaid-render.sh -f view -
stateDiagram-v2
    [*] --> Active
    Active --> Inactive
    Inactive --> [*]
EOF

# ER diagram
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh -f view "erDiagram; USER ||--o{ ORDER : places"
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `-f, --format` | `ascii`, `view`, `image`, `png`, `svg`, `pdf` | `ascii` |
| `-o, --output` | Output file path (auto-detects format) | stdout |
| `-t, --theme` | `default`, `dark`, `forest`, `neutral`, `auto` | `auto` |
| `-w, --width` | Image width in pixels | `800` |
| `-c, --chafa` | `kitty`, `sixel`, `symbols`, `auto` | `auto` |
| `--open` | Always open in external viewer | - |
| `--no-open` | Disable auto-open in nested tmux | - |

## Auto-Detection Features

### Dark/Light Mode Detection

The script automatically detects your system's color scheme and adjusts:
- **Theme**: `dark` for dark mode, `neutral` for light mode
- **Background**: `black` for dark mode, `white` for light mode

Detection priority:
1. `COLORFGBG` environment variable
2. `TERM_BACKGROUND` environment variable
3. GNOME/GTK color scheme (`gsettings`)
4. KDE color scheme (`~/.config/kdeglobals`)
5. macOS `AppleInterfaceStyle`
6. Default: dark mode

Override with `-t <theme>` or set `MERMAID_THEME` / `MERMAID_BG` environment variables.

### Nested tmux Client Detection

When running inside a nested tmux client (e.g., sidekick.nvim's terminal), Kitty graphics cannot display properly because output goes to a different pty.

The script automatically detects this and opens diagrams in your system's default image viewer instead.

- Use `--no-open` to disable auto-open and fall back to Unicode symbols display
- Use `--open` to always open in external viewer regardless of terminal

## Examples

### ASCII Flowcharts

```bash
# Simple flow
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh "graph LR; A-->B-->C"

# With decision node
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh "graph TD; A[Start] --> B{Check}; B -->|OK| C[Done]; B -->|Fail| D[Retry]"
```

### Inline Images

```bash
# Sequence diagram with Kitty graphics
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh -f image "sequenceDiagram; Client->>Server: Request; Server-->>Client: Response"

# Class diagram
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh -f image "classDiagram; Animal <|-- Duck; Animal <|-- Fish"
```

### GUI Viewer (All Diagram Types)

```bash
# Sequence diagram
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh -f view "sequenceDiagram; Client->>Server: Request; Server-->>Client: Response"

# Class diagram
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh -f view "classDiagram; Animal <|-- Duck; Animal <|-- Fish"
```

### File Output

```bash
# PNG with custom width
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh -f png -w 1200 -o flowchart.png diagram.mmd

# SVG (scalable)
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh -f svg -o diagram.svg diagram.mmd

# PDF
~/.agents/skills/mermaid-render/scripts/mermaid-render.sh -f pdf -o diagram.pdf diagram.mmd
```

### From Stdin

```bash
cat <<'EOF' | ~/.agents/skills/mermaid-render/scripts/mermaid-render.sh -f view -
sequenceDiagram
    participant A as Client
    participant B as Server
    A->>B: Request
    B-->>A: Response
EOF
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MERMAID_THEME` | Theme override (`dark`, `neutral`, `forest`, `default`) | auto-detect |
| `MERMAID_BG` | Background color override | auto-detect |
| `FORCE_CHAFA_FORMAT` | Force chafa format (`kitty`, `sixel`, `symbols`) | auto-detect |

## Requirements

| Tool | Purpose | Install |
|------|---------|---------|
| `graph-easy` | ASCII rendering | `sudo apt install libgraph-easy-perl` |
| `mmdc` | PNG/SVG/PDF generation | `npm install -g @mermaid-js/mermaid-cli` |
| `eog` / `xdg-open` | GUI viewer | Usually pre-installed on Linux |
| `chafa` | Terminal image display | `sudo apt install chafa` |

## Known Limitations

### ASCII Only Supports Flowcharts
The ASCII renderer (`graph-easy`) only handles `graph` and `flowchart` diagrams. For other types:
- Use `-f image` for inline Kitty graphics (recommended for supported terminals)
- Use `-f view` to open in GUI viewer
- Use `-f png -o file.png` and view externally

### Semicolon Syntax
Some diagram types (stateDiagram, etc.) don't support inline semicolon syntax. Use multiline input via stdin or file instead.

## Troubleshooting

### "graph-easy not found"
```bash
sudo apt install libgraph-easy-perl
```

### "mmdc not found"
```bash
npm install -g @mermaid-js/mermaid-cli
```

### "No image viewer found"
Install eog or ensure xdg-open is configured:
```bash
sudo apt install eog
```

### "ASCII rendering only supports flowchart/graph diagrams"
Use `-f image` for Kitty graphics, `-f view` for GUI viewer, or `-f png -o file.png` to save as file.

### "mmdc failed to render diagram"
Check mermaid syntax. Some diagram types don't support semicolon-separated inline syntax - use multiline input instead.

### Kitty graphics not displaying in tmux
The script auto-detects nested tmux clients and opens in external viewer. If graphics still don't work:
- Use `--open` to force external viewer
- Use `-f view` for GUI viewer
- Check that `tmux set -p allow-passthrough on` is enabled
