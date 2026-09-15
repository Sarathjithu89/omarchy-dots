#!/bin/bash

# font-set hook: apply the chosen font system-wide (GTK, Qt, KDE), so a single
# font change in omarchy settings behaves like KDE's global font setting.
# Omarchy already handles terminals, the shell bar, and the fontconfig
# `monospace` alias; this hook covers the remaining toolkits.

FONT_NAME="${1:-}"
[[ -z $FONT_NAME ]] && exit 0

# Keep the current UI size if one is set, otherwise default to 10.
SIZE="$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null | grep -oE '[0-9]+$' | head -1)"
[[ $SIZE ]] || SIZE=10

# Escape characters special to sed replacement (& and backslash).
FONT_ESC="$(printf '%s' "$FONT_NAME" | sed 's/[\\&]/\\&/g')"

# GTK/GNOME Settings daemon.
gsettings set org.gnome.desktop.interface font-name "$FONT_NAME $SIZE" 2>/dev/null
gsettings set org.gnome.desktop.interface document-font-name "$FONT_NAME $SIZE" 2>/dev/null
gsettings set org.gnome.desktop.interface monospace-font-name "$FONT_NAME $SIZE" 2>/dev/null
gsettings set org.gnome.desktop.interface legacy-font-name "$FONT_NAME $SIZE" 2>/dev/null

# GTK settings files (gtk-3.0 / gtk-4.0).
for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
  [[ -f $f ]] || continue
  sed -i "s/^gtk-font-name.*/gtk-font-name = $FONT_ESC $SIZE/" "$f"
done

# Qt (qt6ct + qt5ct).
for f in "$HOME/.config/qt6ct/qt6ct.conf" "$HOME/.config/qt5ct/qt5ct.conf"; do
  [[ -f $f ]] || continue
  sed -i "s/^fixed=\".*\"/fixed=\"$FONT_ESC $SIZE\"/; s/^general=\".*\"/general=\"$FONT_ESC $SIZE\"/" "$f"
done

# KDE framework apps (Dolphin, etc.) via kdeglobals.
for f in "$HOME/.config/kdeglobals"; do
  [[ -f $f ]] || continue
  sed -i "s/^font=.*/font=$FONT_ESC,$SIZE,-1,5,50,0,0,0,0,0/" "$f"
  sed -i "s/^monospaceFont=.*/monospaceFont=$FONT_ESC,$SIZE,-1,5,50,0,0,0,0,0/" "$f"
done

exit 0