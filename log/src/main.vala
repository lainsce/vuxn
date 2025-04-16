namespace LogApp {
    public class App : Gtk.Application {
        private Gtk.ApplicationWindow window;
        private Gtk.Box main_box;
        private Gtk.ScrolledWindow scrolled_window;
        private Gtk.Widget text_view;
        private Gtk.TextBuffer buffer;
        private Theme.Manager theme;
        
        // Log-specific additions
        private bool hex_mode = false;
        private File snarf_file;
        private FileMonitor snarf_monitor;
        private Gtk.Label status_label;
        
        public App() {
            Object(
                application_id: "com.example.log",
                flags: ApplicationFlags.FLAGS_NONE
            );
        }
        
        public override void activate() {
            // Create the main window
            window = new Gtk.ApplicationWindow(this) {
                title = "Log",
                default_width = 440,
                default_height = 240
            };
            
            window.set_titlebar(
                new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0) {
                    visible = false
                }
            );
            
            theme = Theme.Manager.get_default();
            theme.apply_to_display();
            setup_theme_management();
            
            // Create the main box
            main_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            window.set_child(main_box);
            
            // Add keyboard event controller to main_box (as per user preference)
            var key_controller = new Gtk.EventControllerKey();
            key_controller.key_pressed.connect(on_key_pressed);
            main_box.add_controller(key_controller);
            
            // Create the sidebar
            var sidebar = new LogSidebar();
            sidebar.close_clicked.connect(() => {
                window.close();
            });
            theme.theme_changed.connect(sidebar.queue_draw);
            
            var win_handle = new Gtk.WindowHandle();
            win_handle.set_child(sidebar);
            
            main_box.append(win_handle);
            
            // Create the content area
            create_content_area();
            
            // Setup snarf file monitoring
            setup_snarf_monitoring();
            
            // Show the window
            window.present();
        }
        
        private void create_content_area() {
            var content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            content_box.set_hexpand(true);
            content_box.set_vexpand(true);
            main_box.append(content_box);
            
            // Status label
            status_label = new Gtk.Label("Monitoring clipboard");
            status_label.set_halign(Gtk.Align.START);
            status_label.set_margin_start(4);
            status_label.set_margin_end(4);
            status_label.set_margin_top(4);
            status_label.set_margin_bottom(4);
            content_box.append(status_label);
            
            // Create scrolled window
            scrolled_window = new Gtk.ScrolledWindow();
            scrolled_window.set_hexpand(true);
            scrolled_window.set_vexpand(true);
            content_box.append(scrolled_window);
            
            // Create LogTextView instead of TextView
            text_view = new LogApp.LogTextView();
            
            // Add text view to scrolled window
            scrolled_window.set_child(text_view);
        }
        
        private string rgba_to_hex(Gdk.RGBA color) {
            // Ensure values are in 0-1 range
            double r = double.max(0, double.min(1, color.red));
            double g = double.max(0, double.min(1, color.green));
            double b = double.max(0, double.min(1, color.blue));
            
            // Convert to 0-255 range with rounding
            uint8 r_int = (uint8)Math.round(r * 255);
            uint8 g_int = (uint8)Math.round(g * 255);
            uint8 b_int = (uint8)Math.round(b * 255);
            
            return "#%02x%02x%02x".printf(r_int, g_int, b_int);
        }
        
        private void setup_snarf_monitoring() {
            try {
                // Get the .snarf file path
                string snarf_path = Path.build_filename(Environment.get_home_dir(), ".snarf");
                snarf_file = File.new_for_path(snarf_path);
                
                // Create the file if it doesn't exist
                if (!snarf_file.query_exists()) {
                    var output_stream = snarf_file.create(FileCreateFlags.NONE);
                    output_stream.close();
                }
                
                // Set up monitoring
                snarf_monitor = snarf_file.monitor_file(FileMonitorFlags.NONE);
                snarf_monitor.changed.connect(on_snarf_changed);
                
                // Initial read
                read_snarf_file();
            } catch (Error e) {
                append_text(get_timestamp() + " Error setting up clipboard monitoring: " + e.message + "\n", "error");
            }
        }
        
        private void on_snarf_changed(File file, File? other_file, FileMonitorEvent event) {
            if (event == FileMonitorEvent.CHANGED || 
                event == FileMonitorEvent.CREATED || 
                event == FileMonitorEvent.CHANGES_DONE_HINT) {
                // The file has changed, read its contents
                read_snarf_file();
            }
        }
        
        private void read_snarf_file() {
            try {
                // Clear the buffer
                buffer.set_text("", 0);
                
                // Read the file content
                uint8[] contents;
                string etag_out;
                snarf_file.load_contents(null, out contents, out etag_out);
                
                // Get file info for size
                FileInfo info = snarf_file.query_info("standard::size", FileQueryInfoFlags.NONE);
                int64 size = info.get_size();
                
                // Update status
                status_label.set_text("Clipboard: " + format_size(size) + " - " + 
                                     (hex_mode ? "Hex Mode" : "Text Mode"));
                
                // Display the content
                if (hex_mode) {
                    display_hex_content(contents);
                } else {
                    display_text_content(contents);
                }
            } catch (Error e) {
                append_text(get_timestamp() + " Error reading clipboard: " + e.message + "\n", "error");
            }
        }
        
        private void display_text_content(uint8[] data) {
            try {
                string text = (string) data;
                ((LogApp.LogTextView)text_view).set_text(text);
            } catch (Error e) {
                append_text("Error displaying text content: " + e.message + "\n", "error");
            }
        }
        
        private void display_hex_content(uint8[] data) {
            ((LogApp.LogTextView)text_view).set_hex_mode(true);
            ((LogApp.LogTextView)text_view).set_text((string)data);
        }
        
        private string format_size(int64 size) {
            if (size < 1024) {
                return size.to_string() + "B";
            } else if (size < 1024 * 1024) {
                return "%.1fKB".printf(size / 1024.0);
            } else {
                return "%.1fMB".printf(size / (1024.0 * 1024.0));
            }
        }
        
        // Method to toggle hex mode
        private void toggle_hex_mode() {
            hex_mode = !hex_mode;
            ((LogApp.LogTextView)text_view).set_hex_mode(hex_mode);
            
            // Re-read the file to update the display
            read_snarf_file();
        }
        
        // Clipboard paste operation
        private void paste_from_clipboard() {
            // Get GTK clipboard
            var clipboard = Gdk.Display.get_default().get_clipboard();
            
            // Request text content asynchronously using the generic value API
            clipboard.read_value_async.begin(typeof(string), 0, null, (obj, async_result) => {
                try {
                    // Get the value using the async result
                    Value value = clipboard.read_text_async.end(async_result);
                    
                    if (value.holds(typeof(string))) {
                        string text = value.get_string();

                        // Write to snarf file
                        FileOutputStream os = snarf_file.replace(null, false, FileCreateFlags.NONE);
                        os.write(text.data);
                        os.close();
                    }
                } catch (Error e) {
                }
            });
        }

        private void copy_to_clipboard() {
            try {
                // Read current clipboard content
                uint8[] contents;
                string etag_out;
                snarf_file.load_contents(null, out contents, out etag_out);
                
                // Convert to string (if possible)
                string text;
                try {
                    text = (string) contents;
                } catch (Error e) {
                    // If we can't convert to string, create a hex representation
                    var builder = new StringBuilder();
                    foreach (uint8 b in contents) {
                        builder.append_printf("%02x ", b);
                    }
                    text = builder.str;
                }
                
                // Create a value for the text
                Value val = Value(typeof(string));
                val.set_string(text);
                
                // Create a content provider from the value
                var provider = new Gdk.ContentProvider.for_value(val);
                
                // Set the clipboard content
                var clipboard = Gdk.Display.get_default().get_clipboard();
                clipboard.set_content(provider);
            } catch (Error e) {
                append_text(get_timestamp() + " Error copying to clipboard: " + e.message + "\n", "error");
            }
        }
        
        private void append_text(string text, string? tag = null) {
            ((LogApp.LogTextView)text_view).append_text(text);
            
            // Scroll to end
            scroll_to_bottom();
        }
        
        // Helper method to get a timestamp string
        private string get_timestamp() {
            var now = new DateTime.now_local();
            return now.format("[%H:%M:%S]");
        }
        
        // Dedicated method for scrolling to ensure it happens correctly
        private void scroll_to_bottom() {
            Idle.add(() => {
                if (text_view is LogApp.LogTextView) {
                    ((LogApp.LogTextView)text_view).scroll_to_end();
                } else if (text_view is Gtk.TextView) {
                    Gtk.TextIter end;
                    buffer.get_end_iter(out end);
                    buffer.place_cursor(end);
                    ((Gtk.TextView)text_view).scroll_to_mark(buffer.get_insert(), 0.0, true, 0.0, 1.0);
                }
                return false;
            });
        }
        
        private bool on_key_pressed(Gtk.EventControllerKey controller, uint keyval, uint keycode, Gdk.ModifierType state) {
            // Only support Ctrl+H, Ctrl+C, and Ctrl+V
            bool ctrl_pressed = (state & Gdk.ModifierType.CONTROL_MASK) != 0;
            
            if (ctrl_pressed) {
                if (keyval == Gdk.Key.h || keyval == Gdk.Key.H) {
                    toggle_hex_mode();
                    return true;
                } else if (keyval == Gdk.Key.c || keyval == Gdk.Key.C) {
                    copy_to_clipboard();
                    return true;
                } else if (keyval == Gdk.Key.v || keyval == Gdk.Key.V) {
                    paste_from_clipboard();
                    return true;
                }
            }
            
            return false; // Allow key to be processed by other handlers
        }
        
        private void setup_theme_management() {
            // Force initial theme load
            var theme_file = GLib.Path.build_filename(Environment.get_home_dir(), ".theme");

            // Set up the check
            GLib.Timeout.add(10, () => {
                if (FileUtils.test(theme_file, FileTest.EXISTS)) {
                    try {
                        theme.load_theme_from_file(theme_file);
                    } catch (Error e) {
                        warning("Theme load failed: %s", e.message);
                    }
                }
                return true; // Continue the timeout
            });
        }
        
        public static int main(string[] args) {
            return new App().run(args);
        }
    }

    // Simplified sidebar widget with original close button design
    public class LogSidebar : Gtk.DrawingArea {
        // Signal for close button clicks
        public signal void close_clicked();
        
        private bool button_hovered = false;
        private bool button_pressed = false;
        private const int BUTTON_SIZE = 12;
        
        private Theme.Manager theme;
        
        public LogSidebar() {
            theme = Theme.Manager.get_default();

            // Set fixed width of 16px like in the original Log
            set_size_request(16, -1);
            set_hexpand(false);
            set_vexpand(true);
            
            // Set up drawing
            set_draw_func(draw);
            
            // Add click controller
            var click = new Gtk.GestureClick();
            click.set_button(1); // Left mouse button
            click.pressed.connect(on_pressed);
            click.released.connect(on_released);
            add_controller(click);
            
            // Add motion controller for hover effect
            var motion = new Gtk.EventControllerMotion();
            motion.enter.connect(() => {
                // We'll set button_hovered based on y position in motion
            });
            motion.leave.connect(() => {
                button_hovered = false;
                queue_draw();
            });
            motion.motion.connect((x, y) => {
                // Check if mouse is over the button area
                bool over_button = y < BUTTON_SIZE + 2;
                if (over_button != button_hovered) {
                    button_hovered = over_button;
                    queue_draw();
                }
            });
            add_controller(motion);
        }
        
        private void on_pressed(int n_press, double x, double y) {
            if (y < BUTTON_SIZE + 2) {
                button_pressed = true;
                queue_draw();
            }
        }
        
        private void on_released(int n_press, double x, double y) {
            if (button_pressed && y < BUTTON_SIZE + 2) {
                close_clicked();
            }
            button_pressed = false;
            queue_draw();
        }
        
        private void draw(Gtk.DrawingArea drawing_area, Cairo.Context cr, int width, int height) {
            // Disable antialiasing as per user preference
            cr.set_antialias(Cairo.Antialias.NONE);
            
            // Draw the checkerboard pattern
            draw_checkerboard(cr, width, height);
            
            // Draw the close button
            draw_close_button(cr);
        }
        
        private void draw_checkerboard(Cairo.Context cr, int width, int height) {
            // Draw background
            Gdk.RGBA bg_color = theme.get_color("theme_bg");
            Gdk.RGBA fg_color = theme.get_color("theme_fg");
            
            cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
            cr.paint();
            
            // Set color for the checkerboard squares
            cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
            cr.set_line_width(1.0); // 1px thick lines as requested
            
            // Draw 2x2 checkerboard pattern like in Log
            for (int y = 0; y < height; y += 1) {
                for (int x = 0; x < width; x += 1) {
                    // If this is a square that should be filled
                    if ((x + y) % 2 == 0) {
                        cr.rectangle(x, y, 1, 1);
                        cr.fill();
                    }
                }
            }
        }
        
        private void draw_close_button(Cairo.Context cr) {
            int x = 2;
            int y = 2;
            
            // Adjust the button's appearance based on state
            if (button_pressed) {
                x += 1;
                y += 1;
            }
            
            Gdk.RGBA bg_color = theme.get_color("theme_bg");
            Gdk.RGBA fg_color = theme.get_color("theme_fg");
            
            // White unfilled rectangle
            cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
            cr.set_line_width(1.0);
            cr.rectangle(x, y, BUTTON_SIZE, BUTTON_SIZE);
            cr.stroke();
            
            // Black unfilled rectangle
            cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
            cr.rectangle(x + 1, y + 1, BUTTON_SIZE - 2, BUTTON_SIZE - 2);
            cr.stroke();
            
            // White filled rectangle
            cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
            cr.rectangle(x + 2, y + 2, BUTTON_SIZE - 4, BUTTON_SIZE - 4);
            cr.fill();
            
            // Circle
            cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
            double center_x = x + BUTTON_SIZE / 2.0;
            double center_y = y + BUTTON_SIZE / 2.0;
            double radius = (BUTTON_SIZE - 6) / 2.0;
            cr.arc(center_x, center_y, radius, 0, 2 * Math.PI);
            cr.fill();
        }
    }
}