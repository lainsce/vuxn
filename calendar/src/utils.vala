using GLib;

public class Utils {
    // Get the path to the events file in the user's home directory
    private static string get_events_file_path() {
        string home_dir = Environment.get_home_dir();
        string app_dir = Path.build_filename(home_dir, ".local", "share", "com.example.calendarapp");
        return Path.build_filename(app_dir, "events.csv");
    }

    public static void save_events(List<string> events) {
        string file_path = get_events_file_path();
        try {
            // Create a Gio.File for the path
            File file = File.new_for_path(file_path);
            var parent = file.get_parent();
            if (parent != null && !parent.query_exists()) {
                parent.make_directory_with_parents();
            }

            // Replace (or create) the file for writing
            FileOutputStream out_stream = file.replace(null, false, FileCreateFlags.NONE, null);
            DataOutputStream dos = new DataOutputStream(out_stream);

            // Write each event (already in "day,text" format) to a new line
            foreach (string event in events) {
                dos.put_string(event + "\n");
            }
            dos.flush();
            out_stream.close(null);

            print("Events saved to: %s\n", file_path);
        } catch (Error e) {
            warning("Failed to save events: %s", e.message);
        }
    }

    public static List<string> load_events() {
        string file_path = get_events_file_path();
        List<string> events = new List<string> ();

        print("Attempting to load events from: %s\n", file_path);


        // Create an empty events list if the file doesn't exist
        if (!FileUtils.test(file_path, FileTest.EXISTS)) {
            print("Events file not found, returning empty list\n");
            return events;
        }

        // Read the file line by line using FileStream
        FileStream stream = FileStream.open(file_path, "r");
        if (stream == null) {
            warning("Could not open file for reading");
            return events;
        }

        string line;
        while ((line = stream.read_line()) != null) {
            if (line.strip() != "") {
                events.append(line);
                print("Read event: %s\n", line);
            }
        }

        return events;
    }
}
