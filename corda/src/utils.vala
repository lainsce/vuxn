// Constants for the rulers
public class CordaConstants {
    public const double CM_TO_INCH = 0.393701;
    public const double INCH_TO_CM = 2.54;
    public const int RULER_HEIGHT = 32;
    public const int RULER_TOP_PADDING = 0;
    public const int WINDOW_WIDTH = 128;
    public const int WINDOW_HEIGHT = 80;
    public const double PIXELS_PER_MM = 8.0;
    public const double CM_RULER_Y = 8;
    public const double INCH_RULER_Y = WINDOW_HEIGHT - RULER_HEIGHT - 8;
}

// Class to store the state of the rulers
public class CordaState {
    public double cm_x = 8;
    public double inch_x = 8;
    public bool dragging_cm = false;
    public bool dragging_inch = false;
    public double drag_start_x = 0;
    public double drag_start_cm_x = 0;
    public double drag_start_inch_x = 0;
}

// Helper class for drawing rulers
public class CordaDrawHelper {
    public static void draw_cm_ruler(Cairo.Context cr, double y, int width) {
        var theme = Theme.Manager.get_default();
        var fg_color = theme.get_color ("theme_fg");
        cr.set_source_rgb(fg_color.red, 
                          fg_color.green, 
                          fg_color.blue);

        double y_aligned = Math.floor(y) + 0.5;
        
        // Draw cm markings (1 cm = 10 mm)
        double mm_width = CordaConstants.PIXELS_PER_MM;
        double ruler_bottom = y_aligned + Math.floor(CordaConstants.RULER_HEIGHT);
        double max_cm_width = (10 * CordaConstants.PIXELS_PER_MM) * 38.7;
        
        draw_ruler_base(cr, y_aligned, max_cm_width);
        
        for (int i = 0; i <= 76.2; i++) {
            double x = Math.floor(i * mm_width * 10) + 0.5;
            
            // Major tick (cm)
            cr.move_to(x, ruler_bottom);
            cr.line_to(x, ruler_bottom - Math.floor(CordaConstants.RULER_HEIGHT / 3));
            cr.stroke();
            
            // Label - positioned near the major tick
            cr.move_to(x + 4, ruler_bottom - 12);
            cr.select_font_face("Monaco", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(10);
            cr.show_text(i.to_string());
            
            // Minor ticks (mm)
            if (i < 76.2) {
                for (int j = 1; j < 10; j++) {
                    double minor_x = Math.floor(x + (j * mm_width)) + 0.5;
                    double tick_height = Math.floor(CordaConstants.RULER_HEIGHT / 5);
                    
                    cr.move_to(minor_x, ruler_bottom);
                    cr.line_to(minor_x, ruler_bottom - tick_height);
                    cr.stroke();
                }
            }
        }
    }
    
    // Draw inch ruler
    public static void draw_inch_ruler(Cairo.Context cr, double y, int width) {
        var theme = Theme.Manager.get_default();
        var fg_color = theme.get_color ("theme_fg");
        cr.set_source_rgb(fg_color.red, 
                          fg_color.green, 
                          fg_color.blue);

        double y_aligned = Math.floor(y) + 0.5;

        // 1 inch = 2.54 cm = 25.4 mm
        double mm_width = CordaConstants.PIXELS_PER_MM;
        double inch_width = 25.4 * mm_width;
        double max_inch_width =  (10 * CordaConstants.PIXELS_PER_MM) * 38.7;
        
        draw_ruler_base(cr, y_aligned, max_inch_width);
        
        for (int i = 0; i <= 30; i++) {
            double x = Math.floor(i * inch_width) + 0.5;
            
            // Major tick (inch)
            cr.move_to(x, y_aligned);
            cr.line_to(x, y_aligned + Math.floor(CordaConstants.RULER_HEIGHT / 3));
            cr.stroke();
            
            // Label - positioned near the major tick
            cr.move_to(x + 4, y_aligned + 16);
            cr.select_font_face("Monaco", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(10);
            cr.show_text(i.to_string());
            
            // Minor ticks (1/8, 1/4, 3/8, 1/2, 5/8, 3/4, 7/8)
            if (i < 30) {
                draw_inch_subdivisions(cr, x, y_aligned, inch_width, true);
            }
        }
    }
    
    // Helper to draw inch subdivisions
    private static void draw_inch_subdivisions(Cairo.Context cr, double x, double y, double inch_width, bool from_top = false) {
        // Eighths
        for (int j = 1; j < 8; j++) {
            double minor_x = Math.floor(x + (j * inch_width / 8)) + 0.5;
            double tick_height;
            
            // 1/4 and 3/4 marks
            if (j == 2 || j == 6) {
                tick_height = Math.floor(CordaConstants.RULER_HEIGHT / 4);
            } 
            // 1/2 mark
            else if (j == 4) {
                tick_height = Math.floor(CordaConstants.RULER_HEIGHT / 3.5);
            } 
            // 1/8, 3/8, 5/8, 7/8 marks
            else {
                tick_height = Math.floor(CordaConstants.RULER_HEIGHT / 6);
            }
            
            if (from_top) {
                cr.move_to(minor_x, y);
                cr.line_to(minor_x, y + tick_height);
            } else {
                double ruler_bottom = y + Math.floor(CordaConstants.RULER_HEIGHT);
                cr.move_to(minor_x, ruler_bottom);
                cr.line_to(minor_x, ruler_bottom - tick_height);
            }
            cr.stroke();
        }
    }
    
    // Helper to draw the ruler base lines
    private static void draw_ruler_base(Cairo.Context cr, double y, double width) {
        double y_aligned = Math.floor(y) + 0.5;
        double height = Math.floor(CordaConstants.RULER_HEIGHT);
        var theme = Theme.Manager.get_default();
        var bg_color = theme.get_color ("theme_bg");
        var fg_color = theme.get_color ("theme_fg");
        
        // Draw a rectangle for the ruler
        cr.rectangle(0.5, y_aligned, width * 2, height);
        cr.set_source_rgb(bg_color.red, 
                          bg_color.green, 
                          bg_color.blue);
        cr.fill_preserve();
        
        // Black outline
        cr.set_source_rgb(fg_color.red, 
                          fg_color.green, 
                          fg_color.blue);
        cr.stroke();
    }
}