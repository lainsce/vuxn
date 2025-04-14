public class MainWindow : Gtk.ApplicationWindow {
    private Gtk.DrawingArea drawing_area;
    private Gtk.ToggleButton mode_toggle;
    private Gtk.Box main_box;
    private ColorIndicator color_indicator;
    private Cairo.ImageSurface? original_image = null;  // Store original image
    private Cairo.ImageSurface? processed_image = null; // Store processed image
    
    // Use a simple boolean flag for 1-bit mode
    private bool is_one_bit_mode = false;
    
    // Contrast level fixed at 5
    private int contrast_level = 5;
    
    // Control visibility of color dots
    private bool show_color_dots = true;
    
    // Use Theme Manager for colors
    private Theme.Manager theme_manager;
    
    // Sampling points (x,y coordinates in image space, not drawing area space)
    private double[,] sample_points;
    private bool dragging_point = false;
    private int active_point = -1;
    private bool points_initialized = false;
    
    // Sample colors from original image
    private Gdk.RGBA[] sampled_colors;
    
    public MainWindow (Gtk.Application app) {
        Object (
            application: app,
            title: "Ditto",
            resizable: false
        );
        
        // Initialize sample points array (4 points with x,y coordinates)
        sample_points = new double[4, 2];
        sampled_colors = new Gdk.RGBA[4];
        
        for (int i = 0; i < 4; i++) {
            sampled_colors[i] = Gdk.RGBA();
        }
        
        setup_ui ();
        setup_keyboard_shortcuts ();
        setup_mouse_events ();
    }
    
    // Method to update color indicators based on current mode and colors
    private void update_color_indicators() {
        if (original_image == null) {
            // No image loaded, show empty/default colors
            Gdk.RGBA[] default_colors = new Gdk.RGBA[4];
            for (int i = 0; i < 4; i++) {
                default_colors[i] = Gdk.RGBA();
                default_colors[i].red = 0.5f;
                default_colors[i].green = 0.5f;
                default_colors[i].blue = 0.5f;
                default_colors[i].alpha = 1.0f;
            }
            color_indicator.update_colors(default_colors);
        } else if (points_initialized) {
            color_indicator.update_colors(sampled_colors);
        } else {
            // Points not initialized yet but we have an image
            // Initialize sampled colors with theme's foreground and background colors
            Gdk.RGBA[] theme_colors = new Gdk.RGBA[4];
            theme_colors[0] = theme_manager.get_color("theme_fg");
            theme_colors[1] = theme_manager.get_color("theme_accent");
            theme_colors[2] = theme_manager.get_color("theme_selection");
            theme_colors[3] = theme_manager.get_color("theme_bg");
            color_indicator.update_colors(theme_colors);
        }
    }
    
    private Gtk.Widget create_titlebar () {
        set_titlebar (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { visible = false });

        // Create classic Mac-style title bar
        var title_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

        // Close button on the left
        var close_button = new Gtk.Button ();
        close_button.add_css_class ("close-button");
        close_button.tooltip_text = "Close";
        close_button.margin_top = 4;
        close_button.margin_start = 4;
        close_button.margin_bottom = 4;
        close_button.valign = Gtk.Align.CENTER;
        close_button.clicked.connect (() => this.close ());

        title_bar.append (close_button);

        var winhandle = new Gtk.WindowHandle ();
        winhandle.set_child (title_bar);

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.append (winhandle);

        return vbox;
    }
    
    private void setup_ui () {
        // Get theme manager
        theme_manager = Theme.Manager.get_default ();
        
        // Main box
        main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        set_child (main_box);

        // Set up custom titlebar
        var titlebar = create_titlebar ();
        main_box.append (titlebar);
        
        // Drawing area
        drawing_area = new Gtk.DrawingArea ();
        drawing_area.set_draw_func (draw_func);
        drawing_area.set_content_width(472);
        drawing_area.set_content_height(340);
        drawing_area.margin_start = 11;
        drawing_area.margin_end = 11;
        main_box.append (drawing_area);
        
        // Bottom box for controls
        var bottom_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        bottom_box.margin_start = 8;
        bottom_box.margin_end = 8;
        bottom_box.margin_bottom = 8;
        bottom_box.set_vexpand (true);
        bottom_box.valign = Gtk.Align.END;
        main_box.append (bottom_box);
        
        // Create mode toggle button with custom DrawingArea inside
        mode_toggle = new Gtk.ToggleButton ();
        mode_toggle.set_tooltip_text ("Switch between 1-bit and 2-bit mode");
        mode_toggle.set_active (is_one_bit_mode);
        
        // Create the DrawingArea for the mode icon
        var mode_icon = new Gtk.DrawingArea ();
        mode_icon.set_content_width (8);
        mode_icon.set_content_height (8);
        mode_icon.set_draw_func ((da, cr, width, height) => {
            // Disable antialiasing as per preferences
            cr.set_antialias (Cairo.Antialias.NONE);
            
            // Set border color
            var fg_color = theme_manager.get_color ("theme_fg");
            cr.set_source_rgb (fg_color.red, fg_color.green, fg_color.blue);
            cr.set_line_width (1.0);
            
            // Draw outer square
            int square_size = 7;
            
            cr.rectangle (1, 1, 7, 7);
            cr.stroke ();
            
            // Draw inner divisions based on mode
            bool toggle_state = mode_toggle.get_active ();
            
            // Vertical division (for both modes)
            cr.move_to (3.5, 1);
            cr.line_to (3.5, 7);
            cr.stroke ();
            
            // Horizontal division (only for 2-bit mode, when toggle is OFF)
            if (!toggle_state) {
                cr.move_to (1, 3.5);
                cr.line_to (7, 3.5);
                cr.stroke ();
            }
        });
        
        mode_toggle.set_child (mode_icon);
        
        // Connect toggle button to our boolean flag
        mode_toggle.toggled.connect (() => {
            is_one_bit_mode = mode_toggle.active;
            
            // Force redraw of the mode icon when toggled
            mode_icon.queue_draw ();
            
            if (original_image != null) {
                process_image ();
                drawing_area.queue_draw ();
                update_color_indicators ();
            }
        });
        
        // Create toggle button for showing/hiding color dots
        var color_dots_toggle = new Gtk.ToggleButton ();
        color_dots_toggle.set_tooltip_text ("Show/hide color sample points");
        color_dots_toggle.set_active (show_color_dots);
        
        // Create the DrawingArea for the color dots icon
        var color_dots_icon = new Gtk.DrawingArea ();
        color_dots_icon.set_content_width (8);
        color_dots_icon.set_content_height (8);
        color_dots_icon.set_draw_func ((da, cr, width, height) => {
            // Disable antialiasing
            cr.set_antialias (Cairo.Antialias.NONE);
            
            // Clear background
            cr.set_source_rgba (0, 0, 0, 0);
            cr.set_operator (Cairo.Operator.SOURCE);
            cr.paint ();
            cr.set_operator (Cairo.Operator.OVER);
            
            // Draw the icon pattern (7x7 grid where * is a lit pixel)
            // _***_
            // *___*
            // __*__
            // _*_*_
            // _*_*_
            // __*__
            
            double pixel_size = 1;
            double start_x = 0;
            double start_y = 0;
            
            // Set colors based on theme
            var fg_color = theme_manager.get_color ("theme_fg");
            cr.set_source_rgb (fg_color.red, fg_color.green, fg_color.blue);
            
            // Define the pattern as a 2D array (7x7)
            bool[,] pattern = {
                {false, false, false, false, false, false, false},
                {false, false, true,  true,  true,  false, false},
                {false, true,  false, false, false, true,  false},
                {true,  false, false, true,  false, false, true },
                {false, false, true,  false, true,  false, false},
                {false, false, false, true,  false, false, false},
                {false, false, false, false, false, false, false}
            };
            
            // Draw the pattern
            for (int y = 0; y < 7; y++) {
                for (int x = 0; x < 7; x++) {
                    if (pattern[y, x]) {
                        double pixel_x = start_x + (x + 1) * pixel_size; // Center horizontally
                        double pixel_y = start_y + (y + 1) * pixel_size; // Center vertically
                        cr.rectangle (pixel_x, pixel_y, pixel_size, pixel_size);
                        cr.fill ();
                    }
                }
            }
        });
        
        color_dots_toggle.set_child (color_dots_icon);
        
        // Connect toggle button to our boolean flag
        color_dots_toggle.toggled.connect (() => {
            show_color_dots = color_dots_toggle.active;
            drawing_area.queue_draw (); // Redraw the main area to show/hide dots
        });
        
        // Create the color indicator widget
        color_indicator = new ColorIndicator ();
        color_indicator.valign = Gtk.Align.CENTER;
        color_indicator.hexpand = true;  // Make it take available space
        color_indicator.halign = Gtk.Align.CENTER;  // Center it
        
        // Create save button with custom DrawingArea inside
        var save_button = new Gtk.Button ();
        save_button.set_tooltip_text ("Save image as CHR");
        
        // Create the DrawingArea for the save icon
        var save_icon = new Gtk.DrawingArea ();
        save_icon.set_content_width (8);
        save_icon.set_content_height (8);
        save_icon.set_draw_func ((da, cr, width, height) => {
            // Disable antialiasing
            cr.set_antialias (Cairo.Antialias.NONE);
            
            // Clear background
            cr.set_source_rgba (0, 0, 0, 0);
            cr.set_operator (Cairo.Operator.SOURCE);
            cr.paint ();
            cr.set_operator (Cairo.Operator.OVER);
            
            // Draw the icon pattern (7x7 grid where * is a lit pixel)
            // __*__
            // *_*_*
            // _***_
            // **_**
            // _***_
            // *_*_*
            // __*__
            
            double pixel_size = 1;
            double start_x = 0;
            double start_y = 0;
            
            // Set colors based on theme
            var ac_color = theme_manager.get_color ("theme_accent");
            cr.set_source_rgb (ac_color.red, ac_color.green, ac_color.blue);
            
            // Define the pattern as a 2D array (7x7)
            bool[,] pattern = {
                {false, false, false, true,  false, false, false},
                {false, true,  false, true,  false, true,  false},
                {false, false, true,  false, true,  false, false},
                {true,  true,  false, false, false, true,  true },
                {false, false, true,  false, true,  false, false},
                {false, true,  false, true,  false, true,  false},
                {false, false, false, true,  false, false, false}
            };
            
            // Draw the pattern
            for (int y = 0; y < 7; y++) {
                for (int x = 0; x < 7; x++) {
                    if (pattern[y, x]) {
                        double pixel_x = start_x + (x + 1) * pixel_size; // Center horizontally
                        double pixel_y = start_y + y * pixel_size;
                        cr.rectangle (pixel_x, pixel_y, pixel_size, pixel_size);
                        cr.fill ();
                    }
                }
            }
        });
        
        save_button.set_child (save_icon);
        
        // Connect save button to save function
        save_button.clicked.connect (() => {
            save_chr_file ();
        });
        
        // Add to bottom box
        bottom_box.append (mode_toggle);
        bottom_box.append (color_dots_toggle);
        bottom_box.append (color_indicator);
        bottom_box.append (save_button);
        
        // Also listen for theme changes
        theme_manager.theme_changed.connect (() => {
            if (original_image != null) {
                process_image ();
                drawing_area.queue_draw ();
                update_color_indicators ();
            }
        });

        // Load CSS provider
        var provider = new Gtk.CssProvider ();
        provider.load_from_resource ("/com/example/ditto/style.css");

        // Apply the CSS to the default display
        Gtk.StyleContext.add_provider_for_display (
            Gdk.Display.get_default (),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }
    
    private void setup_keyboard_shortcuts () {
        var controller = new Gtk.EventControllerKey ();
        controller.key_pressed.connect ((keyval, keycode, state) => {
            if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                switch (keyval) {
                    case Gdk.Key.o:
                        open_file ();
                        return true;
                    case Gdk.Key.s:
                        save_chr_file ();
                        return true;
                }
            }
            return false;
        });
        main_box.add_controller (controller);
    }
    
    private void setup_mouse_events () {
            // Add mouse controllers for interacting with sample points
        var motion_controller = new Gtk.EventControllerMotion();
        var click_controller = new Gtk.GestureClick();
        
        // Track mouse motion
        motion_controller.motion.connect((x, y) => {
            if (!is_one_bit_mode && original_image != null && dragging_point && active_point >= 0) {
                // First, determine if the mouse is actually over the image
                bool is_over_image = is_point_over_image(x, y);
                
                if (is_over_image) {
                    // Convert from drawing area coordinates to image coordinates
                    var image_coords = get_image_coords(x, y);
                    
                    // Update the point position
                    sample_points[active_point, 0] = image_coords.x;
                    sample_points[active_point, 1] = image_coords.y;
                    
                    // Update sampled color
                    update_sampled_color(active_point);
                    
                    // Redraw and reprocess image
                    process_image();
                    drawing_area.queue_draw();
                }
            }
        });
        
        // Track when we release the mouse
        motion_controller.leave.connect(() => {
            dragging_point = false;
            active_point = -1;
        });
        
        // Mouse click handling
        click_controller.pressed.connect((n_press, x, y) => {
            if (is_one_bit_mode || original_image == null || !show_color_dots) {
                return;
            }
            
            // Only allow clicking on points if we're over the image
            if (!is_point_over_image(x, y)) {
                return;
            }
            
            // Initialize points if we haven't yet
            if (!points_initialized) {
                initialize_sample_points();
            }
            
            // Convert drawing area coordinates to image coordinates
            var image_coords = get_image_coords(x, y);
            
            // Check if we clicked on a point
            for (int i = 0; i < 4; i++) {
                double point_x = sample_points[i, 0];
                double point_y = sample_points[i, 1];
                
                // Convert image coordinates back to drawing area coordinates
                var point_da_coords = get_drawing_area_coords(point_x, point_y);
                
                // Check if we're within 8 pixels of a control point
                if (Math.sqrt(Math.pow(x - point_da_coords.x, 2) + Math.pow(y - point_da_coords.y, 2)) <= 8) {
                    dragging_point = true;
                    active_point = i;
                    break;
                }
            }
        });
        
        click_controller.released.connect((n_press, x, y) => {
            dragging_point = false;
            active_point = -1;
        });
        
        // Add controllers to drawing area
        drawing_area.add_controller(motion_controller);
        drawing_area.add_controller(click_controller);
    }
    
    // Helper method to determine if a point in drawing area coordinates is over the actual image
    private bool is_point_over_image(double x, double y) {
        if (original_image == null) {
            return false;
        }
        
        int drawing_width = drawing_area.get_width();
        int drawing_height = drawing_area.get_height();
        int image_width = original_image.get_width();
        int image_height = original_image.get_height();
        
        // Calculate scaling to fit the drawing area while preserving aspect ratio
        double scale_x = (double)drawing_width / image_width;
        double scale_y = (double)drawing_height / image_height;
        double scale = Math.fmin(scale_x, scale_y);
        
        // Calculate the actual dimensions of the displayed image
        double scaled_width = image_width * scale;
        double scaled_height = image_height * scale;
        
        // Calculate the offset to center the image
        double x_offset = (drawing_width - scaled_width) / 2;
        double y_offset = (drawing_height - scaled_height) / 2;
        
        // Check if the point is within the image boundaries
        return (x >= x_offset && x < x_offset + scaled_width &&
                y >= y_offset && y < y_offset + scaled_height);
    }
    
    private void update_sampled_color (int point_index) {
        if (original_image == null || point_index < 0 || point_index >= 4) {
            return;
        }
        
        int x = (int)sample_points[point_index, 0];
        int y = (int)sample_points[point_index, 1];
        
        // Make sure coordinates are within the image
        int width = original_image.get_width ();
        int height = original_image.get_height ();
        
        x = int.min (int.max (0, x), width - 1);
        y = int.min (int.max (0, y), height - 1);
        
        // Get pixel data from the original image
        unowned uint8[] data = original_image.get_data ();
        int stride = original_image.get_stride ();
        
        // Get pixel value (in ARGB format)
        int offset = y * stride + x * 4;
        uint8 b = data[offset + 0];
        uint8 g = data[offset + 1];
        uint8 r = data[offset + 2];
        uint8 a = data[offset + 3];
        
        // Update the sampled color
        sampled_colors[point_index].red = r / 255.0f;
        sampled_colors[point_index].green = g / 255.0f;
        sampled_colors[point_index].blue = b / 255.0f;
        sampled_colors[point_index].alpha = a / 255.0f;
        
        update_color_indicators ();
    }
    
    private void initialize_sample_points () {
        if (original_image == null) {
            return;
        }
        
        int width = original_image.get_width ();
        int height = original_image.get_height ();
        
        // Set points at 1/3 and 2/3 positions in the image
        sample_points[0, 0] = width / 3;
        sample_points[0, 1] = height / 3;
        
        sample_points[1, 0] = 2 * width / 3;
        sample_points[1, 1] = height / 3;
        
        sample_points[2, 0] = width / 3;
        sample_points[2, 1] = 2 * height / 3;
        
        sample_points[3, 0] = 2 * width / 3;
        sample_points[3, 1] = 2 * height / 3;
        
        // Sample colors from these positions
        for (int i = 0; i < 4; i++) {
            update_sampled_color (i);
        }
        
        points_initialized = true;
        update_color_indicators ();
    }
    
    private struct Coordinates {
        public double x;
        public double y;
    }
    
    private Coordinates get_image_coords(double drawing_area_x, double drawing_area_y) {
        Coordinates result = {0, 0};
        
        if (original_image == null) {
            return result;
        }
        
        int drawing_width = drawing_area.get_width();
        int drawing_height = drawing_area.get_height();
        int image_width = original_image.get_width();
        int image_height = original_image.get_height();
        
        // Direct linear mapping (full stretch)
        result.x = (drawing_area_x / drawing_width) * image_width;
        result.y = (drawing_area_y / drawing_height) * image_height;
        
        // Clamp to image bounds
        result.x = Math.fmin(Math.fmax(0, result.x), image_width - 1);
        result.y = Math.fmin(Math.fmax(0, result.y), image_height - 1);
        
        return result;
    }

    private Coordinates get_drawing_area_coords(double image_x, double image_y) {
        Coordinates result = {0, 0};
        
        if (original_image == null) {
            return result;
        }
        
        int drawing_width = drawing_area.get_width();
        int drawing_height = drawing_area.get_height();
        int image_width = original_image.get_width();
        int image_height = original_image.get_height();
        
        // Direct linear mapping (full stretch)
        result.x = (image_x / image_width) * drawing_width;
        result.y = (image_y / image_height) * drawing_height;
        
        return result;
    }
    
    private void process_image () {
        if (original_image == null) {
            return;
        }
        
        // If in 2-bit mode and we have an image loaded but points not initialized
        if (!is_one_bit_mode && !points_initialized && original_image != null) {
            initialize_sample_points ();
        }
        
        // In 2-bit mode, use sampled colors; in 1-bit mode, use the defaults
        if (!is_one_bit_mode) {
            // Custom process image function that uses our sampled colors
            process_image_with_custom_palette (original_image, out processed_image,
                                           is_one_bit_mode, contrast_level, sampled_colors);
        } else {
            // Use the standard processor
            ImageProcessor.process_image (original_image, out processed_image,
                                       is_one_bit_mode, contrast_level, theme_manager);
        }
    }
    
    // Modified version of ImageProcessor.process_image that accepts custom colors
    private void process_image_with_custom_palette (Cairo.ImageSurface input_image, 
                                                 out Cairo.ImageSurface output_image,
                                                 bool is_one_bit_mode, int contrast_level, 
                                                 Gdk.RGBA[] custom_colors) {
        int width = input_image.get_width ();
        int height = input_image.get_height ();
        
        // Create a new surface for the processed image
        output_image = new Cairo.ImageSurface (
            Cairo.Format.ARGB32,
            width,
            height
        );
        
        // Get surface data
        unowned uint8[] src_data = (uint8[]) input_image.get_data ();
        unowned uint8[] dest_data = (uint8[]) output_image.get_data ();
        
        int src_stride = input_image.get_stride ();
        int dest_stride = output_image.get_stride ();
        
        // Create error diffusion buffers
        double[,] error_r = new double[height, width];
        double[,] error_g = new double[height, width];
        double[,] error_b = new double[height, width];
        
        // Define palette based on sampled colors
        uint8[,] palette = new uint8[4, 4]; // 4 colors with BGRA values
        
        for (int i = 0; i < 4; i++) {
            palette[i, 0] = (uint8)(custom_colors[i].blue * 255);  // B
            palette[i, 1] = (uint8)(custom_colors[i].green * 255); // G
            palette[i, 2] = (uint8)(custom_colors[i].red * 255);   // R
            palette[i, 3] = 255;                                   // A
        }
        
        // Calculate contrast factor from slider value (1-10)
        // Map contrast from 0.5 (low contrast) to 2.5 (high contrast)
        double contrast_factor = 0.5 + (contrast_level - 1) * (2.0 / 9.0);
        
        // Define Atkinson dithering pattern (x,y) offsets for 6 pixels
        int[,] atkinson_pattern = {
            {1, 0}, {2, 0},         // right pixels
            {-1, 1}, {0, 1}, {1, 1}, // next row
            {0, 2}                   // two rows down
        };
        
        // Apply Atkinson dithering (same algorithm as in ImageProcessor)
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int src_offset = y * src_stride + x * 4;
                int dest_offset = y * dest_stride + x * 4;
                
                // Get source pixel values (B, G, R, A) and add error
                double b = (double) src_data[src_offset + 0] + error_b[y, x];
                double g = (double) src_data[src_offset + 1] + error_g[y, x];
                double r = (double) src_data[src_offset + 2] + error_r[y, x];
                double a = (double) src_data[src_offset + 3];
                
                // Apply contrast adjustment
                double r_norm = r / 255.0;
                double g_norm = g / 255.0;
                double b_norm = b / 255.0;
                
                r_norm = adjust_contrast (r_norm, contrast_factor);
                g_norm = adjust_contrast (g_norm, contrast_factor);
                b_norm = adjust_contrast (b_norm, contrast_factor);
                
                // Convert back to 0-255 range
                r = r_norm * 255.0;
                g = g_norm * 255.0;
                b = b_norm * 255.0;
                
                // Clamp values
                b = Math.fmin (255, Math.fmax (0, b));
                g = Math.fmin (255, Math.fmax (0, g));
                r = Math.fmin (255, Math.fmax (0, r));
                
                // Find closest color in palette
                int closest_color_index = find_closest_color_index (palette, r, g, b);
                
                // Set destination pixel
                dest_data[dest_offset + 0] = palette[closest_color_index, 0]; // B
                dest_data[dest_offset + 1] = palette[closest_color_index, 1]; // G
                dest_data[dest_offset + 2] = palette[closest_color_index, 2]; // R
                dest_data[dest_offset + 3] = palette[closest_color_index, 3]; // A
                
                // Calculate quantization error
                double error_r_val = r - palette[closest_color_index, 2];
                double error_g_val = g - palette[closest_color_index, 1];
                double error_b_val = b - palette[closest_color_index, 0];
                
                // Atkinson dithering: distribute 1/8 of the error to 6 surrounding pixels
                // Note that only 3/4 of the error is distributed in total
                double error_factor = 1.0 / 8.0;
                
                // Distribute error according to Atkinson pattern
                for (int i = 0; i < 6; i++) {
                    int nx = x + atkinson_pattern[i, 0];
                    int ny = y + atkinson_pattern[i, 1];
                    
                    if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
                        error_r[ny, nx] += error_r_val * error_factor;
                        error_g[ny, nx] += error_g_val * error_factor;
                        error_b[ny, nx] += error_b_val * error_factor;
                    }
                }
            }
        }
        
        // Mark the new surface as dirty to ensure Cairo knows it's been modified
        output_image.mark_dirty ();
    }
    
    // Helper function for contrast adjustment (copied from ImageProcessor)
    private double adjust_contrast (double value, double contrast) {
        // Apply contrast adjustment centered around 0.5
        return 0.5 + (value - 0.5) * contrast;
    }
    
    // Helper function to find closest color (copied from ImageProcessor)
    private int find_closest_color_index (uint8[,] palette, double r, double g, double b) {
        int closest_index = 0;
        double min_distance = double.MAX;
        
        for (int i = 0; i < palette.length[0]; i++) {
            double color_b = (double) palette[i, 0];
            double color_g = (double) palette[i, 1];
            double color_r = (double) palette[i, 2];
            
            // Calculate Euclidean distance
            double distance = Math.sqrt (
                Math.pow (r - color_r, 2) +
                Math.pow (g - color_g, 2) +
                Math.pow (b - color_b, 2)
            );
            
            if (distance < min_distance) {
                min_distance = distance;
                closest_index = i;
            }
        }
        
        return closest_index;
    }
    
    private void draw_func(Gtk.DrawingArea da, Cairo.Context cr, int width, int height) {
        cr.set_antialias(Cairo.Antialias.NONE);
        
        if (processed_image != null) {
            int image_width = processed_image.get_width();
            int image_height = processed_image.get_height();
            
            // Draw image data to fill the entire drawing area
            unowned uint8[] data = (uint8[]) processed_image.get_data();
            int stride = processed_image.get_stride();
            
            // Calculate scaling factors (we'll stretch to fill completely)
            double scale_x = (double)width / image_width;
            double scale_y = (double)height / image_height;
            
            // For pixel-perfect rendering, we determine how to map each drawing area pixel to the source image
            for (int y = 0; y < height; y++) {
                // Map y coordinate back to image space
                int src_y = (int)(y / scale_y);
                if (src_y >= image_height) continue; // Safety check
                
                for (int x = 0; x < width; x++) {
                    // Map x coordinate back to image space
                    int src_x = (int)(x / scale_x);
                    if (src_x >= image_width) continue; // Safety check
                    
                    int offset = src_y * stride + src_x * 4;
                    
                    // Get pixel BGRA values
                    double b = data[offset + 0] / 255.0;
                    double g = data[offset + 1] / 255.0;
                    double r = data[offset + 2] / 255.0;
                    double a = data[offset + 3] / 255.0;
                    
                    if (a > 0) {
                        cr.set_source_rgba(r, g, b, a);
                        cr.rectangle(x, y, 1, 1);
                        cr.fill();
                    }
                }
            }
            
            // Draw sample points
            if (original_image != null && points_initialized && show_color_dots) {
                // Set up font
                cr.select_font_face("atari8", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
                cr.set_font_size(8);
                
                // Draw each point with its label using the new pattern
                for (int i = 0; i < 4; i++) {
                    // Get image coordinates of the point
                    double point_x = sample_points[i, 0];
                    double point_y = sample_points[i, 1];
                    
                    // Convert to drawing area coordinates with full stretch
                    double da_x = point_x * scale_x;
                    double da_y = point_y * scale_y;
                    
                    // Get the color for this point
                    var color = sampled_colors[i];
                    
                    // Draw the indicator pattern
                    draw_sample_point(cr, da_x, da_y, color, i + 1);
                }
            }
        }
    }
    
    // Helper method to draw a sample point with indicator pattern
    private void draw_sample_point(Cairo.Context cr, double center_x, double center_y, Gdk.RGBA color, int label) {
        // Draw the outline in gray
        cr.set_source_rgb(0.9, 0.9, 0.9);
        
        // Top row (row 0): __***__
        for (int px = 2; px <= 4; px++) {
            cr.rectangle(center_x + px - 3, center_y - 3, 1, 1);
        }
        
        // Row 1: _*##*_
        cr.rectangle(center_x - 2, center_y - 2, 1, 1);
        cr.rectangle(center_x + 2, center_y - 2, 1, 1);
        
        // Row 2-4: *#####*
        for (int row = -1; row <= 1; row++) {
            cr.rectangle(center_x - 3, center_y + row, 1, 1);
            cr.rectangle(center_x + 3, center_y + row, 1, 1);
        }
        
        // Row 5: _*##*_
        cr.rectangle(center_x - 2, center_y + 2, 1, 1);
        cr.rectangle(center_x + 2, center_y + 2, 1, 1);
        
        // Bottom row (row 6): __***__
        for (int px = 2; px <= 4; px++) {
            cr.rectangle(center_x + px - 3, center_y + 3, 1, 1);
        }
        
        cr.fill();
        
        // Now fill the inner area with the actual color
        cr.set_source_rgba(color.red, color.green, color.blue, 1.0);
        
        // Row 1: _*##*_
        for (int px = 0; px <= 1; px++) {
            cr.rectangle(center_x - 1 + px, center_y - 2, 1, 1);
        }
        
        // Row 2-4: *#####*
        for (int row = -1; row <= 1; row++) {
            for (int px = -2; px <= 2; px++) {
                cr.rectangle(center_x + px, center_y + row, 1, 1);
            }
        }
        
        // Row 5: _*##*_
        for (int px = 0; px <= 1; px++) {
            cr.rectangle(center_x - 1 + px, center_y + 2, 1, 1);
        }
        
        cr.fill();
        
        // Draw label
        cr.set_source_rgb(0.9, 0.9, 0.9);
        
        // Position text for better visibility
        Cairo.TextExtents extents;
        string label_text = label.to_string();
        cr.text_extents(label_text, out extents);
        
        cr.move_to(
            center_x + 6,
            center_y + 3
        );
        cr.show_text(label_text);
    }
    
    private void open_file () {
        var dialog = new Gtk.FileChooserDialog (
            "Open Image",
            this,
            Gtk.FileChooserAction.OPEN,
            "_Cancel", Gtk.ResponseType.CANCEL,
            "_Open", Gtk.ResponseType.ACCEPT
        );
        
        var filter = new Gtk.FileFilter ();
        filter.set_filter_name ("Image Files");
        filter.add_pattern ("*.png");
        filter.add_pattern ("*.bmp");
        filter.add_pattern ("*.tga");
        dialog.add_filter (filter);
        
        dialog.response.connect ((response_id) => {
            if (response_id == Gtk.ResponseType.ACCEPT) {
                string file_path = dialog.get_file ().get_path ();
                load_image (file_path);
            }
            dialog.destroy ();
        });
        
        dialog.present ();
    }
    
    public void load_image_from_file (File file) {
        string? file_path = file.get_path ();
        if (file_path != null) {
            load_image (file_path);
        } else {
            // Handle files that don't have local paths (like URIs)
            try {
                // Try to load from a URI if possible
                FileInputStream stream = file.read ();
                var pixbuf = new Gdk.Pixbuf.from_stream (stream);
                
                // Create a temporary path to pass to our existing method
                string temp_path = Path.build_filename (Environment.get_tmp_dir (), "ditto-temp.png");
                pixbuf.save (temp_path, "png");
                
                // Load the temporary image
                load_image (temp_path);
            } catch (Error e) {
                var message_dialog = new Gtk.MessageDialog (
                    this,
                    Gtk.DialogFlags.MODAL,
                    Gtk.MessageType.ERROR,
                    Gtk.ButtonsType.OK,
                    "Error loading image: %s", e.message
                );
                message_dialog.response.connect ((response_id) => {
                    message_dialog.destroy ();
                });
                message_dialog.present ();
            }
        }
    }
    
    // Direct save to CHR file without dialog
    private void save_chr_file() {
        if (processed_image == null) {
            var message_dialog = new Gtk.MessageDialog(
                this,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.INFO,
                Gtk.ButtonsType.OK,
                "No image to save"
            );
            message_dialog.response.connect((response_id) => {
                message_dialog.destroy();
            });
            message_dialog.present();
            return;
        }
        
        var dialog = new Gtk.FileChooserDialog(
            "Save Image",
            this,
            Gtk.FileChooserAction.SAVE,
            "_Cancel", Gtk.ResponseType.CANCEL,
            "_Save", Gtk.ResponseType.ACCEPT
        );
        
        dialog.set_current_name("image.chr");
        
        var chr_filter = new Gtk.FileFilter();
        chr_filter.set_filter_name("CHR Files");
        chr_filter.add_pattern("*.chr");
        dialog.add_filter(chr_filter);
        
        dialog.response.connect((response_id) => {
            if (response_id == Gtk.ResponseType.ACCEPT) {
                string file_path = dialog.get_file().get_path();
                
                // Ensure the file has .chr extension
                if (!file_path.down().has_suffix(".chr")) {
                    file_path = file_path + ".chr";
                }
                
                // Always use FileUtils.save_chr_file for both modes
                FileUtils.save_chr_file(file_path, processed_image, is_one_bit_mode, theme_manager);
            }
            dialog.destroy();
        });
        
        dialog.present();
    }
    
    private void save_chr_file_with_custom_palette(string file_path) {
        if (processed_image == null) return;
        
        // Just delegate to the new implementation in FileUtils
        FileUtils.save_chr_file(file_path, processed_image, is_one_bit_mode, theme_manager);
    }
    
    private double color_distance (uint8 r1, uint8 g1, uint8 b1, uint8 r2, uint8 g2, uint8 b2) {
        return Math.sqrt (
            Math.pow (r1 - r2, 2) + 
            Math.pow (g1 - g2, 2) + 
            Math.pow (b1 - b2, 2)
        );
    }

    private void load_image (string file_path) {
        try {
            // Reset contrast to default value (5)
            contrast_level = 5;
            
            // Reset sampling points
            points_initialized = false;
            
            // Load image using GDK Pixbuf
            var pixbuf = new Gdk.Pixbuf.from_file (file_path);
            
            // Resize image if necessary to fit within 512 KB
            int max_pixels = 512 * 1024 / 4; // 4 bytes per pixel (RGBA)
            int current_pixels = pixbuf.width * pixbuf.height;
            
            if (current_pixels > max_pixels) {
                double scale = Math.sqrt ((double)max_pixels / current_pixels);
                int new_width = (int)(pixbuf.width * scale);
                int new_height = (int)(pixbuf.height * scale);
                pixbuf = pixbuf.scale_simple (new_width, new_height, Gdk.InterpType.BILINEAR);
            }
            
            // Convert pixbuf to Cairo surface and store as original
            original_image = new Cairo.ImageSurface (
                Cairo.Format.ARGB32,
                pixbuf.width,
                pixbuf.height
            );
            
            var cr = new Cairo.Context (original_image);
            Gdk.cairo_set_source_pixbuf (cr, pixbuf, 0, 0);
            cr.paint ();
            
            // Apply dithering with current mode
            process_image ();
            update_color_indicators ();
            
            drawing_area.queue_draw ();
        } catch (Error e) {
            var message_dialog = new Gtk.MessageDialog (
                this,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.ERROR,
                Gtk.ButtonsType.OK,
                "Error loading image: %s", e.message
            );
            message_dialog.response.connect ((response_id) => {
                message_dialog.destroy ();
            });
            message_dialog.present ();
        }
    }
}