using Theme;

public class Nowlog : Gtk.Application {
    private Gtk.ApplicationWindow window;
    public ShardManager shard_manager;
    private Gtk.Box main_box;
    private Gtk.Box win_box;
    private Gtk.Box content_box;
    private Gtk.ListBox sidebar;
    public ShardGrid shard_grid;
    private string data_file_path;
    // Add theme manager
    private Theme.Manager theme_manager;
    
    public Nowlog () {
        Object(
            application_id: "com.example.nowlog",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }
    
    protected override void activate () {
        // Initialize theme manager
        theme_manager = Theme.Manager.get_default();
        theme_manager.theme_changed.connect(() => {
            // Refresh UI when theme changes
            if (shard_grid != null) {
                shard_grid.refresh();
            }
        });
        
        // Load CSS
        var provider = new Gtk.CssProvider();
        provider.load_from_resource("/com/example/nowlog/style.css");
        
        // Apply CSS to the app
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );


        window = new Gtk.ApplicationWindow (this) {
            title = "Nowlog",
            default_width = 1200,
            default_height = 600
        };
        
        var _tmp = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        _tmp.visible = false;
        window.titlebar = _tmp;
        
        // Initialize data file path
        var config_dir = Environment.get_user_config_dir ();
        var app_config_dir = Path.build_filename (config_dir, "nowlog");
        data_file_path = Path.build_filename (app_config_dir, "shards.tabl");
        
        // Initialize shard manager
        shard_manager = new ShardManager ();
        
        // Load existing data
        load_data ();
        
        // Setup UI components
        main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        window.set_child (main_box);
        
        main_box.append (create_titlebar ());
        
        win_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            vexpand = true
        };
        main_box.append (win_box);
        
        setup_sidebar ();
        setup_content_area ();
        setup_keyboard_shortcuts ();
        
        // Connect close event to save data
        window.close_request.connect (() => {
            save_data ();
            return false; // Let the window close
        });
        
