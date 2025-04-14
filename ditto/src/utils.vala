namespace ImageProcessor {
    // Helper function to apply contrast adjustment
    private double adjust_contrast(double value, double contrast) {
        // Apply contrast adjustment centered around 0.5
        return 0.5 + (value - 0.5) * contrast;
    }

    // Find the closest color in the palette to the given RGB values
    private int find_closest_color_index (uint8[,] palette, double r, double g, double b) {
        int closest_index = 0;
        double min_distance = double.MAX;
        
        for (int i = 0; i < palette.length[0]; i++) {
            double color_b = (double) palette[i, 0];
            double color_g = (double) palette[i, 1];
            double color_r = (double) palette[i, 2];
            
            // Calculate Euclidean distance
            double distance = Math.sqrt (
                Math.pow (r - color_r, 2) +
                Math.pow (g - color_g, 2) +
                Math.pow (b - color_b, 2)
            );
            
            if (distance < min_distance) {
                min_distance = distance;
                closest_index = i;
            }
        }
        
        return closest_index;
    }
    
    // Process an image with Atkinson dithering
    public void process_image (Cairo.ImageSurface input_image, out Cairo.ImageSurface output_image, 
                             bool is_one_bit_mode, int contrast_level, Theme.Manager theme_manager) {
        int width = input_image.get_width();
        int height = input_image.get_height();
        
        // Create a new surface for the processed image
        output_image = new Cairo.ImageSurface(
            Cairo.Format.ARGB32,
            width,
            height
        );
        
        // Get surface data
        unowned uint8[] src_data = (uint8[]) input_image.get_data();
        unowned uint8[] dest_data = (uint8[]) output_image.get_data();
        
        int src_stride = input_image.get_stride();
        int dest_stride = output_image.get_stride();
        
        // Create error diffusion buffers
        double[,] error_r = new double[height, width];
        double[,] error_g = new double[height, width];
        double[,] error_b = new double[height, width];
        
        // Define palette based on theme colors
        uint8[,] palette;
        
        if (is_one_bit_mode) {
            // Get colors from theme manager
            Gdk.RGBA bg_color = { 1.0f, 1.0f, 1.0f };
            Gdk.RGBA fg_color = { 0.0f, 0.0f, 0.0f };
            
            // Black and white palette (B, G, R, A format)
            palette = {
                {
                    (uint8)(fg_color.blue * 255),
                    (uint8)(fg_color.green * 255),
                    (uint8)(fg_color.red * 255),
                    255
                },
                {
                    (uint8)(bg_color.blue * 255),
                    (uint8)(bg_color.green * 255),
                    (uint8)(bg_color.red * 255),
                    255
                }
            };
        } else {
            // Get all four colors from theme manager
            var bg_color = theme_manager.get_color("theme_bg");
            var fg_color = theme_manager.get_color("theme_fg");
            var accent_color = theme_manager.get_color("theme_accent");
            var selection_color = theme_manager.get_color("theme_selection");
            
            // 2-bit palette (4 colors) in B, G, R, A format
            palette = {
                {
                    (uint8)(fg_color.blue * 255),
                    (uint8)(fg_color.green * 255),
                    (uint8)(fg_color.red * 255),
                    255
                },
                {
                    (uint8)(accent_color.blue * 255),
                    (uint8)(accent_color.green * 255),
                    (uint8)(accent_color.red * 255),
                    255
                },
                {
                    (uint8)(selection_color.blue * 255),
                    (uint8)(selection_color.green * 255),
                    (uint8)(selection_color.red * 255),
                    255
                },
                {
                    (uint8)(bg_color.blue * 255),
                    (uint8)(bg_color.green * 255),
                    (uint8)(bg_color.red * 255),
                    255
                }
            };
        }
        
        // Calculate contrast factor from slider value (1-10)
        // Map contrast from 0.5 (low contrast) to 2.5 (high contrast)
        double contrast_factor = 0.5 + (contrast_level - 1) * (2.0 / 9.0);
        
        // Define Atkinson dithering pattern (x,y) offsets for 6 pixels
        int[,] atkinson_pattern = {
            {1, 0}, {2, 0},         // right pixels
            {-1, 1}, {0, 1}, {1, 1}, // next row
            {0, 2}                   // two rows down
        };
        
        // Apply Atkinson dithering
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                int src_offset = y * src_stride + x * 4;
                int dest_offset = y * dest_stride + x * 4;
                
                // Get source pixel values (B, G, R, A) and add error
                double b = (double) src_data[src_offset + 0] + error_b[y, x];
                double g = (double) src_data[src_offset + 1] + error_g[y, x];
                double r = (double) src_data[src_offset + 2] + error_r[y, x];
                double a = (double) src_data[src_offset + 3];
                
                // Apply contrast adjustment
                double r_norm = r / 255.0;
                double g_norm = g / 255.0;
                double b_norm = b / 255.0;
                
                r_norm = adjust_contrast(r_norm, contrast_factor);
                g_norm = adjust_contrast(g_norm, contrast_factor);
                b_norm = adjust_contrast(b_norm, contrast_factor);
                
                // Convert back to 0-255 range
                r = r_norm * 255.0;
                g = g_norm * 255.0;
                b = b_norm * 255.0;
                
                // Clamp values
                b = double.min(255, double.max(0, b));
                g = double.min(255, double.max(0, g));
                r = double.min(255, double.max(0, r));
                
                // Find closest color in palette
                int closest_color_index = find_closest_color_index(palette, r, g, b);
                
                // Set destination pixel
                dest_data[dest_offset + 0] = palette[closest_color_index, 0]; // B
                dest_data[dest_offset + 1] = palette[closest_color_index, 1]; // G
                dest_data[dest_offset + 2] = palette[closest_color_index, 2]; // R
                dest_data[dest_offset + 3] = palette[closest_color_index, 3]; // A
                
                // Calculate quantization error
                double error_r_val = r - palette[closest_color_index, 2];
                double error_g_val = g - palette[closest_color_index, 1];
                double error_b_val = b - palette[closest_color_index, 0];
                
                // Atkinson dithering: distribute 1/8 of the error to 6 surrounding pixels
                // Note that only 3/4 of the error is distributed in total
                double error_factor = 1.0 / 8.0;
                
                // Distribute error according to Atkinson pattern
                for (int i = 0; i < 6; i++) {
                    int nx = x + atkinson_pattern[i, 0];
                    int ny = y + atkinson_pattern[i, 1];
                    
                    if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
                        error_r[ny, nx] += error_r_val * error_factor;
                        error_g[ny, nx] += error_g_val * error_factor;
                        error_b[ny, nx] += error_b_val * error_factor;
                    }
                }
            }
        }
        
        // Mark the new surface as dirty to ensure Cairo knows it's been modified
        output_image.mark_dirty();
    }
}

