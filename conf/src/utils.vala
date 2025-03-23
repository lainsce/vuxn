/*
 * Varvara Theme Configurator
 *
 * Modified utility functions to work with ColorPickerWidget
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
     */
    public string get_color_hex_digit(ColorPickerWidget picker, int position) {
        // Get the full hex color without the # prefix
        string hex = get_color_picker_hex(picker).substring(1);

        // Make sure the position is valid (0-5)
        if (position >= 0 && position < hex.length) {
            return hex.substring(position, 1);
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
     * Loads the theme file and returns the parsed colors
     * Updated to match the correct mapping:
     * color0/BG = AAA
     * color1/FG = BBB
     * color2/ACCENT = CCC
     * color3/SELECTION = DDD
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

            // Read the file content
            string content;
            FileUtils.get_contents(file_path, out content);

            content = content.strip();

            if (content.length >= 14) { // "ABCD ABCD ABCD" has 14 characters
                // Get the first character of each color component (ABCD)
                string a1 = content.substring(0, 1);
                string b1 = content.substring(1, 1);
                string c1 = content.substring(2, 1);
                string d1 = content.substring(3, 1);
                
                string a2 = content.substring(5, 1);
                string b2 = content.substring(6, 1);
                string c2 = content.substring(7, 1);
                string d2 = content.substring(8, 1);
                
                string a3 = content.substring(10, 1);
                string b3 = content.substring(11, 1);
                string c3 = content.substring(12, 1);
                string d3 = content.substring(13, 1);

                // Interpret as 3-digit hex colors with corrected mapping
                background = "#" + a1 + a2 + a3;     // BG = AAA
                foreground = "#" + b1 + b2 + b3;     // FG = BBB
                accent = "#" + c1 + c2 + c3;         // ACCENT = CCC
                selection = "#" + d1 + d2 + d3;      // SELECTION = DDD

                return true;
            }
        } catch (Error e) {
            warning("Error loading theme file: %s", e.message);
        }

        return false;
    }

    /**
     * Saves colors to the theme file
     * Updated to match the correct mapping:
     * color0/BG = AAA
     * color1/FG = BBB
     * color2/ACCENT = CCC
     * color3/SELECTION = DDD
     */
    public bool save_theme_file(string file_path,
                               ColorPickerWidget accent_picker,
                               ColorPickerWidget selection_picker,
                               ColorPickerWidget fg_picker,
                               ColorPickerWidget bg_picker,
                               Gtk.Window? parent = null) {
        try {
            // Get specific position digits for each color with corrected order
            // First group: first digit (position 0)
            string a1 = get_color_hex_digit(bg_picker, 0);         // BG
            string b1 = get_color_hex_digit(fg_picker, 0);         // FG
            string c1 = get_color_hex_digit(accent_picker, 0);     // ACCENT
            string d1 = get_color_hex_digit(selection_picker, 0);  // SELECTION

            // Second group: third digit (position 2)
            string a2 = get_color_hex_digit(bg_picker, 2);         // BG
            string b2 = get_color_hex_digit(fg_picker, 2);         // FG
            string c2 = get_color_hex_digit(accent_picker, 2);     // ACCENT
            string d2 = get_color_hex_digit(selection_picker, 2);  // SELECTION

            // Third group: fifth digit (position 4)
            string a3 = get_color_hex_digit(bg_picker, 4);         // BG
            string b3 = get_color_hex_digit(fg_picker, 4);         // FG
            string c3 = get_color_hex_digit(accent_picker, 4);     // ACCENT
            string d3 = get_color_hex_digit(selection_picker, 4);  // SELECTION

            // Format the content according to the pattern "ABCD ABCD ABCD"
            string content = a1 + b1 + c1 + d1 + " " + a2 + b2 + c2 + d2 + " " + a3 + b3 + c3 + d3;

            // Write to the theme file
            FileUtils.set_contents(file_path, content);

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