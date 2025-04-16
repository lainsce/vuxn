/*
 * Bitmap font renderer for Log application
 * Uses Cairo to render characters from the bitmap font data defined in assets.vala
 */
namespace LogApp {
    /**
     * Class for rendering bitmap text using Cairo
     * Handles text rendering with the original Log bitmap font
     */
    public class LogFontRenderer : Object {
        // Size of each character in the font
        public const int CHAR_WIDTH = 8;
        public const int CHAR_HEIGHT = 16;
        
        // Characters per row in a standard terminal
        public const int CHARS_PER_ROW = 40;
        
        // Default scale factor for rendering
        public double scale = 1.0;
        
        // Text buffer properties
        private string[] text_buffer;
        private int buffer_size = 1000;
        private int cursor_position = 0;
        private int cursor_line = 0;
        private int cursor_column = 0;
        private bool cursor_visible = true;
        private uint cursor_blink_timer = 0;
        
        // Colors
        private Gdk.RGBA text_color;
        private Gdk.RGBA bg_color;
        private Gdk.RGBA selection_color;
        private Gdk.RGBA accent_color;
        
        // View properties (for scrolling)
        private int view_start_line = 0;
        private int visible_lines = 0;
        
        // Reference to Theme Manager
        private Theme.Manager theme;
        
        /**
         * Create a new font renderer
         */
        public LogFontRenderer() {
            theme = Theme.Manager.get_default();
            
            // Initialize colors
            text_color = theme.get_color("theme_fg");
            bg_color = theme.get_color("theme_bg");
            selection_color = theme.get_color("theme_selection");
            accent_color = theme.get_color("theme_accent");
            
            // Initialize text buffer
            text_buffer = new string[buffer_size];
            for (int i = 0; i < buffer_size; i++) {
                text_buffer[i] = "";
            }
            
            // Setup cursor blinking
            cursor_blink_timer = GLib.Timeout.add(500, () => {
                cursor_visible = !cursor_visible;
                return true; // Keep the timer running
            });
            
            // Connect to theme changes
            theme.theme_changed.connect(update_colors);
        }
        
        /**
         * Update colors when theme changes
         */
        private void update_colors() {
            text_color = theme.get_color("theme_fg");
            bg_color = theme.get_color("theme_bg");
            selection_color = theme.get_color("theme_selection");
            accent_color = theme.get_color("theme_accent");
        }
        
        /**
         * Set the text to display
         */
        public void set_text(string text) {
            // Clear the buffer
            for (int i = 0; i < buffer_size; i++) {
                text_buffer[i] = "";
            }
            
            // Split the text into lines
            string[] lines = text.split("\n");
            
            // Copy lines to buffer (but don't exceed buffer size)
            int line_count = int.min(lines.length, buffer_size);
            for (int i = 0; i < line_count; i++) {
                text_buffer[i] = lines[i];
            }
            
            // Reset cursor to end of text
            cursor_line = line_count - 1;
            cursor_column = text_buffer[cursor_line].length;
            update_cursor_position();
            
            // Reset view to show the end of text
            ensure_cursor_visible();
        }
        
        /**
         * Append text to the buffer
         */
        public void append_text(string text) {
            // Split the text into lines
            string[] lines = text.split("\n");
            
            // First line appends to current line
            if (lines.length > 0 && lines[0].length > 0) {
                text_buffer[cursor_line] += lines[0];
                cursor_column = text_buffer[cursor_line].length;
            }
            
            // Remaining lines go to new lines
            for (int i = 1; i < lines.length; i++) {
                // Shift buffer up if needed
                if (cursor_line >= buffer_size - 1) {
                    // Buffer is full, shift everything up
                    for (int j = 0; j < buffer_size - 1; j++) {
                        text_buffer[j] = text_buffer[j + 1];
                    }
                    text_buffer[buffer_size - 1] = "";
                } else {
                    // Just increment line
                    cursor_line++;
                }
                
                text_buffer[cursor_line] = lines[i];
                cursor_column = text_buffer[cursor_line].length;
            }
            
            update_cursor_position();
            ensure_cursor_visible();
        }
        
        /**
         * Clear the buffer and reset cursor
         */
        public void clear() {
            for (int i = 0; i < buffer_size; i++) {
                text_buffer[i] = "";
            }
            
            cursor_line = 0;
            cursor_column = 0;
            cursor_position = 0;
            view_start_line = 0;
        }
        
