# dotfiles

My personal Arch Linux setup built around Hyprland. Took a while to get everything working the way I wanted, but here it is.

## what's in here

- **Window Manager** — Hyprland
- **Bar** — Waybar
- **Terminal** — Kitty
- **Shell** — Zsh + Oh My Zsh
- **Launcher** — Rofi
- **Notifications** — Dunst
- **Fetch** — Fastfetch
- **Theme** — Catppuccin Mocha
- **Font** — JetBrains Mono Nerd Font

## preview

![setup](screenshot-20260428-234600.png)

## installation

```bash
git clone https://github.com/ghatwary06/dotfiles.git
cd dotfiles
cp -r .config/* ~/.config/
```

> Back up your existing configs before doing this.

### fonts

The setup relies on **JetBrains Mono Nerd Font** for icons in Kitty, Waybar, Fastfetch and Rofi. Install it into your user font directory:

```bash
mkdir -p ~/.local/share/fonts/JetBrainsMonoNerdFont
curl -fLo /tmp/JetBrainsMono.tar.xz \
  https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
tar -xf /tmp/JetBrainsMono.tar.xz -C ~/.local/share/fonts/JetBrainsMonoNerdFont
fc-cache -f
```

## notes

NVIDIA setup included — configured for hybrid Intel + NVIDIA (RTX 4050). May need tweaking for other GPUs.
