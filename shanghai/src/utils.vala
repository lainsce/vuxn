namespace Shanghai {
    // Constants
    public const int TILE_WIDTH = 16;
    public const int TILE_HEIGHT = 24;
    public const int GRID_SIZE = 8;
    public const int NES_WIDTH = 256;
    public const int NES_HEIGHT = 256;
    
    // Tile position multipliers for grid-aligned placement
    public const int TILE_GRID_WIDTH = 2;  // 16px / 8px = 2 grid cells
    public const int TILE_GRID_HEIGHT = 3; // 24px / 8px = 3 grid cells
    
    // Define spacing between tiles (in grid cells)
    public const int TILE_SPACING_X = 3; // 3 grid cells (24px) between tiles horizontally
    public const int TILE_SPACING_Y = 4; // 4 grid cells (32px) between tiles vertically
    
    // Colors (RGBA format)
    public const float[] COLOR_TEAL = { 0.0f, 0.47f, 0.4f, 1.0f };     // #007766
    public const float[] COLOR_BLUE = { 0.2f, 0.0f, 0.73f, 1.0f };     // #3300bb
    public const float[] COLOR_SALMON = { 0.87f, 0.47f, 0.47f, 1.0f }; // #dd7777
    public const float[] COLOR_LIGHT = { 0.93f, 0.93f, 0.93f, 1.0f };  // #eeeeee
    
    // Drawing utilities
    public void set_color(Cairo.Context cr, float[] color) {
        cr.set_source_rgba(color[0], color[1], color[2], color[3]);
    }
    
    public void draw_rounded_rect(Cairo.Context cr, int x, int y, int width, int height, bool fill = true) {
        // Draw a rectangle with cut corners (1px from each corner)
        cr.move_to(x + 1, y);
        cr.line_to(x + width - 1, y);
        cr.line_to(x + width, y + 1);
        cr.line_to(x + width, y + height - 1);
        cr.line_to(x + width - 1, y + height);
        cr.line_to(x + 1, y + height);
        cr.line_to(x, y + height - 1);
        cr.line_to(x, y + 1);
        cr.close_path();
        
        if (fill) {
            cr.fill();
        } else {
            cr.stroke();
        }
    }
    
    // Grid position to pixel position conversion
    public int grid_to_pixel_x(int grid_x) {
        return grid_x * GRID_SIZE;
    }
    
    public int grid_to_pixel_y(int grid_y) {
        return grid_y * GRID_SIZE;
    }
}