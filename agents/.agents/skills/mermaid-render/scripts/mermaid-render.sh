#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Global options
OPEN_VIEWER=""

usage() {
	cat <<EOF
Usage: $(basename "$0") [options] <input>

Render Mermaid diagrams in the terminal as ASCII art, inline images, or save to files.

Input:
  <file.mmd>           Read from file
  -                    Read from stdin
  "<mermaid code>"     Inline mermaid code

Options:
  -o, --output <file>  Output to file (determines format: .png, .svg, .pdf)
  -f, --format <fmt>   Output format: ascii, view, image, png, svg, pdf (default: ascii)
  -t, --theme <theme>  Theme for image output (default, dark, forest, neutral) - auto-detects if not set
  -w, --width <px>     Width for image output (default: 800)
  -c, --chafa <fmt>    Force chafa format: kitty, sixel, symbols, auto (default: auto)
  --open               Always open in external viewer
  --no-open            Disable auto-open in nested tmux (use symbols fallback)
  -h, --help           Show this help

Formats:
  ascii                ASCII art via graph-easy (readable text, flowcharts only)
  view                 Open in GUI image viewer (eog/xdg-open) - RECOMMENDED for readability
  image                Inline image in terminal (uses Kitty graphics when available)
  png/svg/pdf          Save to file (best quality)

Requirements:
  graph-easy           For ASCII output (sudo apt install libgraph-easy-perl)
  mmdc                 For image/file output (npm install -g @mermaid-js/mermaid-cli)
  chafa                For inline terminal images (sudo apt install chafa)

Examples:
  $(basename "$0") "graph LR; A[Start] --> B[End]"        # ASCII art (default)
  $(basename "$0") -f view "sequenceDiagram; A->>B: Hi"   # Open in GUI viewer (recommended)
  $(basename "$0") -f image "graph TD; A-->B"             # Inline image (Kitty graphics)
  $(basename "$0") -f png -o out.png diagram.mmd          # Save as PNG file
  cat diagram.mmd | $(basename "$0") -                    # Pipe input
EOF
}

is_inside_tmux() {
	[ -n "${TMUX:-}" ]
}

# Detect nested tmux client (e.g., sidekick.nvim creates separate session with xterm-256color,
# making kitty graphics go to wrong pty). Returns 0 if nested, 1 otherwise.
in_nested_tmux_client() {
	is_inside_tmux || return 1

	local our_tty our_termname
	our_tty=$(tmux display-message -p "#{client_tty}" 2>/dev/null || echo "")
	[[ -z "$our_tty" ]] && return 1
	our_termname=$(tmux display-message -p "#{client_termname}" 2>/dev/null || echo "")

	local main_client_info
	main_client_info=$(tmux list-clients -F "#{client_tty}:#{client_termname}" 2>/dev/null | grep -E "(kitty|ghostty)" | head -1 || echo "")

	if [[ -n "$main_client_info" ]]; then
		local main_tty="${main_client_info%%:*}"
		[[ "$main_tty" != "$our_tty" ]] && return 0
	fi

	if [[ "$our_termname" == "xterm-256color" ]]; then
		local outer_term
		outer_term=$(tmux show-environment -g TERM 2>/dev/null | cut -d= -f2 || echo "")
		[[ "$outer_term" == *"kitty"* || "$outer_term" == "xterm-ghostty" ]] && return 0
	fi

	return 1
}

# Detect system dark/light mode
is_dark_mode() {
	# 1. Check COLORFGBG env var (format: "fg;bg" where bg=0 is dark, bg=15 is light)
	if [[ -n "${COLORFGBG:-}" ]]; then
		local bg="${COLORFGBG##*;}"
		[[ "$bg" == "0" || "$bg" -lt 8 ]] && return 0
		return 1
	fi

	# 2. Check TERM_BACKGROUND if set (some terminals set this)
	if [[ "${TERM_BACKGROUND:-}" == "dark" ]]; then
		return 0
	elif [[ "${TERM_BACKGROUND:-}" == "light" ]]; then
		return 1
	fi

	# 3. Linux: Check GNOME/GTK color scheme via gsettings
	if command -v gsettings &>/dev/null; then
		local scheme
		scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
		[[ "$scheme" == "prefer-dark" ]] && return 0
		[[ "$scheme" == "prefer-light" || "$scheme" == "default" ]] && return 1
	fi

	# 4. Linux: Check KDE color scheme
	if [[ -f "${HOME}/.config/kdeglobals" ]]; then
		local kde_scheme
		kde_scheme=$(grep -i "ColorScheme=" "${HOME}/.config/kdeglobals" 2>/dev/null | head -1)
		[[ "$kde_scheme" == *"[Dd]ark"* ]] && return 0
		[[ "$kde_scheme" == *"[Ll]ight"* ]] && return 1
	fi

	# 5. macOS: Check AppleInterfaceStyle
	if command -v defaults &>/dev/null; then
		local apple_style
		apple_style=$(defaults read -g AppleInterfaceStyle 2>/dev/null)
		[[ "$apple_style" == "Dark" ]] && return 0
		[[ -z "$apple_style" ]] && return 1
	fi

	# 6. Default to dark (most developer terminals are dark)
	return 0
}

