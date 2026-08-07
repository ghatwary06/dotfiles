<img src="https://raw.githubusercontent.com/cybrcore/cybrcore/refs/heads/main/assets/repo-banners/cybr-swaync-banner-top.png"/>

# Showcase
<img src="https://raw.githubusercontent.com/cybrcore/cybrcore/refs/heads/main/assets/showcase/cybr-swaync.png"/>
<p align="center">
  <em>swaync ↗ (left to right: floating notifications; control center; control center list )</em>
</p>

# Steps
## 0. Before you start
- Make sure [Geist Mono Nerd Font](https://www.nerdfonts.com/font-downloads) is installed, you can do that from terminal with:
```bash
curl -L https://github.com/ryanoasis/nerd-fonts/releases/latest/download/GeistMono.zip -o GeistMono.zip
mkdir -p ~/.local/share/fonts
unzip GeistMono.zip -d ~/.local/share/fonts/GeistMono
fc-cache -fv
```
- Make sure hyprland is installed: `sudo pacman -S hyprland` with [cybrcore theme](https://github.com/cybrcore/cybr-hyprland) applied
- Make sure swaync is installed: `sudo pacman -S kitty`
- See [Installation Guide](https://github.com/cybrcore/cybrdots/blob/main/INSTALL.md) if you're coming from [cybrdots](https://github.com/cybrcore/cybrdots) and haven't set up prerequisites yet
- [swaync Github](https://github.com/ErikReider/SwayNotificationCenter)

## 1. Insert [config.json](../swaync/config.json)
```sh
$EDITOR ~/.config/swaync/config.json
```
## 2. Insert [style.css](../swaync/style.css)
```sh
$EDITOR ~/.config/swaync/style.css
```
## 3. Reload swaync client
```shell
swaync-client -R && swaync-client -rs
```