using GLib;

public class EventManager {
    private static EventManager? instance;
    private HashTable<string, string> events; // Key: "year-month-day" or pattern, Value: event text
    private string events_file;
    private bool is_dirty = false;

    private EventManager() {
        events = new HashTable<string, string> (str_hash, str_equal);
        events_file = get_events_file_path();
        load_events();
        print("EventManager initialized with file path: %s\n", events_file);
    }

    public static EventManager get_instance() {
        if (instance == null) {
            instance = new EventManager();
        }
        return instance;
    }

    private string get_events_file_path() {
        string home_dir = Environment.get_home_dir();
        string app_dir = Path.build_filename(home_dir, ".local", "share", "com.example.calendarapp");
        return Path.build_filename(app_dir, "events.csv");
    }

    private void load_events() {
        events.remove_all(); // Clear existing events

        try {
            File file = File.new_for_path(events_file);
            if (!file.query_exists()) {
                print("Events file not found at: %s\n", events_file);
                return;
            }

            print("Loading events from file: %s\n", events_file);

            uint8[] contents_bytes;
            file.load_contents(null, out contents_bytes, null);
            string contents = (string) contents_bytes;

            string[] lines = contents.split("\n");
            foreach (string line in lines) {
                string trimmed = line.strip();
                if (trimmed == "") continue;

                // Try to parse new format first: YYYY-MM-DD Event Text
                // Or recurring formats: ****-MM-DD Event Text, ****-**-DD Event Text, etc.
                int space_index = trimmed.index_of(" ");
                if (space_index > 0) {
                    string date_pattern = trimmed.substring(0, space_index);
                    string text = trimmed.substring(space_index + 1);
                    
                    if (is_valid_date_pattern(date_pattern)) {
                        events.set(date_pattern, text);
                        print("Loaded event with pattern %s: '%s'\n", date_pattern, text);
                        continue;
                    }
                }

                // If not new format, try old format: year,month,day,text
                string[] parts = trimmed.split(",", 4);
                if (parts.length == 4) {
                    // Convert old format to new format
                    string year = parts[0];
                    string month = parts[1].length == 1 ? "0" + parts[1] : parts[1];
                    string day = parts[2].length == 1 ? "0" + parts[2] : parts[2];
                    string date_pattern = "%s-%s-%s".printf(year, month, day);
                    string text = parts[3];
                    
                    events.set(date_pattern, text);
                    print("Converted old format to new: %s: '%s'\n", date_pattern, text);
                    is_dirty = true; // Mark as dirty to save in new format
                } else if (parts.length == 2) {
                    // Handle even older format (day,text) - will be migrated later
                    print("Found very old format event, will migrate later: %s\n", trimmed);
                }
            }

            print("Loaded %d events from file\n", (int) events.size());
        } catch (Error e) {
            warning("Failed to load events: %s", e.message);
        }
    }

    // Check if a date pattern is valid
    private bool is_valid_date_pattern(string pattern) {
        // Regular date: YYYY-MM-DD
        if (pattern.length == 10 && 
            pattern.get_char(4) == '-' && 
            pattern.get_char(7) == '-') {
            return true;
        }
        
        // Recurring by month and day: ****-MM-DD
        if (pattern.length == 10 && 
            pattern.substring(0, 4) == "****" && 
            pattern.get_char(4) == '-' && 
            pattern.get_char(7) == '-') {
            return true;
        }
        
        // Recurring by day of month: ****-**-DD
        if (pattern.length == 10 && 
            pattern.substring(0, 4) == "****" && 
            pattern.substring(5, 2) == "**" && 
            pattern.get_char(4) == '-' && 
            pattern.get_char(7) == '-') {
            return true;
        }
        
        // Recurring by weekday: ****-**-**-*N (N=1-7 for Monday-Sunday)
        if (pattern.length == 13 && 
            pattern.substring(0, 4) == "****" && 
            pattern.substring(5, 2) == "**" && 
            pattern.substring(8, 2) == "**" && 
            pattern.get_char(4) == '-' && 
            pattern.get_char(7) == '-' && 
            pattern.get_char(10) == '-' && 
            pattern.get_char(11) == '*' && 
            pattern.get_char(12) >= '1' && 
            pattern.get_char(12) <= '7') {
            return true;
        }
        
        return false;
    }

