// Class to handle CHR, ICN, and NMT file operations
public class VasuFileHandler {
    private VasuData chr_data;
    private VasuEditorView editor_view;
    private VasuPreviewView preview_view;
    
    public VasuFileHandler(VasuData data, VasuEditorView editor, VasuPreviewView preview) {
        chr_data = data;
        editor_view = editor;
        preview_view = preview;
    }
    
    public bool save_to_file(string path) {
        try {
            // Create a file for writing
            var file = File.new_for_path(path);
            var dos = new DataOutputStream(file.replace(
                null, false, FileCreateFlags.REPLACE_DESTINATION
            ));
            
            // CHR format structure:
            // - Each 8x8 tile uses 16 bytes (128 bits)
            // - First 8 bytes (64 bits) represent the first channel (bit 0 of each pixel)
            // - Next 8 bytes (64 bits) represent the second channel (bit 1 of each pixel)
            // - Each byte represents one row (8 pixels) of a channel
            
            // Loop through all tiles in the editor (16x16 grid)
            for (int tile_y = 0; tile_y < 16; tile_y++) {
                for (int tile_x = 0; tile_x < 16; tile_x++) {
                    // Prepare arrays for both channels
                    uint8[] channel1 = new uint8[8]; // bit 0
                    uint8[] channel2 = new uint8[8]; // bit 1
                    
                    // Process each row in the tile
                    for (int row = 0; row < 8; row++) {
                        channel1[row] = 0;
                        channel2[row] = 0;
                        
                        // Process each pixel in the row
                        for (int col = 0; col < 8; col++) {
                            // Calculate pixel position in the editor grid
                            int pixel_x = tile_x * 8 + col;
                            int pixel_y = tile_y * 8 + row;
                            
                            // Get the pixel color (0-3) from the appropriate source
                            int pixel_color;
                            if (tile_x == editor_view.selected_tile_x && tile_y == editor_view.selected_tile_y) {
                                // For the currently selected tile, use CHR data directly
                                pixel_color = chr_data.get_pixel(col, row);
                            } else {
                                // For other tiles, use the editor grid
                                pixel_color = editor_view.get_pixel(pixel_x, pixel_y);
                            }
                            
                            // Extract individual bits (channels)
                            bool bit0 = (pixel_color & 0x01) != 0; // First channel
                            bool bit1 = (pixel_color & 0x02) != 0; // Second channel
                            
                            // Set the appropriate bit in each channel
                            if (bit0) {
                                channel1[row] |= (uint8)(1 << (7 - col));
                            }
                            
                            if (bit1) {
                                channel2[row] |= (uint8)(1 << (7 - col));
                            }
                        }
                    }
                    
                    // Write the data in the correct order:
                    // First all 8 bytes of channel 1, then all 8 bytes of channel 2
                    
                    // Write channel 1 (8 bytes)
                    for (int row = 0; row < 8; row++) {
                        dos.put_byte(channel1[row]);
                    }
                    
                    // Write channel 2 (8 bytes)
                    for (int row = 0; row < 8; row++) {
                        dos.put_byte(channel2[row]);
                    }
                }
            }
            
            dos.close();
            
            // Also save the NMT file if preview has data
            if (preview_view != null) {
                save_nmt_file(path);
            }
            
            return true;
        } catch (Error e) {
            print("Error saving CHR file: %s\n", e.message);
            return false;
        }
    }
    
    // Define a structure to hold temporary tile data during loading
    private class TileData {
        public int[,] pixels;
        
        public TileData() {
            pixels = new int[8, 8];
        }
    }
    
