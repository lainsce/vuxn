using Gtk;
using GLib;

public class CalendarView : Gtk.Box {
    private Gtk.Box header;
    private Gtk.Box bottom_box;
    private Gtk.Box bottom_label_box;
    private Gtk.Grid day_grid;
    private int current_day;
    private int current_month;
    private int current_year;
    private EventManager event_manager;
    private EventEntry? current_event_entry = null;
    private int? current_event_day = null;
    private Gtk.Label today_event_label;
    private Gtk.DrawingArea background_area;
    private Theme.Manager theme;
    private Gtk.Label? window_title_label = null;
    private Gtk.ToggleButton? currently_selected_day = null;
    private Gtk.EventControllerKey? key_controller = null;

    public CalendarView () {
        this.orientation = Gtk.Orientation.VERTICAL;
        this.event_manager = EventManager.get_instance ();

        // Migrate any old format events to the new format
        event_manager.migrate_old_events (current_month, current_year);

        // Get current date
        var today = new DateTime.now_local ();
        current_day = today.get_day_of_month ();
        current_month = today.get_month ();
        current_year = today.get_year ();

        // Create the header part
        header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        header.margin_start = 8;
        header.margin_top = 2;
        header.margin_end = 5;
        header.homogeneous = true;
        this.append (header);

        // Create and add the day grid
        day_grid = new Gtk.Grid ();
        day_grid.add_css_class ("day-grid");
        day_grid.margin_start = 7;
        day_grid.margin_end = 7;
        day_grid.margin_bottom = 4;
        day_grid.vexpand = true;
        day_grid.hexpand = true;
        day_grid.column_homogeneous = true;
        day_grid.row_homogeneous = true;
        this.append (day_grid);

        // Container for the dog-ear and today's event
        bottom_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        bottom_label_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        bottom_label_box.margin_start = 32;
        bottom_label_box.margin_bottom = 8;

        // Create the background drawing area first
        background_area = new Gtk.DrawingArea () {
            valign = Gtk.Align.END,
            height_request = 34,
            hexpand = true
        };
        background_area.set_draw_func (draw_background);

	var click_controller = new Gtk.GestureClick ();
	click_controller.set_button (0); // Any button
	click_controller.released.connect ((n_press, x, y) => {
	    int height = background_area.get_height ();
	    double square_size = 20;

	    // Next month region (top-left dog-ear)
	    // Triangle with vertices at: (0, height-27), (square_size, height-27), (square_size, height-7)
	    if (x <= square_size && y >= (height - 27) && y <= (height - 7)) {
	        // Inside the bounding box, now check if inside the triangle
	        // Note: For a point to be in this triangle, it must be to the right of the line from 
	        // (0, height-27) to (square_size, height-7)
	        double diagonal_y = (height - 27) + ((27 - 7) * x / square_size);
	        
	        if (y <= diagonal_y) {
	            change_month (1); // Next month
	            return;
	        }
	    }
	    
	    // Previous month region - TRUE inverse triangle
	    // Triangle with vertices at: (0, height-27), (0, height-7), (square_size, height-7)
	    if (x <= square_size && y >= (height - 27) && y <= (height - 7)) {
	        // Inside the bounding box, now check if inside the triangle
	        // For a point to be in this triangle, it must be to the left of the diagonal line from
	        // (0, height-27) to (square_size, height-7)
	        double diagonal_y = (height - 27) + ((27 - 7) * x / square_size);
	        
	        if (y >= diagonal_y) {
	            change_month (-1); // Previous month
	            return;
	        }
            }
	});
	background_area.add_controller (click_controller);

        // Add label to show today's event
        today_event_label = new Gtk.Label ("");
        today_event_label.halign = Gtk.Align.START;
        today_event_label.hexpand = true;
        today_event_label.ellipsize = Pango.EllipsizeMode.END;
        today_event_label.add_css_class ("today-event");
        bottom_label_box.append (today_event_label);

        var overlay = new Gtk.Overlay ();
        overlay.set_child (background_area);
        overlay.add_overlay (bottom_label_box);

        bottom_box.append (overlay);

        this.append (bottom_box);

        // Populate the calendar with days (7 days per week)
        populate_calendar ();

        // Update today's event display
        update_today_event ();

        theme = Theme.Manager.get_default ();
        theme.theme_changed.connect (background_area.queue_draw);
    }

