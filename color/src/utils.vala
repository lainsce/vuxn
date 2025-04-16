public struct RgbColor {
    public uint8 r;
    public uint8 g;
    public uint8 b;
}

public struct HsvColor {
    public uint8 h;
    public uint8 s;
    public uint8 v;
}

public class ColorWheelArea : Gtk.DrawingArea {
    public uint8 h { get; set; }
    public uint8 s { get; set; }
    public uint8 v { get; set; }
    
    private const int PAD = 20;
    
    public signal void color_changed();
    
    private Gtk.GestureDrag? drag_gesture;
    private Gtk.GestureClick? click_gesture;
    
    // Drag mode tracking
    private enum DragMode {
        NONE,
        HUE,
        SATURATION,
        VALUE
    }
    private DragMode current_drag_mode = DragMode.NONE;
    
    // Reference to theme manager
    private Theme.Manager theme_manager;
    
    public ColorWheelArea(Theme.Manager theme_mgr) {
        this.theme_manager = theme_mgr;
        
        set_draw_func(draw);
        
        click_gesture = new Gtk.GestureClick();
        click_gesture.set_button(1);
        click_gesture.pressed.connect(on_pressed);
        add_controller(click_gesture);
        
        drag_gesture = new Gtk.GestureDrag();
        drag_gesture.drag_begin.connect(on_drag_begin);
        drag_gesture.drag_update.connect(on_drag_update);
        drag_gesture.drag_end.connect(on_drag_end);
        add_controller(drag_gesture);
    }
    
