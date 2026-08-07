-- ###########################################################################
--  RICE — Nord                                                [Lua format]
--  require()d from the LAST line of hyprland.lua, so everything here
--  deliberately overrides values set earlier in that file (later hl.config()
--  calls win, exactly as the last `source =` did in the .conf setup).
--
--  Companion configs:
--    ~/.config/waybar/{config.jsonc,style.css,colors.css}   the bar
--    ~/.config/quickshell/panel/                            the side panel
--    ~/.config/rofi/powermenu.{sh,rasi}                     the power menu
--
--  Palette (keep in sync with waybar/colors.css and quickshell/panel/Theme.qml):
--    bg0 #2E3440 · bg1 #3B4252 · bdr #4C566A · fg #D8DEE9 · accent #88C0D0 (nord8 cyan)
-- ###########################################################################


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 4,
        gaps_out = 8,

        -- Thin hairline instead of the previous 2px gradient.
        border_size = 1,

        col = {
            active_border   = "rgba(88C0D0b3)",
            inactive_border = "rgba(4C566Aff)",
        },

        resize_on_border = true,
    },

    decoration = {
        -- Small radius — rounded, but still reads as a rectangle.
        rounding = 6,

        -- WINDOW TRANSPARENCY — this is what makes blur visible on apps.
        -- Blur only affects translucent pixels, so with opacity at 1.0 the blur
        -- settings below did nothing for application windows; they only ever
        -- applied to the bar and panel. Pulling opacity slightly under 1 is what
        -- actually turns the frosted effect on.
        --
        -- Pushed well past "subtle" — the frosted effect should be obvious. The
        -- heavy blur below (size 8 / 3 passes) is what keeps text readable at this
        -- level; without it 0.84 would be a mess.
        -- If a particular app becomes hard to read, add it to the opaque-* window
        -- rules further down rather than raising these globally.
        active_opacity     = 0.84,
        inactive_opacity   = 0.72,
        fullscreen_opacity = 1.0,

        -- Heavy blur. new_optimizations keeps the cost sane at size 8/passes 3;
        -- xray blurs against the wallpaper rather than the windows behind, which
        -- stops stacked translucent windows turning into grey mush.
        blur = {
            enabled           = true,
            size              = 8,
            passes            = 3,
            new_optimizations = true,
            xray              = true,
            ignore_opacity    = true,
            noise             = 0.015,
            contrast          = 0.9,
            brightness        = 0.82,
            vibrancy          = 0.15,
            vibrancy_darkness = 0.4,
        },

        shadow = {
            enabled        = true,
            range          = 14,
            render_power   = 2,
            color          = "rgba(00000059)",
            color_inactive = "rgba(0000002e)",
        },
    },
})


----------------------
---- WINDOW RULES ----
----------------------

-- Transparency is great on terminals and file managers and actively bad on
-- anything whose content IS the point. These opt back out to fully opaque and
-- skip the blur pass entirely (which also saves the GPU some work).

hl.window_rule({
    name  = "opaque-media",
    match = { class = [[^(mpv|vlc|io\.github\.celluloid|org\.kde\.gwenview|imv|feh|loupe|com\.obsproject\.Studio|obs)$]] },

    opacity = 1.0,
    no_blur = true,
})

hl.window_rule({
    name = "opaque-games",
    -- Steam games report as steam_app_NNN; Proton/Wine titles end in .exe.
    match = { class = [[^(steam_app_.*|.*\.exe|gamescope|lutris|heroic)$]] },

    opacity = 1.0,
    no_blur = true,
})

-- Screenshot/colour-picker overlays must show true colours, not a tinted copy.
hl.window_rule({
    name  = "opaque-capture",
    match = { class = [[^(org\.kde\.spectacle|flameshot|slurp|hyprpicker)$]] },

    opacity = 1.0,
    no_blur = true,
})


---------------------
---- LAYER RULES ----
---------------------

