/**
 * Main application file for Ronin LISP graphics environment
 */
public class RoninApp : Gtk.Application {
    // Theme manager instance
    private Theme.Manager theme_manager;

    public RoninApp () {
        Object (
                application_id: "com.example.ronin",
                flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void activate () {
        var window = new RoninWindow (this);
        window.present ();
    }

    protected override void startup () {
        base.startup ();

        // Register resource bundle
        try {
            var resource = Resource.load ("data/com.example.ronin.gresource");
            resources_register (resource);
        } catch (Error e) {
            warning ("Failed to register resource: %s", e.message);
        }

        // Initialize the theme manager
        theme_manager = Theme.Manager.get_default ();

        // Apply the theme to the display
        theme_manager.apply_to_display ();

        theme_manager.theme_changed.connect (() => {
            print ("Theme changed\n");
        });
    }

    public static int main (string[] args) {
        // Create and run the application
        var app = new RoninApp ();
        return app.run (args);
    }
}

public class RoninWindow : Gtk.ApplicationWindow {
    private Gtk.Box main_box;
    private Gtk.Box left_pane;
    private Gtk.DrawingArea canvas_area;
    private Gtk.TextView code_view;
    private Gtk.ScrolledWindow code_scrolled_window;
    private Gtk.DrawingArea status_bar_area;
    private Gtk.TextBuffer code_buffer;
    private bool show_guides = true;
    private string current_filename = "untitled.lisp";

    // Ronin context manages the drawing state
    private RoninContext ronin_context = null;
    // Lain LISP interpreter
    private Lain lain_interpreter = null;

    private unowned Theme.Manager theme_manager;

    public RoninWindow (RoninApp app) {
        Object (application: app);

        print ("Creating RoninWindow...\n");
        set_default_size (900, 600);
        set_title ("Ronin");

        // Get the theme manager instance
        theme_manager = Theme.Manager.get_default ();

        // Connect to theme change events to update UI
        theme_manager.theme_changed.connect (() => {
            // Queue a redraw of the canvas and status bar when theme changes
            canvas_area.queue_draw ();
            status_bar_area.queue_draw ();
        });

        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_resource ("/com/example/ronin/style.css");
            Gtk.StyleContext.add_provider_for_display (
                                                       display,
                                                       provider,
                                                       Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 10
            );
            print ("Loaded CSS from resources\n");
        } catch (Error e) {
            warning ("Failed to load CSS: %s", e.message);
        }

        // Initialize Ronin context for drawing operations first
        print ("Initializing RoninContext...\n");
        ronin_context = new RoninContext ();
        if (ronin_context == null) {
            print ("ERROR: Failed to create RoninContext!\n");
        } else {
            print ("RoninContext created successfully\n");
        }
        ronin_context.initialize_interop (this, application);

        // Create the UI
        print ("Creating UI...\n");
        create_ui ();

        // Setup and initialize the Lain interpreter second
        print ("Setting up Lain interpreter...\n");
        setup_interpreter ();

        // Setup keyboard shortcuts
        print ("Setting up shortcuts...\n");
        setup_shortcuts ();

        print ("RoninWindow initialization complete\n");
    }

    // Replace the setup_interpreter method in RoninWindow with this version

    private void setup_interpreter () {
        // Create a new Lain interpreter with Ronin builtin functions
        var lib = RoninLib.build_lib (ronin_context);
        lain_interpreter = new Lain (lib);

        // Initialize interop for native functions
        ronin_context.initialize_interop (this, application);

        // Try to load prelude.lisp from resources
        try {
            var prelude_bytes = resources_lookup_data (
                                                       "/com/example/ronin/prelude.lisp",
                                                       ResourceLookupFlags.NONE
            );

            if (prelude_bytes != null) {
                string prelude = (string) prelude_bytes.get_data ();

                // Set the prelude content in the TextView
                code_buffer.set_text (prelude, prelude.length);

                // Execute the prelude
                lain_interpreter.run (prelude);

                print ("Loaded prelude.lisp from resources\n");
            } else {
                print ("Prelude resource not found\n");

                // Fall back to local file if resource not found
                string local_prelude;
                if (FileUtils.get_contents ("prelude.lisp", out local_prelude)) {
                    // Set the prelude content in the TextView
                    code_buffer.set_text (local_prelude, local_prelude.length);

                    // Execute the prelude
                    lain_interpreter.run (local_prelude);

                    print ("Loaded prelude.lisp from local file\n");
                } else {
                    warning ("Failed to load prelude.lisp");
                }
            }
        } catch (Error e) {
            warning ("Failed to load prelude.lisp from resources: %s", e.message);

            // Fall back to local file if resource loading failed
            try {
                string local_prelude;
                if (FileUtils.get_contents ("prelude.lisp", out local_prelude)) {
                    // Set the prelude content in the TextView
                    code_buffer.set_text (local_prelude, local_prelude.length);

                    // Execute the prelude
                    lain_interpreter.run (local_prelude);

                    print ("Loaded prelude.lisp from local file\n");
                }
            } catch (Error e2) {
                warning ("Failed to load local prelude.lisp: %s", e2.message);
            }
        }
    }

    private void create_ui () {
        // Main horizontal pane with resizable splitter
        main_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);

        // Left side (code editor + status)
        left_pane = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        left_pane.set_size_request (300, -1);

        // Code editor
        code_view = new Gtk.TextView ();
        code_view.margin_top = 8;
        code_view.margin_end = 8;
        code_view.margin_bottom = 8;
        code_view.margin_start = 8;
        code_view.set_monospace (true);
        code_buffer = code_view.get_buffer ();
        code_view.add_css_class ("code-editor");

        // Scrolled window for code editor
        code_scrolled_window = new Gtk.ScrolledWindow ();
        code_scrolled_window.set_vexpand (true);
        code_scrolled_window.set_child (code_view);

        // Status bar
        status_bar_area = new Gtk.DrawingArea ();
        status_bar_area.set_content_height (40);
        status_bar_area.set_vexpand (false);
        status_bar_area.set_draw_func (draw_status);
        status_bar_area.add_css_class ("status-bar");

        left_pane.append (code_scrolled_window);
        left_pane.append (status_bar_area);

        // Canvas area (right side)
        canvas_area = new Gtk.DrawingArea ();
        canvas_area.set_hexpand (true);
        canvas_area.set_vexpand (true);
        canvas_area.set_draw_func (draw_canvas);
        canvas_area.add_css_class ("canvas-area");

        // Setup mouse interaction with canvas
        setup_canvas_controllers ();

        print ("Setting up timer for animation...\n");
        setup_timer ();

        // Add components to main paned layout
        main_box.append (left_pane);
        main_box.append (canvas_area);

        // Set the main paned as the window's child
        set_child (main_box);
    }

