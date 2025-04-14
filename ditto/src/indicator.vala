public class ColorIndicator : Gtk.DrawingArea {
    private Gdk.RGBA[] colors;
    private int active_indicator = -1;
    
    public ColorIndicator() {
        colors = new Gdk.RGBA[4];
        
        for (int i = 0; i < 4; i++) {
            colors[i] = Gdk.RGBA();
            colors[i].red = 0.0f;
            colors[i].green = 0.0f;
            colors[i].blue = 0.0f;
            colors[i].alpha = 1.0f;
        }
        
        set_size_request(100, 8); // Width for 4 indicators with spacing
        set_draw_func(draw_func);
        
        // Setup tooltip support
        set_has_tooltip(true);
        query_tooltip.connect(on_query_tooltip);
        
        // Setup mouse hover tracking
        var motion_controller = new Gtk.EventControllerMotion();
        motion_controller.motion.connect((x, y) => {
            int new_active = get_indicator_at_position(x);
            if (new_active != active_indicator) {
                active_indicator = new_active;
                queue_draw(); // Redraw to show hover effect
            }
        });
        
        motion_controller.leave.connect(() => {
            active_indicator = -1;
            queue_draw();
        });
        
        add_controller(motion_controller);
    }
    
    private int get_indicator_at_position(double x) {
        int width = get_width();
        double indicator_width = width / 4.0;
        
        int index = (int)(x / indicator_width);
        if (index >= 0 && index < 4) {
            return index;
        }
        return -1;
    }
    
    private bool on_query_tooltip(int x, int y, bool keyboard_tooltip, Gtk.Tooltip tooltip) {
        int indicator = get_indicator_at_position(x);
        if (indicator >= 0 && indicator < 4) {
            // Get color and normalize to #FFFFFF format
            Gdk.RGBA color = colors[indicator];
            
            // Get RGB values (0-255)
            int r = (int)Math.round(color.red * 255);
            int g = (int)Math.round(color.green * 255);
            int b = (int)Math.round(color.blue * 255);
            
            // Create original hex color string
            string original_hex = "#%02X%02X%02X".printf(r, g, b);
            
            // Normalize the color
            string normalized_hex;
            
            // Check if it's already a standard color
            if (r == 255 && g == 255 && b == 255) {
                normalized_hex = "#FFFFFF"; // Already white
            } else if (r == 0 && g == 0 && b == 0) {
                normalized_hex = "#000000"; // Already black
            } else if (r == 255 && g == 0 && b == 0) {
                normalized_hex = "#FF0000"; // Already pure red
            } else if (r == 0 && g == 255 && b == 0) {
                normalized_hex = "#00FF00"; // Already pure green
            } else if (r == 0 && g == 0 && b == 255) {
                normalized_hex = "#0000FF"; // Already pure blue
            } else {
                // Handle the different cases for normalization
                
                // Case 1: Near white or black
                if (r >= 240 && g >= 240 && b >= 240) {
                    normalized_hex = "#FFFFFF"; // Normalize to white
                } else if (r <= 15 && g <= 15 && b <= 15) {
                    normalized_hex = "#000000"; // Normalize to black
                } 
                // Case 2: Grayscale
                else if (Math.fabs(r - g) <= 10 && Math.fabs(g - b) <= 10 && Math.fabs(r - b) <= 10) {
                    // It's a shade of gray, normalize to pure gray
                    int gray = (r + g + b) / 3;
                    normalized_hex = "#%02X%02X%02X".printf(gray, gray, gray);
                }
                // Case 3: Color with dominant component
                else {
                    // Find the highest value component
                    int max_value = int.max(r, int.max(g, b));
                    
                    // Find the minimum component
                    int min_value = int.min(r, int.min(g, b));
                    
                    // If dominant color is significantly stronger
                    if (max_value > 0 && (max_value - min_value) > 50) {
                        int normalized_r = (r == max_value) ? 255 : (r <= min_value + 20) ? 0 : (r * 255 / max_value);
                        int normalized_g = (g == max_value) ? 255 : (g <= min_value + 20) ? 0 : (g * 255 / max_value);
                        int normalized_b = (b == max_value) ? 255 : (b <= min_value + 20) ? 0 : (b * 255 / max_value);
                        
                        normalized_hex = "#%02X%02X%02X".printf(normalized_r, normalized_g, normalized_b);
                    } 
                    // Case 4: Mixed color without strong dominance
                    else {
                        // Boost contrast
                        double scale = 255.0 / max_value;
                        int normalized_r = (int)Math.round(r * scale);
                        int normalized_g = (int)Math.round(g * scale);
                        int normalized_b = (int)Math.round(b * scale);
                        
                        normalized_hex = "#%02X%02X%02X".printf(normalized_r, normalized_g, normalized_b);
                    }
                }
            }
            
            // Set tooltip text
            tooltip.set_text("Color %d: %s\nNormalized: %s".printf(indicator + 1, original_hex, normalized_hex));
            return true;
        }
        return false;
    }
    
    private void draw_func(Gtk.DrawingArea da, Cairo.Context cr, int width, int height) {
        // Calculate the size and spacing of each indicator
        double indicator_width = width / 4.0;
        double circle_radius = 3.0; // 3px diameter as requested
        
        // Draw each color indicator
        for (int i = 0; i < 4; i++) {
            double x = i * indicator_width + indicator_width / 2;
            double y = height / 2;
            
            // Draw color circle with no antialiasing
            cr.set_antialias(Cairo.Antialias.NONE);
            cr.set_source_rgba(colors[i].red, colors[i].green, colors[i].blue, 1.0);
            cr.arc(x, y, circle_radius, 0, 2 * Math.PI);
            cr.fill();
        }
    }
    
    public void update_colors(Gdk.RGBA[] new_colors) {
        for (int i = 0; i < 4 && i < new_colors.length; i++) {
            colors[i] = new_colors[i];
        }
        queue_draw();
    }
}