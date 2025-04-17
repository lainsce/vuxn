public class FrameBox : Gtk.Box {
    private VasuData chr_data;

    public FrameBox(VasuData data, Gtk.Orientation orientation, int spacing, Gtk.Box? parent) {
        Object(orientation: orientation, spacing: spacing);
        
        chr_data = data;
        
        // Make sure we can draw on this widget
        set_overflow(Gtk.Overflow.HIDDEN);
        
        // Connect to the draw signal
        var draw_controller = new Gtk.DrawingArea();
        draw_controller.set_size_request(10, 10); // Minimal size, will expand
        draw_controller.set_draw_func(draw_frame);
        draw_controller.set_can_target(false);
        
        // Add the drawing area as an overlay
        var overlay = new Gtk.Overlay();
        overlay.set_child(this);
        overlay.add_overlay(draw_controller);
        
        // Replace this box with the overlay in the parent
        if (parent != null) {
            parent.remove(this);
            parent.append(overlay);
        }
        
        chr_data.palette_changed.connect(() => {
            draw_controller.queue_draw();
        });
    }
    
    private void draw_frame(Gtk.DrawingArea drawing_area, Cairo.Context cr, int width, int height) {
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Use the appropriate color from the theme
        Gdk.RGBA color = chr_data.get_color(2);
        cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
        
        // Draw border with the specific corner design
        // Top border
        cr.rectangle(2, 0, width - 4, 1);
        
        // Bottom border
        cr.rectangle(2, height - 1, width - 4, 1);
        
        // Left border
        cr.rectangle(0, 2, 1, height - 4);
        
        // Right border
        cr.rectangle(width - 1, 2, 1, height - 4);
        
        // Top-left corner pixel connections
        cr.rectangle(1, 1, 1, 1);
        
        // Top-right corner pixel connections
        cr.rectangle(width - 2, 1, 1, 1);
        
        // Bottom-left corner pixel connections
        cr.rectangle(1, height - 2, 1, 1);
        
        // Bottom-right corner pixel connections
        cr.rectangle(width - 2, height - 2, 1, 1);
        
        cr.fill();
    }
}