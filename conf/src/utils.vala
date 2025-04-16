/*
 * Varvara Theme Configurator
 *
 * Utility functions for working with the binary theme format
 */

namespace App.Utils {
    // Constants
    public const int GRID_UNIT = 8;
    public const int GRID_SIZE = 8;

    // Color values for pattern generation
    public const int COLOR_BG = 0;
    public const int COLOR_FG = 1;
    public const int COLOR_ACCENT = 2;
    public const int COLOR_SELECTION = 3;

    /**
     * Sets a ColorPickerWidget to a specified hex color
     */
    public void set_color_picker(ColorPickerWidget picker, string hex_color) {
        picker.set_from_hex(hex_color);
    }

    /**
     * Gets the hex representation of a color from a ColorPickerWidget
     */
    public string get_color_picker_hex(ColorPickerWidget picker) {
        return picker.get_hex();
    }

    /**
     * Gets a specific digit from a color's hex representation
     * Uses the 3-character hex code directly
     */
    public string get_color_hex_digit(ColorPickerWidget picker, int position) {
        // Get the 3-character hex code
        string hex_code = picker.get_hex_code();
        
        // Make sure the position is valid (0-2)
        if (position >= 0 && position < hex_code.length) {
            return hex_code.substring(position, 1);
        }
        
        // Default fallback
        return "0";
    }

    /**
     * Shows an error dialog
     */
    public void show_error_dialog(string message, Gtk.Window? parent = null) {
        var dialog = new Gtk.AlertDialog(message);
        dialog.set_modal(true);
        dialog.show(parent);
    }

    /**
     * Shows a success dialog
     */
    public void show_success_dialog(string message, Gtk.Window? parent = null) {
        var dialog = new Gtk.AlertDialog(message);
        dialog.set_modal(true);
        dialog.show(parent);
    }

    /**
     * Helper function to convert hex char to int
     */
    private uint8 hex_char_to_int(char c) {
        if (c >= '0' && c <= '9')
            return (uint8)(c - '0');
        else if (c >= 'a' && c <= 'f')
            return (uint8)(c - 'a' + 10);
        else if (c >= 'A' && c <= 'F')
            return (uint8)(c - 'A' + 10);
        return 0;
    }

    /**
     * Helper function to convert int to hex char
     */
    private char int_to_hex_char(uint8 n) {
        if (n < 10)
            return (char)('0' + n);
        else
            return (char)('a' + (n - 10));
    }

    /**
     * Loads the theme file and returns the parsed colors.
     * Now works with binary format.
     */
    public bool load_theme_file(string file_path,
                                out string accent,
                                out string selection,
                                out string foreground,
                                out string background) {
        // Set default values
        accent = "#77ddcc";
        selection = "#ffbb33";
        foreground = "#000000";
        background = "#ffffff";

        try {
            // Check if the theme file exists
            var file = File.new_for_path(file_path);
            if (!file.query_exists()) {
                // File doesn't exist, use defaults
                return false;
            }

            // Read the binary data
            uint8[] data;
            file.load_contents(null, out data, null);
            
            // Make sure we have 6 bytes of data
            if (data.length != 6) {
                warning("Invalid theme file size: %d bytes (expected 6)", data.length);
                return false;
            }
            
            // Check if it's one-bit mode (all bytes are 0xf0)
            bool is_one_bit = true;
            for (int i = 0; i < 6; i++) {
                if (data[i] != 0xf0) {
                    is_one_bit = false;
                    break;
                }
            }
            
            if (is_one_bit) {
                // One-bit mode colors
                background = "#ffffff";
                foreground = "#000000";
                accent = "#000000";
                selection = "#ffffff";
                return true;
            }
            
            // Extract color components from binary format
            StringBuilder bg_sb = new StringBuilder();
            StringBuilder fg_sb = new StringBuilder();
            StringBuilder accent_sb = new StringBuilder();
            StringBuilder selection_sb = new StringBuilder();
            
            // Extract each digit from the 3 byte pairs
            for (int i = 0; i < 3; i++) {
                uint8 byte1 = data[i*2];
                uint8 byte2 = data[i*2+1];
                
                // Extract 4-bit values
                uint8 bg_val = (byte1 >> 4) & 0x0F;
                uint8 fg_val = byte1 & 0x0F;
                uint8 accent_val = (byte2 >> 4) & 0x0F;
                uint8 selection_val = byte2 & 0x0F;
                
                // Convert to hex chars and append
                bg_sb.append_c(int_to_hex_char(bg_val));
                fg_sb.append_c(int_to_hex_char(fg_val));
                accent_sb.append_c(int_to_hex_char(accent_val));
                selection_sb.append_c(int_to_hex_char(selection_val));
            }
            
            // Convert 3-digit hex codes to 6-digit hex colors
            background = expand_hex_color(bg_sb.str);
            foreground = expand_hex_color(fg_sb.str);
            accent = expand_hex_color(accent_sb.str);
            selection = expand_hex_color(selection_sb.str);
            
            return true;
        } catch (Error e) {
            warning("Error loading theme file: %s", e.message);
        }

        return false;
    }

