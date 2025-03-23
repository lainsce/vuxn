// utils.vala
using Gtk;
using Gst;
using Gst.PbUtils;

public class Utils {
    // CSS Styles for the application
    public const string CSS = """
    * {
    font-family: "Chicago 12.1", monospace;
    font-size: 16px;
    box-shadow: none;
    }
    window.background {
    background-color: #fff;
    color: #000;
    }
    """;

    // Track info class
    public class TrackInfo {
        public string title;
        public string artist;
        public string album;

        public TrackInfo (string title = "", string artist = "", string album = "") {
            this.title = title;
            this.artist = artist;
            this.album = album;
        }
    }

    // Get cleaned track name (no extension)
    public static string clean_track_name (string filename) {
        // Remove file extension
        int last_dot = filename.last_index_of (".");
        if (last_dot > 0) {
            return filename.substring (0, last_dot);
        }
        return filename;
    }

    // Extract metadata from a music file
    public static TrackInfo extract_metadata (Gst.PbUtils.Discoverer discoverer, string file_path) {
        var track_info = new TrackInfo ();

        try {
            var info = discoverer.discover_uri (File.new_for_path (file_path).get_uri ());
            var tags = info.get_tags ();

            // Try to get title
            string title = "";
            if (tags != null && tags.get_string (Gst.Tags.TITLE, out title)) {
                track_info.title = title;
            } else {
                // Use filename without extension as fallback
                track_info.title = clean_track_name (File.new_for_path (file_path).get_basename ());
            }

            // Try to get artist
            string artist = "";
            if (tags != null && tags.get_string (Gst.Tags.ARTIST, out artist)) {
                track_info.artist = artist;
            } else {
                track_info.artist = "Unknown Artist";
            }

            // Try to get album
            string album = "";
            if (tags != null && tags.get_string (Gst.Tags.ALBUM, out album)) {
                track_info.album = album;
            } else {
                track_info.album = "Unknown Album";
            }

            print ("Metadata for %s: Title=%s, Artist=%s, Album=%s\n",
                   file_path, track_info.title, track_info.artist, track_info.album);
        } catch (Error e) {
            warning ("Failed to extract metadata from %s: %s", file_path, e.message);

            // Fallback to filename without extension
            track_info.title = clean_track_name (File.new_for_path (file_path).get_basename ());
        }

        return track_info;
    }

    // Format time in nanoseconds to MM:SS
    public static string format_time (int64 time_ns) {
        int seconds = (int) (time_ns / Gst.SECOND);
        int minutes = seconds / 60;
        seconds %= 60;
        return "%02d:%02d".printf (minutes, seconds);
    }
}
