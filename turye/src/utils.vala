using Gtk;

public class FontMakerUtils {
    /**
     * Generate a BDF font file from the application's font data
     */
    public static void generate_bdf_file(string filepath, FontMakerApp app) {
        try {
            // Make sure the path ends with .bdf extension
            string bdf_path = filepath;
            if (!bdf_path.has_suffix(".bdf")) {
                if (bdf_path.has_suffix(".ttf")) {
                    bdf_path = bdf_path.substring(0, bdf_path.length - 4) + ".bdf";
                } else {
                    bdf_path = bdf_path + ".bdf";
                }
            }
            
            print("Generating BDF font file: %s\n", bdf_path);
            
            // Open file for writing
            var file = File.new_for_path(bdf_path);
            var os = new DataOutputStream(file.replace(null, false, FileCreateFlags.NONE));
            
            // Font metrics - actually using them now
            int ascent = app.ascender_height + app.x_height;
            int descent = app.descender_height;
            
            // === Write BDF header ===
            os.put_string("STARTFONT 2.1\n");
            os.put_string("FONT -FontMaker-PixelFont-Medium-R-Normal--16-160-75-75-M-160-ISO8859-1\n");
            os.put_string("SIZE 16 75 75\n");
            // Use ascent and descent in the FONTBOUNDINGBOX
            os.put_string("FONTBOUNDINGBOX 16 %d 0 -%d\n".printf(ascent + descent, descent));
            
            // Font properties
            os.put_string("STARTPROPERTIES 14\n");
            // Use ascent and descent in the font properties
            os.put_string("FONT_ASCENT %d\n".printf(ascent));
            os.put_string("FONT_DESCENT %d\n".printf(descent));
            os.put_string("PIXEL_SIZE 16\n");
            os.put_string("POINT_SIZE 160\n");
            os.put_string("RESOLUTION_X 75\n");
            os.put_string("RESOLUTION_Y 75\n");
            os.put_string("SPACING \"M\"\n");
            os.put_string("AVERAGE_WIDTH 160\n");
            os.put_string("CHARSET_REGISTRY \"ISO8859\"\n");
            os.put_string("CHARSET_ENCODING \"1\"\n");
            os.put_string("WEIGHT 10\n");
            os.put_string("X_HEIGHT %d\n".printf(app.x_height));
            os.put_string("QUAD_WIDTH 16\n");
            os.put_string("DEFAULT_CHAR 32\n");
            os.put_string("ENDPROPERTIES\n");
            
            // Character count (all defined characters)
            int char_count = 0;
            for (int i = 0; i < 256; i++) {
                // Check if this character has any pixels drawn
                bool has_pixels = false;
                for (int y = 0; y < 16 && !has_pixels; y++) {
                    if (app.character_data[i, y] > 0) {
                        has_pixels = true;
                        char_count++;
                    }
                }
            }
            
            os.put_string("CHARS %d\n".printf(char_count));
            
            // Write each character definition (only for those with pixels)
            for (int i = 0; i < 256; i++) {
                // Check if this character has any pixels
                bool has_pixels = false;
                for (int y = 0; y < 16 && !has_pixels; y++) {
                    if (app.character_data[i, y] > 0) {
                        has_pixels = true;
                    }
                }
                
                // Only export characters with pixels
                if (has_pixels) {
                    write_character_bdf(os, i, app, ascent, descent);
                }
            }
            
            // End of font
            os.put_string("ENDFONT\n");
            
            // Close the file
            os.close();
            
            show_success_dialog((Window)app.active_window, 
                               "BDF font successfully saved to: %s".printf(bdf_path));
            
        } catch (Error e) {
            print("Error generating BDF file: %s\n", e.message);
            show_error_dialog((Window)app.active_window, 
                             "Error generating BDF file: %s".printf(e.message));
        }
    }
    
