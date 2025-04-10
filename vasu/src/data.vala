public class VasuData : Object {
    // CHR file typically contains 8x8 pixel sprites
    public const int TILE_WIDTH = 8;
    public const int TILE_HEIGHT = 8;
    public const int BITS_PER_PIXEL = 2; // 4 colors
    public const int COLORS_COUNT = 4;  // 2^BITS_PER_PIXEL
    
    private int[,] current_tile;
    private Gdk.RGBA[] current_palette;
    private Theme.Manager theme;
    
    // Mirroring flags
    public bool mirror_horizontal { get; set; default = false; }
    public bool mirror_vertical { get; set; default = false; }
    public int selected_pattern_tile { get; set; default = 1; } // Tile index in pattern preview (0-f)
    
    // Signal for when mirroring changes
    public signal void mirroring_changed();
    
    public int selected_color { get; set; default = 1; } // Default to first usable color (not bg/alpha)
    public int selected_tool { get; set; default = 0; } // 0=pen, 1=cursor, 2=zoom
    public int zoom_level { get; set; default = 8; }
    public int sprite_width { get; set; default = 3; } // 3 for 3x2 sprite size
    public int sprite_height { get; set; default = 2; } // 2
    
    public string filename { get; set; default = "untitled10x10.chr"; }
    
    // Signal for when the tile data changes
    public signal void tile_changed();
    public signal void palette_changed();
    
    // Track the number of shifts applied in each direction
    private int horizontal_shifts = 0;
    private int vertical_shifts = 0;
    
    public VasuData() {
        current_tile = new int[TILE_WIDTH, TILE_HEIGHT];
        current_palette = new Gdk.RGBA[COLORS_COUNT];
        
        // Let's use Theme colors
        theme = Theme.Manager.get_default();
        theme.apply_to_display();
        setup_theme_management();

        // Initialize palette with theme colors
        update_palette_from_theme();
        
        // Connect to theme changes
        theme.theme_changed.connect(update_palette_from_theme);
    }
    
    private void setup_theme_management() {
        string theme_file = GLib.Path.build_filename(Environment.get_home_dir(), ".theme");

        Timeout.add(10, () => {
            if (FileUtils.test(theme_file, FileTest.EXISTS)) {
                try {
                    theme.load_theme_from_file(theme_file);
                } catch (Error e) {
                    warning("Theme load failed: %s", e.message);
                }
            }
            return true;
        });
    }
    
    public int invert_color(int color) {
        if (color == 0) return 1;
        if (color == 1) return 0;
        if (color == 2) return 1;
        if (color == 3) return 2;
        
        return 0;
    }
    
    // New method to update palette from theme
    private void update_palette_from_theme() {
        var fg_color = theme.get_color("theme_fg");
        var ac_color = theme.get_color("theme_accent");
        var se_color = theme.get_color("theme_selection");
        var bg_color = theme.get_color("theme_bg");
        
        // Update the palette with new theme colors
        current_palette[0] = { fg_color.red, fg_color.green, fg_color.blue, fg_color.alpha };  // Black/Alpha
        current_palette[1] = { ac_color.red, ac_color.green, ac_color.blue, ac_color.alpha };  // Cyan
        current_palette[2] = { se_color.red, se_color.green, se_color.blue, se_color.alpha };  // Orange
        current_palette[3] = { bg_color.red, bg_color.green, bg_color.blue, bg_color.alpha };  // White
        
        // Emit the palette_changed signal to update UI
        palette_changed();
    }
    
    public void set_pixel(int x, int y, int color_index) {
        if (x >= 0 && x < TILE_WIDTH && y >= 0 && y < TILE_HEIGHT) {
            current_tile[x, y] = color_index;
            tile_changed();
        }
    }
    
    public int get_pixel(int x, int y) {
        if (x >= 0 && x < TILE_WIDTH && y >= 0 && y < TILE_HEIGHT) {
            return current_tile[x, y];
        }
        return 0;
    }
    
    public void set_color(int index, Gdk.RGBA color) {
        if (index >= 0 && index < COLORS_COUNT) {
            current_palette[index] = color;
            palette_changed();
        }
    }
    
    public Gdk.RGBA get_color(int index) {
        if (index >= 0 && index < COLORS_COUNT) {
            return current_palette[index];
        }
        
        var black = Gdk.RGBA();
        black.red = 0.0f;
        black.green = 0.0f;
        black.blue = 0.0f;
        black.alpha = 1.0f;
        return black;
    }
    
    public void clear_tile() {
        for (int y = 0; y < TILE_HEIGHT; y++) {
            for (int x = 0; x < TILE_WIDTH; x++) {
                current_tile[x, y] = 0;
            }
        }
        tile_changed();
    }
    
    // Modified shift_horizontal method with tracking
    public void shift_horizontal() {
        // Store the rightmost column
        int[] rightmost_column = new int[TILE_HEIGHT];
        for (int y = 0; y < TILE_HEIGHT; y++) {
            rightmost_column[y] = current_tile[TILE_WIDTH - 1, y];
        }
        
        // Shift all columns to the right
        for (int y = 0; y < TILE_HEIGHT; y++) {
            for (int x = TILE_WIDTH - 1; x > 0; x--) {
                current_tile[x, y] = current_tile[x - 1, y];
            }
        }
        
        // Wrap the rightmost column to become the leftmost
        for (int y = 0; y < TILE_HEIGHT; y++) {
            current_tile[0, y] = rightmost_column[y];
        }
        
        // Track the shift
        horizontal_shifts = (horizontal_shifts + 1) % TILE_WIDTH;
        
        // Notify listeners that the tile has changed
        tile_changed();
    }

    // Modified shift_vertical method with tracking
    public void shift_vertical() {
        // Store the top row
        int[] top_row = new int[TILE_WIDTH];
        for (int x = 0; x < TILE_WIDTH; x++) {
            top_row[x] = current_tile[x, 0];
        }
        
        // Shift all rows up
        for (int y = 0; y < TILE_HEIGHT - 1; y++) {
            for (int x = 0; x < TILE_WIDTH; x++) {
                current_tile[x, y] = current_tile[x, y + 1];
            }
        }
        
        // Wrap the top row to become the bottom row
        for (int x = 0; x < TILE_WIDTH; x++) {
            current_tile[x, TILE_HEIGHT - 1] = top_row[x];
        }
        
        // Track the shift
        vertical_shifts = (vertical_shifts + 1) % TILE_HEIGHT;
        
        // Notify listeners that the tile has changed
        tile_changed();
    }

    // New method to reset shifts
    public void reset_shift() {
        // Calculate the number of shifts needed to return to the original state
        int h_shifts_to_reset = horizontal_shifts > 0 ? TILE_WIDTH - horizontal_shifts : 0;
        int v_shifts_to_reset = vertical_shifts > 0 ? TILE_HEIGHT - vertical_shifts : 0;
        
        // Apply the inverse horizontal shifts
        for (int i = 0; i < h_shifts_to_reset; i++) {
            // Shift left instead of right
            int[] leftmost_column = new int[TILE_HEIGHT];
            for (int y = 0; y < TILE_HEIGHT; y++) {
                leftmost_column[y] = current_tile[0, y];
            }
            
            for (int y = 0; y < TILE_HEIGHT; y++) {
                for (int x = 0; x < TILE_WIDTH - 1; x++) {
                    current_tile[x, y] = current_tile[x + 1, y];
                }
            }
            
            for (int y = 0; y < TILE_HEIGHT; y++) {
                current_tile[TILE_WIDTH - 1, y] = leftmost_column[y];
            }
        }
        
        // Apply the inverse vertical shifts
        for (int i = 0; i < v_shifts_to_reset; i++) {
            // Shift down instead of up
            int[] bottom_row = new int[TILE_WIDTH];
            for (int x = 0; x < TILE_WIDTH; x++) {
                bottom_row[x] = current_tile[x, TILE_HEIGHT - 1];
            }
            
            for (int y = TILE_HEIGHT - 1; y > 0; y--) {
                for (int x = 0; x < TILE_WIDTH; x++) {
                    current_tile[x, y] = current_tile[x, y - 1];
                }
            }
            
            for (int x = 0; x < TILE_WIDTH; x++) {
                current_tile[x, 0] = bottom_row[x];
            }
        }
        
        // Reset the shift counters
        horizontal_shifts = 0;
        vertical_shifts = 0;
        
        // Notify that the tile has changed
        if (h_shifts_to_reset > 0 || v_shifts_to_reset > 0) {
            tile_changed();
        }
    }
}