namespace FileUtils {
    // Calculate the distance between two colors in RGB space
    private double color_distance(uint8 r1, uint8 g1, uint8 b1, uint8 r2, uint8 g2, uint8 b2) {
        return Math.sqrt(
            Math.pow(r1 - r2, 2) + 
            Math.pow(g1 - g2, 2) + 
            Math.pow(b1 - b2, 2)
        );
    }
    
    // Save an image to CHR format
    public bool save_chr_file(string file_path, Cairo.ImageSurface image, 
                              bool is_one_bit_mode, Theme.Manager theme_manager) {
        try {
            int width = image.get_width();
            int height = image.get_height();
            unowned uint8[] src_data = (uint8[]) image.get_data();
            int src_stride = image.get_stride();
            
            // Calculate number of 8x8 tiles needed
            int tiles_width = (width + 7) / 8;  // Round up to nearest 8
            int tiles_height = (height + 7) / 8; // Round up to nearest 8
            int total_tiles = tiles_width * tiles_height;
            
            // Open file for writing
            FileStream file = FileStream.open(file_path, "wb");
            if (file == null) {
                throw new FileError.FAILED("Could not open file for writing");
            }
            
            // Write header (width and height as 16-bit values)
            file.putc((char)(width & 0xFF));
            file.putc((char)((width >> 8) & 0xFF));
            file.putc((char)(height & 0xFF));
            file.putc((char)((height >> 8) & 0xFF));
            
            // Process each 8x8 tile
            for (int tile_y = 0; tile_y < tiles_height; tile_y++) {
                for (int tile_x = 0; tile_x < tiles_width; tile_x++) {
                    // Process a single 8x8 tile
                    uint8[] channel1 = new uint8[8]; // First bit plane (64 bits = 8 bytes)
                    uint8[] channel2 = new uint8[8]; // Second bit plane (64 bits = 8 bytes)
                    
                    // Initialize arrays to 0
                    for (int i = 0; i < 8; i++) {
                        channel1[i] = 0;
                        channel2[i] = 0;
                    }
                    
                    // Process each pixel in the 8x8 tile
                    for (int row = 0; row < 8; row++) {
                        int y = tile_y * 8 + row;
                        
                        // Skip if we're past the actual image height
                        if (y >= height) continue;
                        
                        for (int col = 0; col < 8; col++) {
                            int x = tile_x * 8 + col;
                            
                            // Skip if we're past the actual image width
                            if (x >= width) continue;
                            
                            // Get the pixel value from the image
                            int offset = y * src_stride + x * 4;
                            uint8 pixel_value = get_pixel_value(src_data, offset, is_one_bit_mode);
                            
                            // Set the appropriate bits in channel1 and channel2
                            // The bit pattern is based on the C implementation provided:
                            // ch1 = ((sprite[v] >> h) & 0x1)
                            // ch2 = (((sprite[v + 8] >> h) & 0x1) << 1)
                            
                            // Extract the 2 bits from our pixel value (0-3)
                            bool bit1 = (pixel_value & 0x1) != 0;
                            bool bit2 = (pixel_value & 0x2) != 0;
                            
                            // Set the corresponding bit in the channel arrays
                            // Note: The C code uses 7-h which means the bits are stored from right to left
                            if (bit1) {
                                channel1[row] |= (1 << (7 - col));
                            }
                            
                            if (bit2) {
                                channel2[row] |= (1 << (7 - col));
                            }
                        }
                    }
                    
                    // Write the 16 bytes (128 bits) for this tile
                    // First the 8 bytes for channel1, then 8 bytes for channel2
                    for (int i = 0; i < 8; i++) {
                        file.putc((char)channel1[i]);
                    }
                    
                    for (int i = 0; i < 8; i++) {
                        file.putc((char)channel2[i]);
                    }
                }
            }
            
            return true;
        } catch (Error e) {
            warning("Error saving file: %s", e.message);
            return false;
        }
    }
    