    private void draw_background (Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        // Fill with background color first
        Gdk.RGBA bg_color = theme.get_color ("theme_bg");
        Gdk.RGBA sel_color = theme.get_color ("theme_selection");
        Gdk.RGBA fg_color = theme.get_color ("theme_fg");
        double square_size = 20;
        cr.set_antialias (Cairo.Antialias.NONE);
        cr.set_line_width (1); // Use integer line width
        cr.set_line_cap (Cairo.LineCap.SQUARE);
        cr.set_line_join (Cairo.LineJoin.MITER);

        // Paint the entire background
        cr.set_source_rgba (bg_color.red, bg_color.green, bg_color.blue, 0);
        cr.paint ();

        // 1. Fill the dog-ear with background color (this creates the illusion of a fold)
        cr.set_source_rgb (sel_color.red, sel_color.green, sel_color.blue);
        cr.new_path (); // Clear the current path
        cr.move_to (0, height - 27);
        cr.line_to (square_size, height - 27);
        cr.line_to (square_size, height - 7);
        cr.close_path ();
        cr.fill ();

        // 2. Draw dog-ear outline
        cr.set_source_rgb (fg_color.red, fg_color.green, fg_color.blue);
        cr.new_path (); // Clear the current path
        cr.move_to (0, height - 27);
        cr.line_to (square_size, height - 27);
        cr.line_to (square_size, height - 7);
        cr.close_path ();
        cr.stroke ();

        // 3. Draw horizontal lines
        cr.new_path (); // Clear the current path
        cr.set_source_rgb (fg_color.red, fg_color.green, fg_color.blue);

        // Draw the line from dog-ear to right edge
        cr.move_to (square_size, height - 7);
        cr.line_to (width, height - 7);
        cr.stroke ();

        cr.move_to (0, height);
        cr.line_to (width, height);
        cr.stroke ();

        cr.move_to (0, height - 1);
        cr.line_to (width, height - 1);
        cr.stroke ();

        cr.move_to (0, height - 3);
        cr.line_to (width, height - 3);
        cr.stroke ();

        cr.move_to (0, height - 5);
        cr.line_to (width, height - 5);
        cr.stroke ();
    }

    public void set_title_label (Gtk.Label label) {
        window_title_label = label;
        update_title_label ();
    }

    private void update_title_label () {
        if (window_title_label == null) {
            return;
        }
        
        var today = new DateTime.now_local ();
        bool is_current_month = (today.get_year () == current_year && today.get_month () == current_month);
        
        if (is_current_month) {
            // Format: "Mon 04 Mar 2025" (use today's date)
            window_title_label.label = today.format ("%a %d %b %Y");
        } else {
            // Format: "Apr 2025" (use first day of the month we're viewing)
            var date = new DateTime.local (current_year, current_month, 1, 0, 0, 0);
            window_title_label.label = date.format ("%b %Y");
        }
    }

    public void update_today_event () {
        // Get today's date for proper comparison
        var today = new DateTime.now_local ();

        // Only show "Today's event" if we're viewing the current month and year
        if (today.get_month () == current_month && today.get_year () == current_year) {
            int today_day = today.get_day_of_month ();
            var today_event = event_manager.get_event_for_day (today_day, current_month, current_year);

            if (today_event != null && today_event != "") {
                today_event_label.label = today_event;
                today_event_label.visible = true;
            } else {
                today_event_label.label = "";
                today_event_label.visible = false;
            }
        } else {
            today_event_label.visible = false;
        }
    }

    private void setup_key_navigation() {
        // Remove any existing controller
        if (key_controller != null) {
            this.remove_controller(key_controller);
        }
        
        // Create a new key controller
        key_controller = new Gtk.EventControllerKey();
        key_controller.key_pressed.connect(on_key_pressed);
        this.add_controller(key_controller);
    }

    private bool on_key_pressed(Gtk.EventControllerKey controller, uint keyval, uint keycode, Gdk.ModifierType state) {
        if (currently_selected_day == null) {
            // If nothing is selected, select the first day when an arrow key is pressed
            if (keyval == Gdk.Key.Left || keyval == Gdk.Key.Right || 
                keyval == Gdk.Key.Up || keyval == Gdk.Key.Down) {
                // Find and select first visible day
                find_first_visible_day();
                return true;
            }
            return false;
        }
        
        // Handle arrow keys
        switch (keyval) {
            case Gdk.Key.Left:
                move_selection(-1, 0);
                return true;
                
            case Gdk.Key.Right:
                move_selection(1, 0);
                return true;
                
            case Gdk.Key.Up:
                move_selection(0, -1);
                return true;
                
            case Gdk.Key.Down:
                move_selection(0, 1);
                return true;
                
            case Gdk.Key.Return:
            case Gdk.Key.KP_Enter:
                // Trigger event entry for the currently selected day
                if (currently_selected_day != null) {
                    int day_value = (int) currently_selected_day.get_data<int>("day-value");
                    toggle_event_entry(day_value);
                }
                return true;
        }
        
        return false;
    }

