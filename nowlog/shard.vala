public class Shard : Object {
    public string title { get; set; }
    public string text { get; set; }
    public DateTime date { get; set; }
    public Cairo.ImageSurface? image { get; set; }
    public string[] tags { get; set; }
    
    public Shard (string title, string text, DateTime date, Cairo.ImageSurface? image, string[] tags) {
        this.title = title;
        this.text = text;
        this.date = date;
        this.image = image;
        this.tags = tags;
    }
    
    public bool has_tag (string tag) {
        foreach (var t in tags) {
            if (t == tag) {
                return true;
            }
        }
        return false;
    }
    
    // Convert date to Arvelie format
    public string get_arvelie_date () {
        if (date == null) {
            return "00A01"; // Default value if date is null
        }
        
        // Arvelie epoch is June 6th, 1993
        var epoch = new DateTime.local (1993, 6, 6, 0, 0, 0);
        
        // Calculate days since epoch
        TimeSpan diff = date.difference(epoch);
        int64 days_since_epoch = diff / TimeSpan.DAY;
        
        // Calculate year offset (each Arvelie year has 365 or 366 days)
        int year = 1993;
        int64 days_in_year;
        int64 days_remaining = days_since_epoch;
        
        while (true) {
            bool is_leap_year = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
            days_in_year = is_leap_year ? 366 : 365;
            
            if (days_remaining < days_in_year) {
                break;
            }
            
            days_remaining -= days_in_year;
            year++;
        }
        
        int year_offset = year - 1993;
        
        // Calculate Arvelie month (A-Z) and day
        unichar month_unichar;
        int day;
        
        // Handle + month (last 1-2 days of the year)
        bool is_leap_year = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
        int plus_month_days = is_leap_year ? 2 : 1;
        
        if (days_remaining >= 364) {  // Days 364-365 (366 in leap years) are + month
            month_unichar = '+';
            day = (int)(days_remaining - 364 + 1);
        } else {
            // Regular months A-Z
            // Each regular month has 14 days, total of 26 months = 364 days
            int month_index = (int)(days_remaining / 14);
            month_unichar = (unichar)((int)'A' + month_index);
            day = (int)(days_remaining % 14) + 1;
        }
        
        return "%02d%c%02d".printf (year_offset, (char)month_unichar, day);
    }
    
    // Convert to string format for tablatal
    public string to_tablatal_row (int[] column_widths) {
        string date_str = get_arvelie_date ();
        string tags_str = string.joinv(",", tags);
        
        // Make sure to properly pad each column according to widths
        return "%-*s %-*s %-*s %-*s".printf(
            column_widths[0], date_str,
            column_widths[1], title,
            column_widths[2], text.replace("\n", "\\n"),
            column_widths[3], tags_str
        );
    }
}

public class ShardManager : Object {
    private Gee.ArrayList<Shard> shards;
    private Gee.HashMap<string, int> tag_counts;
    
    public signal void shards_changed ();
    
    public ShardManager () {
        shards = new Gee.ArrayList<Shard> ();
        tag_counts = new Gee.HashMap<string, int> ();
    }
    
    public void add_shard (Shard shard) {
        shards.add (shard);
        
        // Update tag counts
        foreach (var tag in shard.tags) {
            if (tag_counts.has_key (tag)) {
                tag_counts[tag] = tag_counts[tag] + 1;
            } else {
                tag_counts[tag] = 1;
            }
        }
        
        shards_changed ();
    }
    
    public void remove_shard (Shard shard) {
        // Update tag counts before removing
        foreach (var tag in shard.tags) {
            if (tag_counts.has_key (tag)) {
                tag_counts[tag] = tag_counts[tag] - 1;
                if (tag_counts[tag] <= 0) {
                    tag_counts.unset (tag);
                }
            }
        }
        
        shards.remove (shard);
        shards_changed ();
    }
    
    public Gee.List<Shard> get_all_shards () {
        return shards.read_only_view;
    }
    
    public Gee.List<Shard> get_shards_by_tag (string tag) {
        var filtered = new Gee.ArrayList<Shard> ();
        foreach (var shard in shards) {
            if (shard.has_tag (tag)) {
                filtered.add (shard);
            }
        }
        return filtered;
    }
    
    public string[] get_most_used_tags (int limit = 10) {
        var entries = new Gee.ArrayList<Gee.Map.Entry<string, int>> ();
        foreach (var entry in tag_counts.entries) {
            entries.add (entry);
        }
        
        // Sort by count (descending)
        entries.sort ((a, b) => {
            return b.value - a.value;
        });
        
        // Take top N tags
        var result = new string[int.min (entries.size, limit)];
        for (int i = 0; i < result.length; i++) {
            if (i < entries.size) {
                result[i] = entries[i].key;
            }
        }
        
        return result;
    }
    