    // Helper function to get the pixel value (0-3) from the image data
    private uint8 get_pixel_value(uint8[] data, int offset, bool is_one_bit_mode) {
        // For processed images, we need to determine the pixel value based on the color
        uint8 b = data[offset + 0];
        uint8 g = data[offset + 1];
        uint8 r = data[offset + 2];
        
        // In our implementation, the pixel value is directly encoded in the image
        // based on the palette used during processing
        
        // We can use a simple approach to determine which of the 4 palette colors is closest
        // This assumes the processed image already contains the closest palette color
        
        // If in 1-bit mode, we map to either 0 or 3 (for better contrast in CHR format)
        if (is_one_bit_mode) {
            // Calculate luminance - if darker than 50%, use 0, otherwise use 3
            double luminance = 0.299 * r + 0.587 * g + 0.114 * b;
            return (luminance < 128) ? 0 : 3;
        } else {
            // For 2-bit mode, we need to map to one of 4 possible values (0-3)
            // Since our processed image already uses the palette colors,
            // we can determine which one it is by color distance
            
            // For simplicity, we'll check which channel is dominant
            // This assumes our palette follows a logical pattern:
            // 0: black/dark, 1: accent color, 2: selection color, 3: background/light
            
            // Determine luminance - simplest way to categorize
            double luminance = 0.299 * r + 0.587 * g + 0.114 * b;
            
            if (luminance < 64) {
                return 0; // Darkest
            } else if (luminance < 128) {
                return 1; // Medium dark
            } else if (luminance < 192) {
                return 2; // Medium light
            } else {
                return 3; // Lightest
            }
        }
    }
}