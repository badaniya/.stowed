show_load() {
  local index icon color text module

  index=$1
  icon="$(get_tmux_option "@catppuccin_load_icon" "󰊚")"
  color="$(get_tmux_option "@catppuccin_load_color" "$thm_blue")"
  text="$(get_tmux_option "@catppuccin_load_text" "#(cat /proc/loadavg | awk '{print \"1m:\"\$1i\", 5m:\"\$2\", 15m:\"\$3}')")"

  module=$(build_status_module "$index" "$icon" "$color" "$text")

  echo "$module"
}
