public class MainWindow : Gtk.ApplicationWindow {
    private Gtk.DrawingArea drawing_area;
    private Gtk.CheckButton mode_checkbox;
    private Gtk.Box main_box;
    private ColorIndicator color_indicator;
    private Cairo.ImageSurface? original_image = null;  // Store original image
    private Cairo.ImageSurface? processed_image = null; // Store processed image
    
    // UI controls for contrast
    private Gtk.Scale contrast_scale;
    private Gtk.Label contrast_value;
    
    // Use a simple boolean flag for 1-bit mode
    private bool is_one_bit_mode = false;
    
    // Contrast level (1-10)
    private int contrast_level = 5;
    
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
            default_width: 600,
            default_height: 400,
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
        } else if (is_one_bit_mode) {
            // In 1-bit mode, show the theme's foreground and background colors
            Gdk.RGBA[] theme_colors = new Gdk.RGBA[4];
            theme_colors[0] = theme_manager.get_color("theme_fg");
            theme_colors[1] = theme_manager.get_color("theme_bg");
            theme_colors[2] = theme_colors[0]; // Duplicate for all 4 indicators
            theme_colors[3] = theme_colors[1];
            color_indicator.update_colors(theme_colors);
        } else if (points_initialized) {
            // In 2-bit mode, show the sampled colors
            color_indicator.update_colors(sampled_colors);
        }
    }
    
    private Gtk.Widget create_titlebar () {
        set_titlebar (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { visible = false });

        // Create classic Mac-style title bar
        var title_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = 600;
        title_bar.add_css_class ("title-bar");

        // Close button on the left
        var close_button = new Gtk.Button ();
        close_button.add_css_class ("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;
        close_button.clicked.connect (() => this.close ());

        var title_label = new Gtk.Label (this.title);
        title_label.add_css_class ("title-box");
        title_label.hexpand = true;
        title_label.margin_end = 8;
        title_label.valign = Gtk.Align.CENTER;
        title_label.halign = Gtk.Align.CENTER;

        title_bar.append (close_button);
        title_bar.append (title_label);

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
        drawing_area.set_vexpand (true);
        drawing_area.set_hexpand (true);
        drawing_area.set_margin_start (4);
        drawing_area.set_margin_end (4);
        drawing_area.set_margin_top (4);
        drawing_area.set_margin_bottom (4);
        main_box.append (drawing_area);
        drawing_area.add_css_class ("image-frame");
        
        // Bottom box for checkbox and contrast controls
        var bottom_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        bottom_box.set_margin_start (4);
        bottom_box.set_margin_end (4);
        bottom_box.set_margin_top (4);
        bottom_box.set_margin_bottom (4);
        main_box.append (bottom_box);
        
        // Mode checkbox (on the left)
        mode_checkbox = new Gtk.CheckButton.with_label ("1-bit mode");
        
        // Initialize checkbox state
        mode_checkbox.set_active (is_one_bit_mode);
        
        // Connect checkbox to our boolean flag
        mode_checkbox.toggled.connect (() => {
            is_one_bit_mode = mode_checkbox.active;
                
            if (original_image != null) {
                process_image();
                drawing_area.queue_draw ();
            }
        });
        
        // Create the color indicator widget
        color_indicator = new ColorIndicator();
        color_indicator.valign = Gtk.Align.CENTER;
        color_indicator.hexpand = true;  // Make it take available space
        color_indicator.halign = Gtk.Align.CENTER;  // Center it
        
        // Contrast controls (on the right)
        var contrast_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
        contrast_box.halign = Gtk.Align.END;
        contrast_box.valign = Gtk.Align.CENTER;
        
        var contrast_label = new Gtk.Label ("Contrast:");
        
        // Custom Gtk.Scale with classic Mac styling for contrast
        contrast_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 1, 10, 1);
        contrast_scale.set_draw_value (false); // Don't show the value tooltip
        contrast_scale.set_size_request (120, 20);
        contrast_scale.set_value (contrast_level);
        contrast_scale.add_css_class ("contrast-scale");
        
        // Connect to value-changed signal
        contrast_scale.value_changed.connect (() => {
            contrast_level = (int)contrast_scale.get_value ();
            contrast_value.label = contrast_level.to_string ();
            
            if (original_image != null) {
                process_image();
                drawing_area.queue_draw ();
            }
        });
        
        // Add value indicator
        contrast_value = new Gtk.Label (contrast_level.to_string ());
        contrast_value.width_chars = 2;
        contrast_value.add_css_class ("contrast-value");
        
        // Add elements to the contrast box
        contrast_box.append (contrast_label);
        contrast_box.append (contrast_scale);
        contrast_box.append (contrast_value);
        
        // Add to bottom box with a spacer in between
        bottom_box.append (mode_checkbox);
        bottom_box.append (color_indicator);
        bottom_box.append (contrast_box);
        
        // Also listen for theme changes
        theme_manager.theme_changed.connect (() => {
            if (original_image != null) {
                process_image();
                drawing_area.queue_draw ();
                update_color_indicators();
            }
        });

        // Load CSS provider
        var provider = new Gtk.CssProvider();
        provider.load_from_resource("/com/example/ditto/style.css");

        // Apply the CSS to the default display
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
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
                        save_file ();
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
        });
        
        // Track when we release the mouse
        motion_controller.leave.connect(() => {
            dragging_point = false;
            active_point = -1;
        });
        
        // Mouse click handling
        click_controller.pressed.connect((n_press, x, y) => {
            if (is_one_bit_mode || original_image == null) {
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
                
                // Check if we're within 10 pixels of a control point
                if (Math.sqrt(Math.pow(x - point_da_coords.x, 2) + Math.pow(y - point_da_coords.y, 2)) <= 10) {
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
    
    private void update_sampled_color(int point_index) {
        if (original_image == null || point_index < 0 || point_index >= 4) {
            return;
        }
        
        int x = (int)sample_points[point_index, 0];
        int y = (int)sample_points[point_index, 1];
        
        // Make sure coordinates are within the image
        int width = original_image.get_width();
        int height = original_image.get_height();
        
        x = int.min(int.max(0, x), width - 1);
        y = int.min(int.max(0, y), height - 1);
        
        // Get pixel data from the original image
        unowned uint8[] data = original_image.get_data();
        int stride = original_image.get_stride();
        
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
        
        update_color_indicators();
    }
    
    private void initialize_sample_points() {
        if (original_image == null) {
            return;
        }
        
        int width = original_image.get_width();
        int height = original_image.get_height();
        
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
            update_sampled_color(i);
        }
        
        points_initialized = true;
        update_color_indicators();
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
        
        // Calculate scaling to fit the drawing area while preserving aspect ratio
        double scale_x = (double) drawing_width / image_width;
        double scale_y = (double) drawing_height / image_height;
        double scale = double.min(scale_x, scale_y);
        
        // Center the image
        double x_offset = (drawing_width - image_width * scale) / 2;
        double y_offset = (drawing_height - image_height * scale) / 2;
        
        // Convert drawing area coordinates to image coordinates
        result.x = (drawing_area_x - x_offset) / scale;
        result.y = (drawing_area_y - y_offset) / scale;
        
        // Clamp to image bounds
        result.x = double.min(double.max(0, result.x), image_width - 1);
        result.y = double.min(double.max(0, result.y), image_height - 1);
        
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
        
        // Calculate scaling to fit the drawing area while preserving aspect ratio
        double scale_x = (double) drawing_width / image_width;
        double scale_y = (double) drawing_height / image_height;
        double scale = double.min(scale_x, scale_y);
        
        // Center the image
        double x_offset = (drawing_width - image_width * scale) / 2;
        double y_offset = (drawing_height - image_height * scale) / 2;
        
        // Convert image coordinates to drawing area coordinates
        result.x = image_x * scale + x_offset;
        result.y = image_y * scale + y_offset;
        
        return result;
    }
    
    private void process_image() {
        if (original_image == null) {
            return;
        }
        
        // If in 2-bit mode and we have an image loaded but points not initialized
        if (!is_one_bit_mode && !points_initialized && original_image != null) {
            initialize_sample_points();
        }
        
        // In 2-bit mode, use sampled colors; in 1-bit mode, use the defaults
        if (!is_one_bit_mode) {
            // Custom process image function that uses our sampled colors
            process_image_with_custom_palette(original_image, out processed_image,
                                            is_one_bit_mode, contrast_level, sampled_colors);
        } else {
            // Use the standard processor
            ImageProcessor.process_image(original_image, out processed_image,
                                      is_one_bit_mode, contrast_level, theme_manager);
        }
    }
    
    // Modified version of ImageProcessor.process_image that accepts custom colors
    private void process_image_with_custom_palette(Cairo.ImageSurface input_image, 
                                                out Cairo.ImageSurface output_image,
                                                bool is_one_bit_mode, int contrast_level, 
                                                Gdk.RGBA[] custom_colors) {
        int width = input_image.get_width();
        int height = input_image.get_height();
        
        // Create a new surface for the processed image
        output_image = new Cairo.ImageSurface(
            Cairo.Format.ARGB32,
            width,
            height
        );
        
        // Get surface data
        unowned uint8[] src_data = (uint8[]) input_image.get_data();
        unowned uint8[] dest_data = (uint8[]) output_image.get_data();
        
        int src_stride = input_image.get_stride();
        int dest_stride = output_image.get_stride();
        
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
                
                r_norm = adjust_contrast(r_norm, contrast_factor);
                g_norm = adjust_contrast(g_norm, contrast_factor);
                b_norm = adjust_contrast(b_norm, contrast_factor);
                
                // Convert back to 0-255 range
                r = r_norm * 255.0;
                g = g_norm * 255.0;
                b = b_norm * 255.0;
                
                // Clamp values
                b = double.min(255, double.max(0, b));
                g = double.min(255, double.max(0, g));
                r = double.min(255, double.max(0, r));
                
                // Find closest color in palette
                int closest_color_index = find_closest_color_index(palette, r, g, b);
                
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
        output_image.mark_dirty();
    }
    
    // Helper function for contrast adjustment (copied from ImageProcessor)
    private double adjust_contrast(double value, double contrast) {
        // Apply contrast adjustment centered around 0.5
        return 0.5 + (value - 0.5) * contrast;
    }
    
    // Helper function to find closest color (copied from ImageProcessor)
    private int find_closest_color_index(uint8[,] palette, double r, double g, double b) {
        int closest_index = 0;
        double min_distance = double.MAX;
        
        for (int i = 0; i < palette.length[0]; i++) {
            double color_b = (double) palette[i, 0];
            double color_g = (double) palette[i, 1];
            double color_r = (double) palette[i, 2];
            
            // Calculate Euclidean distance
            double distance = Math.sqrt(
                Math.pow(r - color_r, 2) +
                Math.pow(g - color_g, 2) +
                Math.pow(b - color_b, 2)
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
            // Calculate scaling to fit the drawing area while preserving aspect ratio
            double scale_x = (double) width / processed_image.get_width();
            double scale_y = (double) height / processed_image.get_height();
            double scale = double.min(scale_x, scale_y);
            
            // Center the image
            double x = (width - processed_image.get_width() * scale) / 2;
            double y = (height - processed_image.get_height() * scale) / 2;
            
            cr.save();
            cr.translate(x, y);
            cr.scale(scale, scale);
            cr.set_source_surface(processed_image, 0, 0);
            cr.paint();
            cr.restore();
            
            // Draw sample points if in 2-bit mode and points are initialized
            if (!is_one_bit_mode && original_image != null && points_initialized) {
                // Set up Chicago font
                cr.select_font_face("Chicago 12.1", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
                cr.set_font_size(14);
                
                // Draw each point with its label
                for (int i = 0; i < 4; i++) {
                    double point_x = sample_points[i, 0];
                    double point_y = sample_points[i, 1];
                    
                    // Convert image coordinates to drawing area coordinates
                    var da_coords = get_drawing_area_coords(point_x, point_y);
                    
                    // Draw point circle
                    cr.set_line_width(1);
                    
                    // Draw circle with the sampled color
                    var color = sampled_colors[i];
                    cr.set_source_rgba(color.red, color.green, color.blue, 1.0);
                    cr.arc(da_coords.x, da_coords.y, 8, 0, 2 * Math.PI);
                    cr.fill();
                    
                    // Draw border
                    cr.set_source_rgb(1.0, 1.0, 1.0);
                    cr.arc(da_coords.x, da_coords.y, 8, 0, 2 * Math.PI);
                    cr.stroke();
                    
                    // Draw number (1-based for user, but 0-based in code)
                    cr.set_source_rgb(0.0, 0.0, 0.0);
                    
                    // Adjust text position
                    Cairo.TextExtents extents;
                    string label = (i + 1).to_string();
                    cr.text_extents(label, out extents);
                    
                    cr.move_to(
                        da_coords.x - extents.width / 2,
                        da_coords.y + extents.height / 2
                    );
                    cr.show_text(label);
                }
            }
        } else {
            // Draw a placeholder when no image is loaded
            var bg_color = theme_manager.get_color("theme_bg");
            var fg_color = theme_manager.get_color("theme_fg");
            
            cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
            cr.paint();
            
            cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
            cr.select_font_face("Chicago 12.1", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(32);
            
            cr.move_to(width / 2 - 200, height / 2);
            cr.show_text("Open an image (Ctrl+O)");
        }
    }
    
    private void open_file() {
        var dialog = new Gtk.FileChooserDialog(
            "Open Image",
            this,
            Gtk.FileChooserAction.OPEN,
            "_Cancel", Gtk.ResponseType.CANCEL,
            "_Open", Gtk.ResponseType.ACCEPT
        );
        
        var filter = new Gtk.FileFilter();
        filter.set_filter_name("Image Files");
        filter.add_pattern("*.png");
        filter.add_pattern("*.bmp");
        filter.add_pattern("*.tga");
        dialog.add_filter(filter);
        
        dialog.response.connect((response_id) => {
            if (response_id == Gtk.ResponseType.ACCEPT) {
                string file_path = dialog.get_file().get_path();
                load_image(file_path);
            }
            dialog.destroy();
        });
        
        dialog.present();
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

    private void save_file() {
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
        
        var tga_filter = new Gtk.FileFilter();
        tga_filter.set_filter_name("TGA Files");
        tga_filter.add_pattern("*.tga");
        dialog.add_filter(tga_filter);
        
        dialog.response.connect((response_id) => {
            if (response_id == Gtk.ResponseType.ACCEPT) {
                string file_path = dialog.get_file().get_path();
                
                // Get the selected filter to determine file format
                var selected_filter = dialog.get_filter();
                if (selected_filter == tga_filter || file_path.down().has_suffix(".tga")) {
                    save_tga_file(file_path);
                } else {
                    // In 2-bit mode with custom palette, we need to pass our sampled colors
                    if (!is_one_bit_mode && points_initialized) {
                        save_chr_file_with_custom_palette(file_path);
                    } else {
                        FileUtils.save_chr_file(file_path, processed_image, is_one_bit_mode, theme_manager);
                    }
                }
            }
            dialog.destroy();
        });
        
        dialog.present();
    }
    
    private void save_chr_file_with_custom_palette(string file_path) {
        try {
            int width = processed_image.get_width();
            int height = processed_image.get_height();
            unowned uint8[] src_data = (uint8[]) processed_image.get_data();
            int src_stride = processed_image.get_stride();
            
            // Create CHR file format
            // Simple format: Width (2 bytes), Height (2 bytes), followed by pixel data
            // Each pixel is 1 byte (0-3 for 2-bit mode, 0-1 for 1-bit mode)
            
            FileStream file = FileStream.open(file_path, "wb");
            if (file == null) {
                throw new FileError.FAILED("Could not open file for writing");
            }
            
            // Write header (width and height as 16-bit values)
            file.putc((char)(width & 0xFF));
            file.putc((char)((width >> 8) & 0xFF));
            file.putc((char)(height & 0xFF));
            file.putc((char)((height >> 8) & 0xFF));
            
            // Extract sampled colors for reference during saving
            Gdk.RGBA[] colors = sampled_colors;
            
            // Write pixel data
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    int offset = y * src_stride + x * 4;
                    uint8 b = src_data[offset + 0];
                    uint8 g = src_data[offset + 1];
                    uint8 r = src_data[offset + 2];
                    
                    // Convert to CHR format (0-3 for 2-bit)
                    uint8 chr_value;
                    
                    // Find closest of 4 colors
                    var color_distances = new double[4];
                    for (int i = 0; i < 4; i++) {
                        color_distances[i] = color_distance(
                            r, g, b,
                            (uint8)(colors[i].red * 255),
                            (uint8)(colors[i].green * 255),
                            (uint8)(colors[i].blue * 255)
                        );
                    }
                    
                    // Find minimum distance
                    double min_dist = double.MAX;
                    int min_index = 0;
                    
                    for (int i = 0; i < 4; i++) {
                        if (color_distances[i] < min_dist) {
                            min_dist = color_distances[i];
                            min_index = i;
                        }
                    }
                    
                    chr_value = (uint8)min_index;
                    file.putc((char)chr_value);
                }
            }
        } catch (Error e) {
            warning("Error saving file: %s", e.message);
        }
    }
    
    private double color_distance(uint8 r1, uint8 g1, uint8 b1, uint8 r2, uint8 g2, uint8 b2) {
        return Math.sqrt(
            Math.pow(r1 - r2, 2) + 
            Math.pow(g1 - g2, 2) + 
            Math.pow(b1 - b2, 2)
        );
    }

    private void load_image(string file_path) {
        try {
            // Reset contrast to default value (5)
            contrast_level = 5;
            contrast_scale.set_value(5);
            contrast_value.label = "5";
            
            // Reset sampling points
            points_initialized = false;
            
            // Load image using GDK Pixbuf
            var pixbuf = new Gdk.Pixbuf.from_file(file_path);
            
            // Resize image if necessary to fit within 512 KB
            int max_pixels = 512 * 1024 / 4; // 4 bytes per pixel (RGBA)
            int current_pixels = pixbuf.width * pixbuf.height;
            
            if (current_pixels > max_pixels) {
                double scale = Math.sqrt((double)max_pixels / current_pixels);
                int new_width = (int)(pixbuf.width * scale);
                int new_height = (int)(pixbuf.height * scale);
                pixbuf = pixbuf.scale_simple(new_width, new_height, Gdk.InterpType.BILINEAR);
            }
            
            // Convert pixbuf to Cairo surface and store as original
            original_image = new Cairo.ImageSurface(
                Cairo.Format.ARGB32,
                pixbuf.width,
                pixbuf.height
            );
            
            var cr = new Cairo.Context(original_image);
            Gdk.cairo_set_source_pixbuf(cr, pixbuf, 0, 0);
            cr.paint();
            
            // Apply dithering with current mode
            process_image();
            update_color_indicators();
            
            drawing_area.queue_draw();
        } catch (Error e) {
            var message_dialog = new Gtk.MessageDialog(
                this,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.ERROR,
                Gtk.ButtonsType.OK,
                "Error loading image: %s", e.message
            );
            message_dialog.response.connect((response_id) => {
                message_dialog.destroy();
            });
            message_dialog.present();
        }
    }
    
    private void save_tga_file(string file_path) {
        try {
            // Make sure the file has the .tga extension
            string actual_path = file_path;
            if (!actual_path.down().has_suffix(".tga")) {
                actual_path = actual_path + ".tga";
            }
            
            // Get image dimensions
            int width = processed_image.get_width();
            int height = processed_image.get_height();
            
            // Get image data from Cairo surface
            unowned uint8[] data = processed_image.get_data();
            int stride = processed_image.get_stride();
            
            // Create TGA file
            FileOutputStream stream = File.new_for_path(actual_path).create(FileCreateFlags.REPLACE_DESTINATION);
            
            // Write TGA header (18 bytes)
            uint8[] header = new uint8[18];
            for (int i = 0; i < 18; i++) {
                header[i] = 0;
            }
            
            header[2] = 2; // Uncompressed RGB
            header[12] = (uint8)(width & 0xFF); // Width (low byte)
            header[13] = (uint8)(width >> 8);   // Width (high byte)
            header[14] = (uint8)(height & 0xFF); // Height (low byte)
            header[15] = (uint8)(height >> 8);   // Height (high byte)
            header[16] = 32; // 32 bits per pixel (BGRA)
            header[17] = 0x28;  // 8 bits for alpha + top-left origin (bit 5 set)
            
            // Write header
            stream.write(header);
            
            // Write pixel data (converting from ARGB to BGRA)
            uint8[] row_data = new uint8[width * 4];
            
            for (int y = 0; y < height; y++) { // Write top-to-bottom (we set the origin bit in the header)
                unowned uint8[] src_row = data[y * stride : y * stride + width * 4];
                
                for (int x = 0; x < width; x++) {
                    // Cairo uses ARGB, TGA uses BGRA
                    row_data[x * 4 + 0] = src_row[x * 4 + 2]; // B
                    row_data[x * 4 + 1] = src_row[x * 4 + 1]; // G
                    row_data[x * 4 + 2] = src_row[x * 4 + 0]; // R
                    row_data[x * 4 + 3] = src_row[x * 4 + 3]; // A
                }
                
                stream.write(row_data);
            }
            
            stream.close();
        } catch (Error e) {
            var message_dialog = new Gtk.MessageDialog(
                this,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.ERROR,
                Gtk.ButtonsType.OK,
                "Error saving TGA file: %s", e.message
            );
            message_dialog.response.connect((response_id) => {
                message_dialog.destroy();
            });
            message_dialog.present();
        }
    }
}