    // Find the first day of the current month in the grid
    private void find_first_visible_day() {
        for (int row = 1; row < 7; row++) {
            for (int col = 0; col < 7; col++) {
                var child = day_grid.get_child_at(col, row);
                if (child != null && child is Gtk.ToggleButton) {
                    var button = (Gtk.ToggleButton) child;
                    bool is_current_month = button.get_data<bool>("is-current-month");
                    
                    if (is_current_month) {
                        button.set_active(true);
                        currently_selected_day = button;
                        button.grab_focus();
                        return;
                    }
                }
            }
        }
    }

    // Move selection in the specified direction
    private void move_selection(int x_offset, int y_offset) {
        if (currently_selected_day == null) {
            return;
        }
        
        // Find current position
        int current_row = -1;
        int current_col = -1;
        
        // Scan grid to find current button position
        for (int row = 1; row < 7; row++) {
            for (int col = 0; col < 7; col++) {
                var child = day_grid.get_child_at(col, row);
                if (child == currently_selected_day) {
                    current_row = row;
                    current_col = col;
                    break;
                }
            }
            if (current_row != -1) break;
        }
        
        if (current_row == -1 || current_col == -1) {
            return; // Couldn't find current position
        }
        
        // Try to find a valid cell to move to
        int new_row = current_row;
        int new_col = current_col;
        Gtk.ToggleButton? new_button = null;
        
        // We'll try up to 7 cells in the direction we're moving to find a current month day
        for (int attempt = 1; attempt <= 7; attempt++) {
            // Calculate new position
            if (x_offset != 0) {
                new_col = current_col + (x_offset * attempt);
            } else {
                new_row = current_row + (y_offset * attempt);
            }
            
            // Handle wrap-around for horizontal movement
            if (x_offset != 0) {
                while (new_col < 0) {
                    new_col += 7;
                    new_row--;
                }
                while (new_col > 6) {
                    new_col -= 7;
                    new_row++;
                }
            }
            
            // Check bounds
            if (new_row < 1 || new_row > 6 || new_col < 0 || new_col > 6) {
                break; // Out of bounds, stop trying
            }
            
            // Check if this cell contains a current month button
            var new_child = day_grid.get_child_at(new_col, new_row);
            if (new_child != null && new_child is Gtk.ToggleButton) {
                var button = (Gtk.ToggleButton) new_child;
                bool is_current_month = button.get_data<bool>("is-current-month");
                
                if (is_current_month) {
                    new_button = button;
                    break; // Found a valid button, stop searching
                }
            }
        }
        
        // If we found a valid button to move to, select it
        if (new_button != null) {
            currently_selected_day.set_active(false);
            new_button.set_active(true);
            currently_selected_day = new_button;
            new_button.grab_focus();
        }
    }

    public void populate_calendar () {
        // Clear existing days before redrawing
        Widget? child = day_grid.get_first_child ();
        while (child != null) {
            Widget? next = child.get_next_sibling ();
            child.unparent ();
            child = next;
        }

        Widget? child2 = header.get_first_child ();
        while (child2 != null) {
            Widget? next = child2.get_next_sibling ();
            child2.unparent ();
            child2 = next;
        }

        // First, add a row for day names (Monday, Tuesday, etc.)
        var today = new DateTime.now_local ();
        // In GLib: 1=Monday, 2=Tuesday, ... 7=Sunday
        int glib_day_of_week = today.get_day_of_week ();

        // Convert to our grid where days are arranged as:
        // 0=Sunday, 1=Monday, 2=Tuesday, ... 6=Saturday
        int current_weekday;
        if (glib_day_of_week == 7) {
            current_weekday = 0; // Sunday
        } else {
            current_weekday = glib_day_of_week; // Monday-Saturday
        }
        string[] day_names = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };
        for (int i = 0; i < 7; i++) {
            // Create a box for each day header
            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            header_box.margin_top = 6;
            header_box.margin_bottom = 6;
            header_box.halign = Gtk.Align.FILL;
            header_box.hexpand = true;

            // Add the day name (aligned left)
            var day_label = new Gtk.Label (day_names[i]);
            day_label.add_css_class ("day-header");
            day_label.halign = Gtk.Align.START;
            day_label.xalign = 0;
            header_box.append (day_label);

            // Add a spacer that expands to push the dot to the right
            var spacer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            spacer.hexpand = true;
            header_box.append (spacer);

            // Add a dot if this is the current day of the week (aligned right)
            var dot = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            dot.set_size_request (4, 4);
            dot.margin_end = 8;
            dot.halign = Gtk.Align.END;
            dot.valign = Gtk.Align.CENTER;

            // Only add the dot class if it's the current day of week
            if (i == current_weekday) {
                dot.add_css_class ("current-day-dot");
            }

            header_box.append (dot);

            header.append (header_box);
        }

