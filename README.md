# xed-terminal-plugin

Porting of the Gedit Terminal plugin to Xed

## Requirements

To interface with xed some libraries are needed:

* meson
* ninja-build
* valac
* libpeas-1.0-dev
* libpeas-gtk-1.0
* libglib2.0-dev
* libgtk-3-dev
* libgtksourceview-4-dev
* libxapp-dev
* vte-2.91
* xed-dev

To install on Ubuntu based distros:

    sudo apt install meson ninja-build build-essential valac cmake libgtk-3-dev libpeas-dev xed-dev libxapp-dev libgtksourceview-4-dev libgee-0.8-dev libjson-glib-dev libvte-2.91-dev

## Install

Run <code>./run.sh</code> to install with meson build system.

Or if you want to do it manually:

    meson setup build --prefix=/usr
    ninja -v -C build com.github.tudo75.xed-terminal-plugin-gmo
    ninja -v -C build
    ninja -v -C build install
    

Run <code>xed</code> and go to <i>Preferences->Plugin</i> and enable the <code>Terminal</code>. 
You can verify the plugin preferences pane and information with the bottom buttons.

## Uninstall

Run <code>./uninstall.sh</code> if you installed through meson system or if you would it manually:
    
    sudo ninja -v -C build uninstall
    sudo rm /usr/share/locale/en/LC_MESSAGES/com.github.tudo75.xed-terminal-plugin.mo
    sudo rm /usr/share/locale/it/LC_MESSAGES/com.github.tudo75.xed-terminal-plugin.mo

## Credits

Based on this Gedit Plugin

https://gitlab.gnome.org/GNOME/gedit-plugins/-/tree/master/plugins/terminal

## My Xed Plugins
* xed-terminal-plugin https://github.com/tudo75/xed-terminal-plugin
* xed-codecomment-plugin https://github.com/tudo75/xed-codecomment-plugin
* xed-sessionsaver-plugin https://github.com/tudo75/xed-sessionsaver-plugin
* xed-restore-tabs-plugin https://github.com/tudo75/xed-restore-tabs-plugin
* xed-plantuml-plugin https://github.com/tudo75/xed-plantuml-plugin 
