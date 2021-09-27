/*
 * terminal.vala
 *
 * Copyright 2021 Nicola Tudino
 *
 * This file is part of xed-terminal-plugin.
 *
 * xed-terminal-plugin is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License.
 *
 * xed-terminal-plugin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with xed-terminal-plugin.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-only
 */


namespace TerminalPlugin {
    /*
    * Register plugin extension types
    */
    [CCode (cname="G_MODULE_EXPORT peas_register_types")]
    [ModuleInit]
    public void peas_register_types (TypeModule module) 
    {
        var objmodule = module as Peas.ObjectModule;

        // Register my plugin extension
        objmodule.register_extension_type (typeof (Xed.WindowActivatable), typeof (TerminalPlugin.TerminalWindow));
        // Register my config dialog
        objmodule.register_extension_type (typeof (PeasGtk.Configurable), typeof (TerminalPlugin.ConfigTerminal));
    }
    
    /*
    * WindowActivatable
    */
    public class TerminalWindow : Xed.WindowActivatable, Peas.ExtensionBase {
        
        private XedTerminalPanel panel;
        private string doc_path;

        public TerminalWindow () {
            GLib.Object ();
        }

        public Xed.Window window {
            owned get; construct;
        }

        public void activate () {
            print ("TerminalWindow activated\n");
            this.panel = new XedTerminalPanel ();
            this.panel.populate_popup.connect (this.on_panel_populate_popup);
            this.panel.show ();

            Xed.Panel bottom = this.window.get_bottom_panel ();
            /*
            int margin = 5;
            bottom.set_margin_top (margin);
            bottom.set_margin_bottom (margin);
            bottom.set_margin_start (margin);
            bottom.set_margin_end (margin);
            bottom.add_item (this.panel, _("Terminal"), "utilities-terminal");
            */
            Gtk.Notebook notebook = new Gtk.Notebook ();
            notebook.set_tab_pos (Gtk.PositionType.BOTTOM);
            notebook.append_page (this.panel, new Gtk.Label (_("Terminal")));
            bottom.add_item (notebook, _("Terminal"), "utilities-terminal");
        }

        public void deactivate () {
            print ("TerminalWindow deactivated\n");
            Xed.Panel bottom = this.window.get_bottom_panel ();
            bottom.remove_item (this.panel);
        }

        public void update_state () {
            print ("TerminalWindow update_state\n");
        }

        private void on_panel_populate_popup (XedTerminalPanel panel, Gtk.Menu menu) {
            menu.prepend (new Gtk.SeparatorMenuItem ());
            doc_path = this.get_active_document_directory ();
            Gtk.MenuItem item = new Gtk.MenuItem.with_mnemonic (_("C_hange Directory"));
            item.activate.connect (this.on_change_directory);
            item.set_sensitive (doc_path != "");
            menu.prepend (item);
        }

        private void on_change_directory (Gtk.MenuItem item) {
            doc_path = doc_path.replace ("\\", "\\\\").replace ("\"", "\\\"");
            this.panel.get_terminal ().feed_child(("cd \"%s\"\n").printf (doc_path).data);
            this.panel.get_terminal ().grab_focus();
        }

        private string get_active_document_directory () {
            Xed.Document doc = this.window.get_active_document ();
            if (doc != null) {
                GLib.File location = doc.get_file ().get_location ();
                if (location != null && location.has_uri_scheme ("file")) {
                    GLib.File directory = location.get_parent ();
                    return directory.get_path ();
                }
            }
            return "";
        }
    }

    public class XedTerminal : Vte.Terminal {
        
        private GLib.KeyFile profile_settings;
        private GLib.Pid child_pid;
        
        public XedTerminal () {
            this.set_size (this.get_column_count (), 5);
            this.set_size_request (200, 50);

            this.profile_settings = this.get_profile_settings ();
            
            this.reconfigure_vte ();
            
            try {
                this.spawn_sync (
                    Vte.PtyFlags.DEFAULT, 
                    null,
                    {Vte.get_user_shell ()}, 
                    null, 
                    GLib.SpawnFlags.SEARCH_PATH,
                    null,
                    out child_pid);
            } catch (GLib.Error e) {
                warning (e.message);
            }
        }

        private GLib.KeyFile get_profile_settings () {
            GLib.KeyFile keyfile = new GLib.KeyFile ();
            string file_path = GLib.Environment.get_user_config_dir () + "/xfce4/terminal/terminalrc";
            GLib.File user_file = GLib.File.new_for_path (file_path);
            if (!user_file.query_exists ()) {
                file_path = "/etc/xdg/xdg-default/Terminal/terminalrc";
            }
            try {
                keyfile.load_from_file (file_path, GLib.KeyFileFlags.NONE);
            } catch (GLib.Error e) {
                print ("Error loading KeyFile for settings: %s\n", e.message);
            }
            return keyfile;
        }

