using Gtk;
using Cairo;

namespace ShavianKeyboard {
    // Utility functions for drawing and other operations
    public class Utils {
        // Draw a rounded rectangle
        public static void draw_rounded_rectangle(Cairo.Context cr, double x, double y, double width, double height, double radius) {
            // For pixel-perfect drawing, make sure coordinates are on pixel boundaries
            x = Math.floor(x) + 0.5;
            y = Math.floor(y) + 0.5;
            width = Math.floor(width) - 0.5;
            height = Math.floor(height) - 0.5;
            
            // Adjust radius to be pixel-perfect
            radius = Math.floor(radius);

            // Draw the rounded rectangle path
            cr.move_to(x + radius, y);
            cr.line_to(x + width - radius, y);
            cr.line_to(x + width, y + radius);
            cr.line_to(x + width, y + height - radius);
            cr.line_to(x + width - radius, y + height);
            cr.line_to(x + radius, y + height);
            cr.line_to(x, y + height - radius);
            cr.line_to(x, y + radius);
            cr.close_path();
        }
        
        // Draw pixelated text for Shavian characters
        public static void draw_pixelated_text(Cairo.Context cr, string text, double center_x, double center_y) {
            // Safety check for null or empty text
            if (text == null || text.length == 0) {
                // Draw a simple fallback shape
                cr.rectangle(center_x - 4, center_y - 4, 8, 8);
                cr.fill();
                return;
            }
            
            // For Shavian characters
            unichar first_char = text.get_char();
            
            // Check if we have a predefined pattern for this character
            if (Assets.pixel_patterns.contains(first_char)) {
                // Use the predefined pattern
                string hex_pattern = Assets.pixel_patterns.get(first_char);
                if (hex_pattern == null || hex_pattern.length == 0) {
                    // Fallback if pattern is null or empty
                    draw_fallback_character(cr, first_char, center_x, center_y);
                    return;
                }
                
                int pixel_size = 1; // 1px per pixel for maximum pixelation
                int char_width = 8 * pixel_size;
                int char_height = 16 * pixel_size;
                
                double x = Math.floor(center_x - char_width / 2);
                double y = Math.floor(center_y - char_height / 2);
                
                // Draw each pixel in the pattern
                cr.set_antialias(Cairo.Antialias.NONE);
                cr.set_line_width(1);
                
                // Process hex pattern: convert each hex digit to 4 bits and check each bit
                for (int i = 0; i < hex_pattern.length; i++) {
                    char hex_digit = hex_pattern[i];
                    int value;
                    
                    // Convert hex character to int value
                    if (hex_digit >= '0' && hex_digit <= '9') {
                        value = hex_digit - '0';
                    } else if (hex_digit >= 'A' && hex_digit <= 'F') {
                        value = hex_digit - 'A' + 10;
                    } else if (hex_digit >= 'a' && hex_digit <= 'f') {
                        value = hex_digit - 'a' + 10;
                    } else {
                        continue; // Skip invalid characters
                    }
                    
                    // Calculate row and starting column for this hex digit
                    int row = i / 2;
                    if (row >= 16) continue; // Skip if we're beyond the grid
                    
                    int col_start = (i % 2) * 4;
                    
                    // Process the 4 bits in this hex digit
                    for (int bit = 0; bit < 4; bit++) {
                        int col = col_start + bit;
                        bool pixel_on = ((value >> (3 - bit)) & 1) == 1;
                        
                        if (pixel_on) {
                            cr.rectangle(
                                x + col * pixel_size,
                                y + row * pixel_size,
                                pixel_size,
                                pixel_size
                            );
                        }
                    }
                }
                
                cr.fill();
            } else {
                // Fallback for characters without patterns
                draw_fallback_character(cr, first_char, center_x, center_y);
            }
        }
        
        // Helper method to draw a fallback character pattern
        private static void draw_fallback_character(Cairo.Context cr, unichar character, double center_x, double center_y) {
            int pixel_size = 1;
            int char_width = 8 * pixel_size;
            int char_height = 8 * pixel_size;
            double x = Math.floor(center_x - char_width / 2);
            double y = Math.floor(center_y - char_height / 2);
            
            // Draw a simple representation based on Unicode code point
            uint code_point = character;
            
            // Generate a simple pattern based on the code point
            for (int row = 0; row < 8; row++) {
                for (int col = 0; col < 8; col++) {
                    // Simple algorithm to generate a unique pattern for each character
                    bool pixel_on = ((code_point + row * 8 + col) % 5) < 2;
                    
                    if (pixel_on) {
                        cr.rectangle(
                            x + col * pixel_size,
                            y + row * pixel_size,
                            pixel_size,
                            pixel_size
                        );
                    }
                }
            }
            
            cr.fill();
        }
    }
}