    private int64 get_monotonic_time () {
        return GLib.get_monotonic_time ();
    }

    private void setup_shortcuts () {
        // Create action group for keyboard shortcuts
        var actions = new SimpleActionGroup ();

        // Define actions from Ronin spec
        var action_new = new SimpleAction ("new", null);
        action_new.activate.connect (new_document);
        actions.add_action (action_new);

        var action_save = new SimpleAction ("save", null);
        action_save.activate.connect (save_document);
        actions.add_action (action_save);

        var action_export = new SimpleAction ("export", null);
        action_export.activate.connect (export_image);
        actions.add_action (action_export);

        var action_open = new SimpleAction ("open", null);
        action_open.activate.connect (open_document);
        actions.add_action (action_open);

        var action_toggle_guides = new SimpleAction ("toggle-guides", null);
        action_toggle_guides.activate.connect (() => {
            show_guides = !show_guides;
            canvas_area.queue_draw ();
        });
        actions.add_action (action_toggle_guides);

        var action_reindent = new SimpleAction ("reindent", null);
        action_reindent.activate.connect (reindent_code);
        actions.add_action (action_reindent);

        var action_clean = new SimpleAction ("clean", null);
        action_clean.activate.connect (clean_code);
        actions.add_action (action_clean);

        // Add the action group to the window with "win" prefix
        // This ensures the accelerators can find the actions
        this.insert_action_group ("win", actions);

        // Fix app access - use cast to Gtk.Application
        var gtk_app = (Gtk.Application) application;
        gtk_app.set_accels_for_action ("win.new", { "<Control>n" });
        gtk_app.set_accels_for_action ("win.save", { "<Control>s" });
        gtk_app.set_accels_for_action ("win.export", { "<Control>e" });
        gtk_app.set_accels_for_action ("win.open", { "<Control>u" });
        gtk_app.set_accels_for_action ("win.toggle-guides", { "<Control><Shift>h" });
        gtk_app.set_accels_for_action ("win.reindent", { "<Control><Shift>i" });
        gtk_app.set_accels_for_action ("win.clean", { "Escape" });
    }

