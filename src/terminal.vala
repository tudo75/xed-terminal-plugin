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
        private GLib.Settings settings;
        
        public XedTerminal () {
            this.set_size (this.get_column_count (), 5);
            this.set_size_request (200, 50);

            this.profile_settings = this.get_profile_settings ();

            this.settings = new GLib.Settings ("com.github.tudo75.xed-terminal-plugin");
            
            if (this.settings.get_boolean ("use-custom-settings")) {
                this.vte_settings_config ();
            } else {
                this.vte_keyfile_config ();
            }
            
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

        private void vte_settings_config () {
            if (!this.settings.get_boolean ("use-theme-colors")) {
                Gdk.RGBA fg = Gdk.RGBA ();
                fg.parse (this.settings.get_string ("color-foreground"));
                Gdk.RGBA bg =  Gdk.RGBA ();
                bg.parse (this.settings.get_string ("color-background"));
                Gdk.RGBA[] palette = new Gdk.RGBA[16];
                string[] palette_colors = this.settings.get_strv ("palette");
                for (int i = 0; i < palette_colors.length; i++) {
                    var rgba = Gdk.RGBA();
                    rgba.parse (palette_colors[i]);
                    palette[i] = rgba;
                }
                this.set_colors (fg, bg, palette);
            }
            
            this.set_bold_is_bright (this.settings.get_boolean ("bold-is-bright"));
            this.set_audible_bell (this.settings.get_boolean ("audible-bell"));
            if (this.settings.get_boolean ("scrollback-unlimited")) {
                this.set_scrollback_lines (-1);
            } else  {
                this.set_scrollback_lines ((long) this.settings.get_double ("scrollback-lines"));
            }            
            this.set_scroll_on_keystroke (this.settings.get_boolean ("scroll-on-keystroke"));
            this.set_scroll_on_output (this.settings.get_boolean ("scroll-on-output"));

            int cursor_blink_mode = this.settings.get_enum ("cursor-blink-mode");
            switch (cursor_blink_mode) {
                case 0:
                    this.set_cursor_blink_mode (Vte.CursorBlinkMode.SYSTEM);
                    break;
                case 1:
                    this.set_cursor_blink_mode (Vte.CursorBlinkMode.ON);
                    break;
                case 2:
                    this.set_cursor_blink_mode (Vte.CursorBlinkMode.OFF);
                    break;
            }
            int cursor_shape_setting = this.settings.get_enum ("cursor-shape");
            switch (cursor_shape_setting) {
                case 0:
                    this.set_cursor_shape (Vte.CursorShape.BLOCK);
                    break;
                case 1:
                    this.set_cursor_shape (Vte.CursorShape.IBEAM);
                    break;
                case 2:
                    this.set_cursor_shape (Vte.CursorShape.UNDERLINE);
                    break;
            }
            
            if (!this.settings.get_boolean ("use-system-font")) {
                this.set_font (Pango.FontDescription.from_string (this.settings.get_string ("font")));
            }
            // this.set_allow_bold (this.settings.get_boolean ("allow-bold"));

            this.set_allow_hyperlink (this.settings.get_boolean ("allow-hyperlink"));
        }

        private void vte_keyfile_config () {
            //default values or system values
            string font = this.get_font ().to_string ();

            var context = this.get_style_context ();
            Gdk.RGBA fg = context.get_color (Gtk.StateFlags.NORMAL);
            Gdk.RGBA bg = context.get_background_color (Gtk.StateFlags.NORMAL);
            Gdk.RGBA[] palette = new Gdk.RGBA[16];
            bool use_theme_colors = false;
            bool bell = false;
            bool bold_is_bright = true;

            var blink_mode = Vte.CursorBlinkMode.SYSTEM;
            this.set_cursor_shape (Vte.CursorShape.BLOCK);

            // get values from keyfile
            try{
                if (this.key_exist ("FontName")) {
                    font = this.profile_settings.get_string ("Configuration", "FontName");
                }
                if (this.key_exist ("ColorUseTheme")) {
                    use_theme_colors = (bool) this.profile_settings.get_string ("Configuration", "ColorUseTheme").down ();
                }
                if (!use_theme_colors) {
                    if (this.key_exist ("ColorForeground")) {
                        var fg_color = this.profile_settings.get_string ("Configuration", "ColorForeground");
                        if (fg_color != "") {
                            fg.parse (fg_color);
                        }
                    }
                    if (this.key_exist ("ColorBackground")) {
                        var bg_color = this.profile_settings.get_string ("Configuration", "ColorBackground");
                        if (bg_color != "") {
                            bg.parse (bg_color);
                        }
                    }
                }
                if (this.key_exist ("ColorPalette")) {
                    string[] palette_colors = this.profile_settings.get_string_list ("Configuration", "ColorPalette");
                    if (palette_colors != null) {
                        for (int i = 0; i < palette_colors.length; i++) {
                            var rgba = Gdk.RGBA();
                            rgba.parse (palette_colors[i]);
                            palette[i] = rgba;
                        }
                    }
                }
                if (this.key_exist ("MiscCursorBlinks")) {
                    bool blink = (bool) this.profile_settings.get_string ("Configuration", "MiscCursorBlinks").down ();
                    if (blink) {
                        blink_mode = Vte.CursorBlinkMode.ON;
                    } else {
                        blink_mode = Vte.CursorBlinkMode.OFF;
                    }
                }

                if (this.key_exist ("MiscCursorShape")) {
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
                if (this.key_exist ("MiscBell")) {
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
            this.set_bold_is_bright (bold_is_bright);
            this.set_scroll_on_keystroke (true);
            this.set_scroll_on_output (true);
            this.set_scrollback_lines (1000);
            this.set_allow_hyperlink (true);
            // this.set_allow_bold (true);
        }

        private bool key_exist (string key_name) throws GLib.KeyFileError {
            return this.profile_settings.has_key ("Configuration", key_name);
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
    public class ConfigTerminal : Peas.ExtensionBase, PeasGtk.Configurable {

        private GLib.Settings settings;

        public ConfigTerminal () 
        {
            GLib.Object ();
        }

        public Gtk.Widget create_configure_widget () {

            this.settings = new GLib.Settings ("com.github.tudo75.xed-terminal-plugin");

            int grid_row = 0;
            
            Gtk.Grid main_grid = new Gtk.Grid ();
            main_grid.set_valign (Gtk.Align.START);
            main_grid.set_margin_top (18);
            main_grid.set_margin_bottom (18);
            main_grid.set_margin_start (18);
            main_grid.set_margin_end (18);
            main_grid.set_row_spacing (6);
            main_grid.set_column_spacing (12);
            main_grid.set_column_homogeneous (false);
            main_grid.set_row_homogeneous (false);
            main_grid.set_vexpand (true);

            Gtk.Label title_lbl = new Gtk.Label ("");
            title_lbl.set_markup (_("<big>Xed Terminal Plugin Settings</big>"));
            title_lbl.set_margin_top (10);
            title_lbl.set_margin_bottom (15);
            title_lbl.set_margin_start (10);
            title_lbl.set_margin_end (10);
            main_grid.attach (title_lbl, 0, grid_row, 2, 1);
            grid_row++;

            Gtk.Label main_lbl = new Gtk.Label ("");
            main_lbl.set_markup (_("<b>Main</b>"));
            main_lbl.set_halign (Gtk.Align.START);
            main_grid.attach (main_lbl, 0, grid_row, 1, 1);
            grid_row++;

            Gtk.CheckButton custom_setting_check = new Gtk.CheckButton.with_label (_("Use custom settings"));
            this.settings.bind ("use-custom-settings", custom_setting_check, "active", GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.GET_NO_CHANGES);
            main_grid.attach (custom_setting_check, 1, grid_row, 1, 1);
            grid_row++;


            Gtk.CheckButton allow_hyperlink_check = new Gtk.CheckButton.with_label (_("Allow cliccable hyperlinks"));
            this.settings.bind ("allow-hyperlink", allow_hyperlink_check, "active", GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.GET_NO_CHANGES);
            this.settings.bind ("use-custom-settings", allow_hyperlink_check, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY);
            main_grid.attach (allow_hyperlink_check, 1, grid_row, 1, 1);
            grid_row++;

            Gtk.Label font_lbl = new Gtk.Label ("");
            font_lbl.set_markup (_("<b>Font</b>"));
            font_lbl.set_halign (Gtk.Align.START);
            main_grid.attach (font_lbl, 0, grid_row, 1, 1);
            grid_row++;

            Gtk.Label custom_font_lbl = new Gtk.Label (_("Custom font"));
            custom_font_lbl.set_halign (Gtk.Align.END);
            main_grid.attach (custom_font_lbl, 0, grid_row, 1, 1);

            Gtk.CheckButton system_font_check = new Gtk.CheckButton ();
            this.settings.bind ("use-system-font", system_font_check, "active", GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.GET_NO_CHANGES | GLib.SettingsBindFlags.INVERT_BOOLEAN);
            
            Gtk.FontButton custom_font_chooser = new Gtk.FontButton ();
            custom_font_chooser.set_title (_("Choose a terminal font"));
            this.settings.bind ("font", custom_font_chooser, "font-name", GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.GET_NO_CHANGES);
            this.settings.bind ("use-system-font", custom_font_chooser, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY | GLib.SettingsBindFlags.INVERT_BOOLEAN);
            
            Gtk.Grid font_grid = new Gtk.Grid();
            font_grid.set_column_spacing (12);
            font_grid.set_row_spacing(0);
            font_grid.set_margin_start (2);
            this.settings.bind ("use-custom-settings", font_grid, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY);
            font_grid.attach (system_font_check, 0, 0, 1, 1);
            font_grid.attach (custom_font_chooser, 1, 0, 1, 1);
            main_grid.attach (font_grid, 1, grid_row, 1, 1);
            grid_row++;

            Gtk.Label cursor_lbl = new Gtk.Label ("");
            cursor_lbl.set_markup (_("<b>Cursor</b>"));
            cursor_lbl.set_halign (Gtk.Align.START);
            main_grid.attach (cursor_lbl, 0, grid_row, 2, 1);
            grid_row++;

            Gtk.Label cursor_shape_lbl = new Gtk.Label (_("Cursor shape"));
            cursor_shape_lbl.set_halign (Gtk.Align.END);
            main_grid.attach (cursor_shape_lbl, 0, grid_row, 1, 1);
            Gtk.ComboBox cursor_shape_cb = this.create_combo ( 
                        {_("Block"), _("IBeam"), _("Underline")}, 
                        {"block", "ibeam", "underline"});
            this.settings.bind ("cursor-shape", cursor_shape_cb, "active-id", GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.GET_NO_CHANGES);
            this.settings.bind ("use-custom-settings", cursor_shape_cb, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY);
            main_grid.attach (cursor_shape_cb, 1, grid_row, 1, 1);
            grid_row++;

            Gtk.Label blink_mode_lbl = new Gtk.Label (_("Cursor blink mode"));
            blink_mode_lbl.set_halign (Gtk.Align.END);
            main_grid.attach (blink_mode_lbl, 0, grid_row, 1, 1);
            Gtk.ComboBox blink_mode_cb = this.create_combo (
                        {_("System"), _("On"), _("Off")},
                        {"system", "on", "off"});
            this.settings.bind ("cursor-blink-mode", blink_mode_cb, "active-id", GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.GET_NO_CHANGES);
            this.settings.bind ("use-custom-settings", blink_mode_cb, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY);
            main_grid.attach (blink_mode_cb, 1, grid_row, 1, 1);
            grid_row++;

            Gtk.Label notify_lbl = new Gtk.Label ("");
            notify_lbl.set_markup (_("<b>Notification</b>"));
            notify_lbl.set_halign (Gtk.Align.START);
            main_grid.attach (notify_lbl, 0, grid_row, 2, 1);
            grid_row++;

            Gtk.CheckButton bell_check = new Gtk.CheckButton.with_label (_("Terminal bell"));
            this.settings.bind ("audible-bell", bell_check, "active", GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.GET_NO_CHANGES);
            this.settings.bind ("use-custom-settings", bell_check, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY);
            main_grid.attach (bell_check, 1, grid_row, 1, 1);
            grid_row++;

            Gtk.Label colours_lbl = new Gtk.Label ("");
            colours_lbl.set_markup (_("<b>Colors</b>"));
            colours_lbl.set_halign (Gtk.Align.START);
            main_grid.attach (colours_lbl, 0, grid_row, 2, 1);
            grid_row++;

            Gtk.CheckButton bold_is_bright_check = new Gtk.CheckButton.with_label (_("Show bold text in bright colors"));
            this.settings.bind ("bold-is-bright", bold_is_bright_check, "active", GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.GET_NO_CHANGES);
            this.settings.bind ("use-custom-settings", bold_is_bright_check, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY);
            main_grid.attach (bold_is_bright_check, 1, grid_row, 1, 1);
            grid_row++;

            Gtk.CheckButton use_theme_colors_check = new Gtk.CheckButton.with_label (_("Use theme colors"));
            this.settings.bind ("use-theme-colors", use_theme_colors_check, "active", GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.GET_NO_CHANGES);
            this.settings.bind ("use-custom-settings", use_theme_colors_check, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY);
            main_grid.attach (use_theme_colors_check, 1, grid_row, 1, 1);
            grid_row++;

            main_grid.attach (this.add_primary_colours_grid (), 1, grid_row, 1, 1);
            grid_row++;

            main_grid.attach (this.add_colours_grid (), 1, grid_row, 1, 1);
            grid_row++;

            Gtk.Label scrolling_lbl = new Gtk.Label ("");
            scrolling_lbl.set_markup (_("<b>Scrolling</b>"));
            scrolling_lbl.set_halign (Gtk.Align.START);
            main_grid.attach (scrolling_lbl, 0, grid_row, 2, 1);
            grid_row++;

            Gtk.CheckButton scroll_keystroke_check = new Gtk.CheckButton.with_label (_("Scroll on keystroke"));
            this.settings.bind ("scroll-on-keystroke", scroll_keystroke_check, "active", GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.GET_NO_CHANGES);
            this.settings.bind ("use-custom-settings", scroll_keystroke_check, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY);
            main_grid.attach (scroll_keystroke_check, 1, grid_row, 1, 1);
            grid_row++;

            Gtk.CheckButton scroll_output_check = new Gtk.CheckButton.with_label (_("Scroll on output"));
            this.settings.bind ("scroll-on-output", scroll_output_check, "active", GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.GET_NO_CHANGES);
            this.settings.bind ("use-custom-settings", scroll_output_check, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY);
            main_grid.attach (scroll_output_check, 1, grid_row, 1, 1);
            grid_row++;
                

            Gtk.Label scroll_limit_lbl = new Gtk.Label (_("Scrollback limit"));
            scroll_limit_lbl.set_halign (Gtk.Align.END);
            main_grid.attach (scroll_limit_lbl, 0, grid_row, 1, 1);
            
            Gtk.CheckButton scroll_unlimited_check = new Gtk.CheckButton ();
            this.settings.bind ("scrollback-unlimited", scroll_unlimited_check, "active", GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.GET_NO_CHANGES);
            
            Gtk.SpinButton scrollback_lines = new Gtk.SpinButton.with_range (256.0, 10000.0, 10.0);
            this.settings.bind ("scrollback-lines", scrollback_lines, "value", GLib.SettingsBindFlags.DEFAULT | GLib.SettingsBindFlags.GET_NO_CHANGES);
            this.settings.bind ("scrollback-unlimited", scrollback_lines, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY | GLib.SettingsBindFlags.INVERT_BOOLEAN);
            
            Gtk.Grid scroll_grid = new Gtk.Grid();
            scroll_grid.set_column_spacing (12);
            scroll_grid.set_row_spacing(0);
            scroll_grid.set_margin_start (2);
            this.settings.bind ("use-custom-settings", scroll_grid, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY);
            scroll_grid.attach (scroll_unlimited_check, 0, 0, 1, 1);
            scroll_grid.attach (scrollback_lines, 1, 0, 1, 1);
            main_grid.attach (scroll_grid, 1, grid_row, 1, 1);
            grid_row++;

            return main_grid;
        }

        private Gtk.Grid add_primary_colours_grid () {
            int grid_row = 0;
            Gtk.Grid grid = new Gtk.Grid();
            grid.set_column_spacing (12);
            grid.set_row_spacing(0);

            Gdk.RGBA bg_color = Gdk.RGBA ();
            bg_color.parse (this.settings.get_string ("color-background"));
            Gtk.ColorButton bg_color_btn = new Gtk.ColorButton.with_rgba (bg_color);
            bg_color_btn.set_title (_("Select background color"));
            bg_color_btn.set_name ("color-background");
            bg_color_btn.color_set.connect (() => {
                Gdk.RGBA rgba = bg_color_btn.get_rgba ();
                string color = "#%02X%02X%02X";
                string hex_color = color.printf ((int)(rgba.red*255), (int)(rgba.green*255), (int)(rgba.blue*255));
                this.settings.set_string (bg_color_btn.get_name (), hex_color);
                print ("Color set: %s\t%s\n", rgba.to_string (), hex_color);
            });
            this.settings.bind ("use-theme-colors", bg_color_btn, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY | GLib.SettingsBindFlags.INVERT_BOOLEAN);
            // this.settings.bind ("use-custom-settings", bg_color_btn, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY);
            grid.attach (bg_color_btn, 0, grid_row, 1, 1);
            grid.attach (new Gtk.Label(_("Background")), 1, grid_row, 1, 1);

            Gtk.Label spacer_lbl = new Gtk.Label (" ");
            spacer_lbl.set_hexpand (true);
            grid.attach (spacer_lbl, 2, grid_row, 1, 1);

            Gdk.RGBA fg_color = Gdk.RGBA ();
            fg_color.parse (this.settings.get_string ("color-foreground"));
            Gtk.ColorButton fg_color_btn = new Gtk.ColorButton.with_rgba (fg_color);
            fg_color_btn.set_title (_("Select foreground color"));
            fg_color_btn.set_name ("color-foreground");
            fg_color_btn.color_set.connect (() => {
                Gdk.RGBA rgba = fg_color_btn.get_rgba ();
                string color = "#%02X%02X%02X";
                string hex_color = color.printf ((int)(rgba.red*255), (int)(rgba.green*255), (int)(rgba.blue*255));
                this.settings.set_string (fg_color_btn.get_name (), hex_color);
                print ("Color set: %s\t%s\n", rgba.to_string (), hex_color);
            });
            this.settings.bind ("use-theme-colors", fg_color_btn, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY | GLib.SettingsBindFlags.INVERT_BOOLEAN);
            // this.settings.bind ("use-custom-settings", fg_color_btn, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY);
            grid.attach (fg_color_btn, 3, grid_row, 1, 1);
            grid.attach (new Gtk.Label(_("Foreground")), 4, grid_row, 1, 1);

            this.settings.bind ("use-custom-settings", grid, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY);

            return grid;
        }

        private Gtk.Grid add_colours_grid () {
            Gtk.Grid grid = new Gtk.Grid();
            grid.set_column_spacing (12);
            grid.set_row_spacing(6);

            string[] palette = this.settings.get_strv ("palette");

            for (var i = 0; i < palette.length; i++) {
                Gdk.RGBA color = Gdk.RGBA ();
                color.parse (palette[i]);
                Gtk.ColorButton color_btn = new Gtk.ColorButton.with_rgba (color);
                color_btn.set_title (_("Select color"));
                color_btn.set_data<int> ("index_key", i);
                color_btn.color_set.connect (() => {
                    Gdk.RGBA rgba = color_btn.get_rgba ();
                    string color_mask = "#%02X%02X%02X";
                    string[] tmp_palette = this.settings.get_strv ("palette");
                    tmp_palette[color_btn.get_data<int> ("index_key")] = color_mask.printf ((int)(rgba.red*255), (int)(rgba.green*255), (int)(rgba.blue*255));
                    this.settings.set_strv ("palette", tmp_palette);
                });
                this.settings.bind ("use-theme-colors", color_btn, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY | GLib.SettingsBindFlags.INVERT_BOOLEAN);
                // this.settings.bind ("use-custom-settings", color_btn, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY);
                if (i < 8) {
                    grid.attach (color_btn, i, 0, 1, 1);
                } else {
                    grid.attach (color_btn, i - 8, 1, 1, 1);
                }
            }

            Gtk.Label dark_colors_lbl = new Gtk.Label (_("Dark colors"));
            grid.attach (dark_colors_lbl, 8, 0, 1, 1);
            Gtk.Label light_colors_lbl = new Gtk.Label (_("Light colors"));
            grid.attach (light_colors_lbl, 8, 1, 1, 1);

            this.settings.bind ("use-custom-settings", grid, "sensitive", GLib.SettingsBindFlags.GET | GLib.SettingsBindFlags.NO_SENSITIVITY);

            return grid;
        }

        private Gtk.ComboBox create_combo (string[] names, string[] values) {
            assert (names.length == values.length);

            Gtk.ListStore ls = new Gtk.ListStore (2, typeof (string), typeof (string));
            Gtk.TreeIter iter;

            for (int i = 0; i < names.length; i++) {
                ls.append (out iter);
                ls.set (iter, 0, names[i], 1, values[i]);
            }

            Gtk.ComboBox box = new Gtk.ComboBox.with_model (ls);
            box.set_focus_on_click (false);
            box.set_id_column (1);
            Gtk.CellRendererText cell = new Gtk.CellRendererText ();
            cell.set_alignment (0, 0);
            box.pack_start (cell, false);
            box.add_attribute (cell, "text", 0);

            return box;
        }
    }
}