    public bool load_from_file(string path) {
        try {
            // Open the file for reading
            var file = File.new_for_path(path);
            var dis = new DataInputStream(file.read());
            
            // Update the file name
            chr_data.filename = file.get_basename();
            
            // Calculate file size to determine number of tiles
            var file_info = file.query_info("*", FileQueryInfoFlags.NONE);
            int64 file_size = file_info.get_size();
            
            // Each 8x8 tile takes 16 bytes (8 bytes channel 1 + 8 bytes channel 2)
            int num_tiles = (int)(file_size / 16);
            print("Loading CHR file with %d tiles\n", num_tiles);
            
            // Clear existing data
            chr_data.clear_tile();
            editor_view.clear_editor();
            
            // Load tiles up to the maximum we can display (16x16 grid = 256 tiles)
            int max_tiles = 16 * 16;
            int tiles_to_load = int.min(num_tiles, max_tiles);
            
            // To prevent automatic updates during loading, we'll temporarily store tile data
            TileData[,] loaded_tiles = new TileData[16, 16];
            for (int y = 0; y < 16; y++) {
                for (int x = 0; x < 16; x++) {
                    loaded_tiles[x, y] = new TileData();
                }
            }
            
            // Process each tile
            for (int tile_idx = 0; tile_idx < tiles_to_load; tile_idx++) {
                // Calculate the grid position for this tile
                int grid_x = tile_idx % 16;
                int grid_y = tile_idx / 16;
                
                // Read the tile data following the channel structure
                
                // First, read all 8 bytes of channel 1
                uint8[] channel1 = new uint8[8];
                for (int row = 0; row < 8; row++) {
                    channel1[row] = dis.read_byte();
                }
                
                // Then, read all 8 bytes of channel 2
                uint8[] channel2 = new uint8[8];
                for (int row = 0; row < 8; row++) {
                    channel2[row] = dis.read_byte();
                }
                
                // Now combine the channels to get the pixel colors
                for (int row = 0; row < 8; row++) {
                    for (int col = 0; col < 8; col++) {
                        int bit_pos = 7 - col; // Bits are stored from MSB to LSB
                        
                        // Extract the bits from each channel
                        bool bit0 = (channel1[row] & (1 << bit_pos)) != 0;
                        bool bit1 = (channel2[row] & (1 << bit_pos)) != 0;
                        
                        // Combine the bits to get the color value (0-3)
                        int color_val = 0;
                        if (bit0) color_val |= 0x01; // First bit
                        if (bit1) color_val |= 0x02; // Second bit
                        
                        // Store in our temporary structure
                        loaded_tiles[grid_x, grid_y].pixels[col, row] = color_val;
                    }
                }
            }
            
            // Now update the editor and CHR data from our loaded tile data
            
            // First update CHR data with the first tile
            TileData first_tile = loaded_tiles[0, 0];
            for (int row = 0; row < 8; row++) {
                for (int col = 0; col < 8; col++) {
                    int color_val = first_tile.pixels[col, row];
                    chr_data.set_pixel(col, row, color_val);
                }
            }
            
            // Now update the editor grid
            for (int grid_y = 0; grid_y < 16; grid_y++) {
                for (int grid_x = 0; grid_x < 16; grid_x++) {
                    TileData tile = loaded_tiles[grid_x, grid_y];
                    for (int row = 0; row < 8; row++) {
                        for (int col = 0; col < 8; col++) {
                            int pixel_x = grid_x * 8 + col;
                            int pixel_y = grid_y * 8 + row;
                            int color_val = tile.pixels[col, row];
                            
                            // Update editor pixels directly to avoid triggering unnecessary signals
                            editor_view.set_pixel(pixel_x, pixel_y, color_val);
                        }
                    }
                }
            }
            
            // Trigger a redraw
            editor_view.queue_draw();
            chr_data.tile_changed(); // Signal that the tile data has changed
            
            dis.close();
            
            // Try to load corresponding NMT file if it exists
            load_nmt_file(path);
            
            return true;
        } catch (Error e) {
            print("Error loading CHR file: %s\n", e.message);
            return false;
        }
    }
    
