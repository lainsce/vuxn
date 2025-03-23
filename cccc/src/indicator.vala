public class Indicator : Gtk.Box {
    private const int WIDTH = 8;
    private const int HEIGHT = 16;
    private Gtk.DrawingArea da;
    private Theme.Manager theme;
    public bool playing = false;

    public Indicator() {
        set_size_request(WIDTH, HEIGHT);
        vexpand = true;
        valign = Gtk.Align.CENTER;

        da = new Gtk.DrawingArea();
        da.vexpand = true;
        da.set_size_request(WIDTH, HEIGHT);
        da.set_draw_func(draw_pixel_arrow);

        theme = Theme.Manager.get_default();
        theme.theme_changed.connect(da.queue_draw);

        append(da);
    }

    private void draw_pixel_arrow(Gtk.DrawingArea drawing_area, Cairo.Context cr, int width, int height) {
        cr.set_antialias(Cairo.Antialias.NONE);
        var bg_color = theme.get_color("theme_bg");

        // Centered right-pointing arrow (8px tall, vertically centered)
        int[,] arrow_pixels = {
            // Tip (top to bottom)
            { 0, 4 }, // Row 0 (top of arrow)
            { 1, 5 }, { 0, 5 }, // Row 1
            { 2, 6 }, { 1, 6 }, { 0, 6 }, // Row 2
            { 3, 7 }, { 2, 7 }, { 1, 7 }, { 0, 7 }, // Row 3 (widest)
            { 2, 8 }, { 1, 8 }, { 0, 8 }, // Row 4
            { 1, 9 }, { 0, 9 }, // Row 5
            { 0, 10 }, // Row 6 (bottom of arrow)
        };

        // Draw each pixel
        for (int i = 0; i < arrow_pixels.length[0]; i++) {
            if (playing) {
                cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
            } else {
                cr.set_source_rgba(0.0, 0.0, 0.0, 0.0);
            }
            cr.rectangle(arrow_pixels[i, 0], arrow_pixels[i, 1], 1, 1);
            cr.fill();
        }
    }
}
