public class FontUtils {
    public uint8[] font_data;
    public uint8[] GLYPH_WIDTHS; // Store the widths of each glyph
    public int current_glyph = 0;
    public int font_format = 2; // Default to UF2 format
    public int GLYPH_WIDTH = 16; // Will be set based on format
    public int GLYPH_HEIGHT = 16; // Will be set based on format
    public string current_filename = null;
    
    public const int TILE_SIZE = 8;
    public const int GRID_SCALE = 2;    // Scale factor for grid display
    public const int GRID_COLS = 16;    // Number of columns in the grid
    public const int HEADER_SIZE = 256; // Size of width header in bytes
    
    // Drawing orders for different formats
    // UF1
    private const int[] DRAWING_ORDER_UF1 = {0};
    
    // UF2
    private const int[] DRAWING_ORDER_UF2 = {0, 2, 1, 3};
    
    // UF3
    private const int[] DRAWING_ORDER_UF3 = {0, 3, 6, 1, 4, 7, 2, 5, 8};
    
    public void load_font_file(File file, Gtk.DrawingArea grid_area) {
        try {
            FileInputStream stream = file.read();
            
            // Get file size
            FileInfo info = file.query_info(
                "standard::size", 
                FileQueryInfoFlags.NONE
            );
            int64 size = info.get_size();
            
            // Read the whole file
            font_data = new uint8[size];
            size_t bytes_read;
            stream.read_all(font_data, out bytes_read);
            
            // Store current filename
            current_filename = file.get_path();
            
            // Determine font format based on file extension
            string path = file.get_path();
            if (path.has_suffix(".uf1")) {
                font_format = 1;
                GLYPH_WIDTH = 8;
                GLYPH_HEIGHT = 8;
            } else if (path.has_suffix(".uf2")) {
                font_format = 2;
                GLYPH_WIDTH = 16;
                GLYPH_HEIGHT = 16;
            } else if (path.has_suffix(".uf3")) {
                font_format = 3;
                GLYPH_WIDTH = 24;
                GLYPH_HEIGHT = 24;
            } else {
                warning("Unknown file format, defaulting to UF2");
                font_format = 2;
                GLYPH_WIDTH = 16;
                GLYPH_HEIGHT = 16;
            }
            
            // Extract glyph widths from header
            GLYPH_WIDTHS = new uint8[256];
            for (int i = 0; i < 256 && i < font_data.length; i++) {
                GLYPH_WIDTHS[i] = font_data[i];
            }
            
            // Reset to first glyph
            current_glyph = 0;
            
            // Set grid area content size based on font size
            int displayable_glyphs = get_glyph_count() - 32;
            // Ceiling division
            int rows = (displayable_glyphs + GRID_COLS - 1) / GRID_COLS;
            
            // Calculate width and height with padding for better visibility
            int content_width = GRID_COLS * GLYPH_WIDTH * GRID_SCALE + 16;
            int content_height = rows * GLYPH_HEIGHT * GRID_SCALE + 16;
            
            grid_area.set_content_width(content_width);
            grid_area.set_content_height(content_height);
            
            // Make sure ScrolledWindow knows about this size
            grid_area.set_size_request(content_width, content_height);
            
            // Redraw
            grid_area.queue_draw();
        } catch (Error e) {
            warning("Error loading font file: %s", e.message);
        }
    }
    
