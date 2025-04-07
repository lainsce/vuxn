public class RecentFilesManager {
    private const int MAX_RECENT_FILES = 5;
    private static RecentFilesManager? instance;
    private List<string> recent_files;
    private string recent_files_path;
    private FileMonitor? file_monitor;

    // Signal for when the recent files list changes
    public signal void recent_files_changed();

    private RecentFilesManager () {
        recent_files = new List<string> ();
        recent_files_path = Utils.get_data_path ("recent_files.txt");
        load_recent_files ();
        
        // Set up file monitoring to detect external changes to recent files
        try {
            var file = File.new_for_path(recent_files_path);
            file_monitor = file.monitor_file(FileMonitorFlags.NONE, null);
            file_monitor.changed.connect((file, other_file, event_type) => {
                if (event_type == FileMonitorEvent.CHANGED || 
                    event_type == FileMonitorEvent.CREATED) {
                    // Reload the file when it changes externally
                    load_recent_files();
                    recent_files_changed();
                }
            });
        } catch (Error e) {
            warning("Failed to set up recent files monitoring: %s", e.message);
        }
    }

    public static RecentFilesManager get_default () {
        if (instance == null) {
            instance = new RecentFilesManager ();
        }
        return instance;
    }

    public void add_file (string file_path) {
        // Validate the path
        if (file_path == null || file_path == "") {
            return;
        }
        
        // Normalize the path
        string normalized_path = File.new_for_path(file_path).get_path();
        if (normalized_path == null) {
            return;
        }
        
        // Remove the file if it already exists in the list
        remove_file(normalized_path);

        // Add the file to the beginning of the list
        recent_files.prepend (normalized_path);

        // Ensure we only keep the maximum number of recent files
        while (recent_files.length () > MAX_RECENT_FILES) {
            recent_files.remove(recent_files.last().data);
        }

        // Save the updated list
        save_recent_files ();
        
        // Emit signal
        recent_files_changed();
    }

    public void remove_file (string file_path) {
        if (file_path == null || file_path == "") {
            return;
        }
        
        // Normalize the path for comparison
        string normalized_path = File.new_for_path(file_path).get_path();
        if (normalized_path == null) {
            return;
        }
        
        bool removed = false;
        
        // Find and remove all instances (should be only one, but just in case)
        List<string> to_remove = new List<string>();
        foreach (string item in recent_files) {
            if (item == normalized_path) {
                to_remove.append(item);
                removed = true;
            }
        }
        
        // Remove all matching items
        foreach (string item in to_remove) {
            recent_files.remove(item);
        }

        if (removed) {
            save_recent_files();
            recent_files_changed();
        }
    }

    public unowned List<string> get_recent_files () {
        return recent_files;
    }

    public List<string> get_valid_recent_files (int max_count = -1) {
        List<string> valid_files = new List<string>();
        int count = 0;
        
        foreach (string path in recent_files) {
            if (max_count > 0 && count >= max_count) {
                break;
            }
            
            // Only include files that actually exist
            if (FileUtils.test(path, FileTest.EXISTS) && 
                FileUtils.test(path, FileTest.IS_REGULAR)) {
                valid_files.append(path);
                count++;
            }
        }
        
        return valid_files;
    }

    private void load_recent_files () {
        // Clear existing list
        recent_files = new List<string>();
        
        string content = Utils.load_from_file (recent_files_path);
        if (content != "") {
            string[] lines = content.split ("\n");
            foreach (string line in lines) {
                string trimmed = line.strip();
                if (trimmed != "") {
                    // Don't add duplicates
                    if (!contains_path(recent_files, trimmed)) {
                        recent_files.append (trimmed);
                    }
                }
            }
        }
    }

    private void save_recent_files () {
        StringBuilder builder = new StringBuilder ();
        
        // Get a temporary list to avoid duplicates
        List<string> unique_files = new List<string>();
        foreach (string path in recent_files) {
            if (!contains_path(unique_files, path)) {
                unique_files.append(path);
                builder.append (path);
                builder.append ("\n");
            }
        }

        Utils.save_to_file (recent_files_path, builder.str);
    }
    
    // Helper method to check if a path is already in a list
    private bool contains_path(List<string> list, string path) {
        foreach (string item in list) {
            if (item == path) {
                return true;
            }
        }
        return false;
    }
    
    // Cleanup resources
    public void dispose() {
        if (file_monitor != null) {
            file_monitor.cancel();
            file_monitor = null;
        }
    }
}

