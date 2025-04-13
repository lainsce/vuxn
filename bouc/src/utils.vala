public class FontData {
    public uint8[] widths;
    public Array<uint8> data;
    public int char_width;
    public int char_height;
    
    public FontData() {
        widths = new uint8[256];
        data = new Array<uint8>();
    }
}

// Application constants
namespace AppConstants {
    public const int DEFAULT_WIDTH = 420;
    public const int DEFAULT_HEIGHT = 595;
    public const int LINE_HEIGHT = 16;
    public const int SCROLLBAR_WIDTH = 8;
    public const int TEXT_MARGIN = 8;
    public const int TITLE_Y_POSITION = 64;
    public const int CONTENT_Y_START = 96;
    public const int BASELINE_OFFSET = 8;
    public const int DIAMOND_X = 0;
    public const int DIAMOND_Y = 16;
    public const int DIAMOND_SIZE = 16;
    public const int SCROLLBAR_X = 0;
    public const int SCROLLBAR_Y = 32;
    public const int MIN_THUMB_HEIGHT = 32;
    public const int LINE_COUNTER_X_OFFSET = 32;
    public const int ARROW_BUTTON_HEIGHT = 8;
    public const int SCROLL_SPEED_HOLD = 1; // Lines per update when holding arrow button
}

// Helper functions for color management
public Gdk.RGBA create_rgba(float red, float green, float blue) {
    var color = Gdk.RGBA();
    color.red = red;
    color.green = green;
    color.blue = blue;
    color.alpha = 1.0f;
    return color;
}

