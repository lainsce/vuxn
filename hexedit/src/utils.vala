using Gtk;

/**
 * Utility class providing common helper methods for the application
 */
public class Utils {
    /**
     * Shows an error dialog with the given title and message
     *
     * @param parent The parent window
     * @param title The dialog title
     * @param message The error message to display
     */
    public static void show_error_dialog(Gtk.Window parent, string title, string message) {
        var dialog = new Gtk.AlertDialog(_("%s: %s").printf(title, message));
        dialog.choose.begin(parent, null, (obj, res) => {
            try {
                dialog.choose.end(res);
            } catch (Error e) {
                warning("Alert dialog error: %s\n", e.message);
            }
        });
    }

    /**
     * Shows a warning dialog with the given title and message
     *
     * @param parent The parent window
     * @param title The dialog title
     * @param message The warning message to display
     */
    public static void show_warning_dialog(Gtk.Window parent, string title, string message) {
        var dialog = new Gtk.AlertDialog(_("%s: %s").printf(title, message));
        dialog.choose.begin(parent, null, (obj, res) => {
            try {
                dialog.choose.end(res);
            } catch (Error e) {
                warning("Alert dialog error: %s\n", e.message);
            }
        });
    }

    /**
     * Shows an information dialog with the given title and message
     *
     * @param parent The parent window
     * @param title The dialog title
     * @param message The info message to display
     */
    public static void show_info_dialog(Gtk.Window parent, string title, string message) {
        var dialog = new Gtk.AlertDialog(message);
        dialog.choose.begin(parent, null, (obj, res) => {
            try {
                dialog.choose.end(res);
            } catch (Error e) {
                warning("Alert dialog error: %s\n", e.message);
            }
        });
    }

    /**
     * Converts a byte array to a hexadecimal string
     *
     * @param data The byte array to convert
     * @return The hexadecimal string representation
     */
    public static string bytes_to_hex_string(uint8[] data) {
        var builder = new StringBuilder();
        foreach (var b in data) {
            builder.append_printf("%02x", b);
        }
        return builder.str;
    }
}
