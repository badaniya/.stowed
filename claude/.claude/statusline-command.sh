#!/bin/sh
# Claude Code status line matching screenshot layout:
#   LEFT:   model  in/out  $cost  used%
#   MIDDLE: dir  branch
#   RIGHT:  ctx bar  remaining%  |  Month [bar] rate%  (reset_time)

input=$(cat)

# --- Extract JSON fields ---
cwd=$(echo "$input"           | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input"         | jq -r '.model.display_name // empty')
in_tok=$(echo "$input"        | jq -r '.context_window.current_usage.input_tokens // 0')
out_tok=$(echo "$input"       | jq -r '.context_window.current_usage.output_tokens // 0')
used_pct=$(echo "$input"      | jq -r '.context_window.used_percentage // empty')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
five_pct=$(echo "$input"      | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input"    | jq -r '.rate_limits.five_hour.resets_at // empty')
week_pct=$(echo "$input"      | jq -r '.rate_limits.seven_day.used_percentage // empty')
week_reset=$(echo "$input"    | jq -r '.rate_limits.seven_day.resets_at // empty')

# --- Git branch (skip optional locks to avoid contention) ---
git_branch=$(git -C "${cwd:-.}" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null || true)

# --- ANSI colors (Catppuccin Mocha palette) ---
peach='\033[38;2;250;179;135m'      # model name
yellow='\033[38;2;249;226;175m'     # token counts / cost / used%
green='\033[38;2;166;227;161m'      # context remaining (healthy)
lavender='\033[38;2;180;190;254m'   # directory
mauve='\033[38;2;203;166;247m'      # git branch
teal='\033[38;2;148;226;213m'       # rate limit bars / labels
sapphire='\033[38;2;116;199;236m'   # context bar brackets
red='\033[38;2;243;139;168m'        # high usage warning
overlay0='\033[38;2;108;112;134m'   # section separators
reset='\033[0m'
bold='\033[1m'
dim='\033[2m'

# --- Helper: build a Unicode block progress bar ---
# Usage: make_bar <percent_integer> <width>
make_bar() {
    _pct="$1"; _w="$2"
    _filled=$(awk "BEGIN { f=int($_pct/100*$_w+0.5); print (f<0?0:(f>$_w?$_w:f)) }")
    _empty=$(( _w - _filled ))
    _bar=""
    _i=0
    while [ "$_i" -lt "$_filled" ]; do _bar="${_bar}⣿"; _i=$((_i+1)); done
    _i=0
    while [ "$_i" -lt "$_empty" ]; do _bar="${_bar}⣀"; _i=$((_i+1)); done
    printf "%s" "$_bar"
}

# --- Helper: format seconds-until-epoch as "Xd Yh" or "Yh Zm" ---
fmt_reset() {
    _now=$(date +%s)
    _secs=$(( $1 - _now ))
    [ "$_secs" -lt 0 ] && _secs=0
    _d=$(( _secs / 86400 ))
    _h=$(( (_secs % 86400) / 3600 ))
    _m=$(( (_secs % 3600) / 60 ))
    if [ "$_d" -gt 0 ]; then
        printf "%dd%dh" "$_d" "$_h"
    else
        printf "%dh%dm" "$_h" "$_m"
    fi
}

# --- Estimated cost (Sonnet pricing: $3/M input, $15/M output) ---
cost_usd=$(awk "BEGIN { printf \"%.2f\", ($in_tok * 3 / 1000000) + ($out_tok * 15 / 1000000) }")

# --- Short directory: parent/basename (matches "badaniya/.stowed" style) ---
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
# LEFT: model  in/out  $cost  used%
# ============================================================
left=""

if [ -n "$model" ]; then
    left="$(printf "${bold}${peach}%s${reset}" "$model")"
fi

left="${left}$(printf "  ${yellow}%s/%s${reset}" "$in_tok" "$out_tok")"
left="${left}$(printf "  ${yellow}\$%s${reset}" "$cost_usd")"

if [ -n "$used_pct" ]; then
    _used_int=$(printf '%.0f' "$used_pct")
    _uc="$yellow"
    [ "$_used_int" -ge 80 ] && _uc="$red"
    left="${left}$(printf "  ${_uc}%.0f%%${reset}" "$used_pct")"
fi

# ============================================================
# MIDDLE: dir  branch
# ============================================================
middle="$(printf "${bold}${lavender}%s${reset}" "$display_dir")"

if [ -n "$git_branch" ]; then
    middle="${middle}$(printf "  ${bold}${mauve}%s${reset}" "$git_branch")"
fi

# ============================================================
# RIGHT: ctx bar remaining%  |  Month [bar] rate% (reset)
# ============================================================
right=""

# Context window: Ctx | braille bar (8x sub-char precision) | used%
if [ -n "$used_pct" ] && [ -n "$remaining_pct" ]; then
    _used=$(printf '%.0f' "$used_pct")
    _w=32
    _rc="$green"
    [ "$_used" -ge 80 ] && _rc="$red"

    # Each cell = 8 sub-units → resolution = width * 8
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

    right="$(printf "${dim}Ctx${reset} ${dim}│${reset}${_rc}%s%s${reset}${dim}%s${reset}${dim}│${reset} ${_rc}%d%%${reset}" \
        "$_bar_on" "$_pchar" "$_bar_off" "$_used")"
fi

# Helper: build braille bar segment (sub-char precision), sets _bar_on, _pchar, _bar_off
_make_braille_bar() {
    _mbpct="$1"; _mbw="$2"
    _mbsub=$(awk "BEGIN { printf \"%d\", int($_mbpct / 100.0 * $_mbw * 8 + 0.5) }")
    _mbfull=$(( _mbsub / 8 ))
    _mbpart=$(( _mbsub % 8 ))
    _mbhas=$(( _mbpart > 0 ? 1 : 0 ))
    _mbempty=$(( _mbw - _mbfull - _mbhas ))
    _bar_on=""; _j=0
    while [ "$_j" -lt "$_mbfull" ]; do _bar_on="${_bar_on}⣿"; _j=$((_j+1)); done
    _pchar=""
    case "$_mbpart" in
        1) _pchar="⡀";; 2) _pchar="⡄";; 3) _pchar="⡆";;
        4) _pchar="⡇";; 5) _pchar="⣇";; 6) _pchar="⣧";; 7) _pchar="⣷";;
    esac
    _bar_off=""; _j=0
    while [ "$_j" -lt "$_mbempty" ]; do _bar_off="${_bar_off}⣿"; _j=$((_j+1)); done
}