auto_theme() {
	is_dark_mode && echo "dark" || echo "neutral"
}

auto_background() {
	is_dark_mode && echo "black" || echo "white"
}

kitty_graphics_supported() {
	# Nested tmux clients can't display kitty graphics (output goes to wrong pty)
	in_nested_tmux_client && return 1

	[[ "${TERM:-}" == *"kitty"* ]] && return 0
	[[ "${TERM_PROGRAM:-}" == "ghostty" ]] && return 0
	[[ "${TERM:-}" == "xterm-ghostty" ]] && return 0
	[[ -n "${GHOSTTY_RESOURCES_DIR:-}" ]] && return 0
	[[ "${TERM_PROGRAM:-}" == "WezTerm" ]] && return 0

	if is_inside_tmux; then
		local ghostty_dir
		ghostty_dir=$(tmux show-environment -g GHOSTTY_RESOURCES_DIR 2>/dev/null | cut -d= -f2 || echo "")
		[[ -n "$ghostty_dir" && "$ghostty_dir" != "-GHOSTTY_RESOURCES_DIR" ]] && return 0

		local outer_term
		outer_term=$(tmux show-environment -g TERM 2>/dev/null | cut -d= -f2 || echo "")
		[[ "$outer_term" == *"kitty"* ]] && return 0
		[[ "$outer_term" == "xterm-ghostty" ]] && return 0
	fi

	return 1
}

detect_chafa_format() {
	if [ -n "${FORCE_CHAFA_FORMAT:-}" ]; then
		echo "$FORCE_CHAFA_FORMAT"
		return
	fi

	if ! command -v chafa &>/dev/null; then
		echo "none"
		return
	fi

	# Check for kitty graphics support (includes nested tmux detection)
	if kitty_graphics_supported; then
		echo "kitty"
		return
	fi

	local term_program="${TERM_PROGRAM:-}"
	local term="${TERM:-}"

	if [[ "$term" == *xterm* ]] || [[ "$term_program" == "mlterm" ]]; then
		echo "sixel"
		return
	fi

	echo "symbols"
}

# Open file in default viewer
open_file() {
	local file="$1"
	if command -v xdg-open &>/dev/null; then
		xdg-open "$file" &>/dev/null &
	elif command -v open &>/dev/null; then
		open "$file" &>/dev/null &
	elif command -v eog &>/dev/null; then
		eog "$file" &>/dev/null &
	elif command -v feh &>/dev/null; then
		feh "$file" &>/dev/null &
	else
		echo -e "${RED}Cannot open file: no viewer found (xdg-open/open/eog/feh)${NC}" >&2
		echo "File saved to: $file"
		return 1
	fi
}

# Setup tmux passthrough if needed
setup_tmux_passthrough() {
	if is_inside_tmux; then
		tmux set -p allow-passthrough on 2>/dev/null || true
	fi
}

get_mermaid_input() {
	local input="$1"
	if [ "$input" = "-" ]; then
		cat
	elif [ -f "$input" ]; then
		cat "$input"
	else
		echo "$input"
	fi
}

