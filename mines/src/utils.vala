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
        // Ensure we're using 1px lines with no anti-aliasing
        cr.set_antialias(Cairo.Antialias.NONE);
        cr.set_line_width(1);

        // Draw all white parts
        set_color(cr, 2); // white/background
        cr.rectangle(x, y, 15, 1);           // Row 1: 15 white
        cr.rectangle(x, y + 1, 14, 1);       // Row 2: 14 white
        for (int i = 2; i < 14; i++) {
            cr.rectangle(x, y + i, 2, 1);    // Rows 3-14: 2 white each
        }
        cr.rectangle(x, y + 14, 1, 1);       // Row 15: 1 white
        cr.fill();

        // Draw all gray parts
        set_color(cr, 3); // gray/accent
        cr.rectangle(x + 15, y, 1, 1);       // Row 1: 1 gray at the end
        cr.rectangle(x + 14, y + 1, 1, 1);   // Row 2: 1 gray
        for (int i = 2; i < 14; i++) {
            cr.rectangle(x + 2, y + i, 12, 1); // Rows 3-14: 12 gray each
        }
        cr.rectangle(x + 1, y + 14, 1, 1);   // Row 15: 1 gray
        cr.rectangle(x, y + 15, 1, 1);       // Row 16: 1 gray
        cr.fill();

        // Draw all black parts
        set_color(cr, 1); // black/foreground
        cr.rectangle(x + 15, y + 1, 1, 1);   // Row 2: 1 black at the end
        for (int i = 2; i < 14; i++) {
            cr.rectangle(x + 14, y + i, 2, 1); // Rows 3-14: 2 black each at the end
        }
        cr.rectangle(x + 2, y + 14, 14, 1);  // Row 15: 14 black
        cr.rectangle(x + 1, y + 15, 15, 1);  // Row 16: 15 black
        cr.fill();
    }
    
    public static void draw_flat_tile(Cairo.Context cr, int x, int y, int width, int height) {
        // Ensure we're using 1px lines with no anti-aliasing
        cr.set_antialias(Cairo.Antialias.NONE);
        cr.set_line_width(1);

        // Draw all white parts
        set_color(cr, 0); // white/background
        for (int i = 0; i < 15; i += 2) {
            cr.rectangle(x, y + i, 15, 1);   // Odd rows: 15 white each
        }
        for (int i = 1; i < 15; i += 2) {
            cr.rectangle(x, y + i, 16, 1);   // Even rows: 16 white each
        }
        for (int i = 1; i < 14; i += 2) {
            cr.rectangle(x + i, y + 15, 1, 1); // Bottom row: alternating white
        }
        cr.fill();

        // Draw all gray parts
        set_color(cr, 2); // gray/accent
        for (int i = 0; i < 15; i += 2) {
            cr.rectangle(x + 15, y + i, 1, 1); // Odd rows: 1 gray at the end
        }
        cr.rectangle(x + 14, y + 15, 2, 1);  // Bottom row: 2 gray at the end

        for (int i = 0; i < 14; i += 2) {
            cr.rectangle(x + i, y + 15, 1, 1); // Bottom row: alternating black
        }
        cr.fill();
    }
    
    public static void draw_flag(Cairo.Context cr, int x, int y) {
        // Black parts (color 1)
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
        set_color(cr, 2);
        cr.rectangle(x + 5, y + 4, 1, 1);
        cr.rectangle(x + 4, y + 5, 1, 1);
        cr.rectangle(x + 6, y + 5, 1, 1);
        cr.rectangle(x + 5, y + 6, 1, 1);
        cr.fill();

    }
    
    public static void draw_number(Cairo.Context cr, int x, int y, int number) {
        // With only 4 colors, we'll use black for all numbers in a true 2-bit style
        set_color(cr, 3); // Black for all numbers
        
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
        // Ensure we're using 1px lines with no anti-aliasing
        cr.set_antialias(Cairo.Antialias.NONE);
        cr.set_line_width(1);
        
        // Fill middle with transparent/no color (alpha)
        set_color(cr, 4); // Alpha for background
        cr.rectangle(x + 2, y + 2, width - 4, height - 4);
        cr.fill();
        
        // Draw all dark gray parts (for top and left edges)
        set_color(cr, 1); // Dark gray
        cr.rectangle(x, y, width, 1);        // Top row
        cr.rectangle(x, y + 1, 1, height - 1); // Left column
        cr.rectangle(x + 1, y + 1, width - 2, 1); // Second row
        cr.rectangle(x + 1, y + 2, 1, height - 3); // Second column
        cr.fill();
        
        // Draw all white parts (for bottom and right edges)
        set_color(cr, 2); // White
        cr.rectangle(x + 1, y + height - 1, width - 1, 1); // Bottom row
        cr.rectangle(x + width - 1, y + 1, 1, height - 2); // Right column
        cr.rectangle(x + 2, y + height - 2, width - 3, 1); // Second-to-last row
        cr.rectangle(x + width - 2, y + 2, 1, height - 4); // Second-to-last column
        cr.fill();
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
        // Ensure we're using 1px lines with no anti-aliasing
        cr.set_antialias(Cairo.Antialias.NONE);
        
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
        
        // Draw dark gray background (*)
        set_color(cr, 3); // Dark gray
        cr.rectangle(x, y, 16, 16);
        cr.fill();
        
        // Draw light gray areas (_)
        set_color(cr, 2); // Light gray
        
        // Row 2: 12 light gray in middle
        cr.rectangle(x + 2, y + 1, 12, 1);
        
        // Row 3: special pattern
        cr.rectangle(x + 1, y + 2, 1, 1);
        cr.rectangle(x + 3, y + 2, 10, 1);
        cr.rectangle(x + 14, y + 2, 1, 1);
        
        // Rows 4-7: sides only
        for (int i = 3; i < 7; i++) {
            cr.rectangle(x + 1, y + i, 2, 1);
            cr.rectangle(x + 13, y + i, 2, 1);
        }
        
        // Row 8: special pattern
        cr.rectangle(x + 1, y + 7, 1, 1);
        cr.rectangle(x + 3, y + 7, 10, 1);
        cr.rectangle(x + 14, y + 7, 1, 1);
        
        // Row 9: special pattern with middle section
        cr.rectangle(x + 1, y + 8, 2, 1);
        cr.rectangle(x + 4, y + 8, 8, 1);
        cr.rectangle(x + 13, y + 8, 2, 1);
        
        // Rows 10-13: sides only
        for (int i = 9; i < 13; i++) {
            cr.rectangle(x + 1, y + i, 2, 1);
            cr.rectangle(x + 13, y + i, 2, 1);
        }
        
        // Row 14: special pattern
        cr.rectangle(x + 1, y + 13, 1, 1);
        cr.rectangle(x + 3, y + 13, 10, 1);
        cr.rectangle(x + 14, y + 13, 1, 1);
        
        // Row 15: 12 light gray in middle
        cr.rectangle(x + 2, y + 14, 12, 1);
        cr.fill();
        
        // Now draw the lit segments (black)
        set_color(cr, 1); // Black for lit segments
        
        // Draw the segments based on the provided patterns
        if (segments[digit, 0]) { // Segment A (top)
            cr.rectangle(x + 2, y + 1, 12, 1);  // Row 2: columns 2-13
            cr.rectangle(x + 3, y + 2, 10, 1);  // Row 3: middle
        }
        
        if (segments[digit, 1]) { // Segment B (top right)
            // Columns 13-14, rows 2-7
            cr.rectangle(x + 14, y + 2, 1, 1);  // Row 3: corner
            for (int i = 3; i < 7; i++) {
                cr.rectangle(x + 13, y + i, 2, 1);
            }
            cr.rectangle(x + 14, y + 7, 1, 1);  // Row 8: corner
        }
        
        if (segments[digit, 2]) { // Segment C (bottom right)
            // Columns 13-14, rows 8-13
            cr.rectangle(x + 13, y + 8, 2, 1);
            for (int i = 9; i < 13; i++) {
                cr.rectangle(x + 13, y + i, 2, 1);
            }
            cr.rectangle(x + 14, y + 13, 1, 1); // Row 14: corner
        }
        
        if (segments[digit, 3]) { // Segment D (bottom)
            cr.rectangle(x + 3, y + 13, 10, 1); // Row 14: middle
            cr.rectangle(x + 2, y + 14, 12, 1); // Row 15: columns 2-13
        }
        
        if (segments[digit, 4]) { // Segment E (bottom left)
            // Columns 1-2, rows 8-13
            cr.rectangle(x + 1, y + 8, 2, 1);
            for (int i = 9; i < 13; i++) {
                cr.rectangle(x + 1, y + i, 2, 1);
            }
            cr.rectangle(x + 1, y + 13, 1, 1); // Row 14: corner
        }
        
        if (segments[digit, 5]) { // Segment F (top left)
            // Columns 1-2, rows 2-7
            cr.rectangle(x + 1, y + 2, 1, 1);  // Row 3: corner
            for (int i = 3; i < 7; i++) {
                cr.rectangle(x + 1, y + i, 2, 1);
            }
            cr.rectangle(x + 1, y + 7, 1, 1);  // Row 8: corner
        }
        
        if (segments[digit, 6]) { // Segment G (middle)
            // Only the middle horizontal bars
            cr.rectangle(x + 3, y + 7, 10, 1); // Row 8: columns 3-12
            cr.rectangle(x + 4, y + 8, 8, 1);  // Row 9: columns 4-11
        }
        
        cr.fill();
    }
    
    // Create the standard 3-digit number display (e.g., for timer and mine counter)
    public static Gtk.DrawingArea create_digit_display() {
        return new Gtk.DrawingArea() {
            content_width = 3 * 8, // DIGIT_WIDTH = 8
            content_height = 16    // DIGIT_HEIGHT = 16
        };
    }
}