-- Blur the shell surfaces so the bar and panel sit on frosted charcoal rather
-- than flat colour. `ignore_alpha` keeps fully transparent pixels (the margins
-- around the bar) from being blurred into a visible haze.

hl.layer_rule({
    name  = "blur-waybar",
    match = { namespace = "^waybar$" },

    blur         = true,
    ignore_alpha = 0.1,
})

hl.layer_rule({
    name  = "blur-sidepanel",
    match = { namespace = "^qs-sidepanel$" },

    blur         = true,
    ignore_alpha = 0.1,
    -- The panel animates itself in QML; letting Hyprland animate the layer
    -- surface as well double-animates it and looks sloppy.
    no_anim = true,
})

hl.layer_rule({
    name  = "blur-toast",
    match = { namespace = "^qs-toast$" },

    blur         = true,
    ignore_alpha = 0.1,
    no_anim      = true,
})

hl.layer_rule({
    name  = "blur-dash",
    match = { namespace = "^qs-dash$" },

    blur         = true,
    ignore_alpha = 0.1,
    no_anim      = true,
})

-- The left bar cluster (workspace pills + taskbar) is a TRANSPARENT overlay
-- sitting inside waybar's own slab, so it must NOT be blurred — waybar has
-- already blurred what is behind it, and blurring again just muddies the icons.
-- no_anim stops it sliding around when it hides for a fullscreen window.
hl.layer_rule({
    name  = "noanim-barstrip",
    match = { namespace = "^qs-bar$" },

    no_anim = true,
})

hl.layer_rule({
    name  = "blur-rofi",
    match = { namespace = "^rofi$" },

    blur         = true,
    ignore_alpha = 0.1,
})

hl.layer_rule({
    name  = "blur-swayosd",
    match = { namespace = "^swayosd$" },

    blur         = true,
    ignore_alpha = 0.1,
})


----------------
---- CURSOR ----
----------------

-- Black macOS-style cursor, from the `apple_cursor` package.
--   /usr/share/icons/macOS        <- black  (this one)
--   /usr/share/icons/macOS-White  <- white
--
-- Set in five places so nothing can quietly win over it:
--   1. hl.env below                   Hyprland + everything it launches
--   2. ~/.config/gtk-3.0/settings.ini GTK3
--   3. ~/.config/gtk-4.0/settings.ini GTK4
--   4. ~/.gtkrc-2.0                   GTK2   (was still on capitaine-cursors)
--   5. gsettings/dconf + hyprctl      running session, applied immediately
--
-- HYPRCURSOR_THEME is intentionally NOT set: there is no hyprcursor build of
-- this theme, and Hyprland falls back to XCursor when it is absent — which is
-- what we want. Both displays run at scale 1, so a 24px XCursor is already
-- pixel-exact and converting would only add an AUR dep (xcur2png).
--
-- CAVEAT that bit once (fixed 2026-08-06): "falls back to XCursor" only holds
-- while NO hyprcursor theme is installed. A stray hand-installed
-- ~/.local/share/icons/catppuccin-mocha-mauve-cursors (not owned by any
-- package) was the sole hyprcursor theme present, so Hyprland picked it up for
-- the first moments of every session — a Catppuccin cursor flash at login,
-- until the `hyprctl setcursor` below switched things back to XCursor. Nothing
-- in any config referenced it; every XCursor setting already said macOS. The
-- directory has been deleted. If a Catppuccin cursor ever reappears, look for a
-- theme shipping a hyprcursors/ subdir, not for a config line:
--   for d in ~/.local/share/icons/*/ /usr/share/icons/*/; do
--       [ -d "$d/hyprcursors" ] && echo "$d"; done
hl.env("XCURSOR_THEME", "macOS")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- qt5ct / qt6ct are not installed on this system (Qt styling goes through
-- Kvantum via QT_STYLE_OVERRIDE), and Qt/Wayland reads the cursor straight from
-- XCURSOR_THEME — so there is no Qt config file to keep in sync.