mermaid_to_dot() {
	local mermaid_code="$1"

	# Normalize: convert semicolon-separated to newlines
	mermaid_code=$(echo "$mermaid_code" | tr ';' '\n')

	# Determine direction
	local direction="TB"
	if echo "$mermaid_code" | grep -qiE "graph\s+LR|flowchart\s+LR"; then
		direction="LR"
	elif echo "$mermaid_code" | grep -qiE "graph\s+RL|flowchart\s+RL"; then
		direction="RL"
	elif echo "$mermaid_code" | grep -qiE "graph\s+BT|flowchart\s+BT"; then
		direction="BT"
	fi

	echo "digraph {"
	echo "  rankdir=$direction"
	echo "  node [shape=box]"

	# Track declared nodes to avoid duplicates
	declare -A declared_nodes

	echo "$mermaid_code" | grep -E '\-\->' | while IFS= read -r line; do
		[ -z "$line" ] && continue

		# Extract edge label if present: -->|label|
		local edge_label=""
		if [[ "$line" =~ \|([^|]+)\| ]]; then
			edge_label="${BASH_REMATCH[1]}"
			line=$(echo "$line" | sed 's/|[^|]*|//')
		fi

		# Split by arrow
		if [[ "$line" =~ (.+)--\>(.+) ]]; then
			local left="${BASH_REMATCH[1]}"
			local right="${BASH_REMATCH[2]}"

			# Trim whitespace
			left=$(echo "$left" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
			right=$(echo "$right" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

			# Parse left node
			local left_id left_label="" left_shape="box"
			left_id=$(echo "$left" | sed -E 's/^([A-Za-z0-9_]+).*/\1/')

			if [[ "$left" =~ \[\[([^\]]+)\]\] ]]; then
				left_label="${BASH_REMATCH[1]}"
				left_shape="box"
			elif [[ "$left" =~ \[([^\]]+)\] ]]; then
				left_label="${BASH_REMATCH[1]}"
				left_shape="box"
			elif [[ "$left" =~ \{([^\}]+)\} ]]; then
				left_label="${BASH_REMATCH[1]}"
				left_shape="diamond"
			elif [[ "$left" =~ \(\(([^\)]+)\)\) ]]; then
				left_label="${BASH_REMATCH[1]}"
				left_shape="circle"
			elif [[ "$left" =~ \(([^\)]+)\) ]]; then
				left_label="${BASH_REMATCH[1]}"
				left_shape="ellipse"
			fi

			# Parse right node
			local right_id right_label="" right_shape="box"
			right_id=$(echo "$right" | sed -E 's/^([A-Za-z0-9_]+).*/\1/')

			if [[ "$right" =~ \[\[([^\]]+)\]\] ]]; then
				right_label="${BASH_REMATCH[1]}"
				right_shape="box"
			elif [[ "$right" =~ \[([^\]]+)\] ]]; then
				right_label="${BASH_REMATCH[1]}"
				right_shape="box"
			elif [[ "$right" =~ \{([^\}]+)\} ]]; then
				right_label="${BASH_REMATCH[1]}"
				right_shape="diamond"
			elif [[ "$right" =~ \(\(([^\)]+)\)\) ]]; then
				right_label="${BASH_REMATCH[1]}"
				right_shape="circle"
			elif [[ "$right" =~ \(([^\)]+)\) ]]; then
				right_label="${BASH_REMATCH[1]}"
				right_shape="ellipse"
			fi

			# Output node definitions (only if has label)
			[ -n "$left_label" ] && echo "  $left_id [label=\"$left_label\" shape=$left_shape]"
			[ -n "$right_label" ] && echo "  $right_id [label=\"$right_label\" shape=$right_shape]"

			# Output edge
			if [ -n "$edge_label" ]; then
				echo "  $left_id -> $right_id [label=\"$edge_label\"]"
			else
				echo "  $left_id -> $right_id"
			fi
		fi
	done

	echo "}"
}

render_ascii() {
	local input="$1"
	local mermaid_code

	mermaid_code=$(get_mermaid_input "$input")

	# Check if it's a flowchart/graph (only type we can convert)
	if ! echo "$mermaid_code" | grep -qiE "^[[:space:]]*(graph|flowchart)"; then
		echo -e "${YELLOW}Warning: ASCII rendering only supports flowchart/graph diagrams${NC}" >&2
		echo -e "${YELLOW}Use -f image or -f view for other diagram types${NC}" >&2
		return 1
	fi

	if ! command -v graph-easy &>/dev/null; then
		echo -e "${RED}Error: graph-easy not found${NC}" >&2
		echo -e "${YELLOW}Install with: sudo apt install libgraph-easy-perl${NC}" >&2
		return 1
	fi

	local dot_code
	dot_code=$(mermaid_to_dot "$mermaid_code")

	echo "$dot_code" | graph-easy --from=dot 2>/dev/null || {
		echo -e "${RED}Error: Failed to render ASCII diagram${NC}" >&2
		echo -e "${YELLOW}DOT output for debugging:${NC}" >&2
		echo "$dot_code" >&2
		return 1
	}
}

