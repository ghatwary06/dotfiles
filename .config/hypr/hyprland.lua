-- #######################################################################################
-- HYPRLAND CONFIG — Lua format (Hyprland 0.56+)
--
-- Migrated 2026-08-04 from hyprland.conf. The old .conf files are left in place and
-- untouched: Hyprland only reads them if hyprland.lua is absent, so to roll back just
--     mv ~/.config/hypr/hyprland.lua ~/.config/hypr/hyprland.lua.off
-- and the legacy config takes over again on the next launch.
--
-- Ordering rule is unchanged from the .conf setup: rice.lua is require()d from the LAST
-- line of this file and deliberately overrides values set here.
-- #######################################################################################


------------------
---- MONITORS ----
------------------

-- External (ViewSonic) is the PRIMARY display at 0x0 (left).
-- Laptop panel sits to the RIGHT at 1920x0, so cursor-right crosses into it.
-- (~/.config/hypr/monitors.lua holds the same two monitors, written by nwg-displays.
--  It is not require()d — these inline calls are the ones that take effect, exactly as
--  the inline monitor= lines did before. Swap to require("monitors") if you'd rather let
--  nwg-displays own this.)
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@144.00", position = "0x0",    scale = 1 })
hl.monitor({ output = "eDP-1",    mode = "1920x1200@144",    position = "1920x0", scale = 1 })


---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "rofi -show drun" -- was: hyprlauncher (not installed/unconfigured). rofi config IS in these dotfiles.


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- Give Hyprland both GPUs, NVIDIA first = primary renderer. Rendering on the
-- dGPU avoids copying every frame across GPUs to reach HDMI-A-1 (which is wired
-- to the dGPU), so the external monitor doesn't stutter.
-- Trade-off: dGPU stays awake, so worse battery. Comment out when on the road.
--
-- The card numbers are RESOLVED FRESH AT EVERY LAUNCH from the PCI addresses,
-- because /dev/dri/cardN is assigned by driver probe order and is NOT stable:
-- the 2026-08-02 kernel upgrade (linux-cachyos 7.1.4 -> 7.1.5) reshuffled it
-- from nvidia=card2 to nvidia=card0. The old hardcoded "card2:card1" then
-- silently resolved to Intel-only -- no error, HDMI-A-1 just never appeared and
-- kept displaying the greeter's last frame ("stuck on the login screen").
--
-- Resolved to REAL device nodes, not the /dev/dri/by-path symlinks: feeding
-- aquamarine the symlinks directly is the prime suspect for the 2026-08-06 hang
-- that black-screened both monitors. Real nodes are the form that worked for
-- months, so this keeps the proven input and only automates picking it.
local function drm_node(pci_addr, fallback)
    local ok, node = pcall(function()
        local p = io.popen("readlink -f /dev/dri/by-path/" .. pci_addr .. "-card 2>/dev/null")
        if not p then return nil end
        local out = p:read("*l")
        p:close()
        return out
    end)
    -- io.popen may be unavailable if Hyprland sandboxes the Lua runtime; pcall
    -- keeps that from taking the whole config down with it.
    if ok and type(node) == "string" and node:match("^/dev/dri/card%d+$") then
        return node
    end
    return fallback
end

local gpu_nvidia = drm_node("pci-0000:01:00.0", "/dev/dri/card0")
local gpu_intel  = drm_node("pci-0000:00:02.0", "/dev/dri/card1")
hl.env("AQ_DRM_DEVICES", gpu_nvidia .. ":" .. gpu_intel)
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

hl.env("GTK_THEME", "Adwaita:dark")
hl.env("XCURSOR_THEME", "macOS")
hl.env("QT_STYLE_OVERRIDE", "kvantum")


-----------------------
---- PERMISSIONS ------
-----------------------

-- hl.config({ ecosystem = { enforce_permissions = true } })
-- hl.permission("/usr/(bin|local/bin)/grim", "screencopy", "allow")
-- hl.permission("/usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland", "screencopy", "allow")
-- hl.permission("/usr/(bin|local/bin)/hyprpm", "plugin", "allow")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,

        border_size = 2,

        col = {
            active_border   = { colors = { "rgba(88C0D0ff)", "rgba(81A1C1ff)" }, angle = 45 },
            inactive_border = "rgba(3B4252ff)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding = 12,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },

        -- NOTE: the old .conf had TWO blur blocks (size 6/passes 3, then size 3/passes 1).
        -- Hyprland applied the last one, so size 6/passes 3 was already dead. Only the
        -- effective values survive here (behavior unchanged). Bump size/passes for heavier blur.
        blur = {
            enabled = true,
            size    = 3,
            passes  = 1,

            vibrancy = 0.1696,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true, -- You probably want this
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,    -- no anime mascot wallpapers
        disable_hyprland_logo   = true, -- no hyprland logo background -- we set our own wallpaper
    },
})