    public void save_events() {
        if (!is_dirty) {
            print("No changes to save\n");
            return;
        }

        // Ensure the directory exists
        File file = File.new_for_path(events_file);
        File parent_dir = file.get_parent();

        if (!parent_dir.query_exists()) {
            try {
                parent_dir.make_directory_with_parents();
                print("Created parent directory: %s\n", parent_dir.get_path());
            } catch (Error e) {
                warning("Failed to create directory: %s", e.message);
                return;
            }
        }

        // List all events before saving
        print("Current events before saving:\n");
        int event_count = 0;
        events.foreach((pattern, text) => {
            print("  %d. %s %s\n", ++event_count, pattern, text);
        });

        // Build the file contents as a string
        StringBuilder contents = new StringBuilder();

        events.foreach((pattern, text) => {
            contents.append(pattern);
            contents.append(" ");
            contents.append(text);
            contents.append("\n");
        });

        // Write the file in one operation - replacing any existing content
        print("Saving %d events to file: %s\n", (int) events.size(), events_file);

        try {
            FileUtils.set_contents(events_file, contents.str);
            print("Successfully saved events to file\n");
        } catch (Error e) {
            warning("Error writing to file: %s", e.message);
        }

        is_dirty = false;
    }

    private bool is_date_in_past(int day, int month, int year) {
        var today = new DateTime.now_local();
        var today_day = today.get_day_of_month();
        var today_month = today.get_month();
        var today_year = today.get_year();
        
        // Compare years first
        if (year < today_year) {
            return true;
        }
        
        // Same year, compare months
        if (year == today_year && month < today_month) {
            return true;
        }
        
        // Same year and month, compare days
        if (year == today_year && month == today_month && day < today_day) {
            return true;
        }
        
        // Not in the past
        return false;
    }

    // Get event for a specific day, month, and year
    public string? get_event_for_day(int day, int month, int year, bool include_past_events = false) {
        // Skip past events unless explicitly requested
        if (!include_past_events && is_date_in_past(day, month, year)) {
            return null;
        }
        
        // Format the date components properly with leading zeros
        string year_str = year.to_string();
        string month_str = month < 10 ? "0" + month.to_string() : month.to_string();
        string day_str = day < 10 ? "0" + day.to_string() : day.to_string();
        
        // Get current day of week (1=Monday, 7=Sunday)
        var date = new DateTime.local(year, month, day, 0, 0, 0);
        int day_of_week = date.get_day_of_week();
        
        // Check for exact match first (highest priority)
        string exact_key = "%s-%s-%s".printf(year_str, month_str, day_str);
        string? event_text = events.get(exact_key);
        if (event_text != null) {
            return event_text;
        }
        
        // Check for recurring by month and day: ****-MM-DD
        string month_day_key = "****-%s-%s".printf(month_str, day_str);
        event_text = events.get(month_day_key);
        if (event_text != null) {
            return event_text;
        }
        
        // Check for recurring by day of month: ****-**-DD
        string day_only_key = "****-**-%s".printf(day_str);
        event_text = events.get(day_only_key);
        if (event_text != null) {
            return event_text;
        }
        
        // Check for recurring by weekday: ****-**-**-*N
        string weekday_key = "****-**-**-*%d".printf(day_of_week);
        event_text = events.get(weekday_key);
        if (event_text != null) {
            return event_text;
        }
        
        return null;
    }

