show_ram() {
  local index icon color text module

  index=$1
  icon="$(get_tmux_option "@catppuccin_ram_icon" "")"
  color="$(get_tmux_option "@catppuccin_ram_color" "$thm_blue")"
  text="$(get_tmux_option "@catppuccin_ram_text" "#{ram_percentage}")"

  tmux set-option -g @ram_low_bg_color "$thm_yellow"    # background color when ram is low
  tmux set-option -g @ram_medium_bg_color "$thm_orange" # background color when ram is medium
  tmux set-option -g @ram_high_bg_color "$thm_red"      # background color when ram is high

  module=$(build_status_module "$index" "$icon" "$color" "$text")

  echo "$module"
}
