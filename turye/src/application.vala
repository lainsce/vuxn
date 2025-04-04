using Gtk;

public class FontMakerApp : Gtk.Application {
    // Font metrics
    public int ascender_height = 4;    // Top 4 rows
    public int x_height = 8;           // Middle 8 rows (rows 4-11)
    public int descender_height = 4;   // Bottom 4 rows

    // Font data storage - using 2D array for the character data
    public uint16[,] character_data;
    public int current_char = 65; // 'A'
    public int kerning = 0;

    // Per-character right spacing (where the red line is positioned)
    public int[] character_right_spacing;
    // Per-character baseline position (where the blue line is positioned)
    public int[] character_baseline;

    // Display mode for the editor (0 = simple, 1 = enhanced display)
    public int display_mode = 1;

    // Show center guides
    public bool show_guides = true;

    // Font format preference (true = TTF, false = BDF)
    public bool use_ttf = false;

    public FontMakerApp() {
        Object(application_id: "com.example.fontmaker", flags: ApplicationFlags.FLAGS_NONE);

        // Initialize 2D array for character data (0x00 to 0xFF)
        character_data = new uint16[256, 16];

        // Initialize font data for all characters
        for (int i = 0; i < 256; i++) {
            for (int y = 0; y < 16; y++) {
                character_data[i, y] = 0; // All pixels off
            }
        }
        
        // Initialize arrays for spacing and baseline
        character_right_spacing = new int[256];
        character_baseline = new int[256];

        // Set default values
        for (int i = 0; i < 256; i++) {
            character_right_spacing[i] = 9; // Default at column 9
            character_baseline[i] = 12;     // Default at row 12
        }
    }

    protected override void activate() {
        // Create main window
        var window = new FontMakerWindow(this);
        window.present();
    }

    public uint get_pixel_value(int char_code, int x, int y) {
        // Check single bit (always binary for the actual font data)
        return (character_data[char_code, y] & (1 << (15 - x))) > 0 ? 1 : 0;
    }

    public void toggle_pixel(int char_code, int x, int y) {
        // Toggle a single bit in the bitmap
        character_data[char_code, y] ^= (1 << (15 - x));
    }

    /**
     * Get bitmap data for a character as a list of 16-bit rows
     */
    public uint16[] get_character_bitmap(int char_code) {
        uint16[] bitmap = new uint16[16];

        if (char_code >= 0 && char_code < 128) {
            for (int i = 0; i < 16; i++) {
                bitmap[i] = character_data[char_code, i];
            }
        }

        return bitmap;
    }

    /**
     * Clear a character (set all pixels to 0)
     */
    public void clear_character(int char_code) {
        if (char_code < 0 || char_code > 127) {
            return;
        }

        for (int i = 0; i < 16; i++) {
            character_data[char_code, i] = 0;
        }
    }

    /**
     * Export the entire font data to a binary format
     */
    public uint8[] export_binary() {
        // Format: 16 rows per character, 2 bytes per row, 96 characters
        uint8[] data = new uint8[16 * 2 * 96];

        int index = 0;
        for (int c = 32; c < 128; c++) {
            for (int row = 0; row < 16; row++) {
                uint16 row_data = character_data[c, row];

                // Store row data in big-endian format
                data[index++] = (uint8)(row_data >> 8);
                data[index++] = (uint8)(row_data & 0xFF);
            }
        }

        return data;
    }
    
    /**
     * Get the effective width of a character in pixels based on the rightmost pixel and spacing
     */
    public int get_character_width(int char_code) {
        // Use the right spacing control position as the width
        return character_right_spacing[char_code];
    }

    public static int main(string[] args) {
        return new FontMakerApp().run(args);
    }
}