    public bool save_bdf_file(File file) {
        try {
            // Open file for writing
            var file_stream = file.replace(
                null, 
                false, 
                FileCreateFlags.REPLACE_DESTINATION
            );
            var data_stream = new DataOutputStream(file_stream);
            
            // Get font properties
            string font_name = Path.get_basename(current_filename ?? "unknown");
            if (font_name.has_suffix(".uf1") || 
                font_name.has_suffix(".uf2") || 
                font_name.has_suffix(".uf3")) {
                font_name = font_name.substring(0, font_name.last_index_of("."));
            }
            
            // Write BDF header
            data_stream.put_string("STARTFONT 2.1\n");
            data_stream.put_string("FONT %s\n".printf(font_name));
            data_stream.put_string("SIZE %d 75 75\n".printf(GLYPH_HEIGHT));
            data_stream.put_string(
                "FONTBOUNDINGBOX %d %d 0 0\n".printf(GLYPH_WIDTH, GLYPH_HEIGHT)
            );
            
            // Write font properties
            data_stream.put_string("STARTPROPERTIES 4\n");
            data_stream.put_string("FONT_ASCENT %d\n".printf(GLYPH_HEIGHT));
            data_stream.put_string("FONT_DESCENT 0\n");
            data_stream.put_string("DEFAULT_CHAR 32\n");
            data_stream.put_string("FONT_VERSION 1.0\n");
            data_stream.put_string("ENDPROPERTIES\n");
            
            // Calculate how many glyphs we actually have in the file
            int bytes_per_glyph = get_bytes_per_glyph();
            int data_size = font_data.length - HEADER_SIZE;
            int actual_glyphs = data_size / bytes_per_glyph;
            
            // Ensure we don't exceed the available data
            int max_chars = (int)Math.fmin(actual_glyphs, 256);
            
            // We're going to output characters 32 through max_chars-1
            data_stream.put_string("CHARS %d\n".printf(max_chars));
            
            // Write each glyph
            for (int i = 0; i < max_chars; i++) {
                // Get adjusted offset for this glyph
                int adjusted_index = i;
                int offset = HEADER_SIZE + (adjusted_index * bytes_per_glyph);
                
                // Get the actual width of this glyph
                uint8 actual_width = i < GLYPH_WIDTHS.length ? 
                                    GLYPH_WIDTHS[i] : 
                                    (uint8)GLYPH_WIDTH;
                
                // Write character info
                data_stream.put_string("STARTCHAR U+%04X\n".printf(i));
                data_stream.put_string("ENCODING %d\n".printf(i));
                data_stream.put_string(
                    "SWIDTH %d 0\n".printf((int)(actual_width * 1000 / GLYPH_WIDTH))
                );
                data_stream.put_string("DWIDTH %d 0\n".printf(actual_width));
                data_stream.put_string(
                    "BBX %d %d 0 0\n".printf(GLYPH_WIDTH, GLYPH_HEIGHT)
                );
                data_stream.put_string("BITMAP\n");
                
                // Generate bitmap data based on format
                switch (font_format) {
                    case 1:
                        write_uf1_bitmap(data_stream, offset);
                        break;
                    case 2:
                        write_uf2_bitmap(data_stream, offset);
                        break;
                    case 3:
                        write_uf3_bitmap(data_stream, offset);
                        break;
                    default:
                        write_uf2_bitmap(data_stream, offset);
                        break;
                }
                
                data_stream.put_string("ENDCHAR\n");
            }
            
            // Write footer
            data_stream.put_string("ENDFONT\n");
            
            return true;
        } catch (Error e) {
            warning("Error saving BDF file: %s", e.message);
            
            return false;
        }
    }
    
    private void write_uf1_bitmap(DataOutputStream stream, int offset) 
        throws IOError {
        // Standard UF1 (8x8)
        // For BDF, we need to properly position the 8x8 data in the 8x16 format
        // For 8x8 fonts, place the data at the top of the glyph, pad bottom with zeros
        
        // Each row in BDF requires padding to full byte width (8px = 1 byte = 2 hex chars)
        int row_bytes = (GLYPH_WIDTH + 7) / 8; // Ceiling division for bytes needed per row
        
        // For UF1, write the 8x8 glyph data starting from correct vertical position
        // Calculate vertical centering for smaller glyphs in a taller BDF
        int start_y = 0;
        if (GLYPH_HEIGHT > 8) {
            // For 16 pixel height, position the glyph in the middle to upper half
            start_y = (GLYPH_HEIGHT - 8) / 2;
        }
        
        // First, write any top padding rows if needed
        for (int y = 0; y < start_y; y++) {
            for (int i = 0; i < row_bytes; i++) {
                stream.put_string("00");
            }
            stream.put_string("\n");
        }
        
        // Write the actual 8x8 glyph data
        for (int y = 0; y < 8; y++) {
            // Check if we're still within the font data
            if (offset + y >= font_data.length) {
                // Write an empty row
                for (int i = 0; i < row_bytes; i++) {
                    stream.put_string("00");
                }
            } else {
                // Get the row data from the font
                uint8 row_data = font_data[offset + y];
                
                // Write the first byte with the actual data
                stream.put_string("%02X".printf(row_data));
                
                // Add any additional bytes if the glyph width > 8
                for (int i = 1; i < row_bytes; i++) {
                    stream.put_string("00");
                }
            }
            stream.put_string("\n");
        }
        
        // Write any bottom padding rows if needed
        for (int y = start_y + 8; y < GLYPH_HEIGHT; y++) {
            for (int i = 0; i < row_bytes; i++) {
                stream.put_string("00");
            }
            stream.put_string("\n");
        }
    }
    