    // Save as ICN (monochrome, 1-bit per pixel format)
    public bool save_to_mono_file(string path) {
        try {
            // Create a file for writing
            var file = File.new_for_path(path);
            var dos = new DataOutputStream(file.replace(
                null, false, FileCreateFlags.REPLACE_DESTINATION
            ));
            
            // ICN format structure:
            // - Each 8x8 tile uses 8 bytes (64 bits)
            // - Each byte represents one row (8 pixels)
            // - Bit 1 represents color3, Bit 0 represents color0
            
            // Loop through all tiles in the editor (16x16 grid)
            for (int tile_y = 0; tile_y < 16; tile_y++) {
                for (int tile_x = 0; tile_x < 16; tile_x++) {
                    // Prepare array for mono data
                    uint8[] mono_data = new uint8[8];
                    
                    // Process each row in the tile
                    for (int row = 0; row < 8; row++) {
                        mono_data[row] = 0;
                        
                        // Process each pixel in the row
                        for (int col = 0; col < 8; col++) {
                            // Calculate pixel position in the editor grid
                            int pixel_x = tile_x * 8 + col;
                            int pixel_y = tile_y * 8 + row;
                            
                            // Get the pixel color (0-3) from the appropriate source
                            int pixel_color;
                            if (tile_x == editor_view.selected_tile_x && tile_y == editor_view.selected_tile_y) {
                                // For the currently selected tile, use CHR data directly
                                pixel_color = chr_data.get_pixel(col, row);
                            } else {
                                // For other tiles, use the editor grid
                                pixel_color = editor_view.get_pixel(pixel_x, pixel_y);
                            }
                            
                            // Convert to mono:
                            // In ICN format, we consider color != 0 as set (1) and color == 0 as unset (0)
                            bool bit_set = pixel_color != 0;
                            
                            // Set the appropriate bit
                            if (bit_set) {
                                mono_data[row] |= (uint8)(1 << (7 - col));
                            }
                        }
                    }
                    
                    // Write the data (8 bytes per tile)
                    for (int row = 0; row < 8; row++) {
                        dos.put_byte(mono_data[row]);
                    }
                }
            }
            
            dos.close();
            
            // Also save the NMT file if preview has data
            if (preview_view != null) {
                save_nmt_file(path);
            }
            
            return true;
        } catch (Error e) {
            print("Error saving ICN file: %s\n", e.message);
            return false;
        }
    }
    
    // Load from ICN (monochrome, 1-bit per pixel format)
    public bool load_from_mono_file(string path) {
        try {
            // Open the file for reading
            var file = File.new_for_path(path);
            var dis = new DataInputStream(file.read());
            
            // Update the file name
            chr_data.filename = file.get_basename();
            
            // Calculate file size to determine number of tiles
            var file_info = file.query_info("*", FileQueryInfoFlags.NONE);
            int64 file_size = file_info.get_size();
            
            // Each 8x8 tile takes 8 bytes in ICN format
            int num_tiles = (int)(file_size / 8);
            print("Loading ICN file with %d tiles\n", num_tiles);
            
            // Clear existing data
            chr_data.clear_tile();
            editor_view.clear_editor();
            
            // Load tiles up to the maximum we can display (16x16 grid = 256 tiles)
            int max_tiles = 16 * 16;
            int tiles_to_load = int.min(num_tiles, max_tiles);
            
            // To prevent automatic updates during loading, we'll temporarily store tile data
            TileData[,] loaded_tiles = new TileData[16, 16];
            for (int y = 0; y < 16; y++) {
                for (int x = 0; x < 16; x++) {
                    loaded_tiles[x, y] = new TileData();
                }
            }
            
            // Process each tile
            for (int tile_idx = 0; tile_idx < tiles_to_load; tile_idx++) {
                // Calculate the grid position for this tile
                int grid_x = tile_idx % 16;
                int grid_y = tile_idx / 16;
                
                // Read the tile data (8 bytes per tile)
                uint8[] mono_data = new uint8[8];
                for (int row = 0; row < 8; row++) {
                    mono_data[row] = dis.read_byte();
                }
                
                // Convert mono data to pixel colors
                for (int row = 0; row < 8; row++) {
                    for (int col = 0; col < 8; col++) {
                        int bit_pos = 7 - col; // Bits are stored from MSB to LSB
                        
                        // Extract the bit
                        bool bit_set = (mono_data[row] & (1 << bit_pos)) != 0;
                        
                        // Convert to color (0 or 3)
                        int color_val = bit_set ? 3 : 0;
                        
                        // Store in our temporary structure
                        loaded_tiles[grid_x, grid_y].pixels[col, row] = color_val;
                    }
                }
            }
            
            // Now update the editor and CHR data from our loaded tile data
            // First update CHR data with the first tile
            TileData first_tile = loaded_tiles[0, 0];
            for (int row = 0; row < 8; row++) {
                for (int col = 0; col < 8; col++) {
                    int color_val = first_tile.pixels[col, row];
                    chr_data.set_pixel(col, row, color_val);
                }
            }
            
            // Now update the editor grid
            for (int grid_y = 0; grid_y < 16; grid_y++) {
                for (int grid_x = 0; grid_x < 16; grid_x++) {
                    TileData tile = loaded_tiles[grid_x, grid_y];
                    for (int row = 0; row < 8; row++) {
                        for (int col = 0; col < 8; col++) {
                            int pixel_x = grid_x * 8 + col;
                            int pixel_y = grid_y * 8 + row;
                            int color_val = tile.pixels[col, row];
                            
                            // Update editor pixels directly to avoid triggering unnecessary signals
                            editor_view.set_pixel(pixel_x, pixel_y, color_val);
                        }
                    }
                }
            }
            
            // Trigger a redraw
            editor_view.queue_draw();
            chr_data.tile_changed(); // Signal that the tile data has changed
            
            dis.close();
            
            // Try to load corresponding NMT file if it exists
            load_nmt_file(path);
            
            return true;
        } catch (Error e) {
            print("Error loading ICN file: %s\n", e.message);
            return false;
        }
    }
    
