show_mem-cpu-load() {
  local index icon color text module

  index=$1
  icon="$(get_tmux_option "@catppuccin_mem-cpu-load_icon" "󰊚")"
  color="$(get_tmux_option "@catppuccin_mem-cpu-load_color" "$thm_blue")"
  text="$(get_tmux_option "@catppuccin_mem-cpu-load_text" "#($TMUX_PLUGIN_MANAGER_PATH/tmux-mem-cpu-load/tmux-mem-cpu-load)")"

  module=$(build_status_module "$index" "$icon" "$color" "$text")

  echo "$module"
}
