// New class to replace individual HexCell widgets with efficient drawing
public class HexView : Gtk.Box {
    private Gtk.DrawingArea drawing_area;
    private uint8[] buffer;
    private int bytes_per_line = 16;
    private int byte_width = 20;  // Width of each hex cell
    private int byte_height = 20; // Height of each hex cell
    private int selected_byte = -1;
    private int editing_byte = -1;
    private Gtk.Entry? edit_entry = null;
    private Gtk.Adjustment vadjustment;
    private unowned Window parent_window;
    
    // Define a delegate for byte changes
    public delegate void ByteChangedFunc(int index, uint8 value);
    public unowned ByteChangedFunc? byte_changed_callback = null;
    
    // Constructor
    public HexView(uint8[] buffer_ref, Gtk.Adjustment vadj, Window parent) {
        Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        
        this.buffer = buffer_ref;
        this.vadjustment = vadj;
        this.parent_window = parent;
        
        // Create an overlay to host the drawing area and editable entries
        var overlay = new Gtk.Overlay();
        this.append(overlay);
        
        // Create drawing area for hex view
        drawing_area = new Gtk.DrawingArea() {
            vexpand = true
        };
        drawing_area.set_draw_func(draw_hex_view);
        
        // Set as the child of the overlay
        overlay.set_child(drawing_area);
        
        // Set up input handling
        var click = new Gtk.GestureClick();
        click.pressed.connect(on_click_pressed);
        drawing_area.add_controller(click);
        
        // Listen for adjustment changes
        vadjustment.value_changed.connect(() => {
            drawing_area.queue_draw();
            // Reposition edit entry if active
            if (editing_byte >= 0 && edit_entry != null && edit_entry.visible) {
                position_edit_entry();
            }
        });
    }
    
    // Drawing function
    private void draw_hex_view(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        // Calculate visible rows
        int first_visible_row = (int)(vadjustment.get_value() / byte_height);
        int visible_rows = (height / byte_height) + 1;
        
        // Disable antialiasing
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Set font - using Monaco as requested
        cr.select_font_face("Monaco", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        cr.set_font_size(12);
        cr.set_line_width(1.0);
        
        // Get theme colors
        var theme = Theme.Manager.get_default();
        Gdk.RGBA fg_color = theme.get_color("theme_fg");
        Gdk.RGBA selected_bg = theme.get_color("theme_selection");
        
        // Draw each visible cell
        for (int row = first_visible_row; row < first_visible_row + visible_rows; row++) {
            for (int col = 0; col < bytes_per_line; col++) {
                int byte_pos = row * bytes_per_line + col;
                
                // Calculate position
                int x = col * byte_width;
                int y = (row - first_visible_row) * byte_height;
                
                // Draw background based on selection
                if (byte_pos == selected_byte) {
                    // Selected background
                    cr.set_source_rgba(selected_bg.red, selected_bg.green, selected_bg.blue, selected_bg.alpha);
                    cr.rectangle(x, y, byte_width, byte_height);
                    cr.fill();
                }
                
                // Draw hex value - actual bytes or padding
                cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, fg_color.alpha);
                cr.move_to(x + 2, y + 14);
                
                if (byte_pos < buffer.length) {
                    // Real byte from buffer
                    cr.show_text(("%02x").printf(buffer[byte_pos]));
                } else if (row * bytes_per_line < buffer.length) {
                    // Padding at end of incomplete line
                    cr.show_text("00");
                }
            }
        }
    }
    
    // Handle clicks
    private void on_click_pressed(int n_press, double x, double y) {
        // Calculate which byte was clicked
        int first_visible_row = (int)(vadjustment.get_value() / byte_height);
        int row = first_visible_row + (int)(y / byte_height);
        int col = (int)(x / byte_width);
        
        int byte_pos = row * bytes_per_line + col;
        if (byte_pos < buffer.length) {
            // Select this byte
            parent_window.select_byte(byte_pos);
            
            // Handle double-click for editing
            if (n_press == 2) {
                start_editing(byte_pos);
            }
        }
    }
    
