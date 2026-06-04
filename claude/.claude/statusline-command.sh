#!/bin/sh
# Claude Code status line — 2 lines:
#   Line 1: Ctx bar  used%
#   Line 2: model  in/out  $cost  used%  |  dir  branch

input=$(cat)

# --- Extract JSON fields ---
cwd=$(echo "$input"           | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input"         | jq -r '.model.display_name // empty')
in_tok=$(echo "$input"        | jq -r '.context_window.total_input_tokens // 0')
out_tok=$(echo "$input"       | jq -r '.context_window.total_output_tokens // 0')
used_pct=$(echo "$input"      | jq -r '.context_window.used_percentage // empty')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
cost_usd=$(echo "$input"      | jq -r '.cost.total_cost_usd // empty')
effort=$(echo "$input"        | jq -r '.effort_level // .effortLevel // empty')
[ -z "$effort" ] && effort=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)

# --- Git branch ---
git_branch=$(git -C "${cwd:-.}" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null || true)

# --- ANSI colors (Catppuccin Mocha palette) ---
peach='\033[38;2;250;179;135m'
yellow='\033[38;2;249;226;175m'
green='\033[38;2;166;227;161m'
lavender='\033[38;2;180;190;254m'
mauve='\033[38;2;203;166;247m'
red='\033[38;2;243;139;168m'
overlay0='\033[38;2;108;112;134m'
surface1='\033[38;2;49;50;68m'
reset='\033[0m'
bold='\033[1m'
dim='\033[2m'

# --- Short directory: parent/basename ---
if [ -n "$cwd" ]; then
    display_dir="${cwd/#$HOME/~}"
    _base=$(basename "$display_dir")
    _parent=$(basename "$(dirname "$display_dir")")
    if [ "$_parent" = "." ] || [ "$_parent" = "/" ] || [ "$_parent" = "~" ]; then
        display_dir="$_base"
    else
        display_dir="${_parent}/${_base}"
    fi
else
    display_dir=$(basename "$(pwd)")
fi

# ============================================================
# LINE 1: Ctx braille bar  used%
# ============================================================
line1=""

if [ -n "$used_pct" ] && [ -n "$remaining_pct" ]; then
    _used=$(printf '%.0f' "$used_pct")
    _w=32
    _rc="$green"
    [ "$_used" -ge 80 ] && _rc="$red"

    _subunits=$(awk "BEGIN { printf \"%d\", int($_used / 100.0 * $_w * 8 + 0.5) }")
    _full=$(( _subunits / 8 ))
    _partial=$(( _subunits % 8 ))
    _has_partial=$(( _partial > 0 ? 1 : 0 ))
    _empty=$(( _w - _full - _has_partial ))

    _bar_on=""; _i=0
    while [ "$_i" -lt "$_full" ]; do _bar_on="${_bar_on}⣿"; _i=$((_i+1)); done

    _pchar=""
    case "$_partial" in
        1) _pchar="⡀";; 2) _pchar="⡄";; 3) _pchar="⡆";;
        4) _pchar="⡇";; 5) _pchar="⣇";; 6) _pchar="⣧";; 7) _pchar="⣷";;
    esac

    _bar_off=""; _i=0
    while [ "$_i" -lt "$_empty" ]; do _bar_off="${_bar_off}⣿"; _i=$((_i+1)); done

    line1="$(printf "${dim}Ctx${reset} ${dim}│${reset}${_rc}%s%s${reset}${surface1}%s${reset}${dim}│${reset} ${_rc}%d%%${reset}" \
        "$_bar_on" "$_pchar" "$_bar_off" "$_used")"

    line1="${line1}$(printf "  ${overlay0}│${reset}  ${dim}session${reset}  ${yellow}%s/%s${reset}" "$in_tok" "$out_tok")"

    if [ -n "$cost_usd" ]; then
        line1="${line1}$(printf "  ${yellow}\$%.2f${reset}" "$cost_usd")"
    fi
fi

# ============================================================
# LINE 2: model  used%  |  dir  branch
# ============================================================
line2=""

if [ -n "$model" ]; then
    line2="$(printf "${bold}${peach}%s${reset}" "$model")"
fi

if [ -n "$effort" ]; then
    line2="${line2}$(printf "  ${mauve}%s${reset}" "$effort")"
fi

sep="$(printf "  ${overlay0}│${reset}  ")"
line2="${line2}${sep}$(printf "${bold}${lavender}%s${reset}" "$display_dir")"

if [ -n "$git_branch" ]; then
    line2="${line2}$(printf "  ${bold}${mauve}%s${reset}" "$git_branch")"
fi

# ============================================================
# LINE 3: context-mode statusline (ctx savings, budget, etc.)
# ============================================================
_ctx_bin=$(ls ~/.claude/plugins/cache/context-mode/context-mode/*/bin/statusline.mjs 2>/dev/null | sort -V | tail -1)
ctx_line=$(printf '%s' "$input" | node "$_ctx_bin" 2>/dev/null | sed 's/●/│/g' || true)
if [ -n "$ctx_line" ]; then
    _cm_label=$(printf '%s' "$ctx_line" | awk -F'│' '{gsub(/[[:space:]]+$/,"",$1); print $1}')
    _cm_rest=$(printf '%s' "$ctx_line" | awk -F'│' '{gsub(/^[[:space:]]+/,"",$2); print $2}')
    ctx_line="$(printf "${dim}%s${reset}  ${overlay0}│${reset}  ${green}%s${reset}" "$_cm_label" "$_cm_rest")"
fi

# ============================================================
# Output
# ============================================================
[ -n "$ctx_line" ] && printf "%s\n" "$ctx_line"
if [ -n "$line1" ]; then
    printf "%s\n%s" "$line1" "$line2"
else
    printf "%s" "$line2"
fi