    private bool save_nmt_file(string file_path) {
        try {
            // Create NMT path by adding .nmt to the original file path
            string nmt_path = file_path + ".nmt";
            
            // Check if there's anything to save
            bool has_contents = false;
            for (int y = 0; y < VasuPreviewView.GRID_HEIGHT; y++) {
                for (int x = 0; x < VasuPreviewView.GRID_WIDTH; x++) {
                    if (preview_view.get_placed_tile(x, y) != null) {
                        has_contents = true;
                        break;
                    }
                }
                if (has_contents) break;
            }
            
            // Don't save empty NMT files
            if (!has_contents) {
                print("Preview is empty, not saving NMT file\n");
                return false;
            }
            
            var file = File.new_for_path(nmt_path);
            var dos = new DataOutputStream(file.replace(
                null, false, FileCreateFlags.REPLACE_DESTINATION
            ));
            
            // NMT format:
            // For each placed tile in the preview (16x16 grid)
            // - 3 bytes per tile
            // - First two bytes: CHR byte address (tile_index * 16)
            // - Third byte: pattern transformation byte
            
            // Loop through preview grid
            for (int grid_y = 0; grid_y < VasuPreviewView.GRID_HEIGHT; grid_y++) {
                for (int grid_x = 0; grid_x < VasuPreviewView.GRID_WIDTH; grid_x++) {
                    // Get the tile at this position
                    var tile = preview_view.get_placed_tile(grid_x, grid_y);
                    
                    if (tile != null) {
                        // Calculate tile index (source_tile_y * 16 + source_tile_x)
                        uint16 tile_index = (uint16)(tile.source_tile_y * 16 + tile.source_tile_x);
                        
                        // Calculate CHR byte address (tile_index * 16)
                        uint16 chr_address = tile_index * 16;
                        
                        // Calculate pattern byte:
                        // - Bits 0-1 (0-3): Pattern column
                        // - Bits 2-3 (0-3): Pattern row
                        // - Bit 6: Vertical mirror
                        // - Bit 7: Horizontal mirror
                        uint8 pattern_byte = 0;
                        
                        // Set pattern column (bits 0-1)
                        pattern_byte |= (uint8)(tile.pattern_col & 0x03);
                        
                        // Set pattern row (bits 2-3)
                        pattern_byte |= (uint8)((tile.pattern_row & 0x03) << 2);
                        
                        // Set mirror flags
                        if (tile.mirror_vertical) {
                            pattern_byte |= 0x40; // Bit 6
                        }
                        if (tile.mirror_horizontal) {
                            pattern_byte |= 0x80; // Bit 7
                        }
                        
                        print("Saving tile at %d,%d: source=%d,%d (CHR addr 0x%04x) pattern=%d mirror_h=%s mirror_v=%s\n", 
                              grid_x, grid_y, tile.source_tile_x, tile.source_tile_y, chr_address,
                              tile.pattern_row * 4 + tile.pattern_col,
                              tile.mirror_horizontal.to_string(), tile.mirror_vertical.to_string());
                        
                        // Write the 3 bytes for this tile - note the order is low byte, high byte
                        dos.put_byte((uint8)(chr_address & 0xFF));       // Low byte of address
                        dos.put_byte((uint8)((chr_address >> 8) & 0xFF)); // High byte of address
                        dos.put_byte(pattern_byte);                      // Pattern byte
                    } else {
                        // Write 3 zeros for empty tile (per convention)
                        dos.put_byte(0x00);
                        dos.put_byte(0x00);
                        dos.put_byte(0x00);
                    }
                }
            }
            
            dos.close();
            print("Saved NMT file: %s\n", nmt_path);
            return true;
        } catch (Error e) {
            print("Error saving NMT file: %s\n", e.message);
            return false;
        }
    }
    
