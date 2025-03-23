/*
 * ColorPickerWidget.vala
 * 
 * A custom color picker widget for X11 compatibility
 * Works as a replacement for Gtk.ColorButton
 */

using Gtk;

namespace App {
    public class ColorPickerWidget : Gtk.Box {
        // Constants
        private const int SWATCH_SIZE = 32;
        private const int SLIDER_WIDTH = 200;
        
        // UI elements
        private Gtk.DrawingArea color_swatch;
        private Gtk.Scale red_scale;
        private Gtk.Scale green_scale;
        private Gtk.Scale blue_scale;
        
        // Current color values
        private double red_value = 0;
        private double green_value = 0;
        private double blue_value = 0;

        // Color change signal
        public signal void color_set();
        
        /**
         * Constructor
         */
        public ColorPickerWidget() {
            Object(
                orientation: Gtk.Orientation.HORIZONTAL,
                spacing: 8
            );
            
            // Create the color swatch display
            create_color_swatch();
            
            // Create RGB sliders
            var sliders_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4);
            
            // Red slider
            red_scale = create_color_slider("R", 1.0, 0, 0);
            sliders_box.append(red_scale);
            
            // Green slider
            green_scale = create_color_slider("G", 0, 1.0, 0);
            sliders_box.append(green_scale);
            
            // Blue slider
            blue_scale = create_color_slider("B", 0, 0, 1.0);
            sliders_box.append(blue_scale);
            
            // Add the components to the main container
            this.append(color_swatch);
            this.append(sliders_box);
        }
        
        /**
         * Creates the color swatch DrawingArea
         */
        private void create_color_swatch() {
            color_swatch = new Gtk.DrawingArea() {
                content_width = SWATCH_SIZE,
                content_height = SWATCH_SIZE
            };
            
            // Setup drawing function
            color_swatch.set_draw_func((area, cr, width, height) => {
                // Draw border
                cr.set_source_rgb(0, 0, 0);
                cr.set_antialias(Cairo.Antialias.NONE);
                cr.set_line_width(1);
                cr.rectangle(0.5, 0.5, width - 1, height - 1);
                cr.stroke();
                
                // Fill with current color
                cr.set_source_rgb(red_value, green_value, blue_value);
                cr.rectangle(1, 1, width - 2, height - 2);
                cr.fill();
            });
            
            // Add click gesture to open popover with sliders
            var click_gesture = new Gtk.GestureClick();
            click_gesture.set_button(1); // Primary button
            click_gesture.released.connect((n_press, x, y) => {
                // Could implement color popup here if needed
            });
            color_swatch.add_controller(click_gesture);
        }
        
        /**
         * Snaps a color value to the nearest repeating hex value
         * This ensures colors like #77DDCC instead of #75DEC2
         */
        private float snap_to_repeating_hex(float value) {
            // Convert from 0-1 range to 0-255, keeping as float for precision
            float decimal_value = value * 255.0f;
            
            // Find the nearest value with repeating hex digits
            // These occur at multiples of 17 (0x11): 0, 17, 34, 51, 68, 85, 102, 119, 136, 153, 170, 187, 204, 221, 238, 255
            int rounded_index = (int)((decimal_value / 17.0f) + 0.5f); // Manual rounding
            int snapped_value = rounded_index * 17;
            
            // Ensure we're in the valid range 0-255
            snapped_value = snapped_value.clamp(0, 255);
            
            // Convert back to 0-1 range, ensuring float division
            return (float)snapped_value / 255.0f;
        }
        
        /**
         * Creates the marks on the slider for the repeating hex values
         */
        private void add_hex_repeat_marks(Gtk.Scale scale) {
            // Add marks for each repeating hex value
            for (int i = 0; i <= 15; i++) {
                double value = (i * 17) / 255.0;
                scale.add_mark(value, Gtk.PositionType.BOTTOM, "");
            }
        }
        
        /**
         * Creates a slider for a color channel
         */
        private Gtk.Scale create_color_slider(string label, double red, double green, double blue) {
            var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
            
            // Label
            var channel_label = new Gtk.Label(label) {
                width_chars = 1
            };
            
            // Slider
            var adjustment = new Gtk.Adjustment(0, 0, 1.0, 1.0/255.0, 0.1, 0);
            var scale = new Gtk.Scale(Gtk.Orientation.HORIZONTAL, adjustment) {
                width_request = SLIDER_WIDTH,
                draw_value = true,
                digits = 2,
                value_pos = Gtk.PositionType.RIGHT,
                has_origin = false,
                round_digits = 2
            };
            
            // Add marks for repeating hex values
            add_hex_repeat_marks(scale);
            
            // Set slider color
            var color_css = new Gtk.CssProvider();
            var css_data = @"scale trough highlight { background-color: rgb($(red*255.0f), $(green*255.0f), $(blue*255.0f)); }";
            try {
                color_css.load_from_data(css_data.data);
                scale.get_style_context().add_provider(color_css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            } catch (Error e) {
                warning("Failed to load CSS: %s", e.message);
            }
            
            // Connect to value-changed signal
            scale.value_changed.connect(() => {
                double new_value = snap_to_repeating_hex((float)scale.get_value());
                
                // Check if we're already at a snapped value
                // This prevents infinite loops
                if (Math.fabs(new_value - scale.get_value()) > 0.001) {
                    scale.set_value(new_value);
                    return;
                }
                
                // Update the appropriate color value
                if (label == "R") {
                    red_value = new_value;
                } else if (label == "G") {
                    green_value = new_value;
                } else if (label == "B") {
                    blue_value = new_value;
                }
                
                // Update the color swatch
                color_swatch.queue_draw();
                
                // Emit the color_set signal
                color_set();
            });
            
            box.append(channel_label);
            box.append(scale);
            
            return scale;
        }
        
        /**
         * Sets the color from a hex string
         */
        public void set_from_hex(string hex_color) {
            Gdk.RGBA rgba = Gdk.RGBA();
            if (rgba.parse(hex_color)) {
                // Get the component values as floats (0.0-1.0)
                float red = (float)rgba.red;
                float green = (float)rgba.green;
                float blue = (float)rgba.blue;
                
                // Snap the values to repeating hex
                red_value = snap_to_repeating_hex(red);
                green_value = snap_to_repeating_hex(green);
                blue_value = snap_to_repeating_hex(blue);
                
                red_scale.set_value(red_value);
                green_scale.set_value(green_value);
                blue_scale.set_value(blue_value);
                
                color_swatch.queue_draw();
            }
        }
        
        /**
         * Checks if the current RGB values produce repeating hex digits
         */
        public bool has_repeating_hex_values() {
            // Get hex digits (without the # prefix)
            string hex = get_hex().substring(1);
            
            // Check if each channel has repeating digits
            bool red_repeats = hex[0] == hex[1];
            bool green_repeats = hex[2] == hex[3];
            bool blue_repeats = hex[4] == hex[5];
            
            return red_repeats && green_repeats && blue_repeats;
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
            return "#%02x%02x%02x".printf(
                (uint)(red_value * 255.0f + 0.5f),   // Manual rounding
                (uint)(green_value * 255.0f + 0.5f),
                (uint)(blue_value * 255.0f + 0.5f)
            );
        }
    }
}