        /**
         * Get the number of lines in use
         */
        public int get_line_count() {
            int count = 0;
            for (int i = 0; i < buffer_size; i++) {
                if (text_buffer[i].length > 0) {
                    count = i + 1;
                }
            }
            return count;
        }
        
        /**
         * Update cursor position based on line and column
         */
        private void update_cursor_position() {
            cursor_position = 0;
            for (int i = 0; i < cursor_line; i++) {
                cursor_position += text_buffer[i].length + 1; // +1 for newline
            }
            cursor_position += cursor_column;
        }
        
        /**
         * Ensure the cursor is in the visible area by adjusting view_start_line
         */
        private void ensure_cursor_visible() {
            if (cursor_line < view_start_line) {
                view_start_line = cursor_line;
            } else if (cursor_line >= view_start_line + visible_lines) {
                view_start_line = cursor_line - visible_lines + 1;
                if (view_start_line < 0) view_start_line = 0;
            }
        }
        
        /**
         * Scroll the view by the given number of lines
         */
        public void scroll(int lines) {
            view_start_line += lines;
            
            // Keep within bounds
            int max_start = get_line_count() - visible_lines;
            if (max_start < 0) max_start = 0;
            
            if (view_start_line < 0) {
                view_start_line = 0;
            } else if (view_start_line > max_start) {
                view_start_line = max_start;
            }
        }
        
        /**
         * Set the number of visible lines based on the widget height
         */
        public void set_visible_lines(int height) {
            visible_lines = height / (int)(CHAR_HEIGHT * scale);
            ensure_cursor_visible();
        }
        
        /**
         * Render the text using Cairo
         */
        public void render(Cairo.Context cr, int width, int height) {
            // Save context state
            cr.save();
            
            // Set up the context
            cr.set_antialias(Cairo.Antialias.NONE);
            cr.set_line_width(1.0);
            
            // Update visible lines
            set_visible_lines(height);
            
            // Clear background
            cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
            cr.paint();
            
            // Render visible text
            int start_line = view_start_line;
            int end_line = int.min(start_line + visible_lines, buffer_size);
            
            // Set text color
            cr.set_source_rgb(text_color.red, text_color.green, text_color.blue);
            
            for (int line = start_line; line < end_line; line++) {
                string text = text_buffer[line];
                if (text.length > 0) {
                    render_line(cr, text, 0, (line - start_line) * CHAR_HEIGHT * scale);
                }
            }
            
            // Draw cursor if visible
            if (cursor_visible && cursor_line >= start_line && cursor_line < end_line) {
                double cursor_x = cursor_column * CHAR_WIDTH * scale;
                double cursor_y = (cursor_line - start_line) * CHAR_HEIGHT * scale;
                
                // Set cursor color
                cr.set_source_rgb(accent_color.red, accent_color.green, accent_color.blue);
                
                // Draw the cursor character (using caret_icon from assets)
                render_icon(cr, Assets.caret_icon, cursor_x, cursor_y, 8, 8);
            }
            
            // Restore context state
            cr.restore();
        }
        
        /**
         * Render a line of text
         */
        private void render_line(Cairo.Context cr, string text, double x, double y) {
            double cursor_x = x;
            
            for (int i = 0; i < text.length; i++) {
                char c = text[i];
                
                render_char(cr, c, cursor_x, y);
                
                // Use 8px character width
                cursor_x += CHAR_WIDTH * scale;
            }
        }
        