    private bool load_nmt_file(string file_path) {
        try {
            // Create NMT path by adding .nmt to the original file path
            string nmt_path = file_path + ".nmt";
            
            var file = File.new_for_path(nmt_path);
            
            // Check if the file exists
            if (!file.query_exists()) {
                print("NMT file not found: %s\n", nmt_path);
                return false;
            }
            
            print("Found NMT file: %s\n", nmt_path);
            
            // Clear existing preview
            preview_view.clear_canvas();
            
            var dis = new DataInputStream(file.read());
            
            // Loop through preview grid
            for (int grid_y = 0; grid_y < VasuPreviewView.GRID_HEIGHT; grid_y++) {
                for (int grid_x = 0; grid_x < VasuPreviewView.GRID_WIDTH; grid_x++) {
                    try {
                        // Read 3 bytes for this tile
                        uint8 address_low = dis.read_byte();
                        uint8 address_high = dis.read_byte();
                        uint8 pattern_byte = dis.read_byte();
                        
                        // Check if this is a valid tile (not 0x000000)
                        if (address_low != 0x00 || address_high != 0x00 || pattern_byte != 0x00) {
                            // Calculate the CHR byte address - Note low byte first, high byte second
                            uint16 chr_address = (uint16)((address_low << 8) | address_high);
                            
                            // Each tile in the CHR file takes 16 bytes, so divide by 16 to get the tile index
                            uint16 tile_index = chr_address / 16;
                            
                            // Calculate source tile coordinates (in our 16×16 grid)
                            int source_tile_x = tile_index % 16;
                            int source_tile_y = tile_index / 16;
                            
                            // Skip if the source coordinates are outside our 16×16 grid
                            if (source_tile_x >= 16 || source_tile_y >= 16) {
                                print("Warning: NMT entry at %d,%d references tile outside grid: %d,%d (CHR addr 0x%04x)\n",
                                      grid_x, grid_y, source_tile_x, source_tile_y, chr_address);
                                continue;
                            }
                            
                            // Extract pattern information
                            int pattern_col = pattern_byte & 0x03;
                            int pattern_row = (pattern_byte >> 2) & 0x03;
                            int pattern_tile = pattern_row * 4 + pattern_col;

                            // Extract the high nibble to determine mirror settings
                            int mirror_code = pattern_byte >> 4;
                            bool mirror_horizontal = false;
                            bool mirror_vertical = false;

                            if (mirror_code == 9) {
                                // 9x: horizontal mirroring on
                                mirror_horizontal = true;
                            } else if (mirror_code == 10) {
                                // Ax: vertical mirroring on
                                mirror_vertical = true;
                            } else if (mirror_code == 11) {
                                // Bx: both mirrors applied
                                mirror_horizontal = true;
                                mirror_vertical = true;
                            }
                            
                            print("Loading tile at %d,%d: source=%d,%d (CHR addr 0x%04x) pattern=%d mirror_h=%s mirror_v=%s\n", 
                                  grid_x, grid_y, source_tile_x, source_tile_y, chr_address,
                                  pattern_tile, mirror_horizontal.to_string(), mirror_vertical.to_string());
                            
                            // Temporarily set the pattern tile and mirror flags
                            int old_pattern = chr_data.selected_pattern_tile;
                            bool old_h_mirror = chr_data.mirror_horizontal;
                            bool old_v_mirror = chr_data.mirror_vertical;
                            
                            chr_data.selected_pattern_tile = pattern_tile;
                            chr_data.mirror_horizontal = mirror_horizontal;
                            chr_data.mirror_vertical = mirror_vertical;
                            
                            // Place the tile
                            preview_view.place_tile_at_with_source(grid_x, grid_y, source_tile_x, source_tile_y);
                            
                            // Restore original values
                            chr_data.selected_pattern_tile = old_pattern;
                            chr_data.mirror_horizontal = old_h_mirror;
                            chr_data.mirror_vertical = old_v_mirror;
                        }
                    } catch (Error e) {
                        print("Error reading NMT data at %d,%d: %s\n", grid_x, grid_y, e.message);
                        break;
                    }
                }
            }
            
            dis.close();
            preview_view.queue_draw();
            print("Loaded NMT file: %s\n", nmt_path);
            return true;
        } catch (Error e) {
            print("Error loading NMT file: %s\n", e.message);
            return false;
        }
    }
}