    private void setup_timer () {
        // Create a timeout that triggers every 16ms (approximately 60fps)
        Timeout.add (16, () => {
            // Trigger frame event with current timestamp
            var args = new Gee.ArrayList<LispValue> ();
            args.add (new LispNumber (get_monotonic_time () / 1000.0)); // Time in milliseconds
            ronin_context.trigger_event ("frame", args);

            // Request redraw if there are active animations
            if (ronin_context.event_callbacks.contains ("frame") &&
                ronin_context.event_callbacks.get ("frame").size > 0) {
                canvas_area.queue_draw ();
            }

            return true; // Continue the timeout
        });
    }

    private void setup_canvas_controllers () {
        // Setup click gesture for canvas
        var click_controller = new Gtk.GestureClick ();
        click_controller.set_button (1); // Left button
        click_controller.pressed.connect ((n_press, x, y) => {
            handle_canvas_click (x, y);
        });
        canvas_area.add_controller (click_controller);

        // Setup right-click gesture for canvas
        var right_click_controller = new Gtk.GestureClick ();
        right_click_controller.set_button (3); // Right button
        right_click_controller.pressed.connect ((n_press, x, y) => {
            handle_canvas_right_click (x, y);
        });
        canvas_area.add_controller (right_click_controller);

        // Setup motion controller for canvas
        var motion_controller = new Gtk.EventControllerMotion ();
        motion_controller.motion.connect ((x, y) => {
            handle_canvas_motion (x, y);
        });
        canvas_area.add_controller (motion_controller);

        // Setup key controller for keyboard events
        var key_controller = new Gtk.EventControllerKey ();
        key_controller.key_pressed.connect ((keyval, keycode, state) => {
            return handle_canvas_key_press (keyval, keycode, state);
        });
        // Attach to left_pane as per user preference
        left_pane.add_controller (key_controller);
    }

    // Document operations
    private void new_document () {
        code_buffer.set_text ("", 0);
        current_filename = "untitled.lisp";
        ronin_context.clear ();
        canvas_area.queue_draw ();
        status_bar_area.queue_draw ();
    }

    private void save_document () {
        // Using simplified file dialog instead of deprecated FileChooserDialog
        var dialog = new Gtk.FileDialog ();
        dialog.set_title ("Save LISP File");
        var filter = new Gtk.FileFilter ();
        filter.set_filter_name ("LISP Files"); // Not set_name per preference
        filter.add_pattern ("*.lisp");

        var filters = new ListStore (typeof (Gtk.FileFilter));
        filters.append (filter);
        dialog.set_filters (filters);

        dialog.save.begin (this, null, (obj, res) => {
            try {
                var file = dialog.save.end (res);
                string filename = file.get_path ();

                Gtk.TextIter start, end;
                code_buffer.get_bounds (out start, out end);
                string code = code_buffer.get_text (start, end, true);

                FileUtils.set_contents (filename, code);
                current_filename = filename.substring (filename.last_index_of ("/") + 1);
                status_bar_area.queue_draw ();
            } catch (Error e) {
                if (!(e is IOError.CANCELLED)) {
                    show_error_message ("Error saving file: " + e.message);
                }
            }
        });
    }

    private void open_document () {
        // Using simplified file dialog instead of deprecated FileChooserDialog
        var dialog = new Gtk.FileDialog ();
        dialog.set_title ("Open LISP File");
        var filter = new Gtk.FileFilter ();
        filter.set_filter_name ("LISP Files"); // Not set_name per preference
        filter.add_pattern ("*.lisp");

        var filters = new ListStore (typeof (Gtk.FileFilter));
        filters.append (filter);
        dialog.set_filters (filters);

        dialog.open.begin (this, null, (obj, res) => {
            try {
                var file = dialog.open.end (res);
                string filename = file.get_path ();

                string content;
                FileUtils.get_contents (filename, out content);
                code_buffer.set_text (content, content.length);
                current_filename = filename.substring (filename.last_index_of ("/") + 1);
                status_bar_area.queue_draw ();
            } catch (Error e) {
                if (!(e is IOError.CANCELLED)) {
                    show_error_message ("Error opening file: " + e.message);
                }
            }
        });
    }