    private void write_uf2_bitmap(DataOutputStream stream, int offset) 
        throws IOError {
        // For a 16x16 glyph, each row needs 4 hex digits (16 bits)
        // UF2 has a 2x2 grid of 8x8 tiles
        int bytes_per_tile = 8; // 8 bytes per 8x8 tile
        
        for (int y = 0; y < 16; y++) {
            int tile_row = y / 8; // 0 for top half, 1 for bottom half
            int row_in_tile = y % 8; // Row within the current 8x8 tile
            
            // For each 16-pixel row, we need data from two tiles side by side
            int left_tile_idx = tile_row * 2;
            int right_tile_idx = tile_row * 2 + 1;
            
            // Adjust for the drawing order
            left_tile_idx = DRAWING_ORDER_UF2[left_tile_idx];
            right_tile_idx = DRAWING_ORDER_UF2[right_tile_idx];
            
            // Calculate offsets for the two tiles
            int left_offset = offset + (left_tile_idx * bytes_per_tile) + row_in_tile;
            int right_offset = offset + (right_tile_idx * bytes_per_tile) + row_in_tile;
            
            // Get the byte data
            uint8 left_byte = (left_offset < font_data.length) ? 
                             font_data[left_offset] : 0;
            uint8 right_byte = (right_offset < font_data.length) ? 
                              font_data[right_offset] : 0;
            
            // Output the combined 16 bits (4 hex digits)
            stream.put_string("%02X%02X\n".printf(left_byte, right_byte));
        }
        
        // If we're exporting to a taller BDF, pad with zeros
        if (GLYPH_HEIGHT > 16) {
            for (int y = 16; y < GLYPH_HEIGHT; y++) {
                stream.put_string("0000\n");
            }
        }
    }
    
    private void write_uf3_bitmap(DataOutputStream stream, int offset) 
        throws IOError {
        // For a 24x24 glyph, each row needs 6 hex digits (24 bits)
        // UF3 has a 3x3 grid of 8x8 tiles
        int bytes_per_tile = 8; // 8 bytes per 8x8 tile
        
        for (int y = 0; y < 24; y++) {
            int tile_row = y / 8; // 0, 1, or 2 for top, middle, bottom
            int row_in_tile = y % 8; // Row within the current 8x8 tile
            
            // For each 24-pixel row, we need data from three tiles side by side
            int left_tile_idx = tile_row * 3; // 0, 3, or 6
            int middle_tile_idx = tile_row * 3 + 1; // 1, 4, or 7
            int right_tile_idx = tile_row * 3 + 2; // 2, 5, or 8
            
            // Adjust for the drawing order
            left_tile_idx = DRAWING_ORDER_UF3[left_tile_idx];
            middle_tile_idx = DRAWING_ORDER_UF3[middle_tile_idx];
            right_tile_idx = DRAWING_ORDER_UF3[right_tile_idx];
            
            // Calculate offsets for the three tiles
            int left_offset = offset + (left_tile_idx * bytes_per_tile) + row_in_tile;
            int middle_offset = offset + (middle_tile_idx * bytes_per_tile) + row_in_tile;
            int right_offset = offset + (right_tile_idx * bytes_per_tile) + row_in_tile;
            
            // Get the byte data
            uint8 left_byte = (left_offset < font_data.length) ? 
                             font_data[left_offset] : 0;
            uint8 middle_byte = (middle_offset < font_data.length) ? 
                               font_data[middle_offset] : 0;
            uint8 right_byte = (right_offset < font_data.length) ? 
                              font_data[right_offset] : 0;
            
            // Output the combined 24 bits (6 hex digits)
            stream.put_string("%02X%02X%02X\n".printf(
                left_byte, middle_byte, right_byte)
            );
        }
    }
    
    public int get_glyph_count() {
        if (font_data == null) return 0;
        
        // Calculate bytes per glyph based on format
        int bytes_per_glyph = get_bytes_per_glyph();
        
        // Calculate how many complete glyphs we have
        int data_size = font_data.length - HEADER_SIZE;
        if (data_size <= 0) return 0;
        
        // Calculate total number of glyphs in the file
        int total_glyphs = data_size / bytes_per_glyph;
        
        // Return total glyphs + 32 (to include the ASCII control characters)
        // This represents the total character range from 0-255
        return total_glyphs + 32;
    }
    
    public int get_bytes_per_glyph() {
        // Calculate bytes required for storing a glyph
        switch (font_format) {
            case 1: // UF1
                return 8; // 8 bytes per 8x8 glyph (1 bit per pixel)
            case 2: // UF2: 16x16 (4 tiles)
                return 32; // 32 bytes per 16x16 glyph (1 bit per pixel)
            case 3: // UF3: 24x24 (9 tiles)
                return 72; // 72 bytes per 24x24 glyph (1 bit per pixel)
            default:
                return 32; // Default to UF2 format
        }
    }

