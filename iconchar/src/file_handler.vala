// Class to handle CHR and ICN file operations
public class FileHandler {
    private IconcharData char_data;
    private IconcharView viewer;
    
    public FileHandler(IconcharData data, IconcharView view) {
        char_data = data;
        viewer = view;
    }
    
    // Load from ICN (monochrome, 1-bit per pixel format)
    public bool load_from_mono_file(string path) {
        try {
            // Open the file for reading
            var file = File.new_for_path(path);
            var dis = new DataInputStream(file.read());
            
            // Update the file name
            char_data.filename = file.get_basename();
            print("Loading file: %s\n", char_data.filename);

            // Parse dimensions from filename
            bool dimensions_changed = char_data.parse_dimensions_from_filename();
            print("Dimensions after parsing filename: %dx%d tiles\n", 
                  char_data.grid_width, char_data.grid_height);

            // If dimensions changed, resize the grid
            if (dimensions_changed) {
                print("Resizing grid for new dimensions\n");
                char_data.resize_grid(char_data.grid_width, char_data.grid_height);
            }
            
            // Calculate file size to determine number of tiles
            var file_info = file.query_info("*", FileQueryInfoFlags.NONE);
            int64 file_size = file_info.get_size();
            
            // Each 8x8 tile takes 8 bytes in ICN format
            int num_tiles = (int)(file_size / 8);
            print("Loading ICN file with %d tiles\n", num_tiles);
            
            // If dimensions from filename don't match file size, adjust automatically
            int tiles_needed = (int)Math.ceil((double)num_tiles / char_data.grid_width);
            if (tiles_needed > char_data.grid_height) {
                // File is larger than dimensions specified in filename
                print("File contains more tiles than specified in filename. Adjusting height to %d\n", tiles_needed);
                char_data.grid_height = tiles_needed;
                dimensions_changed = true;
            }
            
            // If we need to resize the grid from dimensions in the filename
            if (dimensions_changed) {
                char_data.resize_grid(char_data.grid_width, char_data.grid_height);

                print("Dimensions changed to %dx%d from filename\n", char_data.grid_width, char_data.grid_height);
                char_data.resize_grid(char_data.grid_width, char_data.grid_height);
                // Explicitly force a view update
                viewer.queue_draw();
            }
            
            // Clear existing data
            char_data.clear_grid();
            
            // Determine grid dimensions
            int grid_width = char_data.grid_width;
            int grid_height = char_data.grid_height;
            
            // Load tiles up to the maximum we can display
            int max_tiles = grid_width * grid_height;
            int tiles_to_load = int.min(num_tiles, max_tiles);
            
            // Process each tile
            for (int tile_idx = 0; tile_idx < tiles_to_load; tile_idx++) {
                // Calculate the grid position for this tile
                int grid_x = tile_idx % grid_width;
                int grid_y = tile_idx / grid_width;
                
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
                        
                        // Calculate pixel position
                        int pixel_x = grid_x * 8 + col;
                        int pixel_y = grid_y * 8 + row;
                        
                        // Set the pixel
                        char_data.set_pixel(pixel_x, pixel_y, color_val);
                    }
                }
            }
            
            // Trigger a redraw
            char_data.data_changed();
            
            // Set the file as monochrome
            char_data.is_monochrome = true;
            
            dis.close();
            return true;
        } catch (Error e) {
            print("Error loading ICN file: %s\n", e.message);
            return false;
        }
    }
    
    public bool load_from_file(string path) {
        try {
            // Open the file for reading
            var file = File.new_for_path(path);
            var dis = new DataInputStream(file.read());
            
            // Update the file name
            char_data.filename = file.get_basename();
            print("Loading file: %s\n", char_data.filename);

            // Parse dimensions from filename
            bool dimensions_changed = char_data.parse_dimensions_from_filename();
            print("Dimensions after parsing filename: %dx%d tiles\n", 
                  char_data.grid_width, char_data.grid_height);

            // If dimensions changed, resize the grid
            if (dimensions_changed) {
                print("Resizing grid for new dimensions\n");
                char_data.resize_grid(char_data.grid_width, char_data.grid_height);
            }
            
            // Calculate file size to determine number of tiles
            var file_info = file.query_info("*", FileQueryInfoFlags.NONE);
            int64 file_size = file_info.get_size();
            
            // Each 8x8 tile takes 16 bytes (8 bytes channel 1 + 8 bytes channel 2)
            int num_tiles = (int)(file_size / 16);
            print("Loading CHR file with %d tiles\n", num_tiles);
            
            // If dimensions from filename don't match file size, adjust automatically
            int tiles_needed = (int)Math.ceil((double)num_tiles / char_data.grid_width);
            if (tiles_needed > char_data.grid_height) {
                // File is larger than dimensions specified in filename
                print("File contains more tiles than specified in filename. Adjusting height to %d\n", tiles_needed);
                char_data.grid_height = tiles_needed;
                dimensions_changed = true;
            }
            
            // If we need to resize the grid from dimensions in the filename
            if (dimensions_changed) {
                char_data.resize_grid(char_data.grid_width, char_data.grid_height);
            }
            
            // Clear existing data
            char_data.clear_grid();
            
            // Determine grid dimensions
            int grid_width = char_data.grid_width;
            int grid_height = char_data.grid_height;
            
            // Load tiles up to the maximum we can display
            int max_tiles = grid_width * grid_height;
            int tiles_to_load = int.min(num_tiles, max_tiles);
            
            // Process each tile
            for (int tile_idx = 0; tile_idx < tiles_to_load; tile_idx++) {
                // Calculate the grid position for this tile
                int grid_x = tile_idx % grid_width;
                int grid_y = tile_idx / grid_width;
                
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
                        
                        // Calculate pixel position
                        int pixel_x = grid_x * 8 + col;
                        int pixel_y = grid_y * 8 + row;
                        
                        // Set the pixel
                        char_data.set_pixel(pixel_x, pixel_y, color_val);
                    }
                }
            }
            
            // Trigger a redraw
            char_data.data_changed();
            
            // Set the file as not monochrome
            char_data.is_monochrome = false;
            
            dis.close();
            return true;
        } catch (Error e) {
            print("Error loading CHR file: %s\n", e.message);
            return false;
        }
    }
}