# Omarchy Dots — Omarchy setup

Custom plugin and configuration backup for [Omarchy](https://omarchy.org/)
(Arch + Hyprland). This repo reproduces the status bar, notification / OSD
daemons, power widget, persistent night light, automation hooks, and the
**Breeze Dark** theme that are installed on the author's machine — so the
whole setup can be restored onto a fresh Omarchy system with one command.

## Contents

```
├── install.sh                        One-command restore script
├── plugins/
│   ├── sarath.nightlight/            Bar widget: persistent night light control
│   ├── sarath.notifications/         Service: notification daemon (clone of omarchy.notifications)
│   ├── sarath.osd/                   Panel: on-screen display (clone of omarchy.osd)
│   └── sarath.power/                 Bar widget: battery + power profile panel (clone of omarchy.power)
├── shell.json                        Bar layout, widget config, plugin enablement, idle/lock
├── shell.toml                        Shell settings (font base size)
├── hooks/
│   ├── font-set.d/system-wide-font.sh     Apply chosen font to GTK/Qt/KDE
│   ├── post-boot.d/login-sound.sh         Play login jingle after the audio server is up
│   ├── post-boot.d/nightlight.sh          Re-apply persisted night light state at login
│   └── post-update.d/                     One-time setup invitations (agent, fingerprint, voxtype)
├── theme/
│   ├── colors.toml                   Breeze Dark color palette
│   └── icons.theme                   Icon theme used by Breeze Dark
├── extensions/omarchy-menu.jsonc     Custom entries in the Omarchy launcher menu
├── branding/                         about text + custom screensaver art
└── defaults/agent                    Default coding agent (opencode)
```

## Requirements

- A freshly installed Omarchy system (Arch + Hyprland), booted to a desktop.
- `git`, and a working graphical/desktop session (the install applies the
  theme and restarts the shell).

## Quick start

Clone this repo and run the restore script on the new machine:

```bash
git clone https://github.com/<your-user>/omarchy-dots.git
cd omarchy-dots
./install.sh            # previews, then asks for confirmation
# or: ./install.sh --yes
```

The script:

1. **Backs up** anything it touches in `~/.config/omarchy/` to
   `~/.config/omarchy/.backups/<timestamp>/`.
2. Installs the four plugins into `~/.config/omarchy/plugins/`.
3. Restores `shell.json` (bar layout + widget settings), `shell.toml`,
   the hooks, the `Breeze Dark` theme, the extended menu, branding, and the
   default agent.
4. Rescans plugins, restarts the shell, applies the theme, and re-applies
   the night light's saved state.

> The plugins are also real Omarchy plugins: you can inspect them with
> `omarchy plugin list`, remove them with `omarchy plugin remove`,
> validate them with `omarchy plugin validate`, and the shell hot-reloads
> edits made under `~/.config/omarchy/plugins/`.

## What you get

### Bar layout (from `shell.json`)

- **Left:** Omarchy menu, workspaces
- **Center:** indicators, clock (`dddd h:mm AP` / `W-ww` alternate format,
  vertical `HH—mm`), keyboard layout, weather, system-update
- **Right:** system tray, agents, bluetooth, network, audio,
  `sarath.nightlight` (default warmth 4010 K), monitor, `sarath.power`
  (show percentage)
- **Position:** top, transparent; clock is the center anchor
- **Idle:** screensaver after 150 s, lock after 300 s

### Plugins

| Plugin | Kind | Purpose |
|--------|------|---------|
| `sarath.nightlight` | bar-widget | Persistent blue-light filter: manual on/off + warmth slider that survive reboots (writes `~/.config/hypr/hyprsunset.conf`) |
| `sarath.notifications` | service | Notification daemon fork of `omarchy.notifications` (popups, DND, history, custom `Service.qml`) |
| `sarath.osd` | panel | Volume / brightness / status overlay fork of `omarchy.osd` |
| `sarath.power` | bar-widget | Battery, power profile, and system stats panel with charge-limit script |

The originals (`omarchy.notifications`, `omarchy.osd`) are disabled in
`shell.json`; the `sarath.*` forks replace them.

### Hooks

| Hook | When |
|------|------|
| `font-set.d/system-wide-font.sh` | Every font change — pushes the font to GTK, Qt, and KDE |
| `post-boot.d/login-sound.sh` | Desktop start — login jingle (waits for the audio server) |
| `post-boot.d/nightlight.sh` | Desktop start — re-applies the persisted night light state |
| `post-update.d/install-voxtype.hook` | After `omarchy update` — invite to install dictation |
| `post-update.d/setup-agent.hook` | After `omarchy update` — invite to set a default agent |
| `post-update.d/setup-fingerprint.hook` | After `omarchy update` — invite to enroll the fingerprint reader |

### Theme

`Breeze Dark` — a dark KDE Breeze-color-inspired theme with a custom
`colors.toml` and the `Breeze-dark` icon set. After install it is applied
via `omarchy theme set "Breeze Dark"` and shows up in the theme switcher.

## After installing

- **Backgrounds are intentionally not in this repo.** The custom wallpaper
  collections live under `~/.config/omarchy/backgrounds/` (≈75 MB of
  images). Copy them across manually if you want them, and the theme's own
  background folder is `~/.config/omarchy/themes/breeze-dark/backgrounds/`
  (drop images there, then `omarchy theme bg set <image>`).
- **A half-finished "phone mic" experiment** (`sarath.phone-mic`) was left
  behind as a disabled backup and is not tracked.
- Secrets: none of these files contain credentials. If you add anything
  that might, keep it out of the repo.

## Updating the repo after changing something

```bash
git add -A
git commit -m "Describe the change"
git push
```

On the other machine, refresh with:

```bash
cd omarchy-dots && git pull && ./install.sh --yes
```

## Install vs. `omarchy plugin add`

`omarchy plugin add <git-url>` installs a *single* plugin repo directly into
`~/.config/omarchy/plugins/`. This repo instead ships the plugins as plain
folders so one clone restores the entire setup (plugins **and** bar layout,
hooks, theme) in a single step. The two approaches are interchangeable for
the plugin portions if you ever want to publish a single plugin on its own.
