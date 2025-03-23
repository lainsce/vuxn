public class Window : Gtk.ApplicationWindow {
    private File? current_file = null;
    private uint8[] buffer = new uint8[0];
    private Gtk.DrawingArea minimap;
    private Gtk.Label range_label;
    private int bytes_per_line = 16;
    private int total_lines = 0;
    private Gtk.Adjustment vadjustment;
    
    // Replace grid containers with optimized views
    private HexView hex_view;
    private AsciiView ascii_view;
    private Gtk.Grid address_grid;
    
    // Currently selected byte
    private int selected_byte = -1;
    
    // Scrolled window reference for scrolling
    private Gtk.ScrolledWindow editor_scroll;

    public Window(Gtk.Application application) {
        Object(
            application: application,
            width_request: 640,
            height_request: 364,
            title: _("Hex Editor")
        );
        
        set_titlebar (
            new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                visible = false
            }
        );
        
        // Load CSS provider
        var provider = new Gtk.CssProvider();
        provider.load_from_resource("/com/example/hexedit/style.css");

        // Apply the CSS to the default display
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 10
        );

        setup_ui();
    }

    private void setup_ui() {
        // Main layout container
        var main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        this.set_child(main_box);

        // Add titlebar and main editor
        main_box.append(create_titlebar());

        // Column headers
        var header_box = create_column_headers();
        main_box.append(header_box);

        // Main editor area with scrolling
        editor_scroll = create_editor_area();
        main_box.append(editor_scroll);

        // Set up keyboard shortcuts
        var open_action = new SimpleAction("open", null);
        open_action.activate.connect(() => on_open_clicked());
        this.add_action(open_action);

        var save_action = new SimpleAction("save", null);
        save_action.activate.connect(() => on_save_clicked());
        this.add_action(save_action);

        // Add keyboard controller
        var key_controller = new Gtk.EventControllerKey();
        key_controller.key_pressed.connect((keyval, keycode, state) => {
            if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                if (keyval == Gdk.Key.o) {
                    on_open_clicked();
                    return true;
                } else if (keyval == Gdk.Key.s) {
                    on_save_clicked();
                    return true;
                }
            }
            return false;
        });
        main_box.add_controller(key_controller);

        // Initialize with empty buffer and update views
        update_views();
    }

    private Gtk.Widget create_titlebar() {
        // Create classic Mac-style title bar
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = 640;
        title_bar.add_css_class("title-bar");

        // Close button on the left
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = _("Close");
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;
        close_button.clicked.connect(() => this.close());

        var title_label = new Gtk.Label(this.title);
        title_label.add_css_class("title-box");
        title_label.hexpand = true;
        title_label.valign = Gtk.Align.CENTER;
        title_label.halign = Gtk.Align.CENTER;

        title_bar.append(close_button);
        title_bar.append(title_label);

        var winhandle = new Gtk.WindowHandle();
        winhandle.set_child(title_bar);

        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        vbox.append(winhandle);

        return vbox;
    }

    private Gtk.Box create_column_headers() {
        var header_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        header_box.add_css_class("data-bar");

        // Address header
        var address_header = new Gtk.Label(_("line"));
        address_header.add_css_class("column-header");
        address_header.xalign = 0;
        address_header.margin_start = 8;
        address_header.set_size_request(66, -1);
        header_box.append(address_header);

        // Hex editor header
        var hex_header = new Gtk.Label(_("data"));
        hex_header.add_css_class("column-header");
        hex_header.xalign = 0;
        hex_header.set_size_request(284, -1);
        header_box.append(hex_header);

        // Range label
        range_label = new Gtk.Label(_("0000"));
        range_label.add_css_class("column-header");
        range_label.add_css_class("column-header-range");
        range_label.xalign = 0;
        range_label.margin_end = 21;
        header_box.append(range_label);

        // ASCII header
        var ascii_header = new Gtk.Label(_("ascii"));
        ascii_header.add_css_class("column-header");
        ascii_header.xalign = 0;
        header_box.append(ascii_header);

        return header_box;
    }

    private Gtk.ScrolledWindow create_editor_area() {
        var scrolled = new Gtk.ScrolledWindow() {
            hexpand = true,
            vexpand = true
        };

        // Keep track of the vertical adjustment for syncing scrolling
        vadjustment = scrolled.get_vadjustment();
        vadjustment.value_changed.connect(() => {
            minimap.queue_draw();
            update_range_label();
            update_visible_address_labels();
        });

        // Create a container for the editor content
        var main_container = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        scrolled.set_child(main_container);

        // Horizontal layout for the components with separators
        var h_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        main_container.append(h_box);

        // 1. Address Grid
        address_grid = new Gtk.Grid() {
            margin_start = 8,
            column_spacing = 0,
            row_spacing = 0,
            width_request = 42,
            vexpand = true
        };
        h_box.append(address_grid);

        // Separator after address
        var separator1 = new Gtk.Separator(Gtk.Orientation.VERTICAL);
        h_box.append(separator1);

        // 2. Minimap
        minimap = new Gtk.DrawingArea() {
            width_request = 16
        };
        minimap.set_draw_func(draw_minimap);
        h_box.append(minimap);

        // Separator after minimap
        var separator2 = new Gtk.Separator(Gtk.Orientation.VERTICAL) {
            margin_end = 4
        };
        h_box.append(separator2);

        // 3. Hex View (optimized replacement for hex_grid)
        hex_view = new HexView(buffer, vadjustment, this);
        hex_view.set_size_request(332, -1);
        hex_view.byte_changed_callback = on_byte_changed;
        h_box.append(hex_view);

        // Separator after hex view
        var separator3 = new Gtk.Separator(Gtk.Orientation.VERTICAL) {
            margin_end = 4
        };
        h_box.append(separator3);

        // 4. ASCII View (optimized replacement for ascii_grid)
        ascii_view = new AsciiView(buffer, vadjustment, this);
        ascii_view.hexpand = true;
        ascii_view.byte_changed_callback = on_byte_changed;
        h_box.append(ascii_view);

        return scrolled;
    }

    // Update views with current buffer - optimized to use custom views
    private void update_views() {
        if (buffer.length == 0) {
            total_lines = 0;
            
            // Clear address labels
            var address_child = address_grid.get_first_child();
            while (address_child != null) {
                address_child.set_visible(false);
                address_child = address_child.get_next_sibling();
            }
            
            minimap.queue_draw();
            update_range_label();
            return;
        }
        
        // Calculate total lines including padding for incomplete last line
        total_lines = (buffer.length + bytes_per_line - 1) / bytes_per_line;
        
        // Set appropriate total height for scrolling
        // This is crucial for proper address line alignment
        vadjustment.set_upper(total_lines * 20); // 20px per line
        vadjustment.set_step_increment(20); // Step by one line at a time
        vadjustment.set_page_increment(20 * 5); // 5 lines per page
        
        // Update the buffer reference in the views
        hex_view.set_buffer(buffer, total_lines, bytes_per_line);
        ascii_view.set_buffer(buffer, total_lines, bytes_per_line);
        
        // Update visible address labels
        update_visible_address_labels();
        
        // Update the minimap and range label
        minimap.queue_draw();
        update_range_label();
        
        // Clear any selection
        clear_selection();
    }
    
    // Update only the visible address labels (virtualized approach)
    private void update_visible_address_labels() {
        if (buffer.length == 0) return;
        
        // Calculate row heights precisely aligned with the scroll position
        int row_height = 20; // Must match byte_height in views
        int visible_rows = (int)(editor_scroll.get_height() / row_height) + 1;
        int first_visible_row = (int)(vadjustment.get_value() / row_height);
        
        // Clear all existing labels first
        var address_child = address_grid.get_first_child();
        while (address_child != null) {
            var next_child = address_child.get_next_sibling();
            address_grid.remove(address_child);
            address_child = next_child;
        }
        
        // Create labels for visible rows only
        for (int row = first_visible_row; row < total_lines; row++) {
            // Create address label
            var addr_label = new Gtk.Label(("%04x").printf(row * bytes_per_line)) {
                xalign = 0,
                height_request = row_height
            };
            addr_label.add_css_class("address-cell");
            
            // Add selection if this is the row with the selected byte
            if (selected_byte >= 0 && row == selected_byte / bytes_per_line) {
                addr_label.add_css_class("selected-address");
            }
            
            var addr_gesture = new Gtk.GestureClick();
            addr_gesture.button = 1;
            int line_num = row;
            addr_gesture.pressed.connect(() => {
                int byte_pos = line_num * bytes_per_line;
                if (byte_pos < buffer.length) {
                    select_byte(byte_pos);
                }
            });
            addr_label.add_controller(addr_gesture);
            
            address_grid.attach(addr_label, 0, row - first_visible_row);
        }
    }

    // Select a byte in both views
    public void select_byte(int byte_pos) {
        if (byte_pos >= buffer.length) return;
        
        // Clear any previous selection
        clear_selection();
        
        // Store the selected byte position
        selected_byte = byte_pos;
        
        // Select in hex and ASCII views
        hex_view.set_selected_byte(byte_pos);
        ascii_view.set_selected_byte(byte_pos);
        
        // Calculate line and select address label
        int line = byte_pos / bytes_per_line;
        int first_visible_row = (int)(vadjustment.get_value() / 20);
        var addr_widget = address_grid.get_child_at(0, line - first_visible_row);
        if (addr_widget != null) {
            addr_widget.add_css_class("selected-address");
        }
        
        // Update range label to show selected byte
        range_label.label = _("%04x").printf(byte_pos);
        
        // Ensure the selected byte is visible
        hex_view.ensure_byte_visible(byte_pos);
        ascii_view.ensure_byte_visible(byte_pos);
    }
    
    // Clear selection
    private void clear_selection() {
        if (selected_byte < 0) return;
        
        // Clear selection in views
        hex_view.set_selected_byte(-1);
        ascii_view.set_selected_byte(-1);
        
        // Clear address selection
        var address_child = address_grid.get_first_child();
        while (address_child != null) {
            address_child.remove_css_class("selected-address");
            address_child = address_child.get_next_sibling();
        }
        
        selected_byte = -1;
    }
    
    // Handle byte changes from either view
    public void on_byte_changed(int index, uint8 value) {
        if (index >= 0 && index < buffer.length) {
            // Update the buffer
            buffer[index] = value;
            
            // Update both views
            hex_view.queue_draw();
            ascii_view.queue_draw();
            
            // Update the minimap
            minimap.queue_draw();
        }
    }

    // Draw the minimap - visualizes the entire file
    private void draw_minimap(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        var theme = Theme.Manager.get_default();

        // Fill background
        Gdk.RGBA bg = theme.get_color("theme_bg");
        Gdk.RGBA fg = theme.get_color("theme_fg");
        cr.set_source_rgb(bg.red, bg.green, bg.blue);
        cr.paint();

        if (buffer.length == 0 || total_lines == 0) {
            return; // Nothing to draw
        }

        // Fixed cell dimensions - 8px width, 16px height to match 8x8 grid
        int cell_width = 8;
        int cell_height = 16; // Match the address line height (font size)

        // Center the minimap horizontally
        double x_offset = (width - cell_width) / 2.0;

        // Start at y position 0
        double y_position = 0;

        // Calculate visible lines based on vadjustment
        double scroll_value = vadjustment.get_value();
        int first_visible_line = (int)(scroll_value / cell_height);
        int visible_lines = (int)(height / cell_height) + 1;

        // Set line width to exactly 1px
        cr.set_line_width(1.0);
        // Disable anti-aliasing
        cr.set_antialias(Cairo.Antialias.NONE);

        // Draw only the visible lines
        for (int line = first_visible_line; line < first_visible_line + visible_lines && line < total_lines; line++) {
            // Calculate base address for this line
            int base_address = line * bytes_per_line;

            // Skip if we're beyond the buffer
            if (base_address >= buffer.length) {
                continue;
            }

            // Create an 8×16 bit array for this cell (all initialized to false)
            bool[,] cell_pixels = new bool[8, 16];

            // Process each byte in this line
            for (int byte_idx = 0; byte_idx < bytes_per_line && (base_address + byte_idx) < buffer.length; byte_idx++) {
                // Get the byte value
                uint8 byte_value = buffer[base_address + byte_idx];

                // Split into high and low nibbles
                uint8 high_nibble = (byte_value >> 4) & 0x0F;
                uint8 low_nibble = byte_value & 0x0F;

                // Calculate position in the cell
                int row = byte_idx % 16; // Map to 0-15 rows in the cell

                // Set pixel values based on nibbles
                // High nibble (left 4 columns)
                for (int bit = 0; bit < 4; bit++) {
                    if ((high_nibble & (1 << (3 - bit))) != 0) {
                        cell_pixels[bit, row] = true;
                    }
                }

                // Low nibble (right 4 columns)
                for (int bit = 0; bit < 4; bit++) {
                    if ((low_nibble & (1 << (3 - bit))) != 0) {
                        cell_pixels[bit + 4, row] = true;
                    }
                }
            }

            // Draw the cell pixel by pixel
            for (int y = 0; y < 16; y++) {
                for (int x = 0; x < 8; x++) {
                    if (cell_pixels[x, y]) {
                        // Use foreground color for set bits
                        cr.set_source_rgb(fg.red, fg.green, fg.blue);

                        // Calculate scaled position to fit the cell_height
                        double pixel_x = x_offset + x;
                        double pixel_y = y_position + (y * cell_height / 16.0);

                        // Draw a 1px pixel to maintain 8x8 grid
                        cr.rectangle(pixel_x, pixel_y, 1, cell_height / 16.0);
                        cr.fill();
                    }
                }
            }

            y_position += cell_height;

            // Stop drawing if we've gone beyond the visible area
            if (y_position >= height) {
                break;
            }
        }
    }

    // Update the range label with current view information
    private void update_range_label() {
        if (buffer.length == 0) {
            range_label.label = _("0000");
            return;
        }

        double start_pos = vadjustment.get_value();
        double total_height = vadjustment.get_upper();

        // Calculate the visible range of bytes
        int start_byte = (int)((start_pos / total_height) * buffer.length);
        
        // Format as hex addresses
        range_label.label = _("%04x").printf(start_byte);
    }
    
    // Optimized file loading that can handle larger files efficiently
    private void load_file(File file) {
        try {
            FileInfo info = file.query_info("standard::size", FileQueryInfoFlags.NONE);
            int64 size = info.get_size();

            if (size <= 0) {
                buffer = new uint8[0];
                update_views();
                this.title = _("Hex Editor - %s (Empty)").printf(file.get_basename());
                return;
            }

            if (size > int.MAX) {
                Utils.show_error_dialog(
                    this,
                    _("File too large"),
                    _("File too large to open (max: %lld bytes)").printf(int.MAX)
                );
                return;
            }

            // Create a new buffer with the right size
            uint8[] new_buffer = new uint8[(int)size];

            // Read the file efficiently
            var stream = file.read();
            size_t bytes_read;
            
            try {
                // Use buffered reading for better performance with large files
                var buffer_stream = new BufferedInputStream(stream);
                buffer_stream.read_all(new_buffer, out bytes_read);
                
                if (bytes_read != size) {
                    // Create a new properly sized buffer if we didn't read the full file
                    uint8[] resized_buffer = new uint8[(int)bytes_read];
                    Memory.copy(resized_buffer, new_buffer, (int)bytes_read);
                    buffer = resized_buffer;
                } else {
                    buffer = new_buffer;
                }
            } catch (Error e) {
                warning("Error reading file: %s\n", e.message);
                // Continue with what we were able to read
                if (bytes_read > 0) {
                    uint8[] resized_buffer = new uint8[(int)bytes_read];
                    Memory.copy(resized_buffer, new_buffer, (int)bytes_read);
                    buffer = resized_buffer;
                } else {
                    buffer = new uint8[0];
                }
            }

            this.title = _("Hex Editor - %s").printf(file.get_basename());
            update_views();
        } catch (Error e) {
            Utils.show_error_dialog(
                this,
                _("Error opening file"),
                e.message
            );
        }
    }

    // File open handler
    private void on_open_clicked() {
        var file_dialog = new Gtk.FileDialog() {
            title = _("Open File"),
            modal = true
        };

        file_dialog.open.begin(this, null, (obj, res) => {
            try {
                current_file = file_dialog.open.end(res);
                if (current_file != null) {
                    load_file(current_file);
                }
            } catch (Error e) {
                if (!(e is IOError.CANCELLED)) {
                    Utils.show_error_dialog(this, _("Error opening file dialog"), e.message);
                }
            }
        });
    }

    // File save handler
    private void on_save_clicked() {
        if (current_file == null) {
            var file_dialog = new Gtk.FileDialog() {
                title = _("Save File"),
                modal = true
            };

            file_dialog.save.begin(this, null, (obj, res) => {
                try {
                    current_file = file_dialog.save.end(res);
                    if (current_file != null) {
                        save_file(current_file);
                    }
                } catch (Error e) {
                    if (!(e is IOError.CANCELLED)) {
                        Utils.show_error_dialog(this, _("Error opening save dialog"), e.message);
                    }
                }
            });
        } else {
            save_file(current_file);
        }
    }

    // Save buffer to file
    private void save_file(File file) {
        try {
            // For better performance with larger files, use buffered output
            var stream = file.replace(null, false, FileCreateFlags.NONE);
            var buffered_stream = new BufferedOutputStream(stream);

            if (buffer.length > 0) {
                size_t bytes_written;
                buffered_stream.write_all(buffer, out bytes_written);
                buffered_stream.flush(); // Ensure all data is written

                if (bytes_written != buffer.length) {
                    Utils.show_warning_dialog(
                        this,
                        _("Incomplete Write"),
                        _("Warning: Only %lld of %lld bytes were written").printf(
                            bytes_written, buffer.length)
                    );
                } else {
                    Utils.show_info_dialog(
                        this,
                        _("Success"),
                        _("File saved successfully!")
                    );
                }
            } else {
                // Create empty file
                buffered_stream.close();
                Utils.show_info_dialog(
                    this,
                    _("Success"),
                    _("Empty file saved successfully!")
                );
            }
        } catch (Error e) {
            Utils.show_error_dialog(
                this,
                _("Error saving file"),
                e.message
            );
        }
    }
}