render_mmdc() {
	local input="$1"
	local output="$2"
	local theme="$3"
	local width="$4"
	local temp_input=""

	# Auto-detect theme if not specified
	if [ -z "$theme" ] || [ "$theme" = "auto" ]; then
		theme=$(auto_theme)
	fi

	local bg
	bg=$(auto_background)

	if [ "$input" = "-" ]; then
		temp_input=$(mktemp --suffix=.mmd)
		cat >"$temp_input"
		input="$temp_input"
	elif [ ! -f "$input" ]; then
		temp_input=$(mktemp --suffix=.mmd)
		echo "$input" >"$temp_input"
		input="$temp_input"
	fi

	local mmdc_args=(-i "$input" -b "$bg")

	if [ -n "$output" ]; then
		mmdc_args+=(-o "$output")
	else
		local temp_output=$(mktemp --suffix=.svg)
		mmdc_args+=(-o "$temp_output")
	fi

	[ -n "$theme" ] && mmdc_args+=(-t "$theme")
	[ -n "$width" ] && mmdc_args+=(-w "$width")

	mmdc "${mmdc_args[@]}" 2>/dev/null
	local exit_code=$?

	[ -n "$temp_input" ] && rm -f "$temp_input"

	if [ $exit_code -eq 0 ]; then
		if [ -z "$output" ]; then
			echo -e "${GREEN}Rendered to: $temp_output${NC}"
		else
			echo -e "${GREEN}Rendered to: $output${NC}"
		fi
	fi

	return $exit_code
}

render_image_pipeline() {
	local input="$1"
	local theme="$2"
	local width="$3"
	local chafa_format="$4"
	local temp_input=""
	local temp_png=""

	if ! command -v chafa &>/dev/null; then
		echo -e "${RED}Error: chafa not found${NC}" >&2
		echo -e "${YELLOW}Install with: sudo apt install chafa${NC}" >&2
		exit 1
	fi

	# Auto-detect theme if not specified
	if [ -z "$theme" ] || [ "$theme" = "auto" ]; then
		theme=$(auto_theme)
	fi

	local bg
	bg=$(auto_background)

	if [ "$input" = "-" ]; then
		temp_input=$(mktemp --suffix=.mmd)
		cat >"$temp_input"
		input="$temp_input"
	elif [ ! -f "$input" ]; then
		temp_input=$(mktemp --suffix=.mmd)
		echo "$input" >"$temp_input"
		input="$temp_input"
	fi

	temp_png=$(mktemp --suffix=.png)

	local mmdc_args=(-i "$input" -o "$temp_png" -b "$bg")
	[ -n "$theme" ] && mmdc_args+=(-t "$theme")
	[ -n "$width" ] && mmdc_args+=(-w "$width")

	if ! mmdc "${mmdc_args[@]}" 2>/dev/null; then
		echo -e "${RED}Error: mmdc failed to render diagram${NC}" >&2
		[ -n "$temp_input" ] && rm -f "$temp_input"
		[ -f "$temp_png" ] && rm -f "$temp_png"
		return 1
	fi

	[ -n "$temp_input" ] && rm -f "$temp_input"

	if [ ! -f "$temp_png" ]; then
		echo -e "${RED}Error: mmdc did not produce output file${NC}" >&2
		return 1
	fi

	if [ "$chafa_format" = "auto" ]; then
		chafa_format=$(detect_chafa_format)
	fi

	# Check for nested tmux client - auto-open in viewer
	local is_nested=false
	in_nested_tmux_client && is_nested=true

	if [[ "$is_nested" == "true" && "$OPEN_VIEWER" != "false" ]]; then
		local persistent_file="/tmp/mermaid-diagram-$$.png"
		cp "$temp_png" "$persistent_file"
		rm -f "$temp_png"
		echo -e "${GREEN}Opening in viewer (nested tmux client detected)...${NC}"
		open_file "$persistent_file"
		return 0
	fi

	local chafa_args=()
	case "$chafa_format" in
	kitty)
		setup_tmux_passthrough
		chafa_args=(--format kitty --optimize 9)
		if is_inside_tmux; then
			chafa_args+=(--passthrough=tmux)
		fi
		;;
	sixel)
		chafa_args=(--format sixel)
		;;
	symbols | *)
		chafa_args=(--format symbols --symbols all)
		;;
	esac

	chafa "${chafa_args[@]}" "$temp_png"
	local exit_code=$?

	# If open requested, also open in viewer
	if [[ "$OPEN_VIEWER" == "true" ]]; then
		local persistent_file="/tmp/mermaid-diagram-$$.png"
		cp "$temp_png" "$persistent_file"
		open_file "$persistent_file"
	fi

	rm -f "$temp_png"

	return $exit_code
}

