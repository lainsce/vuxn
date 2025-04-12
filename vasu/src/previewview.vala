public class VasuPreviewView : Gtk.DrawingArea {
    private VasuData chr_data;
    private VasuEditorView? editor_view;
    
    public signal void preview_updated();
    
    private bool click_handled = false;
    private bool right_click_handled = false;
    private Gtk.GestureDrag? drag_controller = null;
    private Gtk.GestureDrag? right_drag_controller = null;
    
    // Add tracking for mouse drag operations
    private bool is_dragging = false;
    private int prev_drag_x = -1;
    private int prev_drag_y = -1;

    private bool is_right_dragging = false;
    private int right_prev_x = -1;
    private int right_prev_y = -1;
    
    // 16x16 grid of 8x8 tiles
    private const int GRID_WIDTH = 16;
    private const int GRID_HEIGHT = 16;
    
    // Class to represent a placed tile's data
    private class PlacedTile {
        public int[,] pixels;
        public bool mirror_horizontal;
        public bool mirror_vertical;
        // Store source tile coordinates for update tracking
        public int source_tile_x;
        public int source_tile_y;
        // Store pattern information for transformations
        public int pattern_row;
        public int pattern_col;
        
        public PlacedTile(int src_x, int src_y, int p_row, int p_col) {
            pixels = new int[8, 8];
            mirror_horizontal = false;
            mirror_vertical = false;
            source_tile_x = src_x;
            source_tile_y = src_y;
            pattern_row = p_row;
            pattern_col = p_col;
            
            // Initialize with transparent pixels
            for (int y = 0; y < 8; y++) {
                for (int x = 0; x < 8; x++) {
                    pixels[x, y] = 0;
                }
            }
        }
        
        public int transform_color(int original_color) {
            // Create mapping table (same as in TopBarComponent)
            int[,] color_mappings = {
                // Row 1 (ch=0)
                {0, 0, 1, 2}, // Col 1 (col=0): 0->0, 1->0, 2->1, 3->2
                {0, 1, 2, 3}, // Col 2 (col=1): 0->0, 1->1, 2->2, 3->3
                {0, 2, 3, 1}, // Col 3 (col=2): 0->0, 1->2, 2->3, 3->1
                {0, 3, 1, 2}, // Col 4 (col=3): 0->0, 1->3, 2->1, 3->2
                
                // Row 2 (ch=1)
                {1, 0, 1, 2}, // Col 1 (col=0): 0->1, 1->0, 2->1, 3->2
                {0, 1, 2, 3}, // Col 2 (col=1): 0->0, 1->1, 2->2, 3->3
                {1, 2, 3, 1}, // Col 3 (col=2): 0->1, 1->2, 2->3, 3->1
                {1, 3, 1, 2}, // Col 4 (col=3): 0->1, 1->3, 2->1, 3->2
                
                // Row 3 (ch=2)
                {2, 0, 1, 2}, // Col 1 (col=0): 0->2, 1->0, 2->1, 3->2
                {2, 1, 2, 3}, // Col 2 (col=1): 0->2, 1->1, 2->2, 3->3
                {0, 2, 3, 1}, // Col 3 (col=2): 0->0, 1->2, 2->3, 3->1
                {2, 3, 1, 2}, // Col 4 (col=3): 0->2, 1->3, 2->1, 3->2
                
                // Row 4 (ch=3)
                {3, 0, 1, 2}, // Col 1 (col=0): 0->3, 1->0, 2->1, 3->2
                {3, 1, 2, 3}, // Col 2 (col=1): 0->3, 1->1, 2->2, 3->3
                {3, 2, 3, 1}, // Col 3 (col=2): 0->3, 1->2, 2->3, 3->1
                {0, 3, 1, 2}  // Col 4 (col=3): 0->0, 1->3, 2->1, 3->2
            };
            
            // Calculate mapping index
            int mapping_index = pattern_row * 4 + pattern_col;
            
            // Apply the mapping - including to background color (0)
            return color_mappings[mapping_index, original_color];
        }
        
        public int get_transformed_pixel(int x, int y) {
            // Apply mirroring if needed
            int src_x = x;
            int src_y = y;
            
            if (mirror_horizontal) {
                src_x = 7 - x;
            }
            
            if (mirror_vertical) {
                src_y = 7 - y;
            }
            
            // Get the pixel with mirroring applied
            int color = pixels[src_x, src_y];
            
            // Return the transformed color
            return color;
        }
    }
    
    // Store placed tiles in a 2D array of PlacedTile objects
    private PlacedTile?[,] placed_tiles;
    
    // Track the currently selected tile
    private int selected_tile_x = 0;
    private int selected_tile_y = 0;
    
    private double current_scale = 1.0;
    private double current_offset_x = 0.0;
    private double current_offset_y = 0.0;
    
    public VasuPreviewView(VasuData data, VasuEditorView? editor = null) {
        chr_data = data;
        editor_view = editor;
        
        // Make drawing area expand to fill container
        hexpand = true;
        vexpand = true;
        
        // Set minimum size rather than fixed size
        set_size_request(GRID_WIDTH * VasuData.TILE_WIDTH, GRID_HEIGHT * VasuData.TILE_HEIGHT);
        
        // Initialize the placed_tiles array (null means no tile placed)
        placed_tiles = new PlacedTile?[GRID_WIDTH, GRID_HEIGHT];
        for (int y = 0; y < GRID_HEIGHT; y++) {
            for (int x = 0; x < GRID_WIDTH; x++) {
                placed_tiles[x, y] = null;
            }
        }
        
        set_draw_func(draw);
        
        // Add click handler to place tiles
        var click_controller = new Gtk.GestureClick();
        click_controller.pressed.connect(on_press);
        add_controller(click_controller);
        
        var right_click_controller = new Gtk.GestureClick();
        right_click_controller.button = 3;
        right_click_controller.pressed.connect(on_right_press);
        add_controller(right_click_controller);
        
        // Add drag gesture for left button
        drag_controller = new Gtk.GestureDrag();
        drag_controller.drag_begin.connect(on_drag_begin);
        drag_controller.drag_update.connect(on_drag_update);
        drag_controller.drag_end.connect(on_drag_end);
        add_controller(drag_controller);
        
        // Add drag gesture for right button
        right_drag_controller = new Gtk.GestureDrag();
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
        
        editor_view.tile_modified.connect((tile_x, tile_y) => {
            update_placed_tiles_from_source(tile_x, tile_y);
        });
    }
    
    // Method to set the editor view reference
    public void set_editor_view(VasuEditorView editor) {
        editor_view = editor;
        
        // Connect to the editor_view's tile_modified signal
        editor_view.tile_modified.connect((tile_x, tile_y) => {
            update_placed_tiles_from_source(tile_x, tile_y);
        });
    }
    
    // Method to update all placed tiles that use a specific source tile
    private void update_placed_tiles_from_source(int source_x, int source_y) {
        // Iterate through all placed tiles
        for (int grid_y = 0; grid_y < GRID_HEIGHT; grid_y++) {
            for (int grid_x = 0; grid_x < GRID_WIDTH; grid_x++) {
                // Skip empty cells
                if (placed_tiles[grid_x, grid_y] == null) continue;
                
                // Get the placed tile
                PlacedTile tile = placed_tiles[grid_x, grid_y];
                
                // Check if this placed tile uses the modified source tile
                if (tile.source_tile_x == source_x && tile.source_tile_y == source_y) {
                    // Update the tile pixels with transformation applied
                    update_placed_tile(tile, grid_x, grid_y);
                }
            }
        }
        
        // Redraw the preview
        queue_draw();
    }
    
    private void update_placed_tile(PlacedTile tile, int grid_x, int grid_y) {
        // Update the pixels while applying the pattern transformation
        for (int y = 0; y < 8; y++) {
            for (int x = 0; x < 8; x++) {
                // Get original color value from source
                int source_x = tile.source_tile_x * 8 + x;
                int source_y = tile.source_tile_y * 8 + y;
                int original_color = 0;
                
                // Stay within bounds when getting the pixel
                if (source_x < editor_view.GRID_WIDTH * 8 && source_y < editor_view.GRID_HEIGHT * 8) {
                    original_color = editor_view.get_pixel(source_x, source_y);
                }
                
                // Apply pattern transformation using the helper method
                int transformed_color = tile.transform_color(original_color);
                
                // Store the transformed color
                tile.pixels[x, y] = transformed_color;
            }
        }
    }
    
    // Set the currently selected tile
    public void set_selected_tile(int x, int y) {
        selected_tile_x = x;
        selected_tile_y = y;
    }
    
    // Get the currently selected tile X coordinate
    public int get_selected_tile_x() {
        return selected_tile_x;
    }
    
    // Get the currently selected tile Y coordinate
    public int get_selected_tile_y() {
        return selected_tile_y;
    }

    private void draw(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        // Disable antialiasing
        cr.set_antialias(Cairo.Antialias.NONE);
        double scale = 1;
        
        // Store current scale for input coordinate transformation
        current_scale = scale;
        
        // Center the grid in the available space
        double offset_x = (width - GRID_WIDTH * VasuData.TILE_WIDTH * scale) / 2;
        double offset_y = (height - GRID_HEIGHT * VasuData.TILE_HEIGHT * scale) / 2;
        
        // Store current offsets for input coordinate transformation
        current_offset_x = offset_x;
        current_offset_y = offset_y;
        
        // Apply transformation to center and scale the grid
        cr.save();
        cr.translate(offset_x, offset_y);
        cr.scale(scale, scale);
        
        // Draw placed tiles
        for (int grid_y = 0; grid_y < GRID_HEIGHT; grid_y++) {
            for (int grid_x = 0; grid_x < GRID_WIDTH; grid_x++) {
                // Skip empty cells
                if (placed_tiles[grid_x, grid_y] == null) continue;
                
                // Get the placed tile
                PlacedTile tile = placed_tiles[grid_x, grid_y];
                
                // Calculate pixel position for destination
                int dst_px = grid_x * VasuData.TILE_WIDTH;
                int dst_py = grid_y * VasuData.TILE_HEIGHT;
                
                // Draw all pixels of the tile
                for (int y = 0; y < VasuData.TILE_HEIGHT; y++) {
                    for (int x = 0; x < VasuData.TILE_WIDTH; x++) {
                        // Get the transformed pixel using the helper method
                        int color_index = tile.get_transformed_pixel(x, y);
                        
                        // Draw the pixel with the appropriate color
                        Gdk.RGBA color = chr_data.get_color(color_index);
                        cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
                        cr.rectangle(dst_px + x, dst_py + y, 1, 1);
                        cr.fill();
                    }
                }
            }
        }
        
        cr.restore();
        preview_updated();
    }
    
    private void transform_coordinates(ref double x, ref double y) {
        // Inverse transformation: subtract offset, then divide by scale
        x = (x - current_offset_x) / current_scale;
        y = (y - current_offset_y) / current_scale;
    }

    private void on_press(int n_press, double x, double y) {
        // Transform coordinates from window space to grid space
        transform_coordinates(ref x, ref y);

        // Calculate which grid cell was clicked
        int grid_x = (int)(x / VasuData.TILE_WIDTH);
        int grid_y = (int)(y / VasuData.TILE_HEIGHT);
        
        // Ensure click is within bounds
        if (grid_x >= 0 && grid_x < GRID_WIDTH && grid_y >= 0 && grid_y < GRID_HEIGHT) {
            place_tile_at(grid_x, grid_y);
            click_handled = true; // Mark that we handled this click
        }
    }
    
    private void on_right_press(int n_press, double x, double y) {
        transform_coordinates(ref x, ref y);
        
        int grid_x = (int)(x / VasuData.TILE_WIDTH);
        int grid_y = (int)(y / VasuData.TILE_HEIGHT);
        
        if (grid_x >= 0 && grid_x < GRID_WIDTH && grid_y >= 0 && grid_y < GRID_HEIGHT) {
            erase_sprite_at(grid_x, grid_y);
            right_click_handled = true;
        }
    }
    
    // Handle left-click dragging for placing tiles
    private void on_drag_begin(double start_x, double start_y) {
        // If click was already handled, don't place again
        if (click_handled) {
            // Just set up for drag tracking
            transform_coordinates(ref start_x, ref start_y);
            
            int grid_x = (int)(start_x / VasuData.TILE_WIDTH);
            int grid_y = (int)(start_y / VasuData.TILE_HEIGHT);
            
            if (grid_x >= 0 && grid_x < GRID_WIDTH && grid_y >= 0 && grid_y < GRID_HEIGHT) {
                is_dragging = true;
                prev_drag_x = grid_x;
                prev_drag_y = grid_y;
            }
            
            // Reset the flag for next time
            click_handled = false;
            return;
        }
        
        // Otherwise process normally (for direct drags without a preceding click)
        transform_coordinates(ref start_x, ref start_y);
        
        int grid_x = (int)(start_x / VasuData.TILE_WIDTH);
        int grid_y = (int)(start_y / VasuData.TILE_HEIGHT);
        
        if (grid_x >= 0 && grid_x < GRID_WIDTH && grid_y >= 0 && grid_y < GRID_HEIGHT) {
            is_dragging = true;
            prev_drag_x = grid_x;
            prev_drag_y = grid_y;
            
            // Place tile at start point
            place_tile_at(grid_x, grid_y);
        }
    }

    private void on_drag_update(double offset_x, double offset_y) {
        if (!is_dragging) return;
        
        // Calculate current position
        double current_x, current_y;
        
        // Get the start point of the drag if possible
        if (drag_controller != null) {
            double start_x, start_y;
            drag_controller.get_start_point(out start_x, out start_y);
            current_x = start_x + offset_x;
            current_y = start_y + offset_y;
        } else {
            // Fallback calculation
            current_x = get_allocated_width() / 2.0 + offset_x;
            current_y = get_allocated_height() / 2.0 + offset_y;
        }
        
        // Transform to grid coordinates
        transform_coordinates(ref current_x, ref current_y);
        
        // Calculate grid cell
        int grid_x = (int)(current_x / VasuData.TILE_WIDTH);
        int grid_y = (int)(current_y / VasuData.TILE_HEIGHT);
        
        // Ensure valid position and changed from previous
        if (grid_x >= 0 && grid_x < GRID_WIDTH && grid_y >= 0 && grid_y < GRID_HEIGHT &&
            (grid_x != prev_drag_x || grid_y != prev_drag_y)) {
            
            // Place a tile at the new position
            place_tile_at(grid_x, grid_y);
            
            // Update previous position
            prev_drag_x = grid_x;
            prev_drag_y = grid_y;
        }
    }

    private void on_drag_end(double offset_x, double offset_y) {
        is_dragging = false;
        prev_drag_x = -1;
        prev_drag_y = -1;
    }

    // Handle right-click dragging for erasing tiles
    private void on_right_drag_begin(double start_x, double start_y) {
        // If click was already handled, don't erase again
        if (right_click_handled) {
            // Just set up for drag tracking
            transform_coordinates(ref start_x, ref start_y);
            
            int grid_x = (int)(start_x / VasuData.TILE_WIDTH);
            int grid_y = (int)(start_y / VasuData.TILE_HEIGHT);
            
            if (grid_x >= 0 && grid_x < GRID_WIDTH && grid_y >= 0 && grid_y < GRID_HEIGHT) {
                is_right_dragging = true;
                right_prev_x = grid_x;
                right_prev_y = grid_y;
            }
            
            // Reset the flag for next time
            right_click_handled = false;
            return;
        }
        
        // Otherwise process normally
        transform_coordinates(ref start_x, ref start_y);
        
        int grid_x = (int)(start_x / VasuData.TILE_WIDTH);
        int grid_y = (int)(start_y / VasuData.TILE_HEIGHT);
        
        if (grid_x >= 0 && grid_x < GRID_WIDTH && grid_y >= 0 && grid_y < GRID_HEIGHT) {
            is_right_dragging = true;
            right_prev_x = grid_x;
            right_prev_y = grid_y;
            
            // Erase sprite at start point
            erase_sprite_at(grid_x, grid_y);
        }
    }

    private void on_right_drag_update(double offset_x, double offset_y) {
        if (!is_right_dragging) return;
        
        // Calculate current position
        double current_x, current_y;
        
        // Get the start point of the drag if possible
        if (right_drag_controller != null) {
            double start_x, start_y;
            right_drag_controller.get_start_point(out start_x, out start_y);
            current_x = start_x + offset_x;
            current_y = start_y + offset_y;
        } else {
            // Fallback calculation
            current_x = get_allocated_width() / 2.0 + offset_x;
            current_y = get_allocated_height() / 2.0 + offset_y;
        }
        
        // Transform to grid coordinates
        transform_coordinates(ref current_x, ref current_y);
        
        // Calculate grid cell
        int grid_x = (int)(current_x / VasuData.TILE_WIDTH);
        int grid_y = (int)(current_y / VasuData.TILE_HEIGHT);
        
        // Ensure valid position and changed from previous
        if (grid_x >= 0 && grid_x < GRID_WIDTH && grid_y >= 0 && grid_y < GRID_HEIGHT &&
            (grid_x != right_prev_x || grid_y != right_prev_y)) {
            
            // Erase sprite at the new position
            erase_sprite_at(grid_x, grid_y);
            
            // Update previous position
            right_prev_x = grid_x;
            right_prev_y = grid_y;
        }
    }

    private void on_right_drag_end(double offset_x, double offset_y) {
        is_right_dragging = false;
        right_prev_x = -1;
        right_prev_y = -1;
    }

    // Update the place_tile_at method to check for overlaps and bounds
    private void place_tile_at(int grid_x, int grid_y) {
        // Get the sprite dimensions
        int sprite_width = chr_data.sprite_width;
        int sprite_height = chr_data.sprite_height;
        
        // First, check if the sprite would fit completely within the preview bounds
        if (grid_x + sprite_width > GRID_WIDTH || grid_y + sprite_height > GRID_HEIGHT) {
            // Sprite would go outside the bounds, don't place it
            return;
        }
        
        // Second, check if any part of the target area already has tiles
        for (int y = 0; y < sprite_height; y++) {
            for (int x = 0; x < sprite_width; x++) {
                int target_x = grid_x + x;
                int target_y = grid_y + y;
                
                // If a tile already exists here, don't place the sprite
                if (placed_tiles[target_x, target_y] != null) {
                    return;
                }
            }
        }
        
        // Get the selected tile (the top-left corner of the sprite)
        int base_tile_x = get_selected_tile_x();
        int base_tile_y = get_selected_tile_y();
        
        // Get pattern information
        int pattern_row = chr_data.selected_pattern_tile / 4;
        int pattern_col = chr_data.selected_pattern_tile % 4;
        
        // Now we can safely place each tile of the sprite
        for (int y = 0; y < sprite_height; y++) {
            for (int x = 0; x < sprite_width; x++) {
                // Calculate the target position
                int target_x = grid_x + x;
                int target_y = grid_y + y;
                
                // Calculate the source tile
                int source_tile_x = base_tile_x + x;
                int source_tile_y = base_tile_y + y;
                
                // Skip if source is out of bounds
                if (source_tile_x >= 16 || source_tile_y >= 16) {
                    continue;
                }
                
                // Create a new placed tile with source tile and pattern information
                var transformed_tile = new PlacedTile(source_tile_x, source_tile_y, pattern_row, pattern_col);
                
                // Store the current mirroring state in the tile
                transformed_tile.mirror_horizontal = chr_data.mirror_horizontal;
                transformed_tile.mirror_vertical = chr_data.mirror_vertical;
                
                // Copy pixels from source with pattern transformation applied
                for (int py = 0; py < 8; py++) {
                    for (int px = 0; px < 8; px++) {
                        // Get the original color from the editor
                        int editor_x = source_tile_x * 8 + px;
                        int editor_y = source_tile_y * 8 + py;
                        int original_color = editor_view.get_pixel(editor_x, editor_y);
                        
                        // Apply pattern transformation using the helper method
                        int transformed_color = transformed_tile.transform_color(original_color);
                        
                        // Store the transformed color
                        transformed_tile.pixels[px, py] = transformed_color;
                    }
                }
                
                // Place the transformed tile
                placed_tiles[target_x, target_y] = transformed_tile;
            }
        }
        
        queue_draw();
        preview_updated();
    }
    
    // Helper method to erase a sprite at a specific position
    private void erase_sprite_at(int grid_x, int grid_y) {
        // Get the sprite dimensions
        int sprite_width = chr_data.sprite_width;
        int sprite_height = chr_data.sprite_height;
        
        // Erase all tiles in the sprite area
        for (int y = 0; y < sprite_height; y++) {
            for (int x = 0; x < sprite_width; x++) {
                int target_x = grid_x + x;
                int target_y = grid_y + y;
                
                // Skip if out of bounds
                if (target_x >= GRID_WIDTH || target_y >= GRID_HEIGHT) {
                    continue;
                }
                
                // Erase tile
                placed_tiles[target_x, target_y] = null;
            }
        }
        
        queue_draw();
        preview_updated();
    }
    
    // Method to clear all placed tiles
    public void clear_canvas() {
        for (int y = 0; y < GRID_HEIGHT; y++) {
            for (int x = 0; x < GRID_WIDTH; x++) {
                placed_tiles[x, y] = null;
            }
        }
        queue_draw();
    }
}