    private void export_image () {
        // Using simplified file dialog instead of deprecated FileChooserDialog
        var dialog = new Gtk.FileDialog ();
        dialog.set_title ("Export Image");
        var filter = new Gtk.FileFilter ();
        filter.set_filter_name ("PNG Files"); // Not set_name per preference
        filter.add_pattern ("*.png");

        var filters = new ListStore (typeof (Gtk.FileFilter));
        filters.append (filter);
        dialog.set_filters (filters);

        dialog.save.begin (this, null, (obj, res) => {
            try {
                var file = dialog.save.end (res);
                string filename = file.get_path ();
                // Use Ronin's export function
                ronin_context.export_image (filename);
            } catch (Error e) {
                if (!(e is IOError.CANCELLED)) {
                    show_error_message ("Error exporting image: " + e.message);
                }
            }
        });
    }

    private void run_code () {
        print ("run_code() called\n");

        // Get code from text buffer
        Gtk.TextIter start, end;
        code_buffer.get_bounds (out start, out end);
        string code = code_buffer.get_text (start, end, true);

        print ("Code to execute: %s\n", code);

        if (code.strip () == "") {
            print ("Empty code, nothing to run\n");
            return;
        }

        try {
            print ("Calling lain_interpreter.run()...\n");
            var result = lain_interpreter.run (code);
            print ("Interpreter result: %s\n", result != null ? result.to_string () : "null");

            print ("Queueing canvas redraw\n");
            canvas_area.queue_draw ();
            status_bar_area.queue_draw ();
        } catch (Error e) {
            print ("Error running code: %s\n", e.message);
            show_error_message ("Error running code: " + e.message);
        }

        print ("run_code() completed\n");
    }

    private void reindent_code () {
        // Simple reindentation - could be improved
        Gtk.TextIter start, end;
        code_buffer.get_bounds (out start, out end);
        string code = code_buffer.get_text (start, end, true);

        string indented = reindent_lisp (code);
        code_buffer.set_text (indented, indented.length);
    }

    private string reindent_lisp (string code) {
        var builder = new StringBuilder ();
        int depth = 0;
        bool in_string = false;
        bool in_comment = false;
        bool at_line_start = true;

        for (int i = 0; i < code.length; i++) {
            char c = code[i];

            // Handle strings (preserve exactly as-is)
            if (c == '"' && !in_comment) {
                in_string = !in_string;
                builder.append_c (c);
                at_line_start = false;
                continue;
            }

            if (in_string) {
                builder.append_c (c);
                if (c == '\n')at_line_start = true;
                continue;
            }

            // Handle comments (preserve them)
            if (c == ';' && !in_comment) {
                in_comment = true;
                builder.append_c (c);
                at_line_start = false;
                continue;
            }

            if (in_comment) {
                builder.append_c (c);
                if (c == '\n') {
                    in_comment = false;
                    at_line_start = true;
                }
                continue;
            }

            // Handle newlines
            if (c == '\n') {
                builder.append_c (c);
                at_line_start = true;
                continue;
            }

            // Add indentation at line start
            if (at_line_start) {
                for (int j = 0; j < depth * 2; j++) {
                    builder.append_c (' ');
                }
                at_line_start = false;
            }

            // Handle open paren - stay on same line
            if (c == '(') {
                builder.append_c (c);
                depth++;
                continue;
            }

            // Handle close paren - stay on same line
            if (c == ')') {
                builder.append_c (c);
                depth--;
                if (depth < 0)depth = 0;
                continue;
            }

            // Skip extra whitespace
            if (c.isspace ()) {
                // Only add a single space between tokens
                if (builder.str.length > 0 &&
                    !builder.str.get_char (builder.str.length - 1).isspace ()) {
                    builder.append_c (' ');
                }
                continue;
            }

            // Regular character
            builder.append_c (c);
        }

        return builder.str;
    }

    private void clean_code () {
        // Run the (clear) command via the interpreter
        try {
            lain_interpreter.run ("(clear)");
            canvas_area.queue_draw ();
        } catch (Error e) {
            warning ("Error running clear command: %s", e.message);
        }
    }