    /**
     * Write a single character definition in BDF format
     */
    private static void write_character_bdf(DataOutputStream os, int char_code, FontMakerApp app, int ascent, int descent) throws Error {
        // Start character definition
        os.put_string("STARTCHAR U+%04X\n".printf(char_code));
        
        // Character encoding
        os.put_string("ENCODING %d\n".printf(char_code));
        
        // Use the character-specific right spacing for width
        int char_width = app.character_right_spacing[char_code];
        
        // Spacing - use app's kerning value plus character-specific spacing
        os.put_string("SWIDTH %d 0\n".printf(1000 + app.kerning * 100));
        os.put_string("DWIDTH %d 0\n".printf(char_width + app.kerning));
        
        // Use character-specific baseline for y-offset calculation
        // Increased offset from 3px to 5px to fix vertical alignment
        int baseline = app.character_baseline[char_code] + 1; // Add 1px offest for export
        
        // In BDF, the baseline is at Y=0, with positive Y values above baseline
        // and negative Y values below baseline
        // Need to calculate how many pixels from our character are below the baseline
        int pixels_below_baseline = 16 - baseline;
        
        // The y-offset is negative for pixels below the baseline
        int y_offset = -pixels_below_baseline;
        
        // Find the leftmost column that has any pixels
        int leftmost_col = char_width; // Initialize to max possible value
        bool has_pixels = false;
        
        for (int row = 0; row < 16; row++) {
            uint16 row_data = app.character_data[char_code, row];
            
            for (int col = 0; col < char_width; col++) {
                if ((row_data & (1 << (15 - col))) > 0) {
                    if (col < leftmost_col) {
                        leftmost_col = col;
                    }
                    has_pixels = true;
                    break; // Found the leftmost pixel in this row, move to next row
                }
            }
        }
        
        // If no pixels are found, use default values
        if (!has_pixels) {
            leftmost_col = 0;
        }
        
        // Calculate the actual width of the character (from leftmost pixel to right spacing)
        int actual_width = char_width - leftmost_col;
        
        // Ensure actual_width is at least 1 (even for empty characters)
        if (actual_width < 1) actual_width = 1;
        
        // The x-offset is the position of the leftmost pixel
        int x_offset = leftmost_col;
        
        // Bounding box using the calculated width and offsets
        os.put_string("BBX %d %d %d %d\n".printf(actual_width, 16, x_offset, y_offset));
        
        // Bitmap data
        os.put_string("BITMAP\n");
        
        // Write 16 rows of bitmap data in hex format with appropriate extraction
        for (int row = 0; row < 16; row++) {
            uint16 row_data = app.character_data[char_code, row];
            
            // Extract bits from leftmost_col to char_width - 1
            uint16 extracted_data = 0;
            
            for (int col = leftmost_col; col < char_width; col++) {
                if ((row_data & (1 << (15 - col))) > 0) {
                    // Set the corresponding bit in the extracted data
                    // Adjust the bit position to be at the MSB
                    extracted_data |= (1 << (15 - (col - leftmost_col)));
                }
            }
            
            os.put_string("%04X\n".printf(extracted_data));
        }
        
        // End character definition
        os.put_string("ENDCHAR\n");
    }
    
    /**
     * Display a success dialog
     */
    public static void show_success_dialog(Window parent, string message) {
        var dialog = new AlertDialog(message);
        dialog.set_modal(true);
        dialog.set_buttons(new string[] { "OK" });
        dialog.show(parent);
    }
    
    /**
     * Display an error dialog
     */
    public static void show_error_dialog(Window parent, string message) {
        var dialog = new AlertDialog(message);
        dialog.set_modal(true);
        dialog.set_buttons(new string[] { "OK" });
        dialog.set_default_button(0);
        dialog.show(parent);
    }
    
    /**
     * Display an information dialog
     */
    public static void show_info_dialog(Window parent, string message) {
        var dialog = new AlertDialog(message);
        dialog.set_modal(true);
        dialog.set_buttons(new string[] { "OK" });
        dialog.show(parent);
    }
}