        private void reconfigure_vte () {
            //default values or system values
            string font = this.get_font ().to_string ();

            var context = this.get_style_context ();
            Gdk.RGBA fg = context.get_color (Gtk.StateFlags.NORMAL);
            Gdk.RGBA bg = context.get_background_color (Gtk.StateFlags.NORMAL);
            Gdk.RGBA[] palette = new Gdk.RGBA[16];
            bool use_theme_colors = false;
            var blink_mode = Vte.CursorBlinkMode.SYSTEM;
            this.set_cursor_shape (Vte.CursorShape.BLOCK);
            bool bell = false;
            this.set_allow_hyperlink (true);
            this.set_bold_is_bright (true);
            this.set_allow_bold (true);

            // get values from keyfile
            try{
                if (this.profile_settings.has_key ("Configuration", "FontName")) {
                    font = this.profile_settings.get_string ("Configuration", "FontName");
                }
                if (this.profile_settings.has_key ("Configuration", "ColorUseTheme")) {
                    use_theme_colors = (bool) this.profile_settings.get_string ("Configuration", "ColorUseTheme").down ();
                }
                if (!use_theme_colors) {
                    var fg_color = this.profile_settings.get_string ("Configuration", "ColorForeground");
                    if (fg_color != "") {
                        fg.parse (fg_color);
                    }
                    var bg_color = this.profile_settings.get_string ("Configuration", "ColorBackground");
                    if (bg_color != "") {
                        bg.parse (bg_color);
                    }
                }
                string[] palette_colors = this.profile_settings.get_string_list ("Configuration", "ColorPalette");
                if (palette_colors != null) {
                    for (int i = 0; i < palette_colors.length; i++) {
                        var rgba = Gdk.RGBA();
                        rgba.parse (palette_colors[i]);
                        palette[i] = rgba;
                    }
                }
                if (this.profile_settings.has_key ("Configuration", "MiscCursorBlinks")) {
                    bool blink = (bool) this.profile_settings.get_string ("Configuration", "MiscCursorBlinks").down ();
                    if (blink) {
                        blink_mode = Vte.CursorBlinkMode.ON;
                    } else {
                        blink_mode = Vte.CursorBlinkMode.OFF;
                    }
                }

                if (this.profile_settings.has_key ("Configuration", "MiscCursorShape")) {
                    string cursor_shape_setting = this.profile_settings.get_string ("Configuration", "MiscCursorShape");
                    switch (cursor_shape_setting) {
                        case "TERMINAL_CURSOR_SHAPE_BLOCK":
                            this.set_cursor_shape (Vte.CursorShape.BLOCK);
                            break;
                        case "TERMINAL_CURSOR_SHAPE_IBEAM":
                            this.set_cursor_shape (Vte.CursorShape.IBEAM);
                            break;
                        case "TERMINAL_CURSOR_SHAPE_UNDERLINE":
                            this.set_cursor_shape (Vte.CursorShape.UNDERLINE);
                            break;
                    }
                }
                if (this.profile_settings.has_key ("Configuration", "MiscBell")) {
                    bell = (bool) this.profile_settings.get_string ("Configuration", "MiscBell").down ();
                }
            } catch (GLib.KeyFileError e) {
                warning (e.message);
            }

            // set values taken from keyfile
            this.set_font (Pango.FontDescription.from_string (font));
            this.set_colors (fg, bg, palette);
            this.set_cursor_blink_mode (blink_mode);
            this.set_audible_bell (bell);
            this.set_scroll_on_keystroke (true);
            this.set_scroll_on_output (true);
            this.set_scrollback_lines (1000);
        }
    }

    struct Accels {
        public string name;
        public uint accel_key;
        public Gdk.ModifierType modifiers;
    }

    public class XedTerminalPanel : Gtk.ScrolledWindow {

        public signal void populate_popup (Gtk.Menu menu);

        private XedTerminal vte;
        private Accels[] accels;
        private string accel_base = "<Actions>/XedTerminalPlugin/";

        public XedTerminalPanel () {
            accels = 
            {
                {"copy-clipboard",
                Gdk.Key.C,
                Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK},
                {"paste-clipboard",
                Gdk.Key.V,
                Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK}
            };
            foreach (var accel in accels) {
                string path = accel_base + accel.name;
                Gtk.AccelKey key; 
                if (!Gtk.AccelMap.lookup_entry (path, out key)) {
                    Gtk.AccelMap.add_entry (path, accel.accel_key, accel.modifiers);
                }
            }
            
            this.add_terminal ();
        }

        private void add_terminal () {
            this.vte = new XedTerminal ();
            this.vte.show ();
            this.add (this.vte);

            this.vte.child_exited.connect(this.on_vte_child_exited);
            this.vte.key_press_event.connect(this.on_vte_key_press);
            this.vte.button_press_event.connect(this.on_vte_button_press);
            this.vte.popup_menu.connect (this.on_vte_popup_menu);
        }
        
        private void on_vte_child_exited (int status) {
            foreach (var child in this.get_children ()) {
                child.destroy ();
            }
            this.add_terminal ();
            this.vte.grab_focus ();
        }
        