    private void show_error_message (string message) {
        // Using Gtk.AlertDialog instead of deprecated MessageDialog
        var dialog = new Gtk.AlertDialog (message);
        dialog.set_modal (true);
        dialog.set_buttons ({ "Close" });
        dialog.set_default_button (0);
        dialog.set_cancel_button (0);

        dialog.show (this);
    }

    // Canvas event handlers
    private void handle_canvas_click (double x, double y) {
        // Handle left click on canvas
        ronin_context.update_position (x, y);
        status_bar_area.queue_draw ();

        var args = new Gee.ArrayList<LispValue> ();
        args.add (new LispNumber (x));
        args.add (new LispNumber (y));
        ronin_context.trigger_event ("click", args);
    }

    private void handle_canvas_right_click (double x, double y) {
        // Handle right click on canvas - could be extended for $helpers with run
        // For example, if there's a $pos helper in the code, replace it with the current position
        Gtk.TextIter start, end;
        code_buffer.get_bounds (out start, out end);
        string code = code_buffer.get_text (start, end, true);

        if (code.contains ("$pos")) {
            code = code.replace ("$pos", @"(pos $x $y)");
            code_buffer.set_text (code, code.length);
        } else if (code.contains ("$circle")) {
            code = code.replace ("$circle", @"(circle $x $y 50)");
            code_buffer.set_text (code, code.length);
        }

        // More sophisticated helper replacement would be implemented here

        status_bar_area.queue_draw ();
    }

    private void handle_canvas_motion (double x, double y) {
        // Update mouse position in status bar
        ronin_context.update_mouse_position (x, y);
        status_bar_area.queue_draw ();

        double last_x = 0;
        double last_y = 0;
        if (Math.fabs (x - last_x) > 10 || Math.fabs (y - last_y) > 10) {
            var args = new Gee.ArrayList<LispValue> ();
            args.add (new LispNumber (x));
            args.add (new LispNumber (y));
            ronin_context.trigger_event ("move", args);

            last_x = x;
            last_y = y;
        }
    }

    private bool handle_canvas_key_press (uint keyval, uint keycode, Gdk.ModifierType state) {
        // Backup for Ctrl+Return or Ctrl+r to run code
        if ((keyval == Gdk.Key.Return || keyval == Gdk.Key.r) &&
            (state & Gdk.ModifierType.CONTROL_MASK) != 0) {
            run_code ();
            return true; // Handled
        }

        var args = new Gee.ArrayList<LispValue> ();
        args.add (new LispNumber (keyval));
        ronin_context.trigger_event ("key", args);

        // Return false to allow event propagation to other handlers
        return false;
    }

    // Drawing functions
    private void draw_canvas (Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        // Draw Ronin context content
        ronin_context.draw (cr, width, height);

        // Draw guides if enabled
        if (show_guides) {
            draw_guides (cr, width, height);
        }
    }

    private void draw_guides (Cairo.Context cr, int width, int height) {
        // Draw a grid or other guide elements
        cr.set_line_width (1.0);
        cr.set_antialias (Cairo.Antialias.NONE); // Per user preference
        cr.set_source_rgba (0.5, 0.5, 0.5, 0.1);

        // Draw grid
        int grid_size = 20;
        for (int x = 0; x < width; x += grid_size) {
            cr.move_to (x + 0.5, 0); // 0.5 offset for pixel-perfect lines
            cr.line_to (x + 0.5, height);
        }
        for (int y = 0; y < height; y += grid_size) {
            cr.move_to (0, y + 0.5); // 0.5 offset for pixel-perfect lines
            cr.line_to (width, y + 0.5);
        }
        cr.stroke ();
    }

    private void draw_status (Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        // Clear background
        cr.set_source_rgba (1.0, 1.0, 1.0, 0.0);
        cr.paint ();

        cr.select_font_face ("Log", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        cr.set_font_size (16);
        cr.set_source_rgb (0.0, 0.0, 0.0);

        // Top status line
        cr.move_to (4, 18);
        cr.show_text (ronin_context.get_status_text ());

        // Bottom status line with cursor position
        cr.move_to (4, 36);
        cr.show_text (ronin_context.get_position_text ());

        // Filename display
        Cairo.TextExtents extents;
        cr.text_extents (current_filename, out extents);
        cr.move_to (width - extents.width - 4, 36);
        cr.show_text (current_filename);
    }
}