-- Curves, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },       { 1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },   { 0.75, 1 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },    { 0.1, 1 } } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 5,    bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })

-- "Smart gaps" / "No gaps when only" — uncomment all if you wish to use that.
-- hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
-- hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
-- hl.window_rule({ name = "no-gaps-wtv1", match = { float = false, workspace = "w[tv1]" }, border_size = 0, rounding = 0 })
-- hl.window_rule({ name = "no-gaps-f1",   match = { float = false, workspace = "f[1]" },   border_size = 0, rounding = 0 })


---------------
---- INPUT ----
---------------

hl.config({
    input = {
        -- Two layouts, Windows-style Alt+Shift to cycle between them.
        -- Order matters: the FIRST entry is what every keyboard starts on at
        -- login, so "us" stays first and Arabic is the thing you switch INTO.
        --
        -- The toggle is handled by XKB itself (grp:alt_shift_toggle), not by a
        -- Hyprland bind — so it cannot collide with anything in the keybind
        -- block below, and it works inside every client including XWayland.
        kb_layout  = "us,ara",
        kb_variant = "",
        kb_model   = "",
        kb_options = "grp:alt_shift_toggle",
        kb_rules   = "",

        follow_mouse = 1,

        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = false,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Example per-device config
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})


---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
-- hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))   -- REPLACED by Caelestia launcher (see caelestia.conf); SUPER+R is re-bound to rofi further down
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())            -- dwindle
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))      -- dwindle

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
-- Moved off SUPER+SHIFT+S (that collided with the screenshot bind and made the
-- window stick to the scratchpad, floating on top across all workspaces).
hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Laptop multimedia keys -> SwayOSD (small GNOME/Windows-style on-screen popup).
-- Falls back to wpctl/brightnessctl if swayosd isn't installed yet, so keys always work.
local el = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume raise 2>/dev/null || wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), el)
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("swayosd-client --output-volume lower 2>/dev/null || wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      el)
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle 2>/dev/null || wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), el)
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("swayosd-client --input-volume mute-toggle 2>/dev/null || wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), el)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("swayosd-client --brightness raise 2>/dev/null || brightnessctl -d nvidia_wmi_ec_backlight set +5%"), el)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower 2>/dev/null || brightnessctl -d nvidia_wmi_ec_backlight set 5%-"), el)

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- App / utility binds
hl.bind("SUPER + B",     hl.dsp.exec_cmd("librewolf"))
hl.bind("SUPER + Space", hl.dsp.exec_cmd("rofi -show drun"))
hl.bind("SUPER + R",     hl.dsp.exec_cmd("rofi -show drun"))
hl.bind("SUPER + F",     hl.dsp.window.fullscreen())
hl.bind("SUPER + W",     hl.dsp.exec_cmd("~/.config/rofi/wallpaper-menu.sh"))
hl.bind("SUPER + L",     hl.dsp.exec_cmd("hyprlock"))
hl.bind("SUPER + C",     hl.dsp.exec_cmd("code"))
-- Super+M restored to exit/shutdown (defined earlier in this file); was conflicting with spotify here.
hl.bind("SUPER + D",     hl.dsp.exec_cmd("spotify-launcher"))

-- Region screenshot -> copied to clipboard AND saved to ~/Pictures/Screenshots, with a notification.
-- Pressing Esc during selection cancels cleanly (won't clobber the clipboard).
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd('G="$(slurp)" && grim -g "$G" - | tee "$HOME/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png" | wl-copy && notify-send -a Screenshot "Screenshot copied to clipboard & saved"'))
-- Print = full-screen screenshot, copied + saved.
hl.bind("Print", hl.dsp.exec_cmd('grim - | tee "$HOME/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png" | wl-copy && notify-send -a Screenshot "Full screenshot copied to clipboard & saved"'))