public class Utils {
    /**
     * Gets the path to a data file in the application's data directory
     */
    public static string get_data_path(string filename) {
        var data_dir = GLib.Path.build_filename(GLib.Environment.get_user_data_dir(), "right-editor");

        // Create the directory if it doesn't exist
        var dir = File.new_for_path(data_dir);
        if (!dir.query_exists()) {
            try {
                dir.make_directory_with_parents();
            } catch (Error e) {
                warning("Could not create data directory: %s", e.message);
            }
        }

        return GLib.Path.build_filename(data_dir, filename);
    }

    /**
     * Saves content to a file with protection against corruption and concurrent access.
     * Uses lock files, backup files, and atomic operations for safety.
     */
    public static bool save_to_file(string filepath, string content) {
        // Use lock file to prevent concurrent access
        string lock_path = filepath + ".lock";
        File lock_file = File.new_for_path(lock_path);
        bool locked = false;
        
        try {
            // Try to acquire the lock with timeout handling
            locked = acquire_lock(lock_file);
            if (!locked) {
                warning("File appears to be in use by another process: %s", filepath);
                return false;
            }
            
            var file = File.new_for_path(filepath);
            
            // Create parent directory if needed
            var parent = file.get_parent();
            if (parent != null && !parent.query_exists()) {
                parent.make_directory_with_parents();
            }
            
            // Create backup if the file exists
            if (file.query_exists()) {
                try {
                    string backup_path = filepath + ".bak";
                    File backup_file = File.new_for_path(backup_path);
                    
                    if (backup_file.query_exists()) {
                        backup_file.delete();
                    }
                    
                    file.copy(backup_file, FileCopyFlags.OVERWRITE);
                } catch (Error e) {
                    warning("Failed to create backup, continuing anyway: %s", e.message);
                }
            }
            
            // Write to temporary file
            string temp_path = filepath + ".tmp";
            File temp_file = File.new_for_path(temp_path);
            
            if (!FileUtils.set_contents(temp_path, content)) {
                warning("Failed to write to temporary file");
                return false;
            }
            
            // Move temp file to destination (atomic operation)
            try {
                temp_file.move(file, FileCopyFlags.OVERWRITE);
                return true;
            } catch (Error e) {
                warning("Failed to move temporary file to destination: %s", e.message);
                
                // Try to restore from backup
                try_restore_from_backup(filepath);
                return false;
            }
        } catch (Error e) {
            warning("Error during file save: %s", e.message);
            return false;
        } finally {
            // Always release the lock
            if (locked) {
                release_lock(lock_file);
            }
        }
    }
    
    /**
     * Loads content from a file with backup fallback if the main file is corrupted.
     * Also handles potential concurrent access by waiting briefly if a write is in progress.
     */
    public static bool load_from_file_improved(string filepath, out string content) {
        content = "";
        
        // Check if there's a write in progress (active lock file)
        string lock_path = filepath + ".lock";
        File lock_file = File.new_for_path(lock_path);
        
        if (lock_file.query_exists()) {
            // Wait briefly for potential write to complete
            Thread.usleep(300000); // 300ms
        }
        
        try {
            // Try loading the main file
            if (FileUtils.get_contents(filepath, out content)) {
                return true;
            }
            
            // If main file failed, try backup
            string backup_path = filepath + ".bak";
            File backup_file = File.new_for_path(backup_path);
            
            if (backup_file.query_exists()) {
                warning("Loading from backup file after main file failed");
                if (FileUtils.get_contents(backup_path, out content)) {
                    return true;
                }
            }
            
            warning("Failed to load file or backup: %s", filepath);
            return false;
        } catch (Error e) {
            warning("Error loading file: %s", e.message);
            return false;
        }
    }
    
    /**
     * Compatibility method for the original API
     */
    public static string load_from_file(string filepath) {
        string content;
        if (load_from_file_improved(filepath, out content)) {
            return content;
        }
        return "";
    }
    