        private bool on_vte_key_press (Gtk.Widget term, Gdk.EventKey event) {
            Gdk.ModifierType modifiers = event.state + Gtk.accelerator_get_default_mod_mask ();
            if (event.keyval == Gdk.Key.Tab 
                || event.keyval == Gdk.Key.KP_Tab 
                || event.keyval == Gdk.Key.ISO_Left_Tab) {
                    if (modifiers == Gdk.ModifierType.CONTROL_MASK) {
                        return this.get_toplevel ().child_focus (Gtk.DirectionType.TAB_FORWARD);
                    } else if (modifiers == Gdk.ModifierType.CONTROL_MASK 
                        || modifiers == Gdk.ModifierType.SHIFT_MASK) {
                        return this.get_toplevel ().child_focus (Gtk.DirectionType.TAB_BACKWARD);
                    }
            }

            // manage copy/paste and clipboard accels actions and toggles focus between terminal and document
            foreach (var accel in accels) {
                string path = accel_base + accel.name;
                Gtk.AccelKey key; 
                bool accel_exist = Gtk.AccelMap.lookup_entry (path, out key);
                if (accel_exist 
                    && key.accel_key == event.keyval 
                    && key.accel_mods == Gdk.ModifierType.CONTROL_MASK + Gdk.ModifierType.SHIFT_MASK) {
                    switch (accel.name) {
                        case "copy-clipboard":
                            return this.copy_clipboard ();
                        case "paste-clipboard":
                            return this.paste_clipboard ();
                    }
                }
            }

            string keyval_name = Gdk.keyval_name (Gdk.keyval_to_upper (event.keyval));
            
            // Special case some Vte.Terminal shortcuts
            // so the global shortcuts do not override them
            if (modifiers == Gdk.ModifierType.CONTROL_MASK && keyval_name in "ACDEHKLRTUWZ") {
                return false;
            }

            if (modifiers == Gdk.ModifierType.MOD1_MASK && keyval_name in "BF") {
                return false;
            }

            return Gtk.accel_groups_activate (this.get_toplevel(), event.keyval, modifiers);
        }

        private bool on_vte_button_press (Gtk.Widget term, Gdk.Event event) {
            if (event.button.button == 3) {
                this.vte.grab_focus ();
                this.make_popup (event);
                return true;
            }

            return false;
        }

        private bool on_vte_popup_menu () {
            this.make_popup (null);
            return true;
        }

        private Gtk.Menu create_menu () {
            // Popup menu
            var menu = new Gtk.Menu ();
            Gtk.MenuItem copy = new Gtk.MenuItem.with_label (_("Copy"));
            copy.activate.connect (() => {
                this.copy_clipboard ();
            });
            copy.set_accel_path(this.accel_base + "copy-clipboard");
            menu.append (copy);
            Gtk.MenuItem paste = new Gtk.MenuItem.with_label (_("Paste"));
            paste.activate.connect (() => {
                this.paste_clipboard ();
            });
            paste.set_accel_path(this.accel_base + "paste-clipboard");
            menu.append (paste);

            this.populate_popup (menu);

            menu.show_all ();
            return menu;            
        }

        private void make_popup (Gdk.Event trigger_event) {
            var menu = this.create_menu ();
            menu.attach_to_widget (this, null);

            if (trigger_event != null) {
                menu.popup_at_pointer (trigger_event);
            } else {
                menu.popup_at_widget (this,
                            Gdk.Gravity.NORTH_WEST,
                            Gdk.Gravity.SOUTH_WEST,
                            null
                        );
                menu.select_first (false);
            }
        }

        private bool copy_clipboard () {
            this.vte.copy_clipboard ();
            this.vte.grab_focus ();
            return true;
        }

        private bool paste_clipboard () {
            this.vte.paste_clipboard ();
            this.vte.grab_focus ();
            return true;
        }

        public XedTerminal get_terminal () {
            return this.vte;
        }
    }

    /*
    * Plugin config dialog
    */
    public class ConfigTerminal : Peas.ExtensionBase, PeasGtk.Configurable
    {
        public ConfigTerminal () 
        {
            GLib.Object ();
        }

        public Gtk.Widget create_configure_widget () 
        {

            var label = new Gtk.Label ("");
            label.set_markup (_("<big>Xed Terminal Plugin Settings</big>"));
            label.set_margin_top (10);
            label.set_margin_bottom (15);
            label.set_margin_start (10);
            label.set_margin_end (10);

            Gtk.Grid main_grid = new Gtk.Grid ();
            main_grid.set_valign (Gtk.Align.START);
            main_grid.set_margin_top (10);
            main_grid.set_margin_bottom (10);
            main_grid.set_margin_start (10);
            main_grid.set_margin_end (10);
            main_grid.set_column_homogeneous (false);
            main_grid.set_row_homogeneous (false);
            main_grid.set_vexpand (true);
            main_grid.attach (label, 0, 0, 1, 1);

            return main_grid;
        }
    }
}