    /**
     * Expands a 3-digit hex color to a 6-digit hex color
     * For example, "7dc" becomes "#77ddcc"
     */
    private string expand_hex_color(string short_hex) {
        if (short_hex.length != 3) return "#000000";
        
        // Expand each digit
        char r = short_hex[0];
        char g = short_hex[1];
        char b = short_hex[2];

        // Convert 0-f position to 00-ff hex
        return "#%c%c%c%c%c%c".printf(r, r, g, g, b, b);
    }

    /**
     * Saves colors to the theme file in binary format
     */
    public bool save_theme_file(string file_path,
                               ColorPickerWidget accent_picker,
                               ColorPickerWidget selection_picker,
                               ColorPickerWidget fg_picker,
                               ColorPickerWidget bg_picker,
                               Gtk.Window? parent = null) {
        try {
            // Get three-digit hex codes directly from the pickers
            string bg = bg_picker.get_hex_code();
            string fg = fg_picker.get_hex_code();
            string acc = accent_picker.get_hex_code();
            string sel = selection_picker.get_hex_code();
            
            // Create binary data (6 bytes = 3 pairs)
            uint8[] bin_data = new uint8[6];
            
            // First digit pair - byte 0: BG+FG, byte 1: Accent+Selection
            bin_data[0] = (uint8)((hex_char_to_int(bg[0]) << 4) | hex_char_to_int(fg[0]));
            bin_data[1] = (uint8)((hex_char_to_int(acc[0]) << 4) | hex_char_to_int(sel[0]));
            
            // Second digit pair
            bin_data[2] = (uint8)((hex_char_to_int(bg[1]) << 4) | hex_char_to_int(fg[1]));
            bin_data[3] = (uint8)((hex_char_to_int(acc[1]) << 4) | hex_char_to_int(sel[1]));
            
            // Third digit pair
            bin_data[4] = (uint8)((hex_char_to_int(bg[2]) << 4) | hex_char_to_int(fg[2]));
            bin_data[5] = (uint8)((hex_char_to_int(acc[2]) << 4) | hex_char_to_int(sel[2]));
            
            // Write binary data to file
            var file = File.new_for_path(file_path);
            var stream = file.replace(null, false, FileCreateFlags.REPLACE_DESTINATION);
            size_t bytes_written;
            stream.write_all(bin_data, out bytes_written);
            stream.close();
            
            return true;
        } catch (Error e) {
            warning("Error saving theme file: %s", e.message);
            show_error_dialog("Error saving theme file: " + e.message, parent);
            return false;
        }
    }

    /**
     * Generates a random pattern for the 8×8 grid
     */
    public int[,] generate_random_pattern() {
        // Initialize the pattern array
        int[,] pattern = new int[GRID_SIZE, GRID_SIZE];

        // Initialize random number generator with microsecond precision for better randomness
        var rand = new GLib.Rand();
        rand.set_seed((uint32)GLib.get_real_time());

        // Fill the pattern safely, one cell at a time
        for (int y = 0; y < GRID_SIZE; y++) {
            for (int x = 0; x < GRID_SIZE; x++) {
                // Simple random pattern - no mirroring for now to avoid crashes
                int color = rand.int_range(0, 4); // 0-3 for the four colors
                pattern[y, x] = color;
            }
        }

        return pattern;
    }
}