// FilenameComponent - handles the editable filename in the bottom toolbar
public class FilenameComponent : Gtk.Box {
    private VasuData chr_data;
    private Gtk.Entry filename_entry;
    private Gtk.Label filename_label;
    
    private bool is_editing = false;
    private uint flash_timer_id = 0;
    private bool flash_state = false;
    
    public FilenameComponent(VasuData data) {
        Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);
        
        chr_data = data;
        
        setup_ui();
        margin_top = 1; // Align with icons
    }
    
    private void setup_ui() {
        // Create label for normal display
        filename_label = new Gtk.Label(chr_data.filename);
        filename_label.add_css_class("filename-label");
        filename_label.halign = Gtk.Align.START;
        append(filename_label);

        // Create entry for editing mode (initially hidden)
        filename_entry = new Gtk.Entry();
        filename_entry.add_css_class("filename-label");
        filename_entry.set_has_frame(false);
        filename_entry.halign = Gtk.Align.START;
        filename_entry.text = chr_data.filename;
        filename_entry.visible = false;
        append(filename_entry);

        // Add click handler to start editing
        var click_gesture = new Gtk.GestureClick();
        click_gesture.pressed.connect(() => {
            if (!is_editing) {
                start_editing();
            }
        });
        filename_label.add_controller(click_gesture);

        // Add key handler for the entry
        var key_controller = new Gtk.EventControllerKey();
        key_controller.key_pressed.connect((keyval, keycode, state) => {
            if (keyval == Gdk.Key.Escape) {
                cancel_edit();
                return true;
            }
            return false;
        });
        filename_entry.add_controller(key_controller);
        
        filename_entry.activate.connect(() => {
            if (is_editing) {
                apply_edit();
            }
        });

        // Handle focus loss
        var focus_controller = new Gtk.EventControllerFocus();
        focus_controller.leave.connect(() => {
            if (is_editing) {
                apply_edit();
            }
        });
        filename_entry.add_controller(focus_controller);

        // Update filename label when it changes
        chr_data.notify["filename"].connect(() => {
            filename_label.set_text(chr_data.filename);
            filename_entry.text = chr_data.filename;
        });
    }
    
    // Start editing the filename
    public void start_editing() {
        is_editing = true;
        
        // Hide label, show entry
        filename_label.visible = false;
        filename_entry.visible = true;
        filename_entry.text = chr_data.filename;
        filename_entry.grab_focus();
        
        // Select all text
        filename_entry.select_region(0, -1);
        
        // Start flashing timer
        if (flash_timer_id > 0) {
            Source.remove(flash_timer_id);
        }
        
        flash_timer_id = Timeout.add(600, () => {
            if (!is_editing) {
                flash_timer_id = 0;
                return false;
            }
            
            // Toggle flash state
            flash_state = !flash_state;
            
            // Apply flash state
            update_flash();
            
            return true;
        });
        
        // Initial flash state
        flash_state = true;
        update_flash();
    }

    // Apply the current flash state
    private void update_flash() {
        // Create CSS provider for dynamic styling
        var css_provider = new Gtk.CssProvider();
        
        // Get the colors for flashing
        Gdk.RGBA fg_color = chr_data.get_color(flash_state ? 1 : 0);
        Gdk.RGBA bg_color = chr_data.get_color(flash_state ? 0 : 1);
        
        string fg_hex = rgba_to_hex(fg_color);
        string bg_hex = rgba_to_hex(bg_color);
        
        string css_data = """
            entry.filename-label {
                padding: 0;
                margin: 0;
                min-height: 7px;
                min-width: 0px;
                border: none;
                outline: none;
                box-shadow: none;
                -gtk-icon-size: 0px;
            }
            entry.filename-label text {
                border: none;
                background: %s;
                color: %s;
                outline: none;
                box-shadow: none;
                padding: 0;
                margin: 0;
                min-height: 7px;
                min-width: 0px;
                font-family: "atari8", monospace;
                font-size: 8px;
                line-height: 8px;
                -gtk-icon-size: 0px;
            }
        """.printf(bg_hex, fg_hex);
        
        try {
            css_provider.load_from_data(css_data.data);
            
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(), 
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        } catch (Error e) {
            warning("Failed to load CSS: %s", e.message);
        }
    }

    // Apply the filename edit
    private void apply_edit() {
        if (!is_editing) return;
        
        // Stop flashing
        if (flash_timer_id > 0) {
            Source.remove(flash_timer_id);
            flash_timer_id = 0;
        }
        
        is_editing = false;
        
        // Hide entry, show label
        filename_label.visible = true;
        filename_entry.visible = false;
        
        // Update the filename
        string new_filename = filename_entry.text.strip();
        
        // Ensure filename is not empty and has .chr extension
        if (new_filename == "") {
            new_filename = "untitled.chr";
        } else if (!new_filename.has_suffix(".chr")) {
            new_filename += ".chr";
        }
        
        // Set the new filename
        chr_data.filename = new_filename;
    }

    // Cancel filename editing
    private void cancel_edit() {
        if (!is_editing) return;
        
        // Stop flashing
        if (flash_timer_id > 0) {
            Source.remove(flash_timer_id);
            flash_timer_id = 0;
        }
        
        is_editing = false;
        
        // Hide entry, show label
        filename_label.visible = true;
        filename_entry.visible = false;
    }
    
    // Helper function to convert RGBA to hex
    private string rgba_to_hex(Gdk.RGBA rgba) {
        int r = (int)(rgba.red * 255);
        int g = (int)(rgba.green * 255);
        int b = (int)(rgba.blue * 255);
        
        return "#%02x%02x%02x".printf(r, g, b);
    }
}