    private void draw(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        int size = int.min(width, height);
        int radius = (size / 2) - PAD;
        double center_x = width / 2.0;
        double center_y = height / 2.5; // Give enough space between the wheel and the bar

        cr.set_antialias(Cairo.Antialias.NONE);

        var bg_color = theme_manager.get_color("theme_bg");
        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
        cr.paint();
        
        // Check if we're in 1-bit mode
        bool is_one_bit = (theme_manager.color_mode == Theme.ColorMode.ONE_BIT);
        
        // Draw color wheel ring
        for (int i = 0; i < 360; i++) {
            double angle1 = i * Math.PI / 180.0;
            double angle2 = (i + 1) * Math.PI / 180.0;
            
            double x1 = center_x + Math.cos(angle1) * radius;
            double y1 = center_y + Math.sin(angle1) * radius;
            double x2 = center_x + Math.cos(angle2) * radius;
            double y2 = center_y + Math.sin(angle2) * radius;
            
            uint8 hue = (uint8)((angle1 / (2 * Math.PI)) * 255);
            
            var rgb = hsv_to_rgb(hue, 255, 255);
            
            // In 1-bit mode, convert colors to black or white
            if (is_one_bit) {
                // Use Theme.ContrastHelper to convert to 1-bit
                var rgba = Gdk.RGBA();
                rgba.red = rgb.r / 255.0f;
                rgba.green = rgb.g / 255.0f;
                rgba.blue = rgb.b / 255.0f;
                rgba.alpha = 1.0f;
                
                var one_bit = Theme.ContrastHelper.to_one_bit(rgba);
                
                cr.set_source_rgb(one_bit.red, one_bit.green, one_bit.blue);
            } else {
                cr.set_source_rgb(rgb.r / 255.0f, rgb.g / 255.0f, rgb.b / 255.0f);
            }
            
            cr.set_line_width(1); // 1px thick lines as per user preference
            
            cr.move_to(x1, y1);
            cr.line_to(x2, y2);
            cr.stroke();
        }
        
        // Draw hue selection
        double angle = (h / 255.0) * (2 * Math.PI);
        double hue_x = center_x + Math.cos(angle) * radius;
        double hue_y = center_y + Math.sin(angle) * radius;
        
        var hue_rgb = hsv_to_rgb(h, 255, 255);
        
        // In 1-bit mode, convert colors to black or white
        if (is_one_bit) {
            var rgba = Gdk.RGBA();
            rgba.red = hue_rgb.r / 255.0f;
            rgba.green = hue_rgb.g / 255.0f;
            rgba.blue = hue_rgb.b / 255.0f;
            rgba.alpha = 1.0f;
            
            var one_bit = Theme.ContrastHelper.to_one_bit(rgba);
            cr.set_source_rgb(one_bit.red, one_bit.green, one_bit.blue);
        } else {
            cr.set_source_rgb(hue_rgb.r / 255.0f, hue_rgb.g / 255.0f, hue_rgb.b / 255.0f);
        }
        
        cr.arc(hue_x, hue_y, 4, 0, 2 * Math.PI);
        cr.fill();
        
        // Draw saturation
        double distance = (s / 255.0) * (radius * 0.8);
        double sat_x = center_x + Math.cos(angle) * distance;
        double sat_y = center_y + Math.sin(angle) * distance;
        
        var sel_rgb = hsv_to_rgb(h, s, v);
        
        // In 1-bit mode, convert colors to black or white
        if (is_one_bit) {
            var rgba = Gdk.RGBA();
            rgba.red = sel_rgb.r / 255.0f;
            rgba.green = sel_rgb.g / 255.0f;
            rgba.blue = sel_rgb.b / 255.0f;
            rgba.alpha = 1.0f;
            
            var one_bit = Theme.ContrastHelper.to_one_bit(rgba);
            cr.set_source_rgb(one_bit.red, one_bit.green, one_bit.blue);
        } else {
            cr.set_source_rgb(sel_rgb.r / 255.0f, sel_rgb.g / 255.0f, sel_rgb.b / 255.0f);
        }
        
        cr.set_line_width(1);
        cr.arc(center_x, center_y, distance, 0, 2 * Math.PI);
        cr.stroke();
        
        cr.arc(sat_x, sat_y, 4, 0, 2 * Math.PI);
        cr.fill();
        
        // Draw line from hue point to sat point
        cr.move_to(hue_x, hue_y);
        cr.line_to(sat_x, sat_y);
        cr.stroke();
        
        // Draw brightness slider if we have room
        if (height > width + 2 * PAD) {
            double slider_top = height - PAD * 2;
            double slider_bottom = height - PAD;
            double slider_left = PAD;
            double slider_right = width - PAD;
            
            // Draw slider background
            cr.set_source_rgb(0.2, 0.2, 0.2);
            cr.rectangle(slider_left - 2, slider_top - 2, 
                         slider_right - slider_left + 4, 
                         slider_bottom - slider_top + 4);
            cr.fill();
            
            // Draw gradient
            for (int i = 0; i < 16; i++) {
                double gradient_left = slider_left + (slider_right - slider_left) * i / 16.0;
                double gradient_right = slider_left + (slider_right - slider_left) * (i + 1) / 16.0;
                double brightness = i / 16.0;
                
                var gradient_rgb = hsv_to_rgb(h, s, (uint8)(brightness * 255));
                
                // In 1-bit mode, convert colors to black or white
                if (is_one_bit) {
                    var rgba = Gdk.RGBA();
                    rgba.red = gradient_rgb.r / 255.0f;
                    rgba.green = gradient_rgb.g / 255.0f;
                    rgba.blue = gradient_rgb.b / 255.0f;
                    rgba.alpha = 1.0f;
                    
                    var one_bit = Theme.ContrastHelper.to_one_bit(rgba);
                    cr.set_source_rgb(one_bit.red, one_bit.green, one_bit.blue);
                } else {
                    cr.set_source_rgb(gradient_rgb.r / 255.0f, gradient_rgb.g / 255.0f, gradient_rgb.b / 255.0f);
                }
                
                cr.rectangle(gradient_left, slider_top, gradient_right - gradient_left, slider_bottom - slider_top);
                cr.fill();
            }
            
            // Draw value indicator
            double val_x = slider_left + (v / 255.0) * (slider_right - slider_left);
            cr.set_source_rgb(1.0, 1.0, 1.0);
            cr.set_line_width(2);
            cr.move_to(val_x, slider_top - 3);
            cr.line_to(val_x, slider_bottom + 3);
            cr.stroke();
            
            // In 1-bit mode, convert colors to black or white
            if (is_one_bit) {
                var rgba = Gdk.RGBA();
                rgba.red = sel_rgb.r / 255.0f;
                rgba.green = sel_rgb.g / 255.0f;
                rgba.blue = sel_rgb.b / 255.0f;
                rgba.alpha = 1.0f;
                
                var one_bit = Theme.ContrastHelper.to_one_bit(rgba);
                cr.set_source_rgb(one_bit.red, one_bit.green, one_bit.blue);
            } else {
                cr.set_source_rgb(sel_rgb.r / 255.0f, sel_rgb.g / 255.0f, sel_rgb.b / 255.0f);
            }
            
            cr.arc(val_x, (slider_top + slider_bottom) / 2, 4, 0, 2 * Math.PI);
            cr.fill();
        }
    }
    
    private void on_pressed(int n_press, double x, double y) {
        // For single clicks, we determine the mode and apply the change immediately
        determine_drag_mode(x, y);
        handle_pointer_event(x, y);
    }
    
    private void on_drag_begin(double x, double y) {
        // Set the drag mode at the beginning of the drag operation
        determine_drag_mode(x, y);
        handle_pointer_event(x, y);
    }
    
    private void on_drag_update(double offset_x, double offset_y) {
        // Get the starting point that was saved in begin
        double start_x, start_y;
        drag_gesture.get_start_point(out start_x, out start_y);
        
        // During drag updates, use the existing drag mode
        handle_pointer_event(start_x + offset_x, start_y + offset_y);
    }
    
    private void on_drag_end(double offset_x, double offset_y) {
        // Reset the drag mode when the drag is complete
        current_drag_mode = DragMode.NONE;
    }
    
    private void determine_drag_mode(double x, double y) {
        int width = get_width();
        int height = get_height();
        int size = int.min(width, height);
        int radius = (size / 2) - PAD;
        double center_x = width / 2.0;
        double center_y = height / 2.0;
        
        double dx = x - center_x;
        double dy = y - center_y;
        double distance = Math.sqrt(dx * dx + dy * dy);
        
        // Check for brightness slider first
        if (height > width + 2 * PAD && y > height - PAD * 2 && y < height - PAD) {
            current_drag_mode = DragMode.VALUE;
        }
        // Check for hue ring (outer)
        else if (distance > radius * 0.8) {
            current_drag_mode = DragMode.HUE;
        }
        // Otherwise it's saturation (inner)
        else {
            current_drag_mode = DragMode.SATURATION;
        }
    }
    
    private void handle_pointer_event(double x, double y) {
        int width = get_width();
        int height = get_height();
        int size = int.min(width, height);
        int radius = (size / 2) - PAD;
        double center_x = width / 2.0;
        double center_y = height / 2.0;
        
        // Handle the event based on the current drag mode
        switch (current_drag_mode) {
            case DragMode.HUE:
                // Calculate angle for hue
                double dx = x - center_x;
                double dy = y - center_y;
                double angle = Math.atan2(dy, dx);
                if (angle < 0) angle += 2 * Math.PI;
                
                // Update hue
                h = (uint8)((angle / (2 * Math.PI)) * 255);
                break;
                
            case DragMode.SATURATION:
                // Calculate distance for saturation (but cap it to avoid going outside wheel)
                double sx = x - center_x;
                double sy = y - center_y;
                double distance = Math.sqrt(sx * sx + sy * sy);
                
                // Cap the distance to stay within the inner circle
                double max_distance = radius * 0.8;
                distance = Math.fmin(distance, max_distance);
                
                // Update saturation
                s = (uint8)((distance / max_distance) * 255);
                break;
                
            case DragMode.VALUE:
                // Calculate position for brightness slider
                double slider_left = PAD;
                double slider_right = width - PAD;
                double slider_width = slider_right - slider_left;
                
                // Cap x position to slider bounds
                double val_x = Math.fmax(slider_left, Math.fmin(x, slider_right));
                double val_ratio = (val_x - slider_left) / slider_width;
                
                // Update value
                v = (uint8)(val_ratio * 255);
                break;
                
            case DragMode.NONE:
                // This shouldn't happen during normal operation
                break;
        }
        
        queue_draw();
        color_changed();
    }
    
    public RgbColor hsv_to_rgb(uint8 h, uint8 s, uint8 v) {
        RgbColor rgb = {};
        
        if (s == 0) {
            rgb.r = v;
            rgb.g = v;
            rgb.b = v;
            return rgb;
        }
        
        uint8 region = h / 43;
        uint8 remainder = (h - (region * 43)) * 6;
        uint8 p = (v * (255 - s)) >> 8;
        uint8 q = (v * (255 - ((s * remainder) >> 8))) >> 8;
        uint8 t = (v * (255 - ((s * (255 - remainder)) >> 8))) >> 8;
        
        switch (region) {
            case 0:
                rgb.r = v;
                rgb.g = t;
                rgb.b = p;
                break;
            case 1:
                rgb.r = q;
                rgb.g = v;
                rgb.b = p;
                break;
            case 2:
                rgb.r = p;
                rgb.g = v;
                rgb.b = t;
                break;
            case 3:
                rgb.r = p;
                rgb.g = q;
                rgb.b = v;
                break;
            case 4:
                rgb.r = t;
                rgb.g = p;
                rgb.b = v;
                break;
            default:
                rgb.r = v;
                rgb.g = p;
                rgb.b = q;
                break;
        }
        
        return rgb;
    }
    
    public HsvColor rgb_to_hsv(RgbColor rgb) {
        HsvColor hsv = {};
        
        uint8 rgb_min = uint8.min(uint8.min(rgb.r, rgb.g), rgb.b);
        uint8 rgb_max = uint8.max(uint8.max(rgb.r, rgb.g), rgb.b);
        
        hsv.v = rgb_max;
        if (hsv.v == 0) {
            hsv.h = 0;
            hsv.s = 0;
            return hsv;
        }
        
        hsv.s = (uint8)(255 * (rgb_max - rgb_min) / (double)hsv.v);
        if (hsv.s == 0) {
            hsv.h = 0;
            return hsv;
        }
        
        if (rgb_max == rgb.r)
            hsv.h = (uint8)(0 + 43 * (rgb.g - rgb.b) / (double)(rgb_max - rgb_min));
        else if (rgb_max == rgb.g)
            hsv.h = (uint8)(85 + 43 * (rgb.b - rgb.r) / (double)(rgb_max - rgb_min));
        else
            hsv.h = (uint8)(171 + 43 * (rgb.r - rgb.g) / (double)(rgb_max - rgb_min));
        
        return hsv;
    }
}