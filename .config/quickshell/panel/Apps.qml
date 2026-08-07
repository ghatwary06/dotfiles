pragma Singleton

import Quickshell
import QtQuick

// ===========================================================================
//  Window-class -> icon + colour. Single source of truth for the workspace
//  pills and the running-apps taskbar in BarStrip.qml.
//
//  Glyphs are declared as CODEPOINTS and built with String.fromCodePoint at
//  runtime. That is deliberate: literal astral-plane characters have been
//  silently dropped to empty strings on write before, producing blank icons
//  with no error anywhere. A number cannot be mangled.
//
//  Colours are desaturated brand tones — enough to identify an app instantly,
//  muted enough that a full taskbar doesn't turn into a toybox.
// ===========================================================================
Singleton {
    id: root

    function g(cp) {
        return String.fromCodePoint(cp);
    }

    readonly property var rules: [
        {
            re: /^kitty$/i,
            cp: 0xF018D,
            c: "#A3BE8C"
        },
        {
            re: /^(alacritty|foot|wezterm|org\.wezfurlong\.wezterm)$/i,
            cp: 0xF089B,
            c: "#A3BE8C"
        },
        {
            re: /^librewolf$/i,
            cp: 0xF059F,
            c: "#88C0D0"
        },
        {
            re: /^(firefox|zen|navigator)$/i,
            cp: 0xF0239,
            c: "#D08770"
        },
        {
            re: /^(chromium|google-chrome|brave-browser)$/i,
            cp: 0xF02AF,
            c: "#81A1C1"
        },
        {
            re: /^(code|code-oss|vscodium|code-url-handler)$/i,
            cp: 0xF0A1E,
            c: "#88C0D0"
        },
        {
            re: /^jetbrains-/i,
            cp: 0xF0862,
            c: "#B48EAD"
        },
        {
            re: /^spotify$/i,
            cp: 0xF0AA5,
            c: "#5fbd72"
        },
        {
            re: /^(org\.kde\.dolphin|dolphin|thunar|nemo|nautilus|pcmanfm.*)$/i,
            cp: 0xF024B,
            c: "#5aa3c9"
        },
        {
            re: /^(discord|vesktop|webcord|armcord)$/i,
            cp: 0xF066F,
            c: "#7b83db"
        },
        {
            re: /^steam$/i,
            cp: 0xF04D3,
            c: "#9aa8b5"
        },
        {
            re: /^(steam_app_.*|.*\.exe)$/i,
            cp: 0xF0EB5,
            c: "#EBCB8B"
        },
        {
            re: /^(lutris|heroic|net\.lutris\.Lutris)$/i,
            cp: 0xF0296,
            c: "#EBCB8B"
        },
        {
            re: /^(obs|com\.obsproject\.Studio)$/i,
            cp: 0xF040C,
            c: "#BF616A"
        },
        {
            re: /^(mpv|vlc|io\.github\.celluloid)$/i,
            cp: 0xF0567,
            c: "#D08770"
        },
        {
            re: /^gimp/i,
            cp: 0xF02E9,
            c: "#A3BE8C"
        },
        {
            re: /^(org\.kde\.okular|evince|zathura)$/i,
            cp: 0xF0219,
            c: "#b0b6bd"
        },
        {
            re: /^(soffice|libreoffice).*/i,
            cp: 0xF0219,
            c: "#7fa3c9"
        },
        {
            re: /pavucontrol/i,
            cp: 0xF057E,
            c: "#5E81AC"
        },
        {
            re: /^(blueman-manager|\.blueman-manager-wrapped)$/i,
            cp: 0xF00AF,
            c: "#81A1C1"
        },
        {
            re: /^(org\.telegram\.desktop|signal|signal-desktop)$/i,
            cp: 0xF0361,
            c: "#88C0D0"
        },
        {
            re: /^(virt-manager|VirtualBox.*)$/i,
            cp: 0xF08B9,
            c: "#9a8fc9"
        },
        {
            re: /^(systemsettings|.*settings.*)$/i,
            cp: 0xF0493,
            c: "#9aa2ab"
        },
        {
            re: /^(rofi|fuzzel)$/i,
            cp: 0xF0349,
            c: "#5E81AC"
        },
        {
            re: /^(org\.kde\.gwenview|imv|feh|loupe)$/i,
            cp: 0xF02E9,
            c: "#A3BE8C"
        },
        {
            re: /^(thunderbird|org\.gnome\.Evolution)$/i,
            cp: 0xF01F0,
            c: "#81A1C1"
        }
    ]

    readonly property int fallbackCp: 0xF08C6
    readonly property string fallbackColor: "#616E88"

    function _match(cls) {
        if (!cls || cls.length === 0)
            return null;

        for (const r of rules) {
            if (r.re.test(cls))
                return r;
        }

        // Second pass against the last dot-segment. Plenty of apps report a
        // reverse-DNS class ("org.pulseaudio.pavucontrol", "org.gnome.Loupe")
        // where only the tail is meaningful; without this they all silently
        // collapse to the grey generic icon.
        const tail = cls.split(".").pop();
        if (tail && tail !== cls) {
            for (const r of rules) {
                if (r.re.test(tail))
                    return r;
            }
        }
        return null;
    }

    function iconFor(cls) {
        const r = _match(cls);
        return g(r ? r.cp : fallbackCp);
    }

    function colorFor(cls) {
        const r = _match(cls);
        return r ? r.c : fallbackColor;
    }

    // Human-ish label for tooltips: "org.kde.dolphin" -> "dolphin".
    function labelFor(cls) {
        if (!cls || cls.length === 0)
            return "window";
        const parts = cls.split(".");
        return parts[parts.length - 1];
    }

    // -- real application icons ---------------------------------------------
    // Returns a resolved icon URL for a window class, or "" if the icon theme
    // has nothing — in which case the caller falls back to the glyph above.
    //
    // Window classes come in several shapes ("spotify", "org.kde.dolphin",
    // "Alacritty"), and the matching icon may be named after any of them, so
    // try the desktop entry first and then a series of name variants.
    //
    // NOTE: this only resolves if the process has an icon theme, which comes
    // from QT_QPA_PLATFORMTHEME=kde (set in rice.conf) reading Papirus-Dark out
    // of kdeglobals. Without it Qt falls back to hicolor and half the icons —
    // spotify, code, obs, telegram — silently come back empty.
    property var _iconCache: ({})

    function iconSource(cls) {
        if (!cls || cls.length === 0)
            return "";
        if (_iconCache[cls] !== undefined)
            return _iconCache[cls];

        const tail = cls.split(".").pop();
        const candidates = [cls, cls.toLowerCase(), tail, tail.toLowerCase()];

        // The desktop entry knows the canonical icon name (code -> vscode,
        // spotify -> spotify-launcher), so prefer it when the index has it.
        try {
            const entry = DesktopEntries.heuristicLookup(cls);
            if (entry && entry.icon)
                candidates.unshift(entry.icon);
        } catch (e) {}

        let found = "";
        for (const c of candidates) {
            if (!c || c.length === 0)
                continue;
            const p = Quickshell.iconPath(c, true);
            if (p && p.length > 0) {
                found = p;
                break;
            }
        }

        _iconCache[cls] = found;
        return found;
    }
}