render_view() {
	local input="$1"
	local theme="$2"
	local width="$3"
	local temp_input=""
	local temp_png=""

	# Auto-detect theme if not specified
	if [ -z "$theme" ] || [ "$theme" = "auto" ]; then
		theme=$(auto_theme)
	fi

	local bg
	bg=$(auto_background)

	if [ "$input" = "-" ]; then
		temp_input=$(mktemp --suffix=.mmd)
		cat >"$temp_input"
		input="$temp_input"
	elif [ ! -f "$input" ]; then
		temp_input=$(mktemp --suffix=.mmd)
		echo "$input" >"$temp_input"
		input="$temp_input"
	fi

	temp_png=$(mktemp --suffix=.png)

	local mmdc_args=(-i "$input" -o "$temp_png" -b "$bg")
	[ -n "$theme" ] && mmdc_args+=(-t "$theme")
	[ -n "$width" ] && mmdc_args+=(-w "$width")

	if ! mmdc "${mmdc_args[@]}" 2>/dev/null; then
		echo -e "${RED}Error: mmdc failed to render diagram${NC}" >&2
		[ -n "$temp_input" ] && rm -f "$temp_input"
		[ -f "$temp_png" ] && rm -f "$temp_png"
		return 1
	fi

	[ -n "$temp_input" ] && rm -f "$temp_input"

	if [ ! -f "$temp_png" ]; then
		echo -e "${RED}Error: mmdc did not produce output file${NC}" >&2
		return 1
	fi

	echo -e "${GREEN}Opening in viewer...${NC}"
	open_file "$temp_png"

	# Keep file around for a bit for the viewer to load
	sleep 2
	rm -f "$temp_png"
}

check_dependencies() {
	local format="$1"

	case "$format" in
	ascii)
		if ! command -v graph-easy &>/dev/null; then
			echo -e "${RED}Error: graph-easy not found${NC}" >&2
			echo -e "${YELLOW}Install with: sudo apt install libgraph-easy-perl${NC}" >&2
			exit 1
		fi
		;;
	view | image | png | svg | pdf)
		if ! command -v mmdc &>/dev/null; then
			echo -e "${RED}Error: mmdc not found${NC}" >&2
			echo -e "${YELLOW}Install with: npm install -g @mermaid-js/mermaid-cli${NC}" >&2
			exit 1
		fi
		;;
	esac
}

main() {
	local input=""
	local output=""
	local format="ascii"
	local theme="auto"
	local width="800"
	local chafa_format="auto"

	while [[ $# -gt 0 ]]; do
		case $1 in
		-o | --output)
			output="$2"
			shift 2
			;;
		-f | --format)
			format="$2"
			shift 2
			;;
		-t | --theme)
			theme="$2"
			shift 2
			;;
		-w | --width)
			width="$2"
			shift 2
			;;
		-c | --chafa)
			chafa_format="$2"
			shift 2
			;;
		--open)
			OPEN_VIEWER=true
			shift
			;;
		--no-open)
			OPEN_VIEWER=false
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		-)
			input="-"
			shift
			;;
		-*)
			echo -e "${RED}Unknown option: $1${NC}" >&2
			usage
			exit 1
			;;
		*)
			input="$1"
			shift
			;;
		esac
	done

	if [ -z "$input" ]; then
		echo -e "${RED}Error: No input specified${NC}" >&2
		usage
		exit 1
	fi

	if [ -n "$output" ]; then
		case "$output" in
		*.png) format="png" ;;
		*.svg) format="svg" ;;
		*.pdf) format="pdf" ;;
		*.txt) format="ascii" ;;
		esac
	fi

	check_dependencies "$format"

	case "$format" in
	ascii)
		render_ascii "$input"
		;;
	view)
		render_view "$input" "$theme" "$width"
		;;
	image)
		render_image_pipeline "$input" "$theme" "$width" "$chafa_format"
		;;
	png | svg | pdf)
		render_mmdc "$input" "$output" "$theme" "$width"
		;;
	*)
		echo -e "${RED}Error: Unknown format '$format'${NC}" >&2
		exit 1
		;;
	esac
}

main "$@"