        // Calculate dates for the current month
        int days_in_month = days_in_month (current_month, current_year);

        // Find what day of the week the 1st falls on (0=Sunday, 1=Monday, etc.)
        int first_day_position = day_of_week(current_year, current_month, 1);

        // Get today's date
        bool is_current_month = (today.get_year () == current_year && today.get_month () == current_month);

        // Draw the calendar - with days from previous month if needed
        int prev_month = current_month == 1 ? 12 : current_month - 1;
        int prev_year = current_month == 1 ? current_year - 1 : current_year;

        // Handle variable initialization differently to avoid function call in this context
        int days_in_prev_month;
        if (prev_month == 2) {
            bool is_leap = (prev_year % 4 == 0 && prev_year % 100 != 0) || (prev_year % 400 == 0);
            days_in_prev_month = is_leap ? 29 : 28;
        } else if (prev_month == 4 || prev_month == 6 || prev_month == 9 || prev_month == 11) {
            days_in_prev_month = 30;
        } else {
            days_in_prev_month = 31;
        }

        // For next month calculations
        int next_month = current_month == 12 ? 1 : current_month + 1;
        int next_year = current_month == 12 ? current_year + 1 : current_year;

        // Row 1 is for headers, so start at row 1
        for (int row = 1; row < 7; row++) {
            for (int col = 0; col < 7; col++) {
                int position = (row - 1) * 7 + col;
                Gtk.ToggleButton button = new Gtk.ToggleButton ();
                button.vexpand = true;
                button.hexpand = true;
                button.add_css_class ("mac-button");

                int display_day;
                bool is_current_month_day;
                int event_month, event_year;

                // Previous month's days
                if (position < first_day_position) {
                    display_day = days_in_prev_month - (first_day_position - position - 1);
                    is_current_month_day = false;
                    button.add_css_class ("other-month-day");
                    event_month = prev_month;
                    event_year = prev_year;
                }
                // Days after this month
                else if (position >= first_day_position + days_in_month) {
                    display_day = position - (first_day_position + days_in_month) + 1;
                    is_current_month_day = false;
                    button.add_css_class ("other-month-day");
                    event_month = next_month;
                    event_year = next_year;
                }
                // Current month's days
                else {
                    display_day = position - first_day_position + 1;
                    is_current_month_day = true;
                    event_month = current_month;
                    event_year = current_year;
                }

                // Create a vertical box to contain the day number and event text
                var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
                content_box.margin_start = 2;
                content_box.valign = Gtk.Align.START;
                content_box.vexpand = true;
                content_box.hexpand = true;

                // Top row for day number and dot
                var top_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
                top_row.valign = Gtk.Align.START;
                top_row.hexpand = true;

                var label = new Gtk.Label (display_day.to_string ());
                label.valign = Gtk.Align.START;
                label.xalign = 0;
                label.hexpand = true;
                top_row.append (label);

                // Add current day indicator
                if (is_current_month && is_current_month_day && display_day == today.get_day_of_month ()) {
                    button.add_css_class ("current-day");
                }

                content_box.append (top_row);

                // Check if this day has an event (for current, previous, or next month)
                var event_data = event_manager.get_event_for_day (display_day, event_month, event_year);

                // Add event text if this day has an event
                if (event_data != null) {
                    button.add_css_class ("has-event");

                    var event_label = new Gtk.Label (event_data);
                    event_label.halign = Gtk.Align.START;
                    event_label.valign = Gtk.Align.START;
                    event_label.wrap = true;
                    event_label.xalign = 0;
                    event_label.ellipsize = Pango.EllipsizeMode.END;
                    event_label.lines = 1;
                    event_label.max_width_chars = 9;
                    event_label.add_css_class ("event-text");

                    // Only add past class if the event is before today
                    if (is_current_month && display_day < today.get_day_of_month ()) {
                        event_label.add_css_class ("past");
                    }

                    // Add a different style for non-current month events
                    if (!is_current_month_day) {
                        event_label.add_css_class ("other-month-event");
                        event_label.remove_css_class ("past");
                        event_label.remove_css_class ("event-text");
                        button.remove_css_class ("has-event");
                        button.remove_css_class ("month-event");
                    }

                    content_box.append (event_label);
                    button.add_css_class ("month-event");
                }

                button.set_child (content_box);

                // Store the actual day, month, and year values in the button's data
                button.set_data ("day-value", display_day);
                button.set_data ("is-current-month", is_current_month_day);
                button.set_data ("month-value", event_month);
                button.set_data ("year-value", event_year);

                // Toggle button behavior
                button.toggled.connect (() => {
                    if (button.active) {
                        // Another button was active before, deactivate it
                        if (currently_selected_day != null && currently_selected_day != button) {
                            currently_selected_day.set_active(false);
                        }
                        
                        // Set this as the current button
                        currently_selected_day = button;
                        
                        // Focus the button
                        button.grab_focus();
                    } else {
                        // If this button is being deactivated and it was the selected one
                        if (currently_selected_day == button) {
                            currently_selected_day = null;
                        }
                    }
                });

                // Add mouse click handler separately
                button.clicked.connect(() => {
                    // On click, we still toggle the event entry for convenience
                    if (button.active) {
                        int day_value = (int) button.get_data<int>("day-value");
                        toggle_event_entry(day_value);
                    }
                });

                day_grid.attach (button, col, row, 1, 1);
            }
        }