# 5-hour session rate limit
if [ -n "$five_pct" ]; then
    _fp=$(printf '%.0f' "$five_pct")
    _make_braille_bar "$_fp" 16
    [ -n "$right" ] && right="${right}$(printf "  ${overlay0}│${reset}  ")"
    right="${right}$(printf "${dim}5h${reset} ${dim}│${reset}${teal}%s%s${reset}${dim}%s${reset}${dim}│${reset} ${teal}%d%%${reset}" \
        "$_bar_on" "$_pchar" "$_bar_off" "$_fp")"
    [ -n "$five_reset" ] && right="${right}$(printf " ${dim}│${reset} ${teal}%s${reset}" "$(fmt_reset "$five_reset")")"
fi

# 7-day (monthly) rate limit
if [ -n "$week_pct" ]; then
    _wp=$(printf '%.0f' "$week_pct")
    _make_braille_bar "$_wp" 16
    [ -n "$right" ] && right="${right}$(printf "  ${overlay0}│${reset}  ")"
    right="${right}$(printf "${dim}Month${reset} ${dim}│${reset}${teal}%s%s${reset}${dim}%s${reset}${dim}│${reset} ${teal}%d%%${reset}" \
        "$_bar_on" "$_pchar" "$_bar_off" "$_wp")"
    [ -n "$week_reset" ] && right="${right}$(printf " ${dim}│${reset} ${teal}%s${reset}" "$(fmt_reset "$week_reset")")"
fi

# ============================================================
# Assemble: LEFT  |  MIDDLE  |  RIGHT
# ============================================================
sep="$(printf "  ${overlay0}│${reset}  ")"
out="$left"
[ -n "$middle" ] && out="${out}${sep}${middle}"
[ -n "$right" ]  && out="${out}${sep}${right}"

printf "%s" "$out"