    // Set event for a specific day, month, and year
    public bool set_event_for_day(int day, int month, int year, string text) {
        // Don't allow setting events for dates in the past
        if (is_date_in_past(day, month, year)) {
            // Check if this is a recurring event pattern
            if (!text.contains("****")) {
                print("Cannot set event for past date: %d-%d-%d\n", year, month, day);
                return false;
            }
        }
        
        string text_copy = text.strip();
        string key = null;
        
        // Check if the text starts with a date pattern indicator
        bool is_recurring = false;
        
        if (text_copy.has_prefix("R:")) {
            // Recurring event
            is_recurring = true;
            string pattern_type = text_copy.substring(2, 1);
            text_copy = text_copy.substring(4).strip();
            
            // Format the date components properly with leading zeros
            string month_str = month < 10 ? "0" + month.to_string() : month.to_string();
            string day_str = day < 10 ? "0" + day.to_string() : day.to_string();
            
            switch (pattern_type) {
                case "M": // Month and day: ****-MM-DD
                    key = "****-%s-%s".printf(month_str, day_str);
                    break;
                    
                case "D": // Day only: ****-**-DD
                    key = "****-**-%s".printf(day_str);
                    break;
                    
                case "W": // Weekday: ****-**-**-*N
                    var date = new DateTime.local(year, month, day, 0, 0, 0);
                    int day_of_week = date.get_day_of_week();
                    key = "****-**-**-*%d".printf(day_of_week);
                    break;
                    
                default:
                    // Invalid recurring type, fall back to regular event
                    is_recurring = false;
                    break;
            }
        }
        
        if (!is_recurring && text_copy.length >= 4 && text_copy.substring(0, 4) == "****") {
            // This is already in recurring pattern format
            is_recurring = true;
            int space_index = text_copy.index_of(" ");
            if (space_index > 0) {
                key = text_copy.substring(0, space_index);
                text_copy = text_copy.substring(space_index + 1);
            } else {
                key = text_copy;
                text_copy = "";
            }
        }
        
        if (!is_recurring) {
            // Regular event with specific date
            string year_str = year.to_string();
            string month_str = month < 10 ? "0" + month.to_string() : month.to_string();
            string day_str = day < 10 ? "0" + day.to_string() : day.to_string();
            key = "%s-%s-%s".printf(year_str, month_str, day_str);
        }

        print("Setting event for %s to: '%s'\n", key, text_copy);

        // Check if there's an existing event
        string? existing_text = events.get(key);

        // If text is empty, remove the event
        if (text_copy == "") {
            if (existing_text != null) {
                events.remove(key);
                print("Removed event for %s\n", key);
                is_dirty = true;
            } else {
                print("No event to remove for %s\n", key);
            }
        }
        // Otherwise add or update the event
        else {
            // Only mark as dirty if the text changed
            if (existing_text != text_copy) {
                events.set(key, text_copy);
                print("Updated event for %s: '%s'\n", key, text_copy);
                is_dirty = true;
            } else {
                print("Event text unchanged for %s\n", key);
            }
        }

        // Save if changes were made
        if (is_dirty) {
            save_events();
        }
        
        return true;
    }

    // Migrate old format events to the new format
    public void migrate_old_events(int current_month, int current_year) {
        // Reload the file to catch any old format events
        File file = File.new_for_path(events_file);
        if (!file.query_exists()) {
            return;
        }

        try {
            uint8[] contents_bytes;
            file.load_contents(null, out contents_bytes, null);
            string contents = (string) contents_bytes;

            string[] lines = contents.split("\n");
            bool found_old_format = false;

            foreach (string line in lines) {
                string trimmed = line.strip();
                if (trimmed == "") continue;
                
                // Skip lines already in new format
                if (trimmed.contains(" ") && !trimmed.contains(",")) {
                    continue;
                }

                string[] parts = trimmed.split(",", 4);
                
                // Check for old format with year,month,day,text
                if (parts.length == 4) {
                    // Already handled in load_events
                    found_old_format = true;
                    continue;
                }
                
                // Check for very old format (day,text)
                if (parts.length == 2) {
                    // Try to parse the first part as a day number
                    int day;
                    if (int.try_parse(parts[0].strip(), out day) && day >= 1 && day <= 31) {
                        string text = parts[1];
                        
                        // Format with leading zeros
                        string year_str = current_year.to_string();
                        string month_str = current_month < 10 ? "0" + current_month.to_string() : current_month.to_string();
                        string day_str = day < 10 ? "0" + day.to_string() : day.to_string();
                        
                        // Store in new format
                        string key = "%s-%s-%s".printf(year_str, month_str, day_str);
                        events.set(key, text);

                        print("Migrated very old event to %s: '%s'\n", key, text);
                        found_old_format = true;
                    }
                }
            }

            // Save if any migrations occurred
            if (found_old_format) {
                is_dirty = true;
                save_events();
                print("Finished migrating old format events\n");
            }
        } catch (Error e) {
            warning("Error during migration: %s", e.message);
        }
    }

    // Call this when the application is about to exit
    public void flush() {
        if (is_dirty) {
            print("Flushing unsaved changes before exit\n");
            save_events();
        }
    }
}