        window.present ();
    }
    
    private Gtk.Widget create_titlebar() {
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = 1200;
        title_bar.add_css_class("title-bar");
        
        // Create close button
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;
        close_button.clicked.connect(() => {
            window.close();
        });
        
        // Create title label
        var title_label = new Gtk.Label("Nowlog");
        title_label.add_css_class("title-box");
        title_label.hexpand = true;
        title_label.margin_end = 8;
        title_label.valign = Gtk.Align.CENTER;
        title_label.halign = Gtk.Align.CENTER;
        
        title_bar.append(close_button);
        title_bar.append(title_label);
        
        var winhandle = new Gtk.WindowHandle();
        winhandle.set_child(title_bar);
        
        // Create vertical layout
        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        vbox.append(winhandle);
        
        return vbox;
    }
    
    private void setup_sidebar () {
        var sidebar_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        sidebar_box.set_size_request (200, -1);
        sidebar_box.add_css_class ("sidebar-box");
        
        sidebar = new Gtk.ListBox ();
        sidebar.set_selection_mode (Gtk.SelectionMode.SINGLE);
        
        var sidebar_scroll = new Gtk.ScrolledWindow ();
        sidebar_scroll.set_child (sidebar);
        sidebar_scroll.vexpand = true;
        sidebar_box.append (sidebar_scroll);
        
        // Add home item
        var home_row = new Gtk.ListBoxRow ();
        var home_label = new Gtk.Label ("Home");
        home_label.halign = Gtk.Align.START;
        home_label.margin_start = 8;
        home_label.margin_end = 8;
        home_label.margin_top = 8;
        home_label.margin_bottom = 8;
        home_row.set_child (home_label);
        sidebar.append (home_row);
        
        // Connect selection signal
        sidebar.row_selected.connect ((row) => {
            if (row == home_row) {
                if (shard_grid != null) {
                    shard_grid.filter_tag (null); // Show all shards
                }
            } else if (row != null) {
                Gtk.Label label = (Gtk.Label) row.get_child ();
                if (shard_grid != null && label != null) {
                    shard_grid.filter_tag (label.get_text ());
                }
            }
        });
        
        // Select home by default
        sidebar.select_row (home_row);
        
        win_box.append (sidebar_box);

        update_sidebar_tags ();
    }
    
    private void setup_content_area () {
        content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        content_box.hexpand = true;
        
        // Header with input area
        var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
        header_box.margin_end = 8;
        header_box.margin_top = 8;
        header_box.margin_bottom = 8;
        
        var entry = new Gtk.Entry ();
        entry.hexpand = true;
        entry.placeholder_text = "25F13 - Title - Text - tag1,tag2";
        
        var add_button = new Gtk.Button.with_label ("Add Shard");
        
        // Add file menu button
        var file_menu_button = new Gtk.MenuButton ();
        file_menu_button.icon_name = "open-menu-symbolic";
        file_menu_button.tooltip_text = "File Options";
        
        // Create popover menu model
        var menu_model = new GLib.Menu ();
        
        // File section
        var file_section = new GLib.Menu ();
        var save_item = new GLib.MenuItem ("Save", "win.save");
        file_section.append_item (save_item);
        
        var load_item = new GLib.MenuItem ("Load", "win.load");
        file_section.append_item (load_item);
        
        menu_model.append_section (null, file_section);
        
        // Theme section
        var theme_section = new GLib.Menu ();
        
        // Add theme mode toggle
        var theme_mode_item = new GLib.MenuItem ("Toggle One-bit Mode", "win.toggle-theme-mode");
        theme_section.append_item (theme_mode_item);
        
        // Add predefined color themes
        theme_section.append ("Light Theme", "win.set-theme::light");
        theme_section.append ("Dark Theme", "win.set-theme::dark");
        theme_section.append ("Vintage", "win.set-theme::vintage");
        theme_section.append ("Low-Contrast", "win.set-theme::low-contrast");
        
        menu_model.append_section ("Theme", theme_section);
        
        var file_menu = new Gtk.PopoverMenu.from_model (menu_model);
        file_menu_button.popover = file_menu;
        
        // Add actions to window
        var save_action = new GLib.SimpleAction ("save", null);
        save_action.activate.connect (save_data);
        window.add_action (save_action);
        
        var load_action = new GLib.SimpleAction ("load", null);
        load_action.activate.connect (load_data);
        window.add_action (load_action);
        
        // Add the toggle theme mode action
        var toggle_theme_mode_action = new GLib.SimpleAction ("toggle-theme-mode", null);
        toggle_theme_mode_action.activate.connect (() => {
            var manager = Theme.Manager.get_default ();
            if (manager.color_mode == Theme.ColorMode.TWO_BIT) {
                manager.color_mode = Theme.ColorMode.ONE_BIT;
            } else {
                manager.color_mode = Theme.ColorMode.TWO_BIT;
            }
            
            try {
                manager.save_color_mode ();
            } catch (Error e) {
                warning ("Failed to save color mode: %s", e.message);
            }
        });
        window.add_action (toggle_theme_mode_action);
        
        // Add set-theme action with parameter
        var set_theme_action = new GLib.SimpleAction ("set-theme", new GLib.VariantType ("s"));
        set_theme_action.activate.connect ((action, param) => {
            string theme_name = param.get_string ();
            apply_preset_theme (theme_name);
        });
        window.add_action (set_theme_action);
        
        header_box.append (file_menu_button);
        header_box.append (entry);
        header_box.append (add_button);
        
        content_box.append (header_box);
        
        // Shard grid area
        var scroll = new Gtk.ScrolledWindow ();
        scroll.hexpand = true;
        scroll.vexpand = true;
        
        shard_grid = new ShardGrid (shard_manager);
        scroll.set_child (shard_grid);
        
        content_box.append (scroll);
        
        win_box.append (content_box);
        
        // Connect signals
        add_button.clicked.connect (() => {
            add_shard_from_text (entry.text);
            entry.text = "";
        });
        
        entry.activate.connect (() => {
            add_shard_from_text (entry.text);
            entry.text = "";
        });
        
        shard_grid.refresh ();
    }
    
    // Add method to apply preset themes
    private void apply_preset_theme (string theme_name) {
        var manager = Theme.Manager.get_default ();
        
        try {
            switch (theme_name) {
                case "light":
                    manager.set_theme ("F07F", "F0DB", "F0C6");
                    break;
                case "dark":
                    manager.set_theme ("0F7F", "0FDB", "0FC6");
                    break;
                case "vintage":
                    manager.set_theme ("D49A", "A26A", "814A");
                    break;
                case "low-contrast":
                    manager.set_theme ("E8CC", "E8CC", "E8CC");
                    break;
                default:
                    warning ("Unknown theme: %s", theme_name);
                    break;
            }
        } catch (Error e) {
            warning ("Failed to set theme: %s", e.message);
        }
    }
    
    private void add_shard_from_text (string text) {
        var shard = parse_shard_input (text);
        if (shard != null) {
            shard_manager.add_shard (shard);
            update_sidebar_tags ();
            shard_grid.refresh ();
            
            // Auto-save when adding a shard
            save_data ();
        }
    }
    
    private Shard? parse_shard_input (string input) {
        // Parse shard format: "25F13 - Title - Text - tag1,tag2"
        string[] parts = input.split (" - ", 4);
        if (parts.length < 3) {
            show_error_dialog ("Invalid shard format.\nExpected: \"25F13 - Title - Text - tag1,tag2\"");
            return null;
        }
        
        string arvelie_date = parts[0].strip ();
        string title = parts[1].strip ();
        string text = parts[2]; // Don't strip spaces from text content
        string[] tags = {};
        
        if (parts.length > 3) {
            tags = parts[3].strip ().split (",");
            for (int i = 0; i < tags.length; i++) {
                tags[i] = tags[i].strip ();
            }
        }
        
        DateTime? date = null;
        try {
            date = parse_arvelie_date (arvelie_date);
            if (date == null) {
                show_error_dialog ("Failed to create valid date from Arvelie date: " + arvelie_date);
                return null;
            }
        } catch (Error e) {
            show_error_dialog ("Invalid Arvelie date: " + e.message);
            return null;
        }
        
        return new Shard (title, text, date, null, tags);
    }
    
    private DateTime? parse_arvelie_date (string arvelie) throws Error {
        if (arvelie.length < 4) {
            throw new Error.INVALID_FORMAT ("Date too short");
        }
        
        // Parse the year (first two digits)
        int year_offset;
        if (!int.try_parse (arvelie.substring (0, 2), out year_offset)) {
            throw new Error.INVALID_FORMAT ("Invalid year");
        }
        int year = 1993 + year_offset;
        
        // Parse the month (letter A-Z or +)
        unichar month_unichar = arvelie.substring (2, 1).get_char (0);
        
        // Parse the day
        int day;
        if (!int.try_parse (arvelie.substring (3), out day)) {
            throw new Error.INVALID_FORMAT ("Invalid day");
        }
        
        // Arvelie epoch is June 6th, 1993
        var epoch = new DateTime.local (1993, 6, 6, 0, 0, 0);
        
        // Calculate days in the year before current date
        int day_of_year;
        
        if (month_unichar == '+') {
            // Handle + month (last 1-2 days of year)
            bool is_leap_year = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
            int max_days = is_leap_year ? 2 : 1;
            
            if (day < 1 || day > max_days) {
                throw new Error.INVALID_FORMAT ("Invalid day for + month");
            }
            
            day_of_year = 364 + day - 1; // 0-indexed for calculation
        } else if (month_unichar >= 'A' && month_unichar <= 'Z') {
            // Regular A-Z months (14 days each)
            int month_index = (int)month_unichar - (int)'A';
            
            if (month_index < 0 || month_index >= 26) {
                throw new Error.INVALID_FORMAT ("Invalid month character");
            }
            
            if (day < 1 || day > 14) {
                throw new Error.INVALID_FORMAT ("Invalid day for regular month");
            }
            
            day_of_year = month_index * 14 + (day - 1); // 0-indexed for calculation
        } else {
            throw new Error.INVALID_FORMAT ("Invalid month character");
        }
        
        // Calculate total days since epoch
        int total_days = 0;
        
        // Add days from complete years
        for (int y = 1993; y < year; y++) {
            bool is_leap_year = (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
            total_days += is_leap_year ? 366 : 365;
        }
        
        // Add days from current year
        total_days += day_of_year;
        
        // Create the datetime by adding the days to the epoch
        TimeSpan time_span = TimeSpan.DAY * total_days;
        DateTime result = epoch.add(time_span);
        
        return result;
    }
    
    private void update_sidebar_tags () {
        // Clear existing tag rows (except "Home" which is the first row)
        var children = sidebar.observe_children ();
        for (uint i = children.get_n_items () - 1; i > 0; i--) {
            var item = children.get_item (i);
            if (item != null) {
                sidebar.remove ((Gtk.Widget) item);
            }
        }
        
        // Add most used tags
        var tags = shard_manager.get_most_used_tags ();
        foreach (var tag in tags) {
            var row = new Gtk.ListBoxRow ();
            var label = new Gtk.Label (tag);
            label.halign = Gtk.Align.START;
            label.margin_start = 12;
            label.margin_end = 12;
            label.margin_top = 8;
            label.margin_bottom = 8;
            row.set_child (label);
            sidebar.append (row);
        }
    }
    
    private void setup_keyboard_shortcuts () {
        var controller = new Gtk.EventControllerKey ();
        controller.key_pressed.connect ((keyval, keycode, state) => {
            if (keyval == Gdk.Key.n && (state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                // Ctrl+N: focus the entry
                var entry = main_box.get_first_child ().get_next_sibling ().get_next_sibling ()
                    .get_first_child ().get_first_child () as Gtk.Entry;
                if (entry != null) {
                    entry.grab_focus ();
                    return true;
                }
            }
            return false;
        });
        main_box.add_controller (controller);
    }
    
    private void ask_confirmation_dialog (string message, owned Callback confirmed_callback) {
        var dialog = new Gtk.AlertDialog ("");
        dialog.message = message;
        dialog.detail = "This action cannot be undone.";
        dialog.buttons = {"Cancel", "Confirm"};
        dialog.default_button = 0;
        dialog.cancel_button = 0;
        
        dialog.choose.begin (window, null, (obj, res) => {
            try {
                int response = dialog.choose.end (res);
                if (response == 1) { // Confirm button
                    confirmed_callback ();
                }
            } catch (Error e) {
                warning ("Dialog error: %s", e.message);
            }
        });
    }
    
    private void show_error_dialog (string message) {
        var dialog = new Gtk.AlertDialog ("");
        dialog.message = "Error";
        dialog.detail = message;
        dialog.buttons = {"OK"};
        
        dialog.choose.begin (window, null, null);
    }
    
    private void show_info_dialog (string message) {
        var dialog = new Gtk.AlertDialog ("");
        dialog.message = "Information";
        dialog.detail = message;
        dialog.buttons = {"OK"};
        
        dialog.choose.begin (window, null, null);
    }
    
    // Save data to the default file location
    private void save_data () {
        bool success = shard_manager.save_to_file (data_file_path);
        if (!success) {
            warning ("Failed to save data to %s", data_file_path);
        }
    }
    
    // Load data from the default file location
    private void load_data () {
        shard_manager.load_from_file (data_file_path, (date_str) => {
            try {
                return parse_arvelie_date(date_str);
            } catch (Error e) {
                warning("Error parsing date: %s", e.message);
                return null;
            }
        });
    }
    
    public static int main (string[] args) {
        return new Nowlog().run(args);
    }
}

public errordomain Error {
    INVALID_FORMAT
}