// Helper class for drawing operations
public class DrawingHelpers {
    // Draw a diamond shape
    public static void draw_diamond(Cairo.Context cr, Gdk.RGBA color, double x, double y, double size) {
        cr.set_source_rgba(color.red, color.green, color.blue, 1.0);

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
    
    // Draw arrow button with square border
    public static void draw_arrow_button(Cairo.Context cr, Gdk.RGBA color, double x, double y, 
                                       double width, double height, bool up_arrow) {
        // Draw the button border (square)
        cr.set_source_rgba(color.red, color.green, color.blue, 1.0);
        cr.set_line_width(1);
        cr.rectangle(x, y, width, height);
        cr.stroke();
        
        // Calculate arrow position
        double arrow_tip_y = up_arrow ? y : y + height - 2;
        double base_y = up_arrow ? arrow_tip_y : arrow_tip_y - 6;
        
        // Fill the button with pixels to form an arrow
        cr.set_source_rgba(color.red, color.green, color.blue, 1.0);
        
        if (up_arrow) {
            // Draw the arrow pointing up
            // Row 0
            cr.rectangle(x + 3, base_y, 1, 1);
            
            // Row 1
            cr.rectangle(x + 2, base_y + 1, 1, 1);
            cr.rectangle(x + 3, base_y + 1, 1, 1);
            cr.rectangle(x + 4, base_y + 1, 1, 1);
            
            // Row 2
            cr.rectangle(x + 1, base_y + 2, 1, 1);
            cr.rectangle(x + 2, base_y + 2, 1, 1);
            cr.rectangle(x + 3, base_y + 2, 1, 1);
            cr.rectangle(x + 4, base_y + 2, 1, 1);
            cr.rectangle(x + 5, base_y + 2, 1, 1);
            
            // Row 3
            cr.rectangle(x + 0, base_y + 3, 1, 1);
            cr.rectangle(x + 1, base_y + 3, 1, 1);
            cr.rectangle(x + 2, base_y + 3, 1, 1);
            cr.rectangle(x + 3, base_y + 3, 1, 1);
            cr.rectangle(x + 4, base_y + 3, 1, 1);
            cr.rectangle(x + 5, base_y + 3, 1, 1);
            cr.rectangle(x + 6, base_y + 3, 1, 1);
            
            // Row 4
            cr.rectangle(x + 3, base_y + 4, 1, 1);
            
            // Row 5
            cr.rectangle(x + 3, base_y + 5, 1, 1);
            
            // Row 6
            cr.rectangle(x + 3, base_y + 6, 1, 1);
        } else {
            // Draw the arrow pointing down
            // Stem
            cr.rectangle(x + 3, base_y, 1, 1);
            cr.rectangle(x + 3, base_y + 1, 1, 1);
            cr.rectangle(x + 3, base_y + 2, 1, 1);
            
            // Arrow head
            // Row 3
            cr.rectangle(x + 0, base_y + 3, 1, 1);
            cr.rectangle(x + 1, base_y + 3, 1, 1);
            cr.rectangle(x + 2, base_y + 3, 1, 1);
            cr.rectangle(x + 3, base_y + 3, 1, 1);
            cr.rectangle(x + 4, base_y + 3, 1, 1);
            cr.rectangle(x + 5, base_y + 3, 1, 1);
            cr.rectangle(x + 6, base_y + 3, 1, 1);
            
            // Row 4
            cr.rectangle(x + 1, base_y + 4, 1, 1);
            cr.rectangle(x + 2, base_y + 4, 1, 1);
            cr.rectangle(x + 3, base_y + 4, 1, 1);
            cr.rectangle(x + 4, base_y + 4, 1, 1);
            cr.rectangle(x + 5, base_y + 4, 1, 1);
            
            // Row 5
            cr.rectangle(x + 2, base_y + 5, 1, 1);
            cr.rectangle(x + 3, base_y + 5, 1, 1);
            cr.rectangle(x + 4, base_y + 5, 1, 1);
            
            // Row 6
            cr.rectangle(x + 3, base_y + 6, 1, 1);
        }
        cr.fill();
    }
    
    // Draw text with optional width limit
    public static void draw_text(Cairo.Context cr, string text, double x, double y, bool small_font, 
                                 Gdk.RGBA color, double max_width = -1) {
        cr.save();
        cr.set_source_rgba(color.red, color.green, color.blue, 1.0);

        // Disable font softening, it's all bitmap
        Cairo.FontOptions font_options = new Cairo.FontOptions();
        font_options.set_antialias(Cairo.Antialias.NONE);
        font_options.set_hint_style(Cairo.HintStyle.NONE);
        font_options.set_hint_metrics(Cairo.HintMetrics.OFF);
        font_options.set_subpixel_order(Cairo.SubpixelOrder.DEFAULT);
        cr.set_font_options(font_options);

        // Set font based on small_font parameter
        if (small_font) {
            cr.select_font_face("New York 14", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(14);
        } else {
            cr.select_font_face("New York 24", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(24);
        }
        
        string display_text = text;
        
        // Check if we need to limit text width and text is not empty
        if (max_width > 0 && text.length > 0) {
            // Get text extents
            Cairo.TextExtents extents;
            cr.text_extents(text, out extents);
            
            // If text is too wide, truncate it with ellipsis
            if (extents.width > max_width) {
                // Simple truncation approach - estimate how many characters can fit
                double char_width_estimate = extents.width / text.length;
                int chars_that_fit = (int)(max_width / char_width_estimate);
                
                if (chars_that_fit > 0 && chars_that_fit < text.length) {
                    // Make sure we don't cut in the middle of a UTF-8 character
                    string truncated = text.substring(0, chars_that_fit);
                    display_text = truncated;
                    
                    // Double-check if it fits now
                    cr.text_extents(display_text, out extents);
                    
                    // If still too wide, remove one more character
                    if (extents.width > max_width && truncated.length > 1) {
                        display_text = truncated.substring(0, truncated.length);
                    }
                }
            }
        }
        
        // Position and draw the text
        cr.move_to(x, y + AppConstants.BASELINE_OFFSET);
        cr.show_text(display_text);
        
        cr.restore();
    }
    
    // Process a filename to create a nicely formatted title
    public static string create_title_from_filename(string basename) {
        string result = basename;
        
        // Remove extension
        int dot_index = result.last_index_of(".");
        if (dot_index > 0) {
            result = result.slice(0, dot_index);
        }
        
        // Replace underscores with spaces
        string with_spaces = "";
        for (int i = 0; i < result.length; i++) {
            unichar c = result.get_char(i);
            if (c == '_') {
                with_spaces += " ";
            } else {
                with_spaces += c.to_string();
            }
        }
        
        // Capitalize every word
        StringBuilder title_builder = new StringBuilder();
        string[] words = with_spaces.split(" ");
        foreach (string word in words) {
            if (word.length > 0) {
                title_builder.append_c((char)word.get_char(0).toupper());
                if (word.length > 1) {
                    title_builder.append(word.substring(1));
                }
                title_builder.append_c(' ');
            }
        }
        
        return title_builder.str.strip();
    }
}