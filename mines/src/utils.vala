public class MinesweeperUtils {
    // 2-bit color palette as plain doubles (4 colors)
    public static void set_color(Cairo.Context cr, int color_index) {
        var theme = Theme.Manager.get_default();
        var bg_color = theme.get_color("theme_bg");
        var sel_color = theme.get_color("theme_selection");
        var ac_color = theme.get_color("theme_accent");
        var fg_color = theme.get_color("theme_fg");
        switch (color_index) {
            case 0: // White
                cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
                break;
            case 1: // Light Gray
                cr.set_source_rgb(sel_color.red, sel_color.green, sel_color.blue);
                break;
            case 2: // Dark Gray
                cr.set_source_rgb(ac_color.red, ac_color.green, ac_color.blue);
                break;
            case 3: // Black
                cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
                break;
            case 4: // Alpha
                cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, 0.0);
                break;
        }
    }
    
    public static void draw_raised_tile(Cairo.Context cr, int x, int y, int width, int height) {
        // Draw tile background (light gray)
        set_color(cr, 1);
        cr.rectangle(x, y, width, height);
        cr.fill();
        
        // Set line width to 1px
        cr.set_line_width(1);
        
        // Draw bevelled edges inset by 1 pixel
        // White for top/left edges (inset by 1 pixel)
        set_color(cr, 0);
        // Top edge
        cr.move_to(x + 1, y + 1);
        cr.line_to(x + width - 1, y + 1);
        cr.stroke();
        
        // Left edge
        cr.move_to(x + 1, y + 1);
        cr.line_to(x + 1, y + height - 1);
        cr.stroke();
        
        // Dark gray for bottom/right edges (inset by 1 pixel)
        set_color(cr, 2);
        // Bottom edge
        cr.move_to(x + 1, y + height - 1);
        cr.line_to(x + width - 1, y + height - 1);
        cr.stroke();
        
        // Right edge
        cr.move_to(x + width - 1, y + 1);
        cr.line_to(x + width - 1, y + height - 1);
        cr.stroke();
    }
    
    public static void draw_flat_tile(Cairo.Context cr, int x, int y, int width, int height) {
        // Draw tile background (white)
        set_color(cr, 1);
        cr.rectangle(x, y, width, height);
        cr.fill();
        
        // Draw tile border (dotted black)
        cr.set_line_width(1);
        double[] dashes = { 1, 1 };
        cr.set_dash(dashes, 0);
        set_color(cr, 2);
        cr.move_to(x + width, y);
        cr.line_to(x + width, y + height);
        cr.stroke();
        cr.move_to(x, y + height);
        cr.line_to(x + width, y + height);
        cr.stroke();
        cr.set_dash(null, 0);
    }
    
    public static void draw_flag(Cairo.Context cr, int x, int y) {
        // Using black for the flag
        set_color(cr, 3);
        
        // Flag as a simple rectangle
        cr.rectangle(x + 5, y + 4, 6, 4);
        cr.fill();
        
        // Flag pole as a vertical line
        cr.set_line_width(1);
        cr.move_to(x + 5, y + 4);
        cr.line_to(x + 5, y + 12);
        cr.stroke();
    }
    
    public static void draw_mine(Cairo.Context cr, int x, int y) {
        // Using black for the mine
        set_color(cr, 3);
        
        // Draw mine as a "circle" made of rectangles
        // Middle sections
        cr.rectangle(x + 4, y + 6, 8, 4); // horizontal middle
        cr.rectangle(x + 6, y + 4, 4, 8); // vertical middle
        
        // Corner pixels to make it appear rounded
        cr.rectangle(x + 4, y + 4, 1, 1); // top-left
        cr.rectangle(x + 10, y + 4, 1, 1); // top-right
        cr.rectangle(x + 4, y + 10, 1, 1); // bottom-left
        cr.rectangle(x + 10, y + 10, 1, 1); // bottom-right
        
        cr.fill();
        
        // Add spikes using simple lines
        cr.set_line_width(1);
        
        // Horizontal spike
        cr.move_to(x + 2, y + 8);
        cr.line_to(x + 4, y + 8);
        cr.stroke();
        
        cr.move_to(x + 12, y + 8);
        cr.line_to(x + 14, y + 8);
        cr.stroke();
        
        // Vertical spike
        cr.move_to(x + 8, y + 2);
        cr.line_to(x + 8, y + 4);
        cr.stroke();
        
        cr.move_to(x + 8, y + 12);
        cr.line_to(x + 8, y + 14);
        cr.stroke();
        
        // Diagonal spikes (using single pixels)
        cr.rectangle(x + 4, y + 4, 1, 1);
        cr.rectangle(x + 10, y + 10, 1, 1);
        cr.rectangle(x + 4, y + 10, 1, 1);
        cr.rectangle(x + 10, y + 4, 1, 1);
        cr.fill();
    }
    
    public static void draw_number(Cairo.Context cr, int x, int y, int number) {
        // With only 4 colors, we'll use black for all numbers in a true 2-bit style
        set_color(cr, 3); // Black for all numbers
        
        // Simple pixel number representations for 1-8
        switch (number) {
            case 1:
                // Vertical line in center
                cr.rectangle(x + 8, y + 4, 1, 10);
                cr.fill();
                break;
            case 2:
                // Top horizontal
                cr.rectangle(x + 6, y + 4, 6, 1);
                // Middle horizontal
                cr.rectangle(x + 6, y + 8, 6, 1);
                // Bottom horizontal
                cr.rectangle(x + 6, y + 12, 6, 1);
                // Top-right vertical
                cr.rectangle(x + 11, y + 4, 1, 4);
                // Bottom-left vertical
                cr.rectangle(x + 6, y + 8, 1, 4);
                cr.fill();
                break;
            case 3:
                // Horizontals
                cr.rectangle(x + 6, y + 4, 6, 1);
                cr.rectangle(x + 6, y + 8, 6, 1);
                cr.rectangle(x + 6, y + 13, 6, 1);
                // Right vertical
                cr.rectangle(x + 11, y + 4, 1, 10);
                cr.fill();
                break;
            case 4:
                // Left vertical (top half)
                cr.rectangle(x + 6, y + 4, 1, 4);
                // Middle horizontal
                cr.rectangle(x + 6, y + 8, 6, 1);
                // Right vertical
                cr.rectangle(x + 11, y + 4, 1, 10);
                cr.fill();
                break;
            case 5:
                // Horizontals
                cr.rectangle(x + 6, y + 4, 6, 1);
                cr.rectangle(x + 6, y + 8, 6, 1);
                cr.rectangle(x + 6, y + 12, 6, 1);
                // Top-left vertical
                cr.rectangle(x + 6, y + 4, 1, 4);
                // Bottom-right vertical
                cr.rectangle(x + 11, y + 8, 1, 4);
                cr.fill();
                break;
            case 6:
                // Horizontals
                cr.rectangle(x + 6, y + 4, 6, 1);
                cr.rectangle(x + 6, y + 8, 6, 1);
                cr.rectangle(x + 6, y + 13, 6, 1);
                // Left vertical
                cr.rectangle(x + 6, y + 4, 1, 10);
                // Bottom-right vertical
                cr.rectangle(x + 11, y + 8, 1, 4);
                cr.fill();
                break;
            case 7:
                // Top horizontal
                cr.rectangle(x + 6, y + 4, 6, 1);
                // Right vertical
                cr.rectangle(x + 11, y + 4, 1, 10);
                cr.fill();
                break;
            case 8:
                // Horizontals
                cr.rectangle(x + 6, y + 4, 6, 1);
                cr.rectangle(x + 6, y + 8, 6, 1);
                cr.rectangle(x + 6, y + 13, 6, 1);
                // Verticals
                cr.rectangle(x + 6, y + 4, 1, 10);
                cr.rectangle(x + 11, y + 4, 1, 10);
                cr.fill();
                break;
            default:
                // Default for any other number
                cr.rectangle(x + 3, y + 3, 3, 3);
                cr.fill();
                break;
        }
    }
    
    public static void draw_sunken_panel(Cairo.Context cr, int x, int y, int width, int height) {
        // Background
        set_color(cr, 4); // Alpha for background
        cr.rectangle(x, y, width, height);
        cr.fill();
        
        cr.set_line_width(1);
        
        // Draw bevelled edges inset by 1 pixel
        // White for top/left edges (inset by 1 pixel)
        set_color(cr, 2);
        // Top edge
        cr.move_to(x + 1, y + 1);
        cr.line_to(x + width - 1, y + 1);
        cr.stroke();
        
        // Left edge
        cr.move_to(x + 1, y + 1);
        cr.line_to(x + 1, y + height - 1);
        cr.stroke();
        
        // Dark gray for bottom/right edges (inset by 1 pixel)
        set_color(cr, 0);
        // Bottom edge
        cr.move_to(x + 1, y + height - 1);
        cr.line_to(x + width - 1, y + height - 1);
        cr.stroke();
        
        // Right edge
        cr.move_to(x + width - 1, y + 1);
        cr.line_to(x + width - 1, y + height - 1);
        cr.stroke();
    }
    
    public static void draw_seven_segment_number(Cairo.Context cr, int number, int x, int y) {
        // Convert number to 3 digits
        int hundreds = (number / 100) % 10;
        int tens = (number / 10) % 10;
        int ones = number % 10;
        
        // Draw each digit
        draw_seven_segment_digit(cr, hundreds, x, y);
        draw_seven_segment_digit(cr, tens, x + 16, y);
        draw_seven_segment_digit(cr, ones, x + 32, y);
    }
    
    public static void draw_seven_segment_digit(Cairo.Context cr, int digit, int x, int y) {
        // Segment patterns for 0-9
        bool[,] segments = {
            {true, true, true, true, true, true, false},     // 0
            {false, true, true, false, false, false, false}, // 1
            {true, true, false, true, true, false, true},    // 2
            {true, true, true, true, false, false, true},    // 3
            {false, true, true, false, false, true, true},   // 4
            {true, false, true, true, false, true, true},    // 5
            {true, false, true, true, true, true, true},     // 6
            {true, true, true, false, false, false, false},  // 7
            {true, true, true, true, true, true, true},      // 8
            {true, true, true, true, false, true, true}      // 9
        };
        
        if (digit < 0 || digit > 9) 
            digit = 0;

        // Segment coordinates
        int[,] segmentCoords = {
            {4, 1, 8, 2},                 // A: top horizontal
            {13, 2, 2, 5},                 // B: top-right vertical
            {13, 9, 2, 5},                 // C: bottom-right vertical
            {4, 13, 8, 2},                // D: bottom horizontal
            {1, 9, 2, 5},                  // E: bottom-left vertical
            {1, 2, 2, 5},                  // F: top-left vertical
            {4, 7, 8, 2}                  // G: middle horizontal
        };
        
        // Background
        set_color(cr, 3); // Black for background
        cr.rectangle(x, y, 16, 16);
        cr.fill();
        
        // First draw all segments as unlit (dark gray)
        set_color(cr, 2); // Dark gray for unlit
        
        for (int i = 0; i < 7; i++) {
            int sx = x + segmentCoords[i,0];
            int sy = y + segmentCoords[i,1];
            int sw = segmentCoords[i,2];
            int sh = segmentCoords[i,3];
            
            cr.rectangle(sx, sy, sw, sh);
            cr.fill();
        }
        
        // Then draw lit segments (white)
        set_color(cr, 0); // White for lit segments
        
        for (int i = 0; i < 7; i++) {
            if (segments[digit, i]) {
                int sx = x + segmentCoords[i,0];
                int sy = y + segmentCoords[i,1];
                int sw = segmentCoords[i,2];
                int sh = segmentCoords[i,3];
                
                cr.rectangle(sx, sy, sw, sh);
                cr.fill();
            }
        }
    }
    
    // Create the standard 3-digit number display (e.g., for timer and mine counter)
    public static Gtk.DrawingArea create_digit_display() {
        return new Gtk.DrawingArea() {
            content_width = 3 * 8, // DIGIT_WIDTH = 8
            content_height = 16    // DIGIT_HEIGHT = 16
        };
    }
}