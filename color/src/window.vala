public class ColorPickerWindow : Gtk.ApplicationWindow {
    private ColorWheelArea color_wheel;
    private Gtk.DrawingArea pick_da;
    private Gtk.Label hex_label;
    private Gtk.Label rgb_label;
    private Gtk.Box main_box;
    private ScreenColorPicker screen_picker;
    
    // Theme manager instance
    private Theme.Manager theme_manager;
    
    public ColorPickerWindow(Gtk.Application app) {
        Object(
            application: app,
            title: "Color",
            default_width: 200,
            default_height: 293,
            resizable: false
        );
    }
    
    construct {
        // Get the theme manager instance
        theme_manager = Theme.Manager.get_default();
        
        // Connect to theme change signals
        theme_manager.theme_changed.connect(on_theme_changed);
        theme_manager.color_mode_changed.connect(on_color_mode_changed);
        
        var _tmp = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        _tmp.visible = false;
        titlebar = _tmp;
        
        // Load CSS
        var provider = new Gtk.CssProvider();
        provider.load_from_resource("/com/example/color/style.css");
        
        // Apply CSS to the app
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
        
        screen_picker = new ScreenColorPicker(this);
        setup_ui();
        setup_actions();
    }
    
    private void setup_ui() {
        main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8) {
            margin_start = 8,
            margin_end = 8,
            margin_top = 8,
            margin_bottom = 8
        };
        main_box.append (create_titlebar ());
        
        set_child(main_box);
        
        var info_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        main_box.append(info_box);
        
        hex_label = new Gtk.Label("");
        info_box.append(hex_label);
        
        var spacer = new Gtk.Label("") {
            hexpand = true
        };
        info_box.append(spacer);
        
        rgb_label = new Gtk.Label("");
        info_box.append(rgb_label);
        
        color_wheel = new ColorWheelArea(theme_manager) {
            vexpand = true,
            hexpand = true
        };
        main_box.append(color_wheel);
        
        // Initialize color wheel based on current theme colors
        update_color_wheel_from_theme();
        
        color_wheel.color_changed.connect(update_color_display);
    }
    
    private Gtk.Widget create_titlebar() {
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        
        // Create close button
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.clicked.connect(() => {
            close();
        });
        
        title_bar.append(close_button);
        
        // Create color pick button
        var pick_button = new Gtk.Button();
        pick_button.add_css_class("pick-button");
        pick_button.tooltip_text = "Pick Color";
        pick_button.valign = Gtk.Align.CENTER;
        pick_button.halign = Gtk.Align.END;
        pick_button.hexpand = true;
        
        pick_da = new Gtk.DrawingArea ();
        pick_da.set_content_width (8);
        pick_da.set_content_height (8);
        pick_da.set_draw_func (on_draw);
        
        pick_button.set_child (pick_da);
        
        pick_button.clicked.connect(() => {
             screen_picker.start_picking();
        });
        
        title_bar.append(pick_button);
        
        var winhandle = new Gtk.WindowHandle();
        winhandle.set_child(title_bar);
        
        // Create vertical layout
        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        vbox.append(winhandle);
        
        return vbox;
    }
    
    private void on_draw (Gtk.DrawingArea da, Cairo.Context cr, int width, int height) {
        cr.set_antialias(Cairo.Antialias.NONE);
        
        int x = 0;
        int y = 0;
        
        var bg_color = theme_manager.get_color("theme_bg");
        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
        cr.paint();
        
        var color = theme_manager.get_color("theme_accent");
        cr.set_source_rgb(color.red, color.green, color.blue);

        cr.rectangle(x + 3, y, 1, 1);
        cr.rectangle(x + 2, y + 1, 1, 1);
        cr.rectangle(x + 3, y + 1, 1, 1);
        cr.rectangle(x + 4, y + 1, 1, 1);
        cr.rectangle(x + 1, y + 2, 1, 1);
        cr.rectangle(x + 2, y + 2, 1, 1);
        cr.rectangle(x + 3, y + 2, 1, 1);
        cr.rectangle(x + 4, y + 2, 1, 1);
        cr.rectangle(x + 5, y + 2, 1, 1);
        cr.rectangle(x + 0, y + 3, 1, 1);
        cr.rectangle(x + 1, y + 3, 1, 1);
        cr.rectangle(x + 2, y + 3, 1, 1);
        cr.rectangle(x + 3, y + 3, 1, 1);
        cr.rectangle(x + 4, y + 3, 1, 1);
        cr.rectangle(x + 5, y + 3, 1, 1);
        cr.rectangle(x + 6, y + 3, 1, 1);
        cr.rectangle(x + 1, y + 4, 1, 1);
        cr.rectangle(x + 2, y + 4, 1, 1);
        cr.rectangle(x + 3, y + 4, 1, 1);
        cr.rectangle(x + 4, y + 4, 1, 1);
        cr.rectangle(x + 5, y + 4, 1, 1);
        cr.rectangle(x + 2, y + 5, 1, 1);
        cr.rectangle(x + 3, y + 5, 1, 1);
        cr.rectangle(x + 4, y + 5, 1, 1);
        cr.rectangle(x + 3, y + 6, 1, 1);
        
        cr.fill();
    }
    
    private void setup_actions() {
        // Create copy action
        var copy_action = new GLib.SimpleAction("copy-color", null);
        copy_action.activate.connect(() => {
            warning("Copy action activated via Ctrl+C");
            copy_color();
        });
        add_action(copy_action);
        
        // Create paste action
        var paste_action = new GLib.SimpleAction("paste-color", null);
        paste_action.activate.connect(() => {
            warning("Paste action activated via Ctrl+V");
            paste_color();
        });
        add_action(paste_action);
        
        // Create toggle mode action
        var toggle_action = new GLib.SimpleAction("toggle-mode", null);
        toggle_action.activate.connect(() => {
            warning("Toggle mode action activated via Ctrl+T");
            toggle_color_mode();
        });
        add_action(toggle_action);
        
        // Canmcel screen pick
        var cancel_pick_action = new GLib.SimpleAction("cancel-pick", null);
        cancel_pick_action.activate.connect(() => {
            if (screen_picker != null) {
                screen_picker.stop_picking();
            }
        });
        add_action(cancel_pick_action);
    }
    
    private void update_color_display() {
        var rgb = color_wheel.hsv_to_rgb(color_wheel.h, color_wheel.s, color_wheel.v);
        hex_label.label = "#%02x%02x%02x".printf(rgb.r, rgb.g, rgb.b);
        rgb_label.label = "%d,%d,%d".printf(rgb.r, rgb.g, rgb.b);
    }
    
    public void set_color_from_rgb(RgbColor rgb) {
        // Convert RGB to HSV
        var hsv = color_wheel.rgb_to_hsv(rgb);
        
        // Update color wheel with picked color
        color_wheel.h = hsv.h;
        color_wheel.s = hsv.s;
        color_wheel.v = hsv.v;
        color_wheel.queue_draw();
        
        // Update display
        update_color_display();
    }
    
    private void on_theme_changed() {
        warning("Theme changed");
        update_color_wheel_from_theme();
    }
    
    private void on_color_mode_changed(Theme.ColorMode mode) {
        warning("Color mode changed to: %s", mode.to_string());
        update_color_wheel_from_theme();
    }
    
    private void update_color_wheel_from_theme() {
        // Get theme colors
        var accent_color = theme_manager.get_color("theme_accent");
        
        // Convert Gdk.RGBA to RGB values for our color wheel
        RgbColor accent_rgb = {
            (uint8)(accent_color.red * 255),
            (uint8)(accent_color.green * 255),
            (uint8)(accent_color.blue * 255)
        };
        
        // Convert RGB to HSV
        var hsv = color_wheel.rgb_to_hsv(accent_rgb);
        
        // Update color wheel with theme accent color
        color_wheel.h = hsv.h;
        color_wheel.s = hsv.s;
        color_wheel.v = hsv.v;
        color_wheel.queue_draw();
        
        
        // Update button
        pick_da.queue_draw();
        
        // Update display
        update_color_display();
    }
    
    private void toggle_color_mode() {
        // Toggle between 1-bit and 2-bit modes
        if (theme_manager.color_mode == Theme.ColorMode.ONE_BIT) {
            theme_manager.color_mode = Theme.ColorMode.TWO_BIT;
        } else {
            theme_manager.color_mode = Theme.ColorMode.ONE_BIT;
        }
        
        try {
            // Save the color mode
            theme_manager.save_color_mode();
        } catch (Error e) {
            warning("Failed to save color mode: %s", e.message);
        }
    }
    
    private void copy_color() {
        string hex = hex_label.label;
        
        // Get the home directory path
        string home_dir = Environment.get_home_dir();
        string snarf_path = Path.build_filename(home_dir, ".snarf");
        
        try {
            // Create and write to the .snarf file
            FileUtils.set_contents(snarf_path, hex);
            warning("Successfully wrote '%s' to %s", hex, snarf_path);
        } catch (Error e) {
            warning("Error writing to ~/.snarf: %s", e.message);
        }
    }
    
    private void paste_color() {
        // Get the home directory path
        string home_dir = Environment.get_home_dir();
        string snarf_path = Path.build_filename(home_dir, ".snarf");
        
        try {
            // Read from the .snarf file
            string text;
            if (FileUtils.get_contents(snarf_path, out text)) {
                warning("Read from %s: '%s'", snarf_path, text);
                
                RgbColor rgb;
                if (parse_hex_color(text, out rgb)) {
                    warning("Parsed RGB: %d,%d,%d", rgb.r, rgb.g, rgb.b);
                    
                    var hsv = color_wheel.rgb_to_hsv(rgb);
                    color_wheel.h = hsv.h;
                    color_wheel.s = hsv.s;
                    color_wheel.v = hsv.v;
                    color_wheel.queue_draw();
                    update_color_display();
                } else {
                    warning("Failed to parse content in ~/.snarf as a hex color");
                }
            } else {
                warning("Failed to read from ~/.snarf");
            }
        } catch (Error e) {
            warning("Error reading from ~/.snarf: %s", e.message);
        }
    }
    
    /**
     * Converts a hex digit character to its integer value (0-15)
     */
    private int hex_to_int(char c) {
        if (c >= '0' && c <= '9') {
            return c - '0';
        } else if (c >= 'a' && c <= 'f') {
            return c - 'a' + 10;
        } else if (c >= 'A' && c <= 'F') {
            return c - 'A' + 10;
        }
        return 0; // Default for invalid characters
    }

    /**
     * Parse a hex color string (like "#ff0080") into an RGB color
     * Returns true if successful, false otherwise
     */
    private bool parse_hex_color(string hex_color, out RgbColor rgb) {
        rgb = {};
        
        // Clean up and validate input
        string cleaned = hex_color.strip();
        if (cleaned == null || !cleaned.has_prefix("#") || cleaned.length < 7) {
            warning("Invalid hex color format: %s", hex_color);
            return false;
        }
        
        // Parse each component (R, G, B)
        try {
            // Red component (chars 1-2)
            int r_high = hex_to_int(cleaned[1]);
            int r_low = hex_to_int(cleaned[2]);
            rgb.r = (uint8)((r_high << 4) + r_low);
            
            // Green component (chars 3-4)
            int g_high = hex_to_int(cleaned[3]);
            int g_low = hex_to_int(cleaned[4]);
            rgb.g = (uint8)((g_high << 4) + g_low);
            
            // Blue component (chars 5-6)
            int b_high = hex_to_int(cleaned[5]);
            int b_low = hex_to_int(cleaned[6]);
            rgb.b = (uint8)((b_high << 4) + b_low);
            
            return true;
        } catch (Error e) {
            warning("Error parsing hex color: %s", e.message);
            return false;
        }
    }
}