        /**
         * Render a single character
         */
        private void render_char(Cairo.Context cr, unichar c, double x, double y) {
            // Only handle printable ASCII
            if (c < 32 || c > 126) return;
            
            // Get character index in the font data
            int char_index = (int)c - 32;
            
            // Each character has 8 shorts (4 for top tile, 4 for bottom tile)
            int data_offset = char_index * 8;
            
            // First render the top 8x8 tile (first 4 shorts)
            for (int row = 0; row < 4; row++) {
                uint16 rowdata = Assets.font_data[data_offset + row];
                
                // Each short contains data for 2 rows (8 pixels each)
                // Process high byte (first row of the pair)
                uint8 high_byte = (uint8)((rowdata >> 8) & 0xFF);
                for (int col = 0; col < 8; col++) {
                    // Using MSB first - check bit at position 7-col
                    if ((high_byte & (1 << (7 - col))) != 0) {
                        cr.rectangle(
                            x + col * scale,
                            y + (row * 2) * scale,
                            scale, scale
                        );
                        cr.fill();
                    }
                }
                
                // Process low byte (second row of the pair)
                uint8 low_byte = (uint8)(rowdata & 0xFF);
                for (int col = 0; col < 8; col++) {
                    // Using MSB first - check bit at position 7-col
                    if ((low_byte & (1 << (7 - col))) != 0) {
                        cr.rectangle(
                            x + col * scale,
                            y + (row * 2 + 1) * scale,
                            scale, scale
                        );
                        cr.fill();
                    }
                }
            }
            
            // Then render the bottom 8x8 tile (next 4 shorts)
            for (int row = 0; row < 4; row++) {
                uint16 rowdata = Assets.font_data[data_offset + 4 + row];
                
                // Each short contains data for 2 rows (8 pixels each)
                // Process high byte (first row of the pair)
                uint8 high_byte = (uint8)((rowdata >> 8) & 0xFF);
                for (int col = 0; col < 8; col++) {
                    // Using MSB first - check bit at position 7-col
                    if ((high_byte & (1 << (7 - col))) != 0) {
                        cr.rectangle(
                            x + col * scale,
                            y + (8 + row * 2) * scale,
                            scale, scale
                        );
                        cr.fill();
                    }
                }
                
                // Process low byte (second row of the pair)
                uint8 low_byte = (uint8)(rowdata & 0xFF);
                for (int col = 0; col < 8; col++) {
                    // Using MSB first - check bit at position 7-col
                    if ((low_byte & (1 << (7 - col))) != 0) {
                        cr.rectangle(
                            x + col * scale,
                            y + (8 + row * 2 + 1) * scale,
                            scale, scale
                        );
                        cr.fill();
                    }
                }
            }
        }
        
        /**
         * Render an icon/bitmap from data
         */
        private void render_icon(Cairo.Context cr, uint16[] icon_data, double x, double y, 
                               int width, int height) {
            // For each row
            for (int row = 0; row < height && row < icon_data.length; row++) {
                uint16 rowdata = icon_data[row];
                
                // For each column/bit in the row
                for (int col = 0; col < width; col++) {
                    // Check if bit is set (1 = draw pixel, 0 = transparent)
                    if ((rowdata & (1 << (width - 1 - col))) != 0) {
                        // Draw a pixel (scaled rectangle)
                        cr.rectangle(
                            x + col * scale,
                            y + row * scale,
                            scale,
                            scale
                        );
                        cr.fill();
                    }
                }
            }
        }
        
        /**
         * Render text in hex mode
         */
        public void render_hex(Cairo.Context cr, uint8[] data, int width, int height) {
            // First clear the text buffer
            clear();
            
            // Format data as hex
            StringBuilder hex = new StringBuilder();
            int bytes_per_row = 16;
            
            for (int i = 0; i < data.length; i += bytes_per_row) {
                // Add hex values
                for (int j = 0; j < bytes_per_row && i + j < data.length; j++) {
                    hex.append_printf("%02x ", data[i + j]);
                }
                
                // Pad if needed to align ASCII representation
                int remaining = bytes_per_row - (data.length - i < bytes_per_row ? data.length - i : bytes_per_row);
                for (int j = 0; j < remaining; j++) {
                    hex.append("   ");
                }
                hex.append("\n");
            }
            
            // Set the text and render
            set_text(hex.str);
            render(cr, width, height);
        }
        
        /**
         * Clean up resources
         */
        ~LogFontRenderer () {
            if (cursor_blink_timer != 0) {
                Source.remove(cursor_blink_timer);
                cursor_blink_timer = 0;
            }
        }
    }
    
    /**
     * A custom widget for displaying bitmap text
     * Implements scrolling and user interactions
     */
    public class LogTextView : Gtk.DrawingArea {
        private LogFontRenderer renderer;
        private string text = "";
        private bool hex_mode = false;
        private uint8[] current_data;
        
        // Scrolling support
        private Gtk.Adjustment vadjustment;
        private uint scroll_timer = 0;
        
        /**
         * Create a new text view
         */
        public LogTextView() {
            // Setup the drawing area
            set_draw_func(on_draw);
            
            // Create renderer
            renderer = new LogFontRenderer();
            
            // Enable scrolling
            set_hexpand(true);
            set_vexpand(true);
            
            // Add sensible margins
            margin_top = 8;
            margin_start = 8;
            margin_end = 8;
            margin_bottom = 8;
            
            // Set up scroll handling
            var scroll_controller = new Gtk.EventControllerScroll(
                Gtk.EventControllerScrollFlags.BOTH_AXES
            );
            scroll_controller.scroll.connect(on_scroll);
            add_controller(scroll_controller);
            
            // Set up key handling
            var key_controller = new Gtk.EventControllerKey();
            key_controller.key_pressed.connect(on_key_pressed);
            add_controller(key_controller);
        }
        
