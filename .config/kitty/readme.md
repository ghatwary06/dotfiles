<img src="https://raw.githubusercontent.com/cybrcore/cybrcore/refs/heads/main/assets/repo-banners/cybr-kitty-banner-top.png"/>

# Showcase
<img src="https://raw.githubusercontent.com/cybrcore/cybrcore/refs/heads/main/assets/showcase/cybr-kitty.png"/>

# Steps
## 0. Before you start
- Make sure [Geist Mono Nerd Font](https://www.nerdfonts.com/font-downloads) is installed, you can do that from terminal with:
```bash
curl -L https://github.com/ryanoasis/nerd-fonts/releases/latest/download/GeistMono.zip -o GeistMono.zip
mkdir -p ~/.local/share/fonts
unzip GeistMono.zip -d ~/.local/share/fonts/GeistMono
fc-cache -fv
```
- Make sure kitty is installed: `sudo pacman -S kitty`
- See [Installation Guide](https://github.com/cybrcore/cybrdots/blob/main/INSTALL.md) if you're coming from [cybr-hyprland](https://github.com/cybrcore/cybr-hyprland) and haven't set up prerequisites yet
- [kitty Github](https://github.com/kovidgoyal/kitty) | [Arch wiki](https://wiki.archlinux.org/title/Kitty)

## 1. Create theme folder and file
```sh
mkdir -p ~/.config/kitty/themes
$EDITOR ~/.config/kitty/themes/cybrcore.conf
```
## 2. Insert [cybrcore theme](../kitty/cybrcore.conf)
```sh
$EDITOR ~/.config/kitty/themes/cybrcore.conf
```
## 3. Restart kitty and apply theme
```sh
pkill kitty && include themes/cybrcore.conf
```