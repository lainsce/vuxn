// Class to handle CHR and ICN file operations
public class VasuFileHandler {
    private VasuData chr_data;
    private VasuEditorView editor_view;
    
    public VasuFileHandler(VasuData data, VasuEditorView editor) {
        chr_data = data;
        editor_view = editor;
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
                            if (tile_x == 0 && tile_y == 0) {
                                // For the first tile, use the CHR data directly
                                pixel_color = chr_data.get_pixel(col, row);
                            } else {
                                // For other tiles, use the editor grid
                                pixel_color = editor_view.get_pixel(pixel_x, pixel_y);
                            }
                            
                            // Set bits in the appropriate channels based on the color
                            // Color 0 (00): Both channels 0
                            // Color 1 (01): Channel 1 set, Channel 2 unset
                            // Color 2 (10): Channel 1 unset, Channel 2 set
                            // Color 3 (11): Both channels set
                            
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
                            if (tile_x == 0 && tile_y == 0) {
                                // For the first tile, use the CHR data directly
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
            return true;
        } catch (Error e) {
            print("Error loading ICN file: %s\n", e.message);
            return false;
        }
    }
}