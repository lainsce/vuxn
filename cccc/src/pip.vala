namespace App {
    /**
     * Custom drawing area for binary pips that represent hexadecimal value
     */
    private class PipDrawingArea : Gtk.DrawingArea {
        // State tracking for all 16 pips (4 sets of 4 pips)
        private bool[,] pips = new bool[4, 4];

        // Pip dimensions
        private const int PIP_WIDTH = 4;
        private const int PIP_HEIGHT = 8;
        private const int PIP_SPACING_X = 1;
        private const int PIP_GROUP_SPACING = 6;

        // Colors
        private Gdk.RGBA pip_color;

        // Theme manager reference
        private Theme.Manager theme;

        // Callback for when value changes
        public signal void value_changed(string new_value);

        public PipDrawingArea() {
            // Set up the drawing area properties
            set_draw_func(draw_pips);

            // Enable click events
            add_css_class("pip-area");
            set_hexpand(true);
            set_valign(Gtk.Align.CENTER);

            // Set up event controller for mouse clicks
            var click_controller = new Gtk.GestureClick();
            click_controller.set_button(1); // Left mouse button
            click_controller.pressed.connect(on_press);
            add_controller(click_controller);

            // Get the theme manager
            theme = Theme.Manager.get_default();

            // Get color from theme manager
            pip_color = theme.get_color("theme_accent");

            // Listen for theme changes
            theme.theme_changed.connect(update_colors);

            // Set a reasonable size for the widget
            set_size_request(96, 8);
        }

        /**
         * Update pip colors when theme changes
         */
        private void update_colors() {
            pip_color = theme.get_color("theme_selection");
            queue_draw();
        }

        // Update the widget from a hex string
        public void set_from_hex(string hex_value) {
            string padded_hex = hex_value;

            // If empty, default to 0
            if (padded_hex == "") {
                padded_hex = "0";
            }

            // Parse as integer with base 16
            int64 value = int64.parse(padded_hex, 16);

            // Update the pips based on binary representation
            for (int group = 0; group < 4; group++) {
                for (int bit = 0; bit < 4; bit++) {
                    int shift = (3 - group) * 4 + (3 - bit);
                    pips[group, bit] = ((value >> shift) & 1) == 1;
                }
            }

            // Redraw
            queue_draw();
        }

        // Get the current hex string from the pips state
        public string get_hex_value() {
            int64 value = 0;

            // Build the value from pip states
            for (int group = 0; group < 4; group++) {
                for (int bit = 0; bit < 4; bit++) {
                    if (pips[group, bit]) {
                        int shift = (3 - group) * 4 + (3 - bit);
                        value |= ((int64) 1 << shift);
                    }
                }
            }

            return value.to_string("%X");
        }

        // Handle click events
        private void on_press(int n_press, double x, double y) {
            // Convert click coordinates to pip position
            int clicked_group = -1;
            int clicked_bit = -1;

            for (int group = 0; group < 4; group++) {
                int group_x_offset = group * (4 * PIP_WIDTH + 3 * PIP_SPACING_X + PIP_GROUP_SPACING);

                for (int bit = 0; bit < 4; bit++) {
                    int pip_x = group_x_offset + bit * (PIP_WIDTH + PIP_SPACING_X);

                    if (x >= pip_x && x < pip_x + PIP_WIDTH &&
                        y >= 0 && y < PIP_HEIGHT) {
                        clicked_group = group;
                        clicked_bit = bit;
                        break;
                    }
                }

                if (clicked_group >= 0)break;
            }

            // If a pip was clicked, toggle its state
            if (clicked_group >= 0 && clicked_bit >= 0) {
                pips[clicked_group, clicked_bit] = !pips[clicked_group, clicked_bit];

                // Update the value and emit the signal
                queue_draw();
                value_changed(get_hex_value());
            }
        }

        // Draw the pips
        private void draw_pips(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
            // Clear the background
            cr.set_source_rgba(0, 0, 0, 0);
            cr.paint();

            // Set up for no antialiasing
            cr.set_antialias(Cairo.Antialias.NONE);
            cr.set_line_width(1);
            cr.set_line_join(Cairo.LineJoin.MITER);
            cr.set_line_cap(Cairo.LineCap.SQUARE);

            // Draw each pip
            for (int group = 0; group < 4; group++) {
                int group_x_offset = group * (4 * PIP_WIDTH + 3 * PIP_SPACING_X + PIP_GROUP_SPACING);

                for (int bit = 0; bit < 4; bit++) {
                    int pip_x = group_x_offset + bit * (PIP_WIDTH + PIP_SPACING_X);

                    // Set color based on state
                    cr.set_source_rgba(
                                       pip_color.red,
                                       pip_color.green,
                                       pip_color.blue,
                                       pip_color.alpha
                    );

                    if (pips[group, bit]) {
                        // Draw filled pip with rounded corners (skip corner pixels)
                        cr.rectangle(pip_x + 1, 0, PIP_WIDTH - 2, 1); // Top row minus corners
                        cr.rectangle(pip_x, 1, PIP_WIDTH, PIP_HEIGHT - 2); // Middle rows
                        cr.rectangle(pip_x + 1, PIP_HEIGHT - 1, PIP_WIDTH - 2, 1); // Bottom row minus corners
                        cr.fill();
                    } else {
                        // Draw the inactive pip pixel by pixel to match the active shape exactly
                        // Top row (minus corners)
                        for (int i = 1; i < PIP_WIDTH - 1; i++) {
                            cr.rectangle(pip_x + i, 0, 1, 1);
                        }

                        // Left and right sides
                        for (int j = 1; j < PIP_HEIGHT - 1; j++) {
                            cr.rectangle(pip_x, j, 1, 1);
                            cr.rectangle(pip_x + PIP_WIDTH - 1, j, 1, 1);
                        }

                        // Bottom row (minus corners)
                        for (int i = 1; i < PIP_WIDTH - 1; i++) {
                            cr.rectangle(pip_x + i, PIP_HEIGHT - 1, 1, 1);
                        }

                        cr.fill();
                    }
                }
            }
        }
    }
}
