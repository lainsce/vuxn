public class Utils {
    public static string get_data_path (string filename) {
        var data_dir = GLib.Path.build_filename (GLib.Environment.get_user_data_dir (), "notepadapp");
        
        // Create the directory if it doesn't exist
        var dir = File.new_for_path (data_dir);
        if (!dir.query_exists ()) {
            try {
                dir.make_directory_with_parents ();
            } catch (Error e) {
                warning ("Could not create data directory: %s", e.message);
            }
        }
        
        return GLib.Path.build_filename (data_dir, filename);
    }

    public static void save_to_file (string filepath, string content) {
        try {
            // Ensure parent directory exists
            var file = File.new_for_path (filepath);
            var parent = file.get_parent ();
            if (parent != null && !parent.query_exists ()) {
                parent.make_directory_with_parents ();
            }
            
            GLib.FileUtils.set_contents (filepath, content);
        } catch (GLib.Error e) {
            warning ("Failed to save file: %s", e.message);
        }
    }

    public static string load_from_file (string filepath) {
        try {
            // Check if file exists first
            var file = File.new_for_path (filepath);
            if (!file.query_exists ()) {
                return "";
            }
            
            string content;
            GLib.FileUtils.get_contents (filepath, out content);
            return content;
        } catch (GLib.Error e) {
            warning ("Failed to load file: %s", e.message);
            return "";
        }
    }
}
