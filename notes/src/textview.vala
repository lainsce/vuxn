public class CheckboxTextView : Gtk.TextView {
    public Gtk.TextBuffer buffer;
    private Gee.Map<Gtk.TextChildAnchor, CairoCheckbox> checkbox_widgets;
    private bool is_processing = false;
    
    // Structure to store checkbox data
    public class CheckboxData {
        public int line;
        public int offset;
        public bool is_checked;
        
        public CheckboxData(int line, int offset, bool is_checked) {
            this.line = line;
            this.offset = offset;
            this.is_checked = is_checked;
        }
    }
    
    public CheckboxTextView() {
        Object(
            left_margin: 8,
            top_margin: 8, 
            right_margin: 8,
            bottom_margin: 8,
            wrap_mode: Gtk.WrapMode.WORD_CHAR
        );
    }
    
    construct {
        checkbox_widgets = new Gee.HashMap<Gtk.TextChildAnchor, CairoCheckbox>();
        buffer = get_buffer();
        
        // Handle user input for marker detection
        buffer.insert_text.connect((ref pos, new_text, new_text_length) => {
            // Store the current line number instead of the iterator
            int line_num = pos.get_line();
            
            // Schedule processing after insertion completes
            Idle.add(() => {
                if (!is_processing) {
                    process_markers_in_line(line_num);
                }
                return false;
            });
        });
    }
    
    // Process markers in a single line 
    private void process_markers_in_line(int line_num) {
        if (is_processing) return;
        is_processing = true;
        
        // Get line bounds
        Gtk.TextIter line_start, line_end;
        buffer.get_iter_at_line(out line_start, line_num);
        line_end = line_start;
        
        if (!line_end.ends_line()) {
            line_end.forward_to_line_end();
        }
        
        // Get line text
        string line_text = buffer.get_text(line_start, line_end, false);
        
        // Find markers in line
        var markers = new Gee.ArrayList<int>();
        for (int i = 0; i < line_text.length; i++) {
            char c = line_text[i];
            if ((c == '-' || c == '>') && is_standalone_marker(line_text, i)) {
                markers.add(i);
            }
        }
        
        // Process in reverse order
        markers.sort((a, b) => b - a);
        
        foreach (int offset in markers) {
            // Get fresh iterators
            Gtk.TextIter iter_start, iter_end;
            buffer.get_iter_at_line_offset(out iter_start, line_num, offset);
            iter_end = iter_start;
            iter_end.forward_char();
            
            // Check the character to determine checkbox state
            bool is_checked = buffer.get_text(iter_start, iter_end, false) == ">";
            
            // Delete the marker
            buffer.delete(ref iter_start, ref iter_end);
            
            // Add checkbox at this position
            add_checkbox_at_position(iter_start, is_checked);
        }
        
        is_processing = false;
    }
    
    // Determine if the character at position is a standalone marker
    private bool is_standalone_marker(string text, int pos) {
        char c = text[pos];
        if (c != '-' && c != '>') return false;
        
        // Check if surrounded by whitespace or at start/end of line
        bool start_ok = (pos == 0) || is_whitespace(text[pos-1]);
        bool end_ok = (pos == text.length-1) || is_whitespace(text[pos+1]);
        
        return start_ok && end_ok;
    }
    
    private void add_checkbox_at_position(Gtk.TextIter position, bool is_checked) {
        // Create anchor for the checkbox
        var anchor = buffer.create_child_anchor(position);
        
        // Create checkbox widget
        var checkbox = new CairoCheckbox(is_checked);
        
        // Add to the view
        add_child_at_anchor(checkbox, anchor);
        
        // Store in our dictionary
        checkbox_widgets[anchor] = checkbox;
    }
    
    private bool is_whitespace(char c) {
        return c == ' ' || c == '\t' || c == '\n' || c == '\r';
    }
    
    // Process all markers in the document
    public void process_all_markers() {
        if (is_processing) return;
        is_processing = true;
        
        // We'll process line by line
        int line_count = buffer.get_line_count();
        
        for (int line = 0; line < line_count; line++) {
            process_markers_in_line(line);
        }
        
        is_processing = false;
    }
    
    // Get all checkbox data - for saving
    public Gee.List<CheckboxData> get_checkbox_data() {
        var result = new Gee.ArrayList<CheckboxData>();
        
        Gtk.TextIter iter;
        buffer.get_start_iter(out iter);
        
        while (!iter.is_end()) {
            var anchor = iter.get_child_anchor();
            if (anchor != null && checkbox_widgets.has_key(anchor)) {
                result.add(new CheckboxData(
                    iter.get_line(),
                    iter.get_line_offset(),
                    checkbox_widgets[anchor].active
                ));
            }
            iter.forward_char();
        }
        
        return result;
    }
    
    // Add checkboxes from explicit data
    public void add_checkboxes_from_data(Gee.List<CheckboxData> checkbox_data) {
        if (is_processing) return;
        is_processing = true;
        
        // Clear existing checkboxes first
        foreach (var anchor in checkbox_widgets.keys.to_array()) {
            var widget = checkbox_widgets[anchor];
            widget.unparent();
        }
        checkbox_widgets.clear();
        
        // Add new checkboxes
        foreach (var data in checkbox_data) {
            // Get the iterator at the specified position
            Gtk.TextIter pos;
            
            try {
                buffer.get_iter_at_line_offset(out pos, data.line, data.offset);
                add_checkbox_at_position(pos, data.is_checked);
            } catch (Error e) {
                warning("Error adding checkbox: %s", e.message);
            }
        }
        
        is_processing = false;
    }
    
    // For compatibility with the original approach - get text with markers
    public string get_text_with_markers() {
        // Get a copy of the text
        Gtk.TextIter start, end;
        buffer.get_bounds(out start, out end);
        string text = buffer.get_text(start, end, true);
        
        // Collect all checkbox positions and states
        var positions = new Gee.ArrayList<CheckboxPosition>();
        
        Gtk.TextIter iter;
        buffer.get_start_iter(out iter);
        
        while (!iter.is_end()) {
            var anchor = iter.get_child_anchor();
            if (anchor != null && checkbox_widgets.has_key(anchor)) {
                positions.add(new CheckboxPosition(
                    iter.get_offset(),
                    checkbox_widgets[anchor].active
                ));
            }
            iter.forward_char();
        }
        
        // Sort positions in descending order
        positions.sort((a, b) => b.position - a.position);
        
        // Insert markers
        foreach (var pos in positions) {
            if (pos.position <= text.length) {
                string marker = pos.is_checked ? ">" : "-";
                text = text.substring(0, pos.position) + marker + text.substring(pos.position);
            }
        }
        
        return text;
    }
    
    // For compatibility with the original approach
    private class CheckboxPosition {
        public int position;
        public bool is_checked;
        
        public CheckboxPosition(int position, bool is_checked) {
            this.position = position;
            this.is_checked = is_checked;
        }
    }
    
    // For backward compatibility
    public void set_text_with_markers(string text_with_markers) {
        buffer.text = text_with_markers;
        process_all_markers();
    }
    
    // Toggle a marker at the current line
    public void toggle_line_marker(Gtk.TextIter iter) {
        Gtk.TextIter line_start = iter;
        line_start.set_line_offset(0);
        
        // Check if there's a checkbox at the beginning of this line
        var anchor = line_start.get_child_anchor();
        if (anchor != null && checkbox_widgets.has_key(anchor)) {
            // Toggle the checkbox state
            checkbox_widgets[anchor].active = !checkbox_widgets[anchor].active;
            return;
        }
        
        // If no checkbox exists, check if we have a text marker
        if (!line_start.ends_line()) {
            Gtk.TextIter next_char = line_start;
            next_char.forward_char();
            string first_char = buffer.get_text(line_start, next_char, false);
            
            if (first_char == ">" || first_char == "-") {
                // Replace with opposite state
                buffer.delete(ref line_start, ref next_char);
                
                bool is_checked = first_char == "-"; // Toggle state
                buffer.insert(ref line_start, is_checked ? ">" : "-", 1);
                
                // Process markers to convert to checkbox
                process_markers_in_line(line_start.get_line());
                
                // Clear selection
                Gtk.TextIter cursor_pos;
                buffer.get_iter_at_mark(out cursor_pos, buffer.get_insert());
                buffer.select_range(cursor_pos, cursor_pos);
                return;
            }
        }
        
        // If we get here, there's no marker or checkbox - add one
        line_start = iter;
        line_start.set_line_offset(0);
        buffer.insert(ref line_start, "-", 1); // Start with unchecked
        
        // Process to convert to checkbox
        process_markers_in_line(line_start.get_line());
        
        // Clear selection
        Gtk.TextIter cursor_pos;
        buffer.get_iter_at_mark(out cursor_pos, buffer.get_insert());
        buffer.select_range(cursor_pos, cursor_pos);
    }
}