    // Start editing a byte
    public void start_editing(int byte_pos) {
        if (byte_pos >= buffer.length) return;
        
        // If currently editing a different byte, cancel it first
        if (editing_byte >= 0 && editing_byte != byte_pos && edit_entry != null) {
            cancel_editing();
        }
        
        // Create an entry for editing if we don't have one
        if (edit_entry == null) {
            edit_entry = new Gtk.Entry() {
                max_width_chars = 2,
                width_request = 20,
                height_request = 20,
                halign = Gtk.Align.START,
                valign = Gtk.Align.START
            };
            edit_entry.add_css_class("hex-edit");
            
            // Set up event handlers for the entry
            var entry_key = new Gtk.EventControllerKey();
            entry_key.key_pressed.connect((keyval, keycode, state) => {
                if (keyval == Gdk.Key.Escape) {
                    // Cancel editing
                    cancel_editing();
                    return true;
                }
                else if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                    // Commit the change
                    commit_edit();
                    return true;
                }
                else if (keyval == Gdk.Key.BackSpace) {
                    // Reset to 00 when backspace is pressed
                    edit_entry.text = "00";
                    commit_edit();
                    return true;
                }
                return false;
            });
            edit_entry.add_controller(entry_key);
            
            // Filter input to hex only
            edit_entry.insert_text.connect((new_text, new_text_length, ref position) => {
                string filtered = "";
                for (int i = 0; i < new_text_length; i++) {
                    char c = new_text[i];
                    if ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
                        filtered += c.to_string();
                    }
                }
                
                if (filtered != new_text) {
                    GLib.Signal.stop_emission_by_name(edit_entry, "insert-text");
                    edit_entry.insert_text(filtered, (int)filtered.length, ref position);
                }
            });
            
            // Handle focus out
            var focus_controller = new Gtk.EventControllerFocus();
            focus_controller.leave.connect(() => {
                if (editing_byte >= 0) {
                    commit_edit();
                }
            });
            edit_entry.add_controller(focus_controller);
            
            // Add the entry as an overlay
            var parent_overlay = (Gtk.Overlay)drawing_area.get_parent();
            parent_overlay.add_overlay(edit_entry);
        }
        
        // Store editing position and position the entry
        editing_byte = byte_pos;
        position_edit_entry();
        
        // Initialize with current value and focus
        edit_entry.text = ("%02x").printf(buffer[byte_pos]);
        edit_entry.visible = true;
        edit_entry.grab_focus();
        edit_entry.select_region(0, -1); // Select all text
    }
    
    // Position the edit entry correctly
    private void position_edit_entry() {
        if (edit_entry == null || editing_byte < 0) return;
        
        int row = editing_byte / bytes_per_line;
        int col = editing_byte % bytes_per_line;
        int first_visible_row = (int)(vadjustment.get_value() / byte_height);
        
        edit_entry.margin_start = col * byte_width;
        edit_entry.margin_top = (row - first_visible_row) * byte_height;
    }
    
    // Cancel editing
    private void cancel_editing() {
        if (edit_entry != null) {
            edit_entry.visible = false;
        }
        editing_byte = -1;
    }
    
    // Commit the edit
    private void commit_edit() {
        if (edit_entry == null || editing_byte < 0 || editing_byte >= buffer.length) {
            cancel_editing();
            return;
        }
        
        // Parse the hex value
        string text = edit_entry.text.down();
        if (text.length > 0) {
            // Ensure two-character hex format
            if (text.length == 1) {
                text = "0" + text;
            }
            
            // Parse the value
            int val = 0;
            if (int.try_parse("0x" + text, out val) && val >= 0 && val <= 255) {
                // Update the buffer
                buffer[editing_byte] = (uint8)val;
                
                // Notify the change
                if (byte_changed_callback != null) {
                    byte_changed_callback(editing_byte, (uint8)val);
                }
                
                // Redraw
                drawing_area.queue_draw();
            }
        }
        
        // Hide the entry
        edit_entry.visible = false;
        editing_byte = -1;
    }
    
    // Update selection
    public void set_selected_byte(int byte_pos) {
        if (selected_byte != byte_pos) {
            selected_byte = byte_pos;
            drawing_area.queue_draw();
        }
    }
    
    // Ensure selected byte is visible
    public void ensure_byte_visible(int byte_pos) {
        int row = byte_pos / bytes_per_line;
        double y = row * byte_height;
        
        double current = vadjustment.get_value();
        double page_size = vadjustment.get_page_size();
        
        if (y < current || y + byte_height > current + page_size) {
            // Scroll to make the byte visible
            double target = y - (page_size / 2);
            if (target < 0) target = 0;
            vadjustment.set_value(target);
        }
    }
    
    public void set_buffer(uint8[] new_buffer, int total_lines, int line_width) {
        this.buffer = new_buffer;
        this.bytes_per_line = line_width;
        
        // Update size request based on buffer size
        if (buffer.length > 0) {
            // Set minimum height to fit all lines
            int min_height = total_lines * byte_height;
            drawing_area.set_size_request(-1, min_height);
        } else {
            // Reset to default if buffer is empty
            drawing_area.set_size_request(-1, -1);
        }
        
        drawing_area.queue_draw();
    }
}