<img src="https://raw.githubusercontent.com/cybrcore/cybrcore/refs/heads/main/assets/repo-banners/cybr-btop-banner-top.png"/>

# Showcase
<img src="https://raw.githubusercontent.com/cybrcore/cybrcore/refs/heads/main/assets/showcase/cybr-btop.png"/>

# Steps
## 0. Before you start
- Make sure [Geist Mono Nerd Font](https://www.nerdfonts.com/font-downloads) is installed, you can do that from terminal with:
```bash
curl -L https://github.com/ryanoasis/nerd-fonts/releases/latest/download/GeistMono.zip -o GeistMono.zip
mkdir -p ~/.local/share/fonts
unzip GeistMono.zip -d ~/.local/share/fonts/GeistMono
fc-cache -fv
```
- Make sure kitty is installed: `sudo pacman -S kitty` and [cybrcore theme](https://github.com/cybrcore/cybr-kitty) is applied
- Make sure btop is installed: `sudo pacman -S btop`
- See [Installation Guide](https://github.com/cybrcore/cybrdots/blob/main/INSTALL.md) if you're coming from [cybr-hyprland](https://github.com/cybrcore/cybr-hyprland) and haven't set up prerequisites yet
- [btop Github](https://github.com/aristocratos/btop)

## 1. Create theme folder and file
```sh
mkdir -p ~/.config/btop/themes
$EDITOR ~/.config/btop/themes/cybrcore.theme
```

## 2. Insert [cybrcore theme](../btop/cybrcore.theme)

## 3. Apply theme
```sh
btop

# Press ESC -> Options
# Select Color theme, then select cybrcore with left/right arrow keys
# You can exit btop by pressing Q
```