    // Draw glyph without checking for < 32
    public void draw_glyph_at_position(Cairo.Context cr, int offset, 
                                      int x_offset, int y_offset, 
                                      int scale, uint8 actual_width) {
        // Make sure we're not trying to access data before the start of the file
        if (offset < HEADER_SIZE) {
            offset = HEADER_SIZE;
        }
        
        switch (font_format) {
            case 1:
                draw_uf1_glyph(cr, offset, x_offset, y_offset, 
                                  scale, actual_width);
                break;
            case 2:
                draw_uf2_glyph(cr, offset, x_offset, y_offset, 
                              scale, actual_width);
                break;
            case 3:
                draw_uf3_glyph(cr, offset, x_offset, y_offset, 
                              scale, actual_width);
                break;
            default:
                draw_uf2_glyph(cr, offset, x_offset, y_offset, 
                              scale, actual_width);
                break;
        }
    }
    
    private void draw_uf1_glyph(Cairo.Context cr, int offset, 
                               int x_offset, int y_offset, 
                               int scale, uint8 actual_width) {
        // UF1 is simple: just one 8x8 tile
        draw_tile(cr, offset, x_offset, y_offset, scale);
    }
    
    private void draw_uf2_glyph(Cairo.Context cr, int offset, 
                               int x_offset, int y_offset, 
                               int scale, uint8 actual_width) {
        // Coordinates for each tile relative to glyph origin
        int[,] tile_coords = {
            {0, 0},   // Tile 0 (top-left)
            {0, 8},   // Tile 1 (top-right)
            {8, 0},   // Tile 2 (bottom-left)
            {8, 8}    // Tile 3 (bottom-right)
        };
        
        // Each 8x8 tile requires 8 bytes (1 bit per pixel)
        int bytes_per_tile = 8;
        
        // Draw each tile in the correct order
        foreach (int tile_idx in DRAWING_ORDER_UF2) {
            int tile_x = tile_coords[tile_idx, 0] + x_offset;
            int tile_y = tile_coords[tile_idx, 1] + y_offset;
            
            // Calculate offset for this tile in the font data
            int tile_offset = offset + (tile_idx * bytes_per_tile);
            
            // Draw the 8x8 tile
            draw_tile(cr, tile_offset, tile_x, tile_y, scale);
        }
    }
    
    private void draw_uf3_glyph(Cairo.Context cr, int offset, 
                               int x_offset, int y_offset, 
                               int scale, uint8 actual_width) {
        // Coordinates for each tile relative to glyph origin
        int[,] tile_coords = {
            {0, 0},    // Tile 0 (top-left)
            {8, 0},    // Tile 1 (top-middle)
            {16, 0},   // Tile 2 (top-right)
            {0, 8},    // Tile 3 (middle-left)
            {8, 8},    // Tile 4 (middle-middle)
            {16, 8},   // Tile 5 (middle-right)
            {0, 16},   // Tile 6 (bottom-left)
            {8, 16},   // Tile 7 (bottom-middle)
            {16, 16}   // Tile 8 (bottom-right)
        };
        
        // Each 8x8 tile requires 8 bytes (1 bit per pixel)
        int bytes_per_tile = 8;
        
        // Draw each tile in the specified order
        foreach (int tile_idx in DRAWING_ORDER_UF3) {
            int tile_x = tile_coords[tile_idx, 0] + x_offset;
            int tile_y = tile_coords[tile_idx, 1] + y_offset;
            
            // Calculate offset for this tile in the font data
            int tile_offset = offset + (tile_idx * bytes_per_tile);
            
            // Draw the 8x8 tile
            draw_tile(cr, tile_offset, tile_x, tile_y, scale);
        }
    }
    
    private void draw_tile(Cairo.Context cr, int offset, 
                          int tile_x, int tile_y, int scale) {
        // Each byte represents 8 pixels in a row
        for (int y = 0; y < TILE_SIZE; y++) {
            // Check if we're still within the font data
            if (offset + y >= font_data.length) return;
            
            uint8 row_data = font_data[offset + y];
            
            // Process each bit (pixel) in the byte
            for (int x = 0; x < TILE_SIZE; x++) {
                // Check if the bit is set (MSB first)
                if ((row_data & (1 << (7 - x))) != 0) {
                    // Draw a filled pixel (scaled) - use integer coords for crisp rendering
                    int px = (tile_x + x) * scale;
                    int py = (tile_y + y) * scale;
                    cr.rectangle(
                        px, 
                        py, 
                        scale, 
                        scale
                    );
                }
            }
        }
        cr.fill();
    }
}