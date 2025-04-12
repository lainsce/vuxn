public class IconcharView : Gtk.DrawingArea {
    private IconcharData char_data;
    
    // Display configuration
    private double scale = 1.0;
    private double offset_x = 0.0;
    private double offset_y = 0.0;
    private bool show_grid = true;
    
    // Signals
    public signal void view_updated();
    
    public IconcharView(IconcharData data) {
        // Safety check
        if (data == null) {
            error("Character data cannot be null");
        }
        
        char_data = data;
        
        // Make drawing area expand to fill container
        hexpand = true;
        vexpand = true;
        
        // Add safety check for initial grid dimensions
        if (char_data.grid_width <= 0 || char_data.grid_height <= 0) {
            warning("Invalid grid dimensions in view constructor: %dx%d", 
                    char_data.grid_width, char_data.grid_height);
                    
            // Default to 10x10 if dimensions are invalid
            char_data.grid_width = 10;
            char_data.grid_height = 10;
            char_data.resize_grid(10, 10);
        }
        
        // Initial size based on default grid dimensions
        update_size_request();
        
        // Set up draw function
        set_draw_func(draw);
        
        // Connect data signal
        char_data.data_changed.connect(() => {
            update_size_request();
            queue_draw();
        });
        
        char_data.palette_changed.connect(() => {
            queue_draw();
        });
    }
    
    // Update the size request based on grid dimensions
    private void update_size_request() {
        // Calculate pixel dimensions from tile dimensions
        int width_px = char_data.grid_width * IconcharData.TILE_WIDTH;
        int height_px = char_data.grid_height * IconcharData.TILE_HEIGHT;
        
        print("Setting size request for %dx%d pixels\n", width_px, height_px);
        
        // Set minimum size while allowing expansion
        int min_width = (int)Math.fmin(width_px * 2, 800);  // Keep reasonable max size
        int min_height = (int)Math.fmin(height_px * 2, 600); // Keep reasonable max size
        
        // Update size request
        set_size_request(min_width, min_height);
    }
    
    // Draw the entire view
    private void draw(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        // Disable antialiasing for pixel-perfect rendering
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Safety check - make sure we have a valid char_data
        if (char_data == null) {
            warning("Character data is null in draw function");
            return;
        }
        
        // Safety check - ensure dimensions are valid
        int grid_width = char_data.grid_width.clamp(1, 256);
        int grid_height = char_data.grid_height.clamp(1, 256);
        
        if (grid_width != char_data.grid_width || grid_height != char_data.grid_height) {
            warning("Invalid grid dimensions: %dx%d, clamping to %dx%d", 
                    char_data.grid_width, char_data.grid_height, grid_width, grid_height);
        }
        
        // Calculate total grid size in pixels
        int grid_width_px = grid_width * IconcharData.TILE_WIDTH;
        int grid_height_px = grid_height * IconcharData.TILE_HEIGHT;
        
        // Fill background first
        try {
            Gdk.RGBA bg_color = char_data.get_color(0);
            cr.set_source_rgba(bg_color.red, bg_color.green, bg_color.blue, bg_color.alpha);
            cr.paint();
        } catch (Error e) {
            warning("Failed to draw background: %s", e.message);
            // Use a default color
            cr.set_source_rgb(0.2, 0.2, 0.2);
            cr.paint();
        }
        
        // Get the current zoom scale
        scale = 1.0;
        
        // Center the grid in the available space
        offset_x = (width - grid_width_px * scale) / 2;
        offset_y = (height - grid_height_px * scale) / 2;
        
        // Ensure offsets are never negative
        offset_x = Math.fmax(0, offset_x);
        offset_y = Math.fmax(0, offset_y);
        
        // Apply transformation to center and scale the grid
        cr.save();
        cr.translate(offset_x, offset_y);
        cr.scale(scale, scale);
        
        // Only draw pixels if within reasonable bounds
        if (grid_width_px <= 2048 && grid_height_px <= 2048) {
            // Draw grid lines if enabled
            if (show_grid) {
                try {
                    Gdk.RGBA grid_color = char_data.get_color(0);
                    cr.set_source_rgba(grid_color.red, grid_color.green, grid_color.blue, 0.3);
                    cr.set_line_width(1.0 / scale);
                    
                    // Draw vertical grid lines for tile boundaries
                    for (int x = 0; x <= grid_width_px; x += IconcharData.TILE_WIDTH) {
                        cr.move_to(x, 0);
                        cr.line_to(x, grid_height_px);
                    }
                    
                    // Draw horizontal grid lines for tile boundaries
                    for (int y = 0; y <= grid_height_px; y += IconcharData.TILE_HEIGHT) {
                        cr.move_to(0, y);
                        cr.line_to(grid_width_px, y);
                    }
                    
                    cr.stroke();
                } catch (Error e) {
                    warning("Failed to draw grid lines: %s", e.message);
                }
            }
        
            // Draw all pixels
            for (int y = 0; y < grid_height_px; y++) {
                for (int x = 0; x < grid_width_px; x++) {
                    try {
                        // Get color index for this pixel
                        int color_idx = char_data.get_pixel(x, y);
                        
                        // Get the actual color
                        Gdk.RGBA color = char_data.get_color(color_idx);
                        
                        // Draw the pixel
                        cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
                        cr.rectangle(x, y, 1, 1);
                        cr.fill();
                    } catch (Error e) {
                        // Skip this pixel on error
                    }
                }
            }
        } else {
            // Draw an error message instead
            cr.set_source_rgb(1.0, 0.0, 0.0);
            cr.set_font_size(16);
            cr.move_to(10, 30);
            cr.show_text("Error: Grid dimensions too large to display");
        }
        
        cr.restore();
        view_updated();
    }
    
    // Toggle grid visibility
    public void toggle_grid() {
        show_grid = !show_grid;
        queue_draw();
    }
    
    // Clear all pixel data
    public void clear_view() {
        char_data.clear_grid();
        queue_draw();
    }
}