public class VasuPreviewView : Gtk.DrawingArea {
    private VasuData chr_data;
    private VasuEditorView? editor_view;
    
    public signal void preview_updated();
    
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
        // Get pattern information from the tile
        int pattern_row = tile.pattern_row;
        int pattern_col = tile.pattern_col;
        
        // Update the pixels while applying the pattern transformation
        for (int y = 0; y < 8; y++) {
            for (int x = 0; x < 8; x++) {
                // Get original color value from source
                int color = get_tile_pixel(tile.source_tile_x, tile.source_tile_y, x, y);
                
                // Skip transparent pixels
                if (color == 0) {
                    tile.pixels[x, y] = 0;
                    continue;
                }
                
                // Apply the advanced color transformation formula
                int c;
                if ((color % 4) + pattern_row == 1) {
                    c = 0;  // Make transparent
                } else {
                    c = (pattern_row - 2 + (color & 3)) % 3 + 1;
                }
                
                // Apply column-specific transformation
                int final_color = (c + pattern_col) % 4;
                
                // Set the transformed color
                tile.pixels[x, y] = final_color;
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
    
    // Helper method to get a pixel color from a specific tile
    private int get_tile_pixel(int tile_x, int tile_y, int pixel_x, int pixel_y) {
        if (tile_x == 0 && tile_y == 0) {
            // For the first tile, use the CHR data directly
            return chr_data.get_pixel(pixel_x, pixel_y);
        } else {
            // For other tiles, use the editor data
            if (editor_view != null) {
                return editor_view.get_pixel(tile_x * 8 + pixel_x, tile_y * 8 + pixel_y);
            } else {
                // Fallback if no editor view is available
                return 0;
            }
        }
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
                        // Apply mirroring to the source coordinates using the tile's own mirroring state
                        int src_x = x;
                        int src_y = y;
                        
                        if (tile.mirror_horizontal) {
                            src_x = VasuData.TILE_WIDTH - 1 - x;
                        }
                        
                        if (tile.mirror_vertical) {
                            src_y = VasuData.TILE_HEIGHT - 1 - y;
                        }
                        
                        // Get the pixel color from the placed tile snapshot
                        int color_index = tile.pixels[src_x, src_y];
                        
                        // Skip transparent pixels (color 0)
                        if (color_index == 0) continue;
                        
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
            // Get pattern information
            int pattern_row = chr_data.selected_pattern_tile / 4;
            int pattern_col = chr_data.selected_pattern_tile % 4;
            
            // Create a new placed tile with source tile and pattern information
            var transformed_tile = new PlacedTile(selected_tile_x, selected_tile_y, pattern_row, pattern_col);
            
            // Store the current mirroring state in the tile
            transformed_tile.mirror_horizontal = chr_data.mirror_horizontal;
            transformed_tile.mirror_vertical = chr_data.mirror_vertical;
            
            // Apply pattern transformation to the tile pixels
            update_placed_tile(transformed_tile, grid_x, grid_y);
            
            // Place the transformed tile at the clicked position
            placed_tiles[grid_x, grid_y] = transformed_tile;
            
            queue_draw();
            preview_updated();
        }
    }
    
    private void on_right_press(int n_press, double x, double y) {
        int grid_x = (int)(x / VasuData.TILE_WIDTH);
        int grid_y = (int)(y / VasuData.TILE_HEIGHT);
        
        if (grid_x >= 0 && grid_x < GRID_WIDTH && grid_y >= 0 && grid_y < GRID_HEIGHT) {
            // Erase tile
            placed_tiles[grid_x, grid_y] = null;
            
            queue_draw();
            preview_updated();
        }
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