    // Save shards to a tablatal file
    public bool save_to_file (string file_path) {
        try {
            var file = File.new_for_path (file_path);
            
            // Create parent directories if they don't exist
            if (file.get_parent () != null && !file.get_parent ().query_exists ()) {
                try {
                    file.get_parent ().make_directory_with_parents ();
                } catch (Error e) {
                    warning ("Failed to create directory: %s", e.message);
                    return false;
                }
            }
            
            try {
                var file_stream = file.replace (null, false, FileCreateFlags.NONE);
                var data_stream = new DataOutputStream (file_stream);
                
                try {
                    // Define column headers
                    string[] headers = { "DATE", "TITLE", "TEXT", "TAGS" };
                    
                    // Calculate column widths based on the content
                    int[] column_widths = { 0, 0, 0, 0 };
                    
                    // Start with minimum widths based on headers
                    for (int i = 0; i < headers.length; i++) {
                        column_widths[i] = headers[i].length + 2;
                    }
                    
                    // Calculate widths needed for all shards
                    foreach (var shard in shards) {
                        string date_str = shard.get_arvelie_date ();
                        string tags_str = string.joinv(",", shard.tags);
                        
                        column_widths[0] = int.max(column_widths[0], date_str.length + 2);
                        column_widths[1] = int.max(column_widths[1], shard.title.length + 2);
                        column_widths[2] = int.max(column_widths[2], shard.text.replace("\n", "\\n").length + 2);
                        column_widths[3] = int.max(column_widths[3], tags_str.length + 2);
                    }
                    
                    // Write the header with proper formatting
                    string header = "%-*s %-*s %-*s %-*s".printf(
                        column_widths[0], headers[0],
                        column_widths[1], headers[1],
                        column_widths[2], headers[2],
                        column_widths[3], headers[3]
                    );
                    data_stream.put_string(header + "\n");
                    
                    // Write each shard as a row
                    foreach (var shard in shards) {
                        data_stream.put_string (shard.to_tablatal_row (column_widths) + "\n");
                    }
                } catch (IOError e) {
                    warning ("Failed to write to file: %s", e.message);
                    return false;
                }
            } catch (Error e) {
                warning ("Failed to create file: %s", e.message);
                return false;
            }
            
            return true;
        } catch (Error e) {
            warning ("Failed to save shards: %s", e.message);
            return false;
        }
    }
    
    // Load shards from a tablatal file
    public delegate DateTime? DateParserFunc(string date_str) throws Error;
    
    public bool load_from_file (string file_path, DateParserFunc date_parser) {
        try {
            var file = File.new_for_path (file_path);
            
            if (!file.query_exists ()) {
                warning ("File does not exist: %s", file_path);
                return false;
            }
            
            // Clear existing shards
            shards.clear ();
            tag_counts.clear ();
            
            try {
                var input_stream = file.read ();
                var data_input = new DataInputStream (input_stream);
                
                try {
                    // Read the header line to get column positions
                    string? header_line = data_input.read_line ();
                    if (header_line == null) {
                        warning ("Empty file or failed to read header");
                        return false;
                    }
                    
                    // Check the header format
                    if (!header_line.contains ("DATE") || !header_line.contains ("TITLE") ||
                        !header_line.contains ("TEXT") || !header_line.contains ("TAGS")) {
                        warning ("Invalid tablatal header format");
                        return false;
                    }
                    
                    // Extract column positions from header
                    int date_pos = header_line.index_of ("DATE");
                    int title_pos = header_line.index_of ("TITLE");
                    int text_pos = header_line.index_of ("TEXT");
                    int tags_pos = header_line.index_of ("TAGS");
                    
                    // Read each data line
                    string? line;
                    try {
                        while ((line = data_input.read_line ()) != null) {
                            if (line.strip () == "") continue; // Skip empty lines
                            
                            try {
                                // Extract data based on positions
                                string date_str = "";
                                string title = "";
                                string text = "";
                                string tags_str = "";
                                
                                // Extract date (from start to title position)
                                if (date_pos < title_pos) {
                                    date_str = line.substring (date_pos, title_pos - date_pos).strip ();
                                }
                                
                                // Extract title (between date and text)
                                if (title_pos < text_pos) {
                                    title = line.substring (title_pos, text_pos - title_pos).strip ();
                                }
                                
                                // Extract text (between title and tags)
                                if (text_pos < tags_pos) {
                                    text = line.substring (text_pos, tags_pos - text_pos).strip ();
                                    // Convert escaped newlines back
                                    text = text.replace ("\\n", "\n");
                                }
                                
                                // Extract tags (from tags to end)
                                if (tags_pos < line.length) {
                                    tags_str = line.substring (tags_pos).strip ();
                                }
                                
                                // Parse date
                                DateTime? date = null;
                                try {
                                    date = date_parser(date_str);
                                } catch (Error e) {
                                    warning("Error parsing date '%s': %s", date_str, e.message);
                                    continue;
                                }
                                
                                if (date == null) {
                                    warning ("Failed to parse date: %s", date_str);
                                    continue;
                                }
                                
                                // Parse tags
                                string[] tags = {};
                                if (tags_str != "") {
                                    tags = tags_str.split (",");
                                    for (int i = 0; i < tags.length; i++) {
                                        tags[i] = tags[i].strip ();
                                    }
                                }
                                
                                // Create shard and add it
                                var shard = new Shard (title, text, date, null, tags);
                                add_shard (shard);
                                
                            } catch (Error e) {
                                warning ("Error parsing line: %s", e.message);
                                continue;
                            }
                        }
                    } catch (IOError e) {
                        warning ("Error reading line: %s", e.message);
                        return false;
                    }
                    
                } catch (IOError e) {
                    warning ("Error reading header: %s", e.message);
                    return false;
                }
                
            } catch (Error e) {
                warning ("Error opening file: %s", e.message);
                return false;
            }
            
            shards_changed ();
            return true;
        } catch (Error e) {
            warning ("Failed to load shards: %s", e.message);
            return false;
        }
    }
}