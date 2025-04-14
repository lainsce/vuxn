public class MinesweeperUtils {
    // 2-bit color palette as plain doubles (4 colors)
    public static void set_color(Cairo.Context cr, int color_index) {
        var theme = Theme.Manager.get_default();
        var fg_color = theme.get_color("theme_fg");
        var bg_color = theme.get_color("theme_bg");
        var ac_color = theme.get_color("theme_accent");
        var sel_color = theme.get_color("theme_selection");
        switch (color_index) {
            case 0: // White
                cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
                break;
            case 1: // Black
                cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
                break;
            case 2: // Light Gray
                cr.set_source_rgb(ac_color.red, ac_color.green, ac_color.blue);
                break;
            case 3: // Dark Gray
                cr.set_source_rgb(sel_color.red, sel_color.green, sel_color.blue);
                break;
            case 4: // Alpha
                cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, 0.0);
                break;
        }
    }
    
    public static void draw_raised_tile(Cairo.Context cr, int x, int y, int width, int height) {
        // Draw tile background (light gray)
        set_color(cr, 2);
        cr.rectangle(x, y, width, height);
        cr.fill();
        
        // Set line width to 1px
        cr.set_line_width(1);
        
        // Draw bevelled edges inset by 2 pixels
        // White for top/left edges (inset by 2 pixels)
        set_color(cr, 1);
        // Top edge
        cr.move_to(x + 1, y + 1);
        cr.line_to(x + width - 1, y + 1);
        cr.move_to(x + 2, y + 2);
        cr.line_to(x + width - 2, y + 2);
        cr.stroke();
        
        // Left edge
        cr.move_to(x + 1, y + 1);
        cr.line_to(x + 1, y + height - 1);
        cr.move_to(x + 2, y + 2);
        cr.line_to(x + 2, y + height - 2);
        cr.stroke();
        
        // Dark gray for bottom/right edges (inset by 2 pixels)
        set_color(cr, 3);
        // Bottom edge
        cr.move_to(x + 1, y + height - 1);
        cr.line_to(x + width - 1, y + height - 1);
        cr.move_to(x + 2, y + height - 2);
        cr.line_to(x + width - 2, y + height - 2);
        cr.stroke();
        
        // Right edge
        cr.move_to(x + width - 1, y + 1);
        cr.line_to(x + width - 1, y + height - 1);
        cr.move_to(x + width - 2, y + 2);
        cr.line_to(x + width - 2, y + height - 2);
        cr.stroke();
    }
    
    public static void draw_flat_tile(Cairo.Context cr, int x, int y, int width, int height) {
        // Draw tile background (white)
        set_color(cr, 0);
        cr.rectangle(x, y, width, height);
        cr.fill();
        
        // Draw tile border (dotted black)
        cr.set_line_width(1);
        double[] dashes = { 1, 1 };
        cr.set_dash(dashes, 0);
        set_color(cr, 1);
        cr.move_to(x + width, y);
        cr.line_to(x + width, y + height);
        cr.stroke();
        cr.move_to(x, y + height);
        cr.line_to(x + width, y + height);
        cr.stroke();
        cr.set_dash(null, 0);
    }
    
    public static void draw_flag(Cairo.Context cr, int x, int y) {
        // Black parts (color 3)
        set_color(cr, 1);
        // Flag pole
        cr.rectangle(x + 7, y + 4, 1, 6);

        // Flag ground
        cr.rectangle(x + 5, y + 10, 5, 1);
        cr.rectangle(x + 4, y + 11, 7, 1);
        cr.fill();
        
        // Gray parts
        // Flag triangle
        set_color(cr, 2);
        cr.rectangle(x + 6, y + 4, 1, 4);
        cr.rectangle(x + 5, y + 4, 1, 3);
        cr.rectangle(x + 4, y + 5, 1, 1);
        cr.fill();
    }
    
    public static void draw_mine(Cairo.Context cr, int x, int y) {
        // Using black for the mine
        set_color(cr, 1);
        
        // Top stem
        cr.rectangle(x + 7, y + 1, 1, 2);

        // Upper body outline
        cr.rectangle(x + 3, y + 3, 1, 1);
        cr.rectangle(x + 5, y + 3, 5, 1);
        cr.rectangle(x + 4, y + 4, 7, 1);
        cr.rectangle(x + 11, y + 3, 1, 1);

        // Left side 
        cr.rectangle(x + 3, y + 5, 2, 2);

        // Right side
        cr.rectangle(x + 8, y + 5, 4, 2);

        // Middle parts
        cr.rectangle(x + 6, y + 5, 2, 1);
        cr.rectangle(x + 6, y + 6, 2, 1);

        // Horizontal middle line
        cr.rectangle(x + 1, y + 7, 13, 1);

        // Lower body
        cr.rectangle(x + 3, y + 8, 9, 2);
        cr.rectangle(x + 4, y + 10, 7, 1);
        cr.rectangle(x + 3, y + 11, 1, 1);
        cr.rectangle(x + 5, y + 11, 5, 1);
        cr.rectangle(x + 11, y + 11, 1, 1);
        
        // Bottom stem
        cr.rectangle(x + 7, y + 12, 1, 2);
        cr.fill();

        // White "shine" spots
        set_color(cr, 0);
        cr.rectangle(x + 5, y + 4, 1, 1);
        cr.rectangle(x + 4, y + 5, 1, 1);
        cr.rectangle(x + 6, y + 5, 1, 1);
        cr.rectangle(x + 5, y + 6, 1, 1);
        cr.fill();

    }
    
    public static void draw_number(Cairo.Context cr, int x, int y, int number) {
        // With only 4 colors, we'll use black for all numbers in a true 2-bit style
        set_color(cr, 1); // Black for all numbers
        
        // Simple pixel number representations for 1-8
        switch (number) {
            case 1:
                // Vertical line in center
                cr.rectangle(x + 7, y + 3, 1, 9);
                cr.rectangle(x + 6, y + 3, 1, 9);
                cr.fill();
                break;
            case 2:
                // Top horizontal
                cr.rectangle(x + 4, y + 3, 6, 1);
                // Middle horizontal
                cr.rectangle(x + 5, y + 7, 5, 1);
                // Bottom horizontal
                cr.rectangle(x + 5, y + 11, 6, 1);
                // Top-right vertical
                cr.rectangle(x + 9, y + 3, 1, 4);
                cr.rectangle(x + 10, y + 3, 1, 5);
                // Bottom-left vertical
                cr.rectangle(x + 4, y + 7, 1, 5);
                cr.rectangle(x + 5, y + 7, 1, 4);
                cr.fill();
                break;
            case 3:
                // Horizontals
                cr.rectangle(x + 4, y + 3, 6, 1);
                cr.rectangle(x + 4, y + 7, 6, 1);
                cr.rectangle(x + 4, y + 11, 6, 1);
                // Right vertical
                cr.rectangle(x + 9, y + 3, 1, 9);
                cr.rectangle(x + 10, y + 3, 1, 9);
                cr.fill();
                break;
            case 4:
                // Left vertical (top half)
                cr.rectangle(x + 4, y + 3, 1, 4);
                cr.rectangle(x + 5, y + 3, 1, 4);
                // Middle horizontal
                cr.rectangle(x + 4, y + 7, 6, 1);
                // Right vertical
                cr.rectangle(x + 9, y + 3, 1, 9);
                cr.rectangle(x + 10, y + 3, 1, 9);
                cr.fill();
                break;
            case 5:
                // Horizontals
                cr.rectangle(x + 5, y + 3, 7, 1);
                cr.rectangle(x + 4, y + 7, 6, 1);
                cr.rectangle(x + 4, y + 11, 7, 1);
                // Top-left vertical
                cr.rectangle(x + 4, y + 3, 1, 4);
                cr.rectangle(x + 5, y + 3, 1, 4);
                // Bottom-right vertical
                cr.rectangle(x + 9, y + 7, 1, 4);
                cr.rectangle(x + 10, y + 7, 1, 4);
                cr.fill();
                break;
            case 6:
                // Horizontals
                cr.rectangle(x + 5, y + 3, 7, 1);
                cr.rectangle(x + 5, y + 7, 6, 1);
                cr.rectangle(x + 5, y + 11, 7, 1);
                // Left vertical
                cr.rectangle(x + 4, y + 3, 1, 9);
                cr.rectangle(x + 5, y + 3, 1, 9);
                // Bottom-right vertical
                cr.rectangle(x + 9, y + 8, 1, 4);
                cr.rectangle(x + 10, y + 8, 1, 4);
                cr.fill();
                break;
            case 7:
                // Top horizontal
                cr.rectangle(x + 5, y + 3, 7, 1);
                // Right vertical
                cr.rectangle(x + 9, y + 3, 1, 9);
                cr.rectangle(x + 10, y + 3, 1, 9);
                cr.fill();
                break;
            case 8:
                // Horizontals
                cr.rectangle(x + 5, y + 3, 7, 1);
                cr.rectangle(x + 5, y + 7, 7, 1);
                cr.rectangle(x + 5, y + 11, 7, 1);
                // Verticals
                cr.rectangle(x + 4, y + 3, 1, 9);
                cr.rectangle(x + 5, y + 3, 1, 9);
                cr.rectangle(x + 9, y + 3, 1, 9);
                cr.rectangle(x + 10, y + 3, 1, 9);
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
        // White for top/left edges (inset by 2 pixels)
        set_color(cr, 1);
        // Top edge
        cr.move_to(x + 1, y + 1);
        cr.line_to(x + width - 1, y + 1);
        cr.move_to(x + 2, y + 2);
        cr.line_to(x + width - 2, y + 2);
        cr.stroke();
        
        // Left edge
        cr.move_to(x + 1, y + 1);
        cr.line_to(x + 1, y + height - 1);
        cr.move_to(x + 2, y + 2);
        cr.line_to(x + 2, y + height - 2);
        cr.stroke();
        
        // Dark gray for bottom/right edges (inset by 2 pixels)
        set_color(cr, 3);
        // Bottom edge
        cr.move_to(x + 1, y + height - 1);
        cr.line_to(x + width - 1, y + height - 1);
        cr.move_to(x + 2, y + height - 2);
        cr.line_to(x + width - 2, y + height - 2);
        cr.stroke();
        
        // Right edge
        cr.move_to(x + width - 1, y + 1);
        cr.line_to(x + width - 1, y + height - 1);
        cr.move_to(x + width - 2, y + 2);
        cr.line_to(x + width - 2, y + height - 2);
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
            {3, 1, 9, 1},                 // A: top horizontal
            {12, 2, 1, 5},                 // B: top-right vertical
            {12, 8, 1, 5},                 // C: bottom-right vertical
            {3, 13, 9, 1},                // D: bottom horizontal
            {2, 8, 1, 5},                  // E: bottom-left vertical
            {2, 2, 1, 5},                  // F: top-left vertical
            {3, 7, 9, 1}                  // G: middle horizontal
        };
        
        // Background
        set_color(cr, 0); // Black for background
        cr.rectangle(x, y, 16, 16);
        cr.fill();
        
        // First draw all segments as unlit (dark gray)
        set_color(cr, 3); // Dark gray for unlit
        
        for (int i = 0; i < 7; i++) {
            int sx = x + segmentCoords[i,0];
            int sy = y + segmentCoords[i,1];
            int sw = segmentCoords[i,2];
            int sh = segmentCoords[i,3];
            
            switch (i) {
                case 0:
                   cr.rectangle(sx, sy, sw, sh);
                   cr.rectangle(sx + 1, sy + 1, sw - 2, sh);
                   cr.fill();
                   break;
                case 1:
                   cr.rectangle(sx, sy, sw, sh);
                   cr.rectangle(sx - 1, sy + 1, sw, sh - 2);
                   cr.fill();
                   break;
                case 2:
                   cr.rectangle(sx, sy, sw, sh);
                   cr.rectangle(sx - 1, sy + 1, sw, sh - 2);
                   cr.fill();
                   break;
                case 3:
                   cr.rectangle(sx, sy, sw, sh);
                   cr.rectangle(sx + 1, sy - 1, sw - 2, sh);
                   cr.fill();
                   break;
                case 4:
                   cr.rectangle(sx, sy, sw, sh);
                   cr.rectangle(sx + 1, sy + 1, sw, sh - 2);
                   cr.fill();
                   break;
                case 5:
                   cr.rectangle(sx, sy, sw, sh);
                   cr.rectangle(sx + 1, sy + 1, sw, sh - 2);
                   cr.fill();
                   break;
                case 6:
                   cr.rectangle(sx, sy, sw, sh);
                   cr.rectangle(sx + 1, sy + 1, sw - 2, sh);
                   cr.fill();
                   break;
            }
        }
        
        // Then draw lit segments (white)
        set_color(cr, 1); // White for lit segments
        
        for (int i = 0; i < 7; i++) {
            if (segments[digit, i]) {
                int sx = x + segmentCoords[i,0];
                int sy = y + segmentCoords[i,1];
                int sw = segmentCoords[i,2];
                int sh = segmentCoords[i,3];
                
                switch (i) {
                    case 0:
                       cr.rectangle(sx, sy, sw, sh);
                       cr.rectangle(sx + 1, sy + 1, sw - 2, sh);
                       cr.fill();
                       break;
                    case 1:
                       cr.rectangle(sx, sy, sw, sh);
                       cr.rectangle(sx - 1, sy + 1, sw, sh - 2);
                       cr.fill();
                       break;
                    case 2:
                       cr.rectangle(sx, sy, sw, sh);
                       cr.rectangle(sx - 1, sy + 1, sw, sh - 2);
                       cr.fill();
                       break;
                    case 3:
                       cr.rectangle(sx, sy, sw, sh);
                       cr.rectangle(sx + 1, sy - 1, sw - 2, sh);
                       cr.fill();
                       break;
                    case 4:
                       cr.rectangle(sx, sy, sw, sh);
                       cr.rectangle(sx + 1, sy + 1, sw, sh - 2);
                       cr.fill();
                       break;
                    case 5:
                       cr.rectangle(sx, sy, sw, sh);
                       cr.rectangle(sx + 1, sy + 1, sw, sh - 2);
                       cr.fill();
                       break;
                    case 6:
                       cr.rectangle(sx, sy, sw, sh);
                       cr.rectangle(sx + 1, sy + 1, sw - 2, sh);
                       cr.fill();
                       break;
                }
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