        /**
         * Set the text to display
         */
        public void set_text(string new_text) {
            text = new_text;
            
            if (hex_mode) {
                // Store as raw bytes for hex rendering
                current_data = new uint8[new_text.length];
                for (int i = 0; i < new_text.length; i++) {
                    current_data[i] = (uint8)new_text[i];
                }
            } else {
                // Set text directly
                renderer.set_text(new_text);
            }
            
            queue_draw();
        }
        
        /**
         * Append text to the view
         */
        public void append_text(string new_text) {
            text += new_text;
            
            if (hex_mode) {
                // Update raw data
                uint8[] new_data = new uint8[new_text.length];
                for (int i = 0; i < new_text.length; i++) {
                    new_data[i] = (uint8)new_text[i];
                }
                
                // Combine arrays
                uint8[] combined = new uint8[current_data.length + new_data.length];
                for (int i = 0; i < current_data.length; i++) {
                    combined[i] = current_data[i];
                }
                for (int i = 0; i < new_data.length; i++) {
                    combined[current_data.length + i] = new_data[i];
                }
                
                current_data = combined;
            } else {
                // Append directly
                renderer.append_text(new_text);
            }
            
            queue_draw();
        }
        
        /**
         * Set hex mode on/off
         */
        public void set_hex_mode(bool mode) {
            if (hex_mode == mode) return;
            
            hex_mode = mode;
            
            if (hex_mode) {
                // Convert current text to bytes for hex view
                current_data = new uint8[text.length];
                for (int i = 0; i < text.length; i++) {
                    current_data[i] = (uint8)text[i];
                }
            } else {
                // Set text directly
                renderer.set_text(text);
            }
            
            queue_draw();
        }
        
        /**
         * Get the current hex mode status
         */
        public bool get_hex_mode() {
            return hex_mode;
        }
        
        /**
         * Clear the text
         */
        public void clear() {
            text = "";
            current_data = new uint8[0];
            renderer.clear();
            queue_draw();
        }
        
        public void scroll_to_end() {
            // Scroll to show the latest content
            renderer.scroll(1000); // Large number to ensure scrolling to end
            queue_draw();
        }
        
        /**
         * Draw function for the widget
         */
        private void on_draw(Gtk.DrawingArea drawing_area, Cairo.Context cr, int width, int height) {
            if (hex_mode && current_data != null && current_data.length > 0) {
                // Render hex view
                renderer.render_hex(cr, current_data, width, height);
            } else {
                // Render text view
                renderer.render(cr, width, height);
            }
        }
        
        /**
         * Handle scrolling
         */
        private bool on_scroll(double dx, double dy) {
            // Scroll by lines based on direction
            int lines = (int)dy;
            if (lines != 0) {
                renderer.scroll(lines);
                queue_draw();
            }
            
            return true; // Event handled
        }
        
        /**
         * Handle key presses
         */
        private bool on_key_pressed(uint keyval, uint keycode, Gdk.ModifierType state) {
            bool handled = false;
            
            // Handle navigation keys
            switch (keyval) {
                case Gdk.Key.Up:
                    renderer.scroll(-1);
                    handled = true;
                    break;
                case Gdk.Key.Down:
                    renderer.scroll(1);
                    handled = true;
                    break;
                case Gdk.Key.Page_Up:
                    renderer.scroll(-10);
                    handled = true;
                    break;
                case Gdk.Key.Page_Down:
                    renderer.scroll(10);
                    handled = true;
                    break;
                case Gdk.Key.Home:
                    renderer.scroll(-1000); // Large number to scroll to top
                    handled = true;
                    break;
                case Gdk.Key.End:
                    renderer.scroll(1000); // Large number to scroll to bottom
                    handled = true;
                    break;
            }
            
            if (handled) {
                queue_draw();
            }
            
            return handled;
        }
        
        /**
         * Get the line count
         */
        public int get_line_count() {
            return renderer.get_line_count();
        }
        
        /**
         * Clean up resources
         */
        public override void dispose() {
            renderer.dispose();
            
            if (scroll_timer != 0) {
                Source.remove(scroll_timer);
                scroll_timer = 0;
            }
            
            base.dispose();
        }
    }
}