--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- External (HDMI-A-1) is primary -> gets workspaces 1-5, default focus on 1.
-- Laptop (eDP-1) gets 6-10.
for i = 1, 10 do
    hl.workspace_rule({
        workspace = tostring(i),
        monitor   = i <= 5 and "HDMI-A-1" or "eDP-1",
        default   = (i == 1 or i == 6) or nil,
    })
end

-- Ignore maximize requests from all apps. You'll probably like this.
hl.window_rule({
    name  = "suppress-maximize-all",
    match = { class = ".*" },

    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name  = "nofocus-empty-xwayland",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Hyprland-run windowrule
hl.window_rule({
    name  = "hyprland-run-float",
    match = { class = "hyprland-run" },

    float = true,
})

hl.window_rule({
    name  = "hyprland-run-move",
    match = { class = "hyprland-run" },

    move = "20 100%-120",
})


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar &> /dev/null &")
    hl.exec_cmd("nm-applet")
    -- Wallpaper daemon. The installed package is `awww` (a swww fork in the terra
    -- repo; it obsoletes swww). Binaries: awww-daemon + `awww img <path>`.
    hl.exec_cmd("awww-daemon &> /dev/null & disown")
    -- Load the last-chosen wallpaper. The path lives in ~/.config/hypr/current-wallpaper,
    -- which the Super+W picker (rofi) updates. Edit that file to change the default.
    hl.exec_cmd('sleep 1 && awww img "$(cat ~/.config/hypr/current-wallpaper)" &> /dev/null & disown')
    -- Small on-screen volume/brightness popup daemon (GNOME/Windows-style).
    hl.exec_cmd("swayosd-server")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("blueman-applet")

    -- DISABLED 2026-08-03: the Quickshell side panel (~/.config/quickshell/panel,
    -- started from rice.lua) is now the notification daemon, and only one process
    -- can own org.freedesktop.Notifications. To go back to dunst: uncomment this
    -- line and remove the `qs -c panel` exec in rice.lua.
    -- hl.exec_cmd("dunst")
end)

-- LIBREWOLF PRELOAD — REMOVED 2026-08-06. Do not reintroduce without reading this.
--
-- What it was: a one-shot 8s timer that launched LibreWolf onto a hidden
-- "preload" special workspace, so SUPER+B would open a window from the
-- already-warm process (measured 0.62s vs 1.36s) at a cost of ~750MB RAM held
-- permanently.
--
-- Why it went: the preloaded window was NOT hidden. It sat on top of every
-- workspace and could not be moved away, only killed with SUPER+Q. Special
-- workspaces overlay whatever workspace you switch to, so a revealed one follows
-- you everywhere.
--
-- What was actually wrong, established by live testing (not guesswork):
--   * `no_initial_focus` only stops the window taking focus. It does NOT stop
--     the special workspace from being REVEALED. That was the whole bug.
--   * `silent` is not a standalone rule effect ("unknown effect 'silent'"). It is
--     a modifier inside the workspace VALUE: "special:preload silent".
--   * That modifier is silently ignored by exec_cmd's rules table -- accepted,
--     no error, no effect. It only works via hl.window_rule.
--   * But a window_rule matching class librewolf catches EVERY LibreWolf window,
--     including the one SUPER+B opens -- verified: the second window landed on
--     special:preload too, i.e. the browser would open invisibly.
--   * There is no rule-removal function in the Lua API (only window_rule,
--     layer_rule, workspace_rule, unbind), so a "add rule, launch, drop rule"
--     sequence is not possible. Enumerate the API with:
--       hyprctl eval 'local f=io.open("/tmp/api","w") for k,v in pairs(hl) do
--                     f:write(k.."\n") end f:close()'
--
-- Keeping it hidden AND leaving SUPER+B normal would need event-driven code
-- (hl.on window-open + a silent move), which is a lot of machinery for ~0.7s.
-- SUPER+B (see the bind above) now just opens a normal tiled window.


-----------------------------
---- CAELESTIA SHELL (UI) ---
-----------------------------
-- Reverted to the traditional waybar + rofi setup.
-- Caelestia is left installed but NOT loaded. caelestia.conf is still legacy .conf and
-- would need its own migration before it can be require()d from here.


-----------------------------
---- RICE OVERRIDES (LAST) --
-----------------------------
-- Must stay the last line: theming, layer blur rules, cursor and the side
-- panel's autostart live there and deliberately override the defaults set
-- above. Existing keybinds and autostart entries are not touched by it.
require("rice")