        // Set up key navigation
        setup_key_navigation();

        // Update today's event display
        update_today_event ();
        
        // Update the title label
        update_title_label ();
    }

    // Helper method to get days in a month
    private int days_in_month (int month, int year) {
        switch (month) {
        case 2 :
            bool is_leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
            return is_leap ? 29 : 28;
        case 4 :
        case 6 :
        case 9 :
        case 11 :
            return 30;
        default:
            return 31;
        }
    }
    
    // Efficient day of week calculation by Tomohiko Sakamoto (0 = Sunday)
    private int day_of_week(int year, int month, int day) {
        int[] t = {0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4};
        year -= month < 3 ? 1 : 0;
        return (year + year/4 - year/100 + year/400 + t[month-1] + day) % 7;
    }

    private void toggle_event_entry (int day_num) {
        print ("Toggle event entry for day %d\n", day_num);

        // If we already have an event entry
        if (current_event_entry != null) {
            // If clicking the same day, remove the entry
            if (current_event_day == day_num) {
                print ("Closing entry for day %d (same day clicked)\n", day_num);
                current_event_entry.unparent ();
                today_event_label.set_parent (bottom_label_box);
                current_event_entry = null;
                current_event_day = null;
                return;
            }
            // Otherwise, remove the old entry before creating a new one
            else {
                print ("Removing previous entry for day %d before creating for day %d\n",
                       current_event_day, day_num);
                current_event_entry.unparent ();
                today_event_label.set_parent (bottom_label_box);
                current_event_entry = null;
                current_event_day = null;
            }
        }

        // Create a new event entry for the clicked day, passing month and year info
        print ("Creating new event entry for day %d\n", day_num);
        current_event_entry = new EventEntry (day_num, current_month, current_year, this);
        today_event_label.unparent ();
        current_event_day = day_num;
        current_event_entry.hexpand = true;

        bottom_label_box.append (current_event_entry);
    }

    public void event_entry_closed () {
        // Clear the references to the event entry
        current_event_entry = null;
        current_event_day = null;
        
        // Also untoggle the selected day button if there is one
        if (currently_selected_day != null) {
            currently_selected_day.set_active(false);
            currently_selected_day = null;
        }
        
        print ("Event entry references cleared\n");
    }

    private void change_month (int direction = 1) {
	if (direction > 0) {
	        // Go forward
	        if (current_month == 12) {
	            current_month = 1; // January after December
	            current_year++; // Increment the year when wrapping around
	        } else {
	            current_month++;
	        }
	    } else {
	        // Go backward
	        if (current_month == 1) {
	            current_month = 12; // December before January
	            current_year--; // Decrement the year when wrapping around
	        } else {
            current_month--;
	        }
    	}

        // Refresh the calendar display
        populate_calendar ();
        
        // Update the title label
        update_title_label ();
    }
}