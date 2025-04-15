public class VasuEditorView : Gtk.DrawingArea {
    private VasuData chr_data;
    
    // Display a 10x10 grid of 8x8 tiles
    public int GRID_WIDTH = 16;
    public int GRID_HEIGHT = 16;
    
    // Editor pixel data
    private int[,] editor_pixels;
    public signal void tile_selected(int tile_x, int tile_y);
    public signal void tile_modified(int tile_x, int tile_y);
    
    private int hovering_x = -1;
    private int hovering_y = -1;
    
    private double view_scale = 1.0;
    private double view_offset_x = 0.0;
    private double view_offset_y = 0.0;

    // Fields to track left-click drag for drawing
    private bool is_dragging = false;
    private int prev_x = -1;
    private int prev_y = -1;
    
    // Fields to track right-click drag for erasing
    private bool is_right_dragging = false;
    private int right_prev_x = -1;
    private int right_prev_y = -1;

    // For multi-tile selection
    public int selected_tile_x = 0;
    public int selected_tile_y = 0;
    public int selection_start_tile_x = -1;
    public int selection_start_tile_y = -1;
    public int selection_end_tile_x = -1;
    public int selection_end_tile_y = -1;
    private bool is_selecting = false;

    private int zoom_origin_x = 0;
    private int zoom_origin_y = 0;

    // Add methods to select and highlight a tile
    public void select_tile(int x, int y) {
        selected_tile_x = x;
        selected_tile_y = y;
        tile_selected(x, y);
        queue_draw();
    }

    public int get_selected_tile_x() {
        return selected_tile_x;
    }

    public int get_selected_tile_y() {
        return selected_tile_y;
    }
    
    public VasuEditorView(VasuData data) {
        chr_data = data;
        
        // Initialize editor pixels
        editor_pixels = new int[GRID_WIDTH * 8, GRID_HEIGHT * 8];
        for (int y = 0; y < GRID_HEIGHT * 8; y++) {
            for (int x = 0; x < GRID_WIDTH * 8; x++) {
                editor_pixels[x, y] = 0;
            }
        }
        
        // Set size for a 10x10 grid of 8x8 tiles
        set_size_request(GRID_WIDTH * 8, GRID_HEIGHT * 8);
        
        hexpand = true;
        vexpand = true;
        
        set_draw_func(draw);
        
        // Mouse handling
        var motion_controller = new Gtk.EventControllerMotion();
        motion_controller.motion.connect(on_motion);
        motion_controller.leave.connect(on_leave);
        add_controller(motion_controller);
        
        var click_controller = new Gtk.GestureClick();
        click_controller.pressed.connect(on_press);
        click_controller.released.connect(on_release);
        add_controller(click_controller);
        
        var click2_controller = new Gtk.GestureClick();
        click2_controller.pressed.connect(on_right_press);
        click2_controller.button = 3;
        add_controller(click2_controller);
        
        var drag_controller = new Gtk.GestureDrag();
        drag_controller.drag_begin.connect(on_drag_begin);
        drag_controller.drag_update.connect(on_drag_update);
        drag_controller.drag_end.connect(on_drag_end);
        add_controller(drag_controller);
        
        var right_drag_controller = new Gtk.GestureDrag();
        right_drag_controller.button = 3; // Right mouse button
        right_drag_controller.drag_begin.connect(on_right_drag_begin);
        right_drag_controller.drag_update.connect(on_right_drag_update);
        right_drag_controller.drag_end.connect(on_right_drag_end);
        add_controller(right_drag_controller);
        
        // Update when data changes
        chr_data.tile_changed.connect(() => {
            queue_draw();
        });
        
        chr_data.palette_changed.connect(() => {
            queue_draw();
        });
    }
    
    private void draw(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        // Disable antialiasing
        cr.set_antialias(Cairo.Antialias.NONE);
        view_scale = 1;
        
        // Center grid
        view_offset_x = (width - GRID_WIDTH * 8 * view_scale) / 2;
        view_offset_y = (height - GRID_HEIGHT * 8 * view_scale) / 2;
        
        // Transform and render
        cr.save();
        cr.translate(view_offset_x, view_offset_y);
        cr.scale(view_scale, view_scale);
        
        if (chr_data.zoom_level == 16) {
            draw_zoomed_view(cr, GRID_WIDTH * 8, GRID_HEIGHT * 8);
        } else {
            draw_normal_view(cr, GRID_WIDTH * 8, GRID_HEIGHT * 8);
        }
        
        cr.restore();
    }
    
    public int get_pixel(int x, int y) {
        if (x >= 0 && x < GRID_WIDTH * 8 && y >= 0 && y < GRID_HEIGHT * 8) {
            return editor_pixels[x, y];
        }
        return 0;
    }
    
    public void set_pixel(int x, int y, int color) {
        if (x >= 0 && x < GRID_WIDTH * 8 && y >= 0 && y < GRID_HEIGHT * 8) {
            editor_pixels[x, y] = color;
            
            // Also update CHR data if this is in the first tile
            if (x < 8 && y < 8) {
                chr_data.set_pixel(x, y, color);
            }
            
            int tile_x = x / 8;
            int tile_y = y / 8;
            tile_modified(tile_x, tile_y);
        }
    }
    
    // Variant useful for loading/saving
    public void set_pixel_silent(int x, int y, int color) {
        if (x >= 0 && x < GRID_WIDTH * 8 && y >= 0 && y < GRID_HEIGHT * 8) {
            editor_pixels[x, y] = color;
            // No CHR update or signal emission
        }
    }
    
    // Update the editor pixels with the current tile data
    public void update_from_current_tile() {
        // Update the editor pixels with the current tile data
        for (int x = 0; x < VasuData.TILE_WIDTH; x++) {
            for (int y = 0; y < VasuData.TILE_HEIGHT; y++) {
                int editor_x = selected_tile_x * VasuData.TILE_WIDTH + x;
                int editor_y = selected_tile_y * VasuData.TILE_HEIGHT + y;
                
                // Get the pixel color from the current tile
                int color = chr_data.get_pixel(x, y);
                
                // Update the editor pixel
                set_pixel(editor_x, editor_y, color);
            }
        }
        
        // Redraw
        queue_draw();
    }
    
    private bool window_to_grid(double wx, double wy, out int gx, out int gy) {
        double scale_x = (double)get_allocated_width() / (GRID_WIDTH * 8);
        double scale_y = (double)get_allocated_height() / (GRID_HEIGHT * 8);
        double scale = Math.fmin(scale_x, scale_y);
        
        double offset_x = (get_allocated_width() - GRID_WIDTH * 8 * scale) / 2;
        double offset_y = (get_allocated_height() - GRID_HEIGHT * 8 * scale) / 2;
        
        // Apply inverse transformation
        double x = (wx - offset_x) / scale;
        double y = (wy - offset_y) / scale;
        
        // In zoomed mode, we need to handle the coordinate conversion differently
        if (chr_data.zoom_level == 16) {
            // We're focusing on a 16x16 section of the editor
            int zoom_width = 16;
            int zoom_height = 16;
            
            // In zoomed mode, the 16x16 section is stretched to fill the view
            // Calculate zoom scale factors
            double zoom_scale_x = (double)get_allocated_width() / zoom_width;
            double zoom_scale_y = (double)get_allocated_height() / zoom_height;
            double zoom_scale = Math.fmin(zoom_scale_x, zoom_scale_y);
            
            // Calculate zoom offsets (centering)
            double zoom_offset_x = (get_allocated_width() - zoom_width * zoom_scale) / 2;
            double zoom_offset_y = (get_allocated_height() - zoom_height * zoom_scale) / 2;
            
            // Apply inverse zoom transformation
            double zoom_x = (wx - zoom_offset_x) / zoom_scale;
            double zoom_y = (wy - zoom_offset_y) / zoom_scale;
            
            // Ensure coordinates are within visible area (the zoomed section)
            if (zoom_x < 0 || zoom_x >= zoom_width || zoom_y < 0 || zoom_y >= zoom_height) {
                gx = -1;
                gy = -1;
                return false;
            }
            
            // Map zoomed coordinates to grid coordinates by adding the zoom origin
            gx = (int)zoom_x + zoom_origin_x;
            gy = (int)zoom_y + zoom_origin_y;
        } else {
            // Normal mode - just check bounds
            if (x < 0 || x >= GRID_WIDTH * 8 || y < 0 || y >= GRID_HEIGHT * 8) {
                gx = -1;
                gy = -1;
                return false;
            }
            
            gx = (int)x;
            gy = (int)y;
        }
        
        return true;
    }
    
    private void draw_normal_view(Cairo.Context cr, int width, int height) {
        // Draw pixels
        cr.set_antialias(Cairo.Antialias.NONE);
        for (int x = 0; x < GRID_WIDTH * 8; x++) {
            for (int y = 0; y < GRID_HEIGHT * 8; y++) {
                int color_idx = editor_pixels[x, y];
                Gdk.RGBA color = chr_data.get_color(color_idx);
                
                cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
                cr.rectangle(x, y, 1, 1);
                cr.fill();
            }
        }
        
        // Draw selection tile indicators
        // Calculate the current selected tile position
        int tile_x = selected_tile_x; 
        int tile_y = selected_tile_y;
        
        // Draw the single tile selection first
        Gdk.RGBA color = chr_data.get_color(1);
        cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
        cr.rectangle(tile_x * 8, tile_y * 8, 8, 8);
        cr.fill();
        
        if (selection_start_tile_x != -1 && selection_end_tile_x != -1) {
            // Calculate selection bounds
            int sel_left = int.min(selection_start_tile_x, selection_end_tile_x);
            int sel_top = int.min(selection_start_tile_y, selection_end_tile_y);
            int sel_right = int.max(selection_start_tile_x, selection_end_tile_x);
            int sel_bottom = int.max(selection_start_tile_y, selection_end_tile_y);
            
            // Calculate selection dimensions
            int sel_width = sel_right - sel_left + 1;
            int sel_height = sel_bottom - sel_top + 1;

            // Now invert all colors inside the selection
            for (int y = sel_top * 8; y < (sel_bottom + 1) * 8; y++) {
                for (int x = sel_left * 8; x < (sel_right + 1) * 8; x++) {
                    // Get original color and invert it
                    int color_idx = editor_pixels[x, y];
                    int inverted_color_idx = (color_idx + 2) % 4; // Simple inversion formula
                    
                    // Draw with inverted color
                    Gdk.RGBA inverted_color = chr_data.get_color(inverted_color_idx);
                    cr.set_source_rgba(inverted_color.red, inverted_color.green, inverted_color.blue, inverted_color.alpha);
                    cr.rectangle(x, y, 1, 1);
                    cr.fill();
                }
            }
            
            // Draw multi-tile selection if active
            if (selection_start_tile_x != -1 && selection_end_tile_x != -1) {
                // If selection spans more than 2 tiles horizontally and vertically,
                // draw the hex dimensions at the bottom-right
                if (sel_width > 2 && sel_height > 2) {
                    // Convert dimensions to hex
                    string dim_hex = "%x%x".printf(sel_width, sel_height);
                    
                    // Draw the background
                    Gdk.RGBA bg_color = chr_data.get_color(2);
                    cr.set_source_rgba(bg_color.red, bg_color.green, bg_color.blue, bg_color.alpha);
                    cr.rectangle((sel_left * 8), (sel_bottom * 8) + 8, 15, 8);
                    cr.fill();
                    
                    // Draw each digit of the hex value
                    Gdk.RGBA fg_color = chr_data.get_color(0);
                    cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, fg_color.alpha);
                    
                    // First digit (width)
                    draw_hex_digit(cr, dim_hex.substring(0, 1), (sel_left * 8), (sel_bottom * 8) + 8);

                    // Second digit (height)
                    draw_hex_digit(cr, dim_hex.substring(1, 1), (sel_left * 8) + 7, (sel_bottom * 8) + 8);
                }
            }
        }
    }
    
    // Helper method to draw a hex digit in pixel art style
    private void draw_hex_digit(Cairo.Context cr, string digit, int x, int y) {
        // Save current state to restore later
        cr.save();
        
        // Disable antialiasing for pixel-perfect rendering
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Set font properties to match CSS (8px atari8 font)
        cr.select_font_face("atari8", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        cr.set_font_size(8);
        
        // Position the text
        // The y position may need adjustment after visual testing
        cr.move_to(x, y + 8); // +6 adjusts for baseline position
        
        // Draw the text
        cr.show_text(digit);
        
        // Restore previous state
        cr.restore();
    }
    
    public void get_selection_bounds(out int left, out int top, out int width, out int height) {
        if (selection_start_tile_x != -1 && selection_end_tile_x != -1) {
            int sel_left = int.min(selection_start_tile_x, selection_end_tile_x);
            int sel_top = int.min(selection_start_tile_y, selection_end_tile_y);
            int sel_right = int.max(selection_start_tile_x, selection_end_tile_x);
            int sel_bottom = int.max(selection_start_tile_y, selection_end_tile_y);
            
            left = sel_left;
            top = sel_top;
            width = sel_right - sel_left + 1;
            height = sel_bottom - sel_top + 1;
        } else {
            // Default to the currently selected single tile
            left = selected_tile_x;
            top = selected_tile_y;
            width = 1;
            height = 1;
        }
    }
    
    private void draw_zoomed_view(Cairo.Context cr, int width, int height) {
        int zoom_width = 16;
        int zoom_height = 16;
        
        // Draw zoomed pixels
        for (int y = 0; y < zoom_height; y++) {
            for (int x = 0; x < zoom_width; x++) {
                // Get color from the editor using the zoom origin
                int editor_x = zoom_origin_x + x;
                int editor_y = zoom_origin_y + y;
                
                // Check if this pixel is within bounds
                if (editor_x >= 0 && editor_x < GRID_WIDTH * 8 && 
                    editor_y >= 0 && editor_y < GRID_HEIGHT * 8) {
                    int color_idx = editor_pixels[editor_x, editor_y];
                    Gdk.RGBA color = chr_data.get_color(color_idx);
                    
                    cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
                    double x1 = x * 8;
                    double y1 = y * 8;
                    
                    // Draw the pixel
                    cr.rectangle(x1 + 1, y1, 5, 7);
                    cr.rectangle(x1, y1 + 1, 7, 5);
                    cr.fill();
                }
            }
        }
        
        // Draw quarters lines
        Gdk.RGBA gcolor = chr_data.get_color(2);
        cr.set_source_rgba(gcolor.red, gcolor.green, gcolor.blue, gcolor.alpha);
        // Vertical dotted line
        int center_x = width / 2;  // 64 for a 128px width
        for (int y = 0; y < height; y += 2) {
            cr.rectangle(center_x, y, 1, 1);
        }
        cr.fill();
        
        // Horizontal dotted line
        int center_y = height / 2;  // 64 for a 128px height
        for (int x = 0; x < width; x += 2) {
            cr.rectangle(x, center_y, 1, 1);
        }
        cr.fill();
    }
    
    private void on_motion(double x, double y) {
        int grid_x, grid_y;
        if (!window_to_grid(x, y, out grid_x, out grid_y)) {
            hovering_x = -1;
            hovering_y = -1;
            queue_draw();
            return;
        }
        
        hovering_x = grid_x;
        hovering_y = grid_y;
        queue_draw();
        
        // Handle drawing during motion if dragging with pen tool
        if (is_dragging && chr_data.selected_tool == 0 && prev_x != -1 && prev_y != -1) {
            // Only allow pen tool if zoomed in
            if (chr_data.zoom_level == 16) {
                set_pixel(grid_x, grid_y, chr_data.selected_color);
                // Update previous position
                prev_x = grid_x;
                prev_y = grid_y;
            }
        }
        
        // Handle erasing during right-click drag
        if (is_right_dragging && right_prev_x != -1 && right_prev_y != -1) {
            set_pixel(grid_x, grid_y, 0);
            // Update previous position
            right_prev_x = grid_x;
            right_prev_y = grid_y;
        }
        
        // If we're using the cursor tool, update selection
        if (chr_data.selected_tool == 1 && is_selecting) {
            // Convert pixel coordinates to tile coordinates
            int tile_x = grid_x / 8;
            int tile_y = grid_y / 8;
            
            // Update the selection end
            selection_end_tile_x = tile_x;
            selection_end_tile_y = tile_y;
            
            queue_draw();
        }
    }
    
    private void on_leave() {
        hovering_x = -1;
        hovering_y = -1;
        queue_draw();
    }
    
    private void on_press(int n_press, double x, double y) {
        int grid_x, grid_y;
        if (!window_to_grid(x, y, out grid_x, out grid_y)) {
            return;  // Click outside drawable area
        }

        // Initialize drag tracking
        prev_x = grid_x;
        prev_y = grid_y;
        
        // Handle based on selected tool
        if (chr_data.selected_tool == 0 && chr_data.zoom_level == 16) { // Pen tool (only works zoomed)
            set_pixel(grid_x, grid_y, chr_data.selected_color);
            queue_draw();
        } else if (chr_data.selected_tool == 1) { // Cursor tool
            // Start selection mode for multiselect
            int tile_x = grid_x / 8;
            int tile_y = grid_y / 8;
            
            // Begin selection (will be adjusted during drag)
            selection_start_tile_x = tile_x;
            selection_start_tile_y = tile_y;
            selection_end_tile_x = tile_x;
            selection_end_tile_y = tile_y;
            is_selecting = true;
            
            // Update the selected tile
            selected_tile_x = tile_x;
            selected_tile_y = tile_y;
            
            // Emit tile selection signal
            tile_selected(tile_x, tile_y);
            
            // Copy the tile data to the current CHR data
            for (int xe = 0; xe < 8; xe++) {
                for (int ye = 0; ye < 8; ye++) {
                    int editor_x = tile_x * 8 + xe;
                    int editor_y = tile_y * 8 + ye;
                    
                    if (editor_x < GRID_WIDTH * 8 && editor_y < GRID_HEIGHT * 8) {
                        int color = editor_pixels[editor_x, editor_y];
                        chr_data.set_pixel(xe, ye, color);
                    }
                }
            }
            queue_draw();
        } else if (chr_data.selected_tool == 2) { // Zoom tool
            // Snap to 8×8 logical areas
            // Each area is 16×16 pixels (128/8 × 128/8)
            
            // Determine which area was clicked
            int area_x = grid_x / 16;  // 0-7 (128 / 8 = 16)
            int area_y = grid_y / 16;  // 0-7 (128 / 8 = 16)
            
            // Ensure valid range
            area_x = (int)Math.fmin(7, Math.fmax(0, area_x));
            area_y = (int)Math.fmin(7, Math.fmax(0, area_y));
            
            // Calculate the top-left corner of the area
            zoom_origin_x = area_x * 16;
            zoom_origin_y = area_y * 16;
            
            // Toggle zoom mode
            if (chr_data.zoom_level == 8) {
                chr_data.zoom_level = 16;
            } else {
                chr_data.zoom_level = 8;
            }
            
            queue_draw();
        }
    }
    
    private void on_right_press(int n_press, double x, double y) {
        int grid_x, grid_y;
        if (!window_to_grid(x, y, out grid_x, out grid_y)) {
            return;  // Click outside drawable area
        }
        
        // Erase pixel (set to background color 0)
        set_pixel(grid_x, grid_y, 0);
        queue_draw();
    }
    
    private void on_release(int n_press, double x, double y) {
        is_dragging = false;
    }
    
    // Handle right-click dragging (for erasing)
    private void on_right_drag_begin(double start_x, double start_y) {
        int grid_x, grid_y;
        if (!window_to_grid(start_x, start_y, out grid_x, out grid_y)) {
            return;
        }
        
        is_right_dragging = true;
        right_prev_x = grid_x;
        right_prev_y = grid_y;
        
        // Erase the starting pixel
        set_pixel(grid_x, grid_y, 0);
    }

    private void on_right_drag_update(double offset_x, double offset_y) {
        if (!is_right_dragging) return;
        
        int current_x, current_y;
        if (!window_to_grid(get_event_widget().get_allocated_width() / 2.0 + offset_x,
                            get_event_widget().get_allocated_height() / 2.0 + offset_y,
                            out current_x, out current_y)) {
            return;  // Outside drawable area
        }
        
        // Skip if position hasn't changed
        if (current_x == right_prev_x && current_y == right_prev_y) return;
        
        // Erase at the new position
        set_pixel(current_x, current_y, 0);
        
        // Update previous position
        right_prev_x = current_x;
        right_prev_y = current_y;
    }

    private void on_right_drag_end(double offset_x, double offset_y) {
        is_right_dragging = false;
        right_prev_x = -1;
        right_prev_y = -1;
    }
    
    private void on_drag_begin(double start_x, double start_y) {
        int grid_x, grid_y;
        if (!window_to_grid(start_x, start_y, out grid_x, out grid_y)) {
            return;
        }
        
        is_dragging = true;
        prev_x = grid_x;
        prev_y = grid_y;
    }
    
    // Add handlers for multi-tile selection
    private void on_drag_update(double offset_x, double offset_y) {
        if (!is_dragging) return;
        
        int current_x, current_y;
        if (!window_to_grid(get_event_widget().get_allocated_width() / 2.0 + offset_x, 
                            get_event_widget().get_allocated_height() / 2.0 + offset_y, 
                            out current_x, out current_y)) {
            return;  // Outside drawable area
        }
        
        // Skip if position hasn't changed
        if (current_x == prev_x && current_y == prev_y) return;
    }
    
    private void on_drag_end(double offset_x, double offset_y) {
        is_dragging = false;
        prev_x = -1;
        prev_y = -1;
        
        // Finalize selection if using cursor tool
        if (chr_data.selected_tool == 1 && is_selecting) {
            is_selecting = false;
        }
    }
    
    private Gtk.Widget? get_event_widget() {
        return this;
    }
    
    // Clear the entire editor
    public void clear_editor() {
        for (int y = 0; y < GRID_HEIGHT * 8; y++) {
            for (int x = 0; x < GRID_WIDTH * 8; x++) {
                editor_pixels[x, y] = 0;
            }
        }
        
        // Also clear the current tile
        chr_data.clear_tile();
        
        queue_draw();
    }
}