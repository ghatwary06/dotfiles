source /usr/share/cachyos-fish-config/cachyos-config.fish

# fastfetch does not reflow — it renders one fixed width and wraps into its own
# logo if the terminal is narrower. So pick the layout by actual column count:
#   >=80 cols (half-width niri column or wider) -> full layout, ~75 cols
#   <80 cols (third-width column, split panes)  -> compact layout, ~41 cols
# This overrides the fish_greeting that cachyos-config.fish defines above.
function fish_greeting
    if test "$COLUMNS" -ge 80
        fastfetch
    else
        fastfetch -c ~/.config/fastfetch/compact.jsonc
    end
end

# `ff` re-runs the greeting on demand, same width logic.
alias ff="fish_greeting"


# Added by Antigravity CLI installer
set -gx PATH "/home/mazen/.local/bin" $PATH