    /**
     * Tries to restore from backup after a failed save
     */
    private static void try_restore_from_backup(string filepath) {
        try {
            string backup_path = filepath + ".bak";
            File backup_file = File.new_for_path(backup_path);
            File orig_file = File.new_for_path(filepath);
            
            if (backup_file.query_exists()) {
                backup_file.copy(orig_file, FileCopyFlags.OVERWRITE);
                warning("Restored from backup after failed save");
            }
        } catch (Error e) {
            warning("Failed to restore from backup: %s", e.message);
        }
    }
    
    /**
     * Try to acquire a file lock with timeout
     */
    private static bool acquire_lock(File lock_file) throws Error {
        // If lock exists, check if it's stale or wait for it
        if (lock_file.query_exists()) {
            // Check if it's a stale lock (over 30 seconds old)
            FileInfo info = lock_file.query_info(FileAttribute.TIME_MODIFIED, 
                                                FileQueryInfoFlags.NONE);
                                                
            int64 mod_time = info.get_modification_time().tv_sec;
            int64 current_time = (int64)time_t();
            
            if (current_time - mod_time > 30) {
                // Stale lock - try to delete it
                lock_file.delete();
            } else {
                // Fresh lock - wait up to 3 seconds
                int timeout_ms = 3000;
                int wait_interval_ms = 100;
                int waited_ms = 0;
                
                while (lock_file.query_exists() && waited_ms < timeout_ms) {
                    Thread.usleep(wait_interval_ms * 1000);
                    waited_ms += wait_interval_ms;
                }
                
                // If it still exists after timeout, fail
                if (lock_file.query_exists()) {
                    return false;
                }
            }
        }
        
        // Create lock file with timestamp and process info
        string lock_content = "PID: %d\nTime: %s".printf(
            Posix.getpid(),
            new DateTime.now_local().format("%F %T")
        );
        
        FileUtils.set_contents(lock_file.get_path(), lock_content);
        return true;
    }
    
    /**
     * Release a file lock
     */
    private static void release_lock(File lock_file) {
        try {
            if (lock_file.query_exists()) {
                lock_file.delete();
            }
        } catch (Error e) {
            warning("Failed to release lock file: %s", e.message);
        }
    }
    
    /**
     * Checks if the file has a supported extension for syntax highlighting
     */
    public static bool is_valid_file_type(string filename) {
        string[] supported_extensions = {
            ".txt", ".md", ".c", ".h", ".cpp", ".hpp", ".vala", ".vapi",
            ".py", ".js", ".html", ".css", ".xml", ".json", ".sh"
        };

        foreach (string ext in supported_extensions) {
            if (filename.down().has_suffix(ext)) {
                return true;
            }
        }

        // If no extension matches, still return true - we can edit any text file
        return true;
    }

    /**
     * Gets a human-readable name for a file type based on its extension
     */
    public static string get_file_type_name(string filename) {
        if (filename.has_suffix(".vala") || filename.has_suffix(".vapi")) {
            return "Vala";
        } else if (filename.has_suffix(".c") || filename.has_suffix(".h")) {
            return "C";
        } else if (filename.has_suffix(".cpp") || filename.has_suffix(".hpp")) {
            return "C++";
        } else if (filename.has_suffix(".js")) {
            return "JavaScript";
        } else if (filename.has_suffix(".py")) {
            return "Python";
        } else if (filename.has_suffix(".html") || filename.has_suffix(".htm")) {
            return "HTML";
        } else if (filename.has_suffix(".css")) {
            return "CSS";
        } else if (filename.has_suffix(".xml")) {
            return "XML";
        } else if (filename.has_suffix(".json")) {
            return "JSON";
        } else if (filename.has_suffix(".md") || filename.has_suffix(".markdown")) {
            return "Markdown";
        } else if (filename.has_suffix(".sh")) {
            return "Shell Script";
        } else {
            return "Plain Text";
        }
    }

    /**
     * Shows an info dialog with an OK button
     */
    public static void show_info_dialog(Gtk.Window parent, string title, string message) {
        var dialog = new Gtk.AlertDialog("");
        dialog.set_message(title);
        dialog.set_detail(message);
        dialog.set_modal(true);
        dialog.set_buttons({"OK"});

        dialog.choose.begin(parent, null, (obj, res) => {
            try {
                dialog.choose.end(res);
            } catch (Error e) {
                // Ignore errors (like dismissal)
            }
        });
    }
}