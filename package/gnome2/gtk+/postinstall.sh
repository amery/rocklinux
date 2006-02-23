
# update gnome2 icon cache files for gnome2 directories that
# contain index.theme files

echo "Gnome 2 icon cache files: running gtk-update-icon-cache..."

all_installed "gnome2/share/.*/index.theme$" |
while read IDX; do
	gtk-update-icon-cache "${IDX%index.theme}"
done

# update gnome2 icon cache files for icon directories
# that don't contain an index.theme file

all_touched "gnome2/share/.*/icons" |
while read FILE; do
	DIR="${FILE%icons/*}icons"
	[ ! -e "$DIR/index.theme" ] && 
		gtk-update-icon-cache --ignore-theme-index "$DIR"
done

all_touched "gnome2/share/icons/hicolor" |
while read FILE; do
	DIR="${FILE%hicolor/*}hicolor"
	[ ! -e "$DIR/index.theme" ] && 
		gtk-update-icon-cache --ignore-theme-index "$DIR"
done
