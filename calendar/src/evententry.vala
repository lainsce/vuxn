public class EventEntry : Gtk.Box {
    private Gtk.Entry event_entry;
    private int day_num;
    private int month_num;
    private int year_num;
    private EventManager event_manager;
    private CalendarView parent_view;
    private uint delayed_save_source_id = 0;

    public EventEntry (int day_num, int month_num, int year_num, CalendarView parent_view) {
        this.orientation = Gtk.Orientation.HORIZONTAL;
        this.day_num = day_num;
        this.month_num = month_num;
        this.year_num = year_num;
        this.event_manager = EventManager.get_instance ();
        this.parent_view = parent_view;

        // Create a single-line entry for event text
        event_entry = new Gtk.Entry ();
        event_entry.valign = Gtk.Align.START;
        event_entry.add_css_class ("mac-entry");
	event_entry.get_first_child ().valign = Gtk.Align.START;
        event_entry.get_first_child ().margin_top = 5;

        // Check if there's an existing event for this day
        string? existing_event = event_manager.get_event_for_day (day_num, month_num, year_num);
        if (existing_event != null) {
            event_entry.text = existing_event;
        }

        this.append (event_entry);

        // Connect to the changed signal - but use debouncing
        event_entry.changed.connect (() => {
            // Cancel any previous delayed save
            if (delayed_save_source_id > 0) {
                Source.remove (delayed_save_source_id);
                delayed_save_source_id = 0;
            }

            // Set a new delayed save (500ms after typing stops)
            delayed_save_source_id = Timeout.add (500, () => {
                save_current_text ();
                delayed_save_source_id = 0;
                return Source.REMOVE;
            });
        });

        // Save immediately when Enter is pressed and close the entry
        event_entry.activate.connect (() => {
            // Cancel any pending delayed save
            if (delayed_save_source_id > 0) {
                Source.remove (delayed_save_source_id);
                delayed_save_source_id = 0;
            }

            // Save the current text
            save_current_text ();

            // Always remove the entry when Enter is pressed (whether empty or not)
            print ("Enter pressed - hiding event entry\n");
            this.unparent ();

            // Also tell the CalendarView that the entry is now closed
            parent_view.event_entry_closed ();
        });

        // In GTK4, use notify::has-focus to detect focus changes
        event_entry.notify["has-focus"].connect (() => {
            // If the entry loses focus
            if (!event_entry.has_focus) {
                // Cancel any pending delayed save
                if (delayed_save_source_id > 0) {
                    Source.remove (delayed_save_source_id);
                    delayed_save_source_id = 0;
                }

                save_current_text ();
            }
        });

        // Set focus to the entry when it's created
        event_entry.grab_focus ();
    }

    private void save_current_text () {
        string text = event_entry.text.strip ();

        // Save the current text with year, month, day information
        event_manager.set_event_for_day (day_num, month_num, year_num, text);

        // Always update the calendar to reflect changes
        parent_view.populate_calendar ();

        // Update today event display
        parent_view.update_today_event ();
    }

    public override void dispose () {
        // Ensure any pending save is completed when the widget is destroyed
        if (delayed_save_source_id > 0) {
            Source.remove (delayed_save_source_id);
            save_current_text ();
        }

        base.dispose ();
    }
}