------------------
---- QT APPS -----
------------------

-- FIXES DOLPHIN'S UNREADABLE DARK-ON-DARK TEXT.
--
-- QT_STYLE_OVERRIDE=kvantum sets the widget STYLE (how things are drawn) but
-- not the PALETTE (what colour text is). With no platform theme, Qt fell back
-- to its built-in light palette — dark text — while Kvantum painted dark
-- backgrounds underneath it. Hence invisible labels in Dolphin's sidebar and
-- file names.
--
-- `kde` loads KDEPlasmaPlatformTheme6.so (from plasma-integration, already
-- installed because Plasma is on this system), which reads the colour scheme
-- out of ~/.config/kdeglobals — where a perfectly good dark scheme already
-- lived, unused.
hl.env("QT_QPA_PLATFORMTHEME", "kde")


-------------------
---- AUTOSTART ----
-------------------
-- Additive only. Every autostart entry already in hyprland.lua is untouched.

hl.on("hyprland.start", function()
    -- Side panel + notification daemon (Quickshell). This process owns
    -- org.freedesktop.Notifications, which is why `dunst` is commented out in
    -- hyprland.lua — two daemons cannot both hold that bus name.
    hl.exec_cmd("qs -c panel")

    -- Apply the cursor to the *current* session too, not just to newly launched
    -- clients, so it is correct the moment Hyprland comes up.
    hl.exec_cmd("hyprctl setcursor macOS 24")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme macOS")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 24")

    -- Push the cursor vars into the systemd user session + D-Bus activation
    -- environment, so apps started by a portal or a user unit (rather than by
    -- Hyprland directly) inherit them as well.
    hl.exec_cmd("dbus-update-activation-environment --systemd XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_SIZE")
end)


---------------------
---- EXTRA BINDS ----
---------------------
-- NEW binds only — nothing in hyprland.lua was edited, and none of these
-- collide with an existing one. Delete this block if you'd rather drive
-- everything from the bar.

hl.bind("SUPER + A",         hl.dsp.exec_cmd("qs -c panel ipc call panel tab system"))
hl.bind("SUPER + N",         hl.dsp.exec_cmd("qs -c panel ipc call panel tab notifications"))
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("qs -c panel ipc call notifs toggleDnd"))
hl.bind("SUPER + X",         hl.dsp.exec_cmd("~/.config/rofi/powermenu.sh"))
-- Centre dashboard: clock, calendar, weather and the media player w/ seek bar.
hl.bind("SUPER + G",         hl.dsp.exec_cmd("qs -c panel ipc call dash toggle"))
-- Delayed screenshot, for things that DISAPPEAR when you reach for the mouse.
-- SUPER+SHIFT+S (in hyprland.lua, untouched) runs slurp, which needs a
-- click-drag — that kills any hover state, open menu, or focus-sensitive
-- surface before it can ever be captured. This one takes no input: it counts
-- down, then grabs the whole focused monitor. Crop afterwards.
hl.bind("SUPER + ALT + S",   hl.dsp.exec_cmd("~/.config/hypr/screenshot-delayed.sh 5"))
-- Brightness for the EXTERNAL monitor. The bare XF86MonBrightness keys (bound
-- in hyprland.lua, untouched) only drive the laptop backlight — the external
-- panel has no backlight interface at all and can only be reached over DDC/CI.
-- Routed through the panel's IPC rather than calling ddcutil directly so these
-- share the debounce and the write lock: a held key would otherwise queue one
-- ~1s i2c transaction per repeat and back the bus right up.
local el = { locked = true, repeating = true }
hl.bind("SUPER + XF86MonBrightnessUp",   hl.dsp.exec_cmd("qs -c panel ipc call brightness step external 5"),  el)
hl.bind("SUPER + XF86MonBrightnessDown", hl.dsp.exec_cmd("qs -c panel ipc call brightness step external -5"), el)
