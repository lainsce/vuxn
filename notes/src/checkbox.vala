private class CairoCheckbox : Gtk.DrawingArea {
    private bool _active = false;
    public bool active {
        get { return _active; }
        set {
            _active = value;
            queue_draw();
        }
    }

    construct {
        width_request = 11;
        height_request = 11;
        set_draw_func(draw_checkbox);
    }

    private void draw_checkbox(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        var theme = Theme.Manager.get_default();
        Gdk.RGBA fg_color = theme.get_color("theme_fg");
        Gdk.RGBA bg_color = theme.get_color("theme_bg");
        
        draw_cairo_checkbox(cr, width, height, active, fg_color, bg_color);
    }

   public void draw_cairo_checkbox(Cairo.Context cr, int width, int height, bool checked, Gdk.RGBA fg_color, Gdk.RGBA bg_color) {
    // Set antialias to none for crisp pixel-perfect drawing
    cr.set_antialias(Cairo.Antialias.NONE);
    
    // Set line width to 1 pixel
    cr.set_line_width(1.0);
    
    // Draw circle outline using rectangles
    cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, fg_color.alpha);
    
    // Top horizontal line
    cr.rectangle(2, 0, 7, 1);
    cr.fill();
    
    // Bottom horizontal line
    cr.rectangle(2, 10, 7, 1);
    cr.fill();
    
    // Left vertical line
    cr.rectangle(0, 2, 1, 7);
    cr.fill();
    
    // Right vertical line
    cr.rectangle(10, 2, 1, 7);
    cr.fill();
    
    // Corner pixels
    cr.rectangle(1, 1, 1, 1);  // top-left
    cr.fill();
    cr.rectangle(9, 1, 1, 1);  // top-right
    cr.fill();
    cr.rectangle(1, 9, 1, 1);  // bottom-left
    cr.fill();
    cr.rectangle(9, 9, 1, 1);  // bottom-right
    cr.fill();
    
    // If checked, draw inner fill
    if (checked) {
        cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, fg_color.alpha);
        
        // Flattened array of check pixels
int[] check_pixels = {
    3, 2, 4, 2, 5, 2, 6, 2, 7, 2,  // 5px line at the top
    2, 3, 3, 3, 4, 3, 5, 3, 6, 3, 7, 3, 8, 3,  // 7px line
    2, 4, 3, 4, 4, 4, 5, 4, 6, 4, 7, 4, 8, 4,  // 7px line
    2, 5, 3, 5, 4, 5, 5, 5, 6, 5, 7, 5, 8, 5,  // 7px line
    2, 6, 3, 6, 4, 6, 5, 6, 6, 6, 7, 6, 8, 6,  // 7px line
    2, 7, 3, 7, 4, 7, 5, 7, 6, 7, 7, 7, 8, 7,  // 7px line
    3, 8, 4, 8, 5, 8, 6, 8, 7, 8  // 5px line at the bottom
};
        
        for (int i = 0; i < check_pixels.length; i += 2) {
            cr.rectangle(check_pixels[i], check_pixels[i+1], 1, 1);
            cr.fill();
        }
    }
}

    public CairoCheckbox(bool initial_state = false) {
        active = initial_state;
    }
}