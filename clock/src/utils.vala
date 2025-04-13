public class Clock : Gtk.DrawingArea {
    private Theme.Manager theme;

    public Clock () {
        width_request = 200; // avoid spillage
        height_request = 200;
        theme = Theme.Manager.get_default ();
        set_draw_func (on_draw);
        theme.theme_changed.connect (queue_draw);
        set_vexpand (true);
        set_hexpand (true);
    }

    private void on_draw (Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        var center_x = width / 2.0;
        var center_y = height / 2.0;
        var radius = double.min (width, height) / 2.5;

        // Get theme colors (BG and FG are inverted for style purposes)
        var bg_color = theme.get_color ("theme_bg");
        var accent_color = theme.get_color ("theme_accent");
        var sel_color = theme.get_color ("theme_selection");

        // Draw clock border (dotted)
        cr.set_source_rgba (bg_color.red, bg_color.green, bg_color.blue, bg_color.alpha);
        cr.set_line_width (1);
        cr.set_antialias (Cairo.Antialias.NONE);
        cr.set_dash (new double[] { 1, 8 }, 1);
        cr.arc (center_x, center_y, radius, 0, 2 * Math.PI);
        cr.stroke ();
        cr.set_dash (null, 0);

        // Draw hour marks
        for (int i = 0; i < 12; i++) {
            double angle = i * Math.PI / 6;
            cr.move_to (
                        center_x + Math.cos (angle) * (radius - 13),
                        center_y + Math.sin (angle) * (radius - 13)
            );
            cr.line_to (
                        center_x + Math.cos (angle) * radius,
                        center_y + Math.sin (angle) * radius
            );
            cr.stroke ();
        }

        // Get current time
        var now = new DateTime.now_local ();
        double hours = now.get_hour () % 12 + now.get_minute () / 60.0;
        double minutes = now.get_minute () + now.get_second () / 60.0;
        double seconds = now.get_second ();

        // Draw hour hand
        draw_hand (cr, center_x, center_y, hours * 30, radius * 0.5, 1, accent_color);

        // Draw minute hand
        draw_hand (cr, center_x, center_y, minutes * 6, radius * 0.7, 1, accent_color);

        // Draw second hand
        draw_hand (cr, center_x, center_y, seconds * 6, radius * 0.8, 1, sel_color);
    }

    private void draw_hand (Cairo.Context cr, double x, double y, double angle, double length, double width, Gdk.RGBA color) {
        cr.save ();
        cr.set_line_width (width);
        cr.set_source_rgba (color.red, color.green, color.blue, color.alpha);
        angle = (angle - 90) * Math.PI / 180;
        cr.move_to (x, y);
        cr.line_to (
                    x + Math.cos (angle) * length,
                    y + Math.sin (angle) * length
        );
        cr.stroke ();
        cr.restore ();
    }
}
