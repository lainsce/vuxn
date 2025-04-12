public class IconcharData : Object {
    // Constants for tile size
    public const int TILE_WIDTH = 8;
    public const int TILE_HEIGHT = 8;
    public const int BITS_PER_PIXEL = 2; // 4 colors
    public const int COLORS_COUNT = 4;  // 2^BITS_PER_PIXEL
    
    // Grid dimensions (configurable based on filename)
    public int grid_width { get; set; default = 10; } // default 10x10
    public int grid_height { get; set; default = 10; } // default 10x10
    
    // Pixel data for the entire grid
    private int[,] grid_pixels;
    private Gdk.RGBA[] current_palette;
    private Theme.Manager theme;
    
    // File information
    public string filename { get; set; default = "untitled10x10.chr"; }
    public bool is_monochrome { get; set; default = false; } // ICN vs CHR
    
    // Signal for when the data changes
    public signal void data_changed();
    public signal void palette_changed();
    
    public IconcharData() {
        // Initialize with default grid dimensions
        grid_width = 10;
        grid_height = 10;
        
        print("Creating IconcharData with initial size %dx%d tiles\n", grid_width, grid_height);
        
        // Initialize pixel array with known safe dimensions
        int pixel_width = grid_width * TILE_WIDTH;
        int pixel_height = grid_height * TILE_HEIGHT;
        
        try {
            print("Allocating initial grid of %dx%d pixels\n", pixel_width, pixel_height);
            grid_pixels = new int[pixel_width, pixel_height];
            
            // Initialize all pixels to 0
            for (int y = 0; y < pixel_height; y++) {
                for (int x = 0; x < pixel_width; x++) {
                    grid_pixels[x, y] = 0;
                }
            }
        } catch (Error e) {
            error("Failed to allocate initial grid: %s", e.message);
        }
        
        // Initialize palette with safe values
        current_palette = new Gdk.RGBA[COLORS_COUNT];
        for (int i = 0; i < COLORS_COUNT; i++) {
            current_palette[i] = { 0.0f, 0.0f, 0.0f, 1.0f }; // Default to black
        }
        
        // Set up theme
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
    
    // Update palette from theme
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

    // Resize the grid based on new dimensions
    public void resize_grid(int width, int height) {
        // Enforce strict limits on dimensions to prevent memory allocation issues
        width = width.clamp(1, 256);  // Max reasonable width
        height = height.clamp(1, 256); // Max reasonable height
        
        print("Resizing grid from %dx%d to %dx%d tiles\n", grid_width, grid_height, width, height);
        
        // Update dimensions
        grid_width = width;
        grid_height = height;
        
        // Calculate pixel dimensions
        int pixel_width = width * TILE_WIDTH;
        int pixel_height = height * TILE_HEIGHT;
        
        print("Grid pixel dimensions: %dx%d\n", pixel_width, pixel_height);
        
        // Safety check to prevent excessive memory allocation
        if (pixel_width > 2048 || pixel_height > 2048) {
            warning("Excessive grid dimensions requested (%dx%d pixels), clamping", pixel_width, pixel_height);
            
            // Restrict to max 2048x2048 pixels (still very large)
            width = (int)Math.fmin(width, 2048 / TILE_WIDTH);
            height = (int)Math.fmin(height, 2048 / TILE_HEIGHT);
            
            grid_width = width;
            grid_height = height;
            pixel_width = width * TILE_WIDTH;
            pixel_height = height * TILE_HEIGHT;
            
            print("Clamped to %dx%d tiles (%dx%d pixels)\n", width, height, pixel_width, pixel_height);
        }
        
        // Extra validation
        if (pixel_width <= 0 || pixel_height <= 0 || 
            pixel_width > 2048 || pixel_height > 2048) {
            error("Invalid pixel dimensions: %dx%d", pixel_width, pixel_height);
        }
        
        try {
            print("Allocating array of size %dx%d (%d total elements)\n", 
                  pixel_width, pixel_height, pixel_width * pixel_height);
                  
            // Allocate new pixel array and initialize every element to zero
            grid_pixels = new int[pixel_width, pixel_height];
            clear_grid();
        } catch (Error e) {
            error("Failed to allocate grid of size %dx%d: %s", 
                  pixel_width, pixel_height, e.message);
        }
    }
    
    // Clear the grid
    public void clear_grid() {
        for (int y = 0; y < grid_height * TILE_HEIGHT; y++) {
            for (int x = 0; x < grid_width * TILE_WIDTH; x++) {
                grid_pixels[x, y] = 0;
            }
        }
        data_changed();
    }
    
    // Set a pixel in the grid - ensure correct grid calculation
    public void set_pixel(int x, int y, int color_index) {
        // Ensure we're within bounds
        if (x >= 0 && x < grid_width * TILE_WIDTH && 
            y >= 0 && y < grid_height * TILE_HEIGHT) {
            grid_pixels[x, y] = color_index;
        }
    }

    // Get a pixel from the grid
    public int get_pixel(int x, int y) {
        if (x >= 0 && x < grid_width * TILE_WIDTH && 
            y >= 0 && y < grid_height * TILE_HEIGHT) {
            return grid_pixels[x, y];
        }
        return 0;
    }
    
    // Set a color in the palette
    public void set_color(int index, Gdk.RGBA color) {
        if (index >= 0 && index < COLORS_COUNT) {
            current_palette[index] = color;
            palette_changed();
        }
    }
    
    // Get a color from the palette
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
    
    // Parse dimensions from a filename (supporting hexadecimal)
    public bool parse_dimensions_from_filename() {
        try {
            if (filename == null || filename.length == 0) {
                return false;
            }
            
            string filename_lower = filename.down();
            int orig_width = grid_width;
            int orig_height = grid_height;
            
            // Look for pattern like "name20x10.chr" or "name20x10.icn"
            if (filename_lower.has_suffix(".chr") || filename_lower.has_suffix(".icn")) {
                try {
                    var regex = new Regex("([0-9a-f]{1,2})x([0-9a-f]{1,2})\\.(chr|icn)$");
                    MatchInfo match_info;
                    
                    if (regex.match(filename_lower, 0, out match_info)) {
                        string width_str = match_info.fetch(1);
                        string height_str = match_info.fetch(2);
                        string ext = match_info.fetch(3);
                        
                        if (width_str != null && height_str != null) {
                            // Try to parse as hex
                            int width = 0;
                            int height = 0;
                            bool parse_success = true;
                            
                            // Safe manual hex parsing
                            try {
                                // Parse width
                                for (int i = 0; i < width_str.length && i < 2; i++) {
                                    char c = width_str[i];
                                    width = width * 16;
                                    if (c >= '0' && c <= '9')
                                        width += c - '0';
                                    else if (c >= 'a' && c <= 'f')
                                        width += c - 'a' + 10;
                                    else {
                                        parse_success = false;
                                        break;
                                    }
                                }
                                
                                // Parse height
                                for (int i = 0; i < height_str.length && i < 2; i++) {
                                    char c = height_str[i];
                                    height = height * 16;
                                    if (c >= '0' && c <= '9')
                                        height += c - '0';
                                    else if (c >= 'a' && c <= 'f')
                                        height += c - 'a' + 10;
                                    else {
                                        parse_success = false;
                                        break;
                                    }
                                }
                            } catch (Error e) {
                                parse_success = false;
                                warning("Error in hex parsing: %s", e.message);
                            }
                            
                            if (!parse_success) {
                                // Fall back to treating as decimal
                                print("Hex parsing failed, trying decimal parsing\n");
                                width = int.parse(width_str);
                                height = int.parse(height_str);
                            }
                            
                            print("Parsed dimensions: %s=%d, %s=%d\n", width_str, width, height_str, height);
                            
                            // Update monochrome flag
                            is_monochrome = (ext == "icn");
                            
                            // Enforce reasonable limits (1-256 tiles in each dimension)
                            width = width.clamp(1, 256);
                            height = height.clamp(1, 256);
                            
                            // Only update if dimensions are valid
                            if (width > 0 && height > 0) {
                                grid_width = width;
                                grid_height = height;
                                
                                print("Setting grid dimensions to %dx%d tiles\n", grid_width, grid_height);
                                return true;
                            } else {
                                print("Invalid dimensions from filename: %dx%d\n", width, height);
                            }
                        }
                    } else {
                        // No dimensions in filename, check extension
                        is_monochrome = filename_lower.has_suffix(".icn");
                        print("No dimensions found in filename\n");
                    }
                } catch (RegexError e) {
                    warning("Regex error: %s", e.message);
                }
            }
            
            // Return true if dimensions changed
            return (orig_width != grid_width || orig_height != grid_height);
        } catch (Error e) {
            warning("Error in parse_dimensions_from_filename: %s", e.message);
            return false;
        }
    }
}