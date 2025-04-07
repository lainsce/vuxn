/*
 * ColorPickerWidget.vala
 * 
 * A custom color picker widget with three Cairo-drawn bars and pixel font display
 */

using Gtk;

namespace App {
    public class ColorPickerWidget : Gtk.Box {
        // Constants
        private const int BAR_WIDTH = 68;
        private const int BAR_HEIGHT = 14;
        private const int BAR_GAP = 1;
        private const int CHECKERBOARD_SIZE = 2;
        
        // UI elements
        private Gtk.DrawingArea bars_area;
        private Gtk.Label hex_label;
        
        // Current color values (0-15 for positions on bars)
        private int red_position = 0;
        private int green_position = 0;
        private int blue_position = 0;
        
        // Computed color values (0-1 for RGB)
        private float red_value = 0;
        private float green_value = 0;
        private float blue_value = 0;
        
        // Theme Manager
        private Theme.Manager theme;

        // Color change signal
        public signal void color_set();
        
        /**
         * Constructor
         */
        public ColorPickerWidget() {
            Object(
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 7
            );
            
            theme = Theme.Manager.get_default();
            theme.apply_to_display();
            theme.theme_changed.connect(() => {
                bars_area.queue_draw();
            });
            
            // Create the Cairo drawing area for the color bars
            create_color_bars();
            setup_theme_management();
            
            // Create the hex code label
            hex_label = new Gtk.Label("000");
            hex_label.add_css_class("pixel-font");
            hex_label.halign = Gtk.Align.START;
            
            // Add components to the main container
            this.append(bars_area);
            this.append(hex_label);
            
            // Apply CSS for pixel font styling
            var css_provider = new Gtk.CssProvider();
            try {
                css_provider.load_from_data("""
                    .pixel-font {
                        font-family: "Monaco";
                        font-size: 12px;
                    }
                """.data);
                Gtk.StyleContext.add_provider_for_display(
                    Gdk.Display.get_default(),
                    css_provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                );
            } catch (Error e) {
                warning("Failed to load CSS: %s", e.message);
            }
            
            // Initialize values
            update_label();
        }
        
        private void setup_theme_management() {
            string theme_file = GLib.Path.build_filename(Environment.get_home_dir(), ".theme");
            
            Timeout.add(10, () => {
                if (FileUtils.test(theme_file, FileTest.EXISTS)) {
                    try {
                        theme.load_theme_from_file(theme_file);
                    } catch (Error e) {
                        warning("Theme load failed: %s", e.message);
                    }
                }
                return true;
            });
        }
        
        /**
         * Creates the color bars drawing area
         */
        private void create_color_bars() {
            int total_height = (BAR_HEIGHT * 3) + BAR_GAP;
            
            bars_area = new Gtk.DrawingArea() {
                content_width = BAR_WIDTH,
                content_height = total_height
            };
            
            // Setup drawing function
            bars_area.set_draw_func((area, cr, width, height) => {
                // Draw each color bar
                draw_color_bar(cr, 0, 0, red_position);                 // Red bar
                draw_color_bar(cr, 0, BAR_HEIGHT - BAR_GAP, green_position);  // Green bar
                draw_color_bar(cr, 0, (BAR_HEIGHT - BAR_GAP) * 2, blue_position);  // Blue bar
            });
            
            // Add click gesture
            var click_gesture = new Gtk.GestureClick();
            click_gesture.set_button(1); // Primary button
            click_gesture.pressed.connect((n_press, x, y) => {
                handle_bar_click(x, y);
            });
            bars_area.add_controller(click_gesture);
            
            // Add motion controller for drag operations
            var motion_controller = new Gtk.EventControllerMotion();
            motion_controller.motion.connect((x, y) => {
                // Only update if mouse button is pressed (checked in the drag handler)
            });
            bars_area.add_controller(motion_controller);
            
            // Add drag gesture
            var drag_gesture = new Gtk.GestureDrag();
            drag_gesture.drag_update.connect((offset_x, offset_y) => {
                double start_x, start_y;
                drag_gesture.get_start_point(out start_x, out start_y);
                handle_bar_click(start_x + offset_x, start_y + offset_y);
            });
            bars_area.add_controller(drag_gesture);
        }
        
        /**
         * Draws a single color bar with checkerboard background
         * 
         * @param cr Cairo context
         * @param x X position
         * @param y Y position
         * @param position Current position (0-15)
         */
        private void draw_color_bar(Cairo.Context cr, int x, int y, int position) {
            // Calculate the active width based on position (0-15)
            float active_width = (position + 1) * (BAR_WIDTH / 16.0f);
            
            // Draw checkerboard pattern for background
            draw_checkerboard(cr, x + 1, y + 1, BAR_WIDTH - 2, BAR_HEIGHT - 2);
            
            // Draw active part of the bar
            var se_color = theme.get_color ("theme_selection");
            cr.set_source_rgb(se_color.red, se_color.green, se_color.blue);
            cr.rectangle(x + 1, y + 1, active_width - 2, BAR_HEIGHT - 2);
            cr.fill();
        }
        
        /**
         * Draws a checkerboard pattern
         */
        private void draw_checkerboard(Cairo.Context cr, int x, int y, int width, int height) {
            // Save the current state
            cr.save();
            
            // Create the checkerboard pattern
            for (int cy = y; cy < y + height; cy += CHECKERBOARD_SIZE) {
                for (int cx = x; cx < x + width; cx += CHECKERBOARD_SIZE) {
                    bool is_light = ((cx / CHECKERBOARD_SIZE) + (cy / CHECKERBOARD_SIZE)) % 2 == 0;
                    
                    var ac_color = theme.get_color ("theme_accent");
                    var bg_color = theme.get_color ("theme_bg");
                    if (is_light) {
                        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
                    } else {
                        cr.set_source_rgb(ac_color.red, ac_color.green, ac_color.blue);
                    }
                    
                    double cell_width = Math.fmin(CHECKERBOARD_SIZE, x + width - cx);
                    double cell_height = Math.fmin(CHECKERBOARD_SIZE, y + height - cy);
                    
                    cr.rectangle(cx, cy, (int)cell_width, (int)cell_height);
                    cr.fill();
                }
            }
            
            // Restore the saved state
            cr.restore();
        }
        
        /**
         * Handles clicks on the color bars
         */
        private void handle_bar_click(double x, double y) {
            if (x < 0 || x > BAR_WIDTH) return;
            
            // Calculate the new position (0-15)
            int new_position = (int)Math.floor(x / (BAR_WIDTH / 16.0));
            if (new_position > 15) new_position = 15;
            if (new_position < 0) new_position = 0;
            
            // Determine which bar was clicked
            int bar_index = -1;
            
            if (y >= 0 && y < BAR_HEIGHT) {
                // Red bar
                bar_index = 0;
            } else if (y >= (BAR_HEIGHT + BAR_GAP) && y < (BAR_HEIGHT * 2 + BAR_GAP)) {
                // Green bar
                bar_index = 1;
            } else if (y >= ((BAR_HEIGHT + BAR_GAP) * 2) && y < (BAR_HEIGHT * 3 + BAR_GAP * 2)) {
                // Blue bar
                bar_index = 2;
            }
            
            if (bar_index == -1) return;
            
            // Update the appropriate position
            if (bar_index == 0 && red_position != new_position) {
                red_position = new_position;
                red_value = (float)(red_position) / 15.0f;
            } else if (bar_index == 1 && green_position != new_position) {
                green_position = new_position;
                green_value = (float)(green_position) / 15.0f;
            } else if (bar_index == 2 && blue_position != new_position) {
                blue_position = new_position;
                blue_value = (float)(blue_position) / 15.0f;
            } else {
                // Nothing changed
                return;
            }
            
            // Update the UI
            bars_area.queue_draw();
            update_label();
            
            // Emit color change signal
            color_set();
        }
        
        /**
         * Updates the hex label to show the current values
         */
        private void update_label() {
            // Convert positions (0-15) to hex digits (0-f)
            string red_hex = position_to_hex(red_position);
            string green_hex = position_to_hex(green_position);
            string blue_hex = position_to_hex(blue_position);
            
            // Update the label
            hex_label.set_text("%s%s%s".printf(red_hex, green_hex, blue_hex));
        }
        
        /**
         * Converts a position (0-15) to a hex digit (0-f)
         */
        private string position_to_hex(int position) {
            string[] hex_digits = {"0", "1", "2", "3", "4", "5", "6", "7", 
                                  "8", "9", "a", "b", "c", "d", "e", "f"};
            return hex_digits[position];
        }
        
        /**
         * Sets the color from a hex string
         */
        public void set_from_hex(string hex_color) {
            Gdk.RGBA rgba = Gdk.RGBA();
            if (rgba.parse(hex_color)) {
                // Get RGB values (0-1)
                float red = (float)rgba.red;
                float green = (float)rgba.green;
                float blue = (float)rgba.blue;
                
                // Convert to positions (0-15)
                red_position = (int)Math.floor(red * 15.0f + 0.5f).clamp(0, 15);
                green_position = (int)Math.floor(green * 15.0f + 0.5f).clamp(0, 15);
                blue_position = (int)Math.floor(blue * 15.0f + 0.5f).clamp(0, 15);
                
                // Update the color values
                red_value = (float)red_position / 15.0f;
                green_value = (float)green_position / 15.0f;
                blue_value = (float)blue_position / 15.0f;
                
                // Update the UI
                bars_area.queue_draw();
                update_label();
            }
        }
        
        /**
         * Gets the current color as Gdk.RGBA
         */
        public Gdk.RGBA get_rgba() {
            Gdk.RGBA rgba = Gdk.RGBA();
            rgba.red = (float)red_value;
            rgba.green = (float)green_value;
            rgba.blue = (float)blue_value;
            rgba.alpha = 1.0f;
            return rgba;
        }
        
        /**
         * Gets the current color as a hex string (#RRGGBB)
         */
        public string get_hex() {
            // Convert positions to hex values (00-FF)
            int r = (int)Math.floor(red_value * 255.0f + 0.5f);
            int g = (int)Math.floor(green_value * 255.0f + 0.5f);
            int b = (int)Math.floor(blue_value * 255.0f + 0.5f);
            
            return "#%02x%02x%02x".printf(r, g, b);
        }
        
        /**
         * Gets the hex code representation (three digits)
         */
        public string get_hex_code() {
            return hex_label.get_text();
        }
    }
}