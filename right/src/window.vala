public class Window : Gtk.ApplicationWindow {
    private Gtk.TextBuffer buffer;
    private Gtk.Label title_label;
    private Gtk.ScrolledWindow scrolled_window;
    private bool modified = false;
    private string window_title = "Right";
    private string last_search = "";
    private GtkSource.View source_view;
    private GtkSource.Buffer source_buffer;
    private SymbolSidebar symbol_tree;
    private Gtk.Box main_paned;
    private TerminalPanel terminal_panel;
    private Gtk.Box editor_terminal_box;

    // Unified search and replace toolbar
    private Gtk.SearchBar unified_search_bar;
    private Gtk.Entry search_entry;
    private Gtk.Box replace_box;
    private Gtk.Entry replace_entry;
    private bool replace_mode = false;

    // Undo/redo
    private GLib.Queue<TextOperation?> undo_stack;
    private GLib.Queue<TextOperation?> redo_stack;
    private bool ignore_changes = false;

    private struct TextOperation {
        public string text;
        public int start_pos;
        public int end_pos;
        public OperationType type;
    }

    private enum OperationType {
        INSERT,
        DELETE
    }

    public Window (Gtk.Application app) {
        Object (application: app);
        height_request = 600;
        width_request = 800;
        
        // Load CSS
        var provider = new Gtk.CssProvider();
        provider.load_from_resource("/com/example/right/style.css");
        
        // Apply CSS to the app
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        // Setup main toolbar that will also act as titlebar
        var toolbar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);

        // Close button on the left
        var close_button = new Gtk.Button ();
        close_button.add_css_class ("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.clicked.connect (() => {
            if (has_unsaved_changes () && !confirm_discard_changes ()) {
                return;
            }
            this.close ();
        });

        // Add close button first
        toolbar.append (close_button);

        // File menu
        var menu_bar = new GLib.Menu ();
        
        var file_menu = new GLib.Menu ();
        file_menu.append ("New", "app.new");
        file_menu.append ("Open", "app.open");
        file_menu.append ("Save", "app.save");
        file_menu.append ("Save As", "app.save_as");

        // Add recent files submenu
        var appl = (App) application;
        file_menu.append_submenu ("Recent Files", appl.get_recent_files_menu ());
        menu_bar.append_submenu("File", file_menu);

        // Edit menu
        var edit_menu = new GLib.Menu ();
        edit_menu.append ("Undo", "app.undo");
        edit_menu.append ("Redo", "app.redo");
        edit_menu.append ("Cut", "app.cut");
        edit_menu.append ("Copy", "app.copy");
        edit_menu.append ("Paste", "app.paste");
        edit_menu.append ("Select All", "app.select_all");
        menu_bar.append_submenu("Edit", edit_menu);

        // View menu (new)
        var view_menu = new GLib.Menu();
        view_menu.append ("Toggle Outline", "app.toggle_outline");
        view_menu.append ("Toggle Terminal", "app.toggle_terminal");
        menu_bar.append_submenu("View", view_menu);
        
        // Search menu
        var search_menu = new GLib.Menu ();
        search_menu.append ("Find", "app.find");
        search_menu.append ("Find Next", "app.find_next");
        search_menu.append ("Replace", "app.replace");
        menu_bar.append_submenu("Search", search_menu);

        // Add menu buttons
        var menubar = new Gtk.PopoverMenuBar.from_model(menu_bar);
        toolbar.append (menubar);

        // Create title label
        title_label = new Gtk.Label (window_title);
        title_label.hexpand = true;
        title_label.valign = Gtk.Align.CENTER;
        title_label.halign = Gtk.Align.START;

        // Add title label
        toolbar.append (title_label);

        // Wrap toolbar in a WindowHandle to make it draggable
        var winhandle = new Gtk.WindowHandle ();
        winhandle.set_child (toolbar);

        // Setup unified search bar
        setup_unified_search_bar ();

        // Setup text view
        setup_source_view ();

        scrolled_window = new Gtk.ScrolledWindow ();
        scrolled_window.vexpand = true;
        scrolled_window.hexpand = true;
        scrolled_window.set_child (source_view);

        editor_terminal_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        editor_terminal_box.append (scrolled_window);

        // Create terminal panel
        terminal_panel = new TerminalPanel ();
        terminal_panel.visible = false; // Hidden by default
        terminal_panel.vexpand = false;
        editor_terminal_box.append (terminal_panel);

        // Setup symbol tree view
        symbol_tree = new SymbolSidebar (source_view);
        symbol_tree.set_source_buffer (source_buffer);

        // Set minimal width for the symbol browser
        symbol_tree.set_size_request (200, -1);

        // Hide symbol tree by default - only show when relevant
        symbol_tree.visible = false;

        main_paned = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        main_paned.append (symbol_tree);
        main_paned.append (editor_terminal_box);

        // Main layout
        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.append (winhandle);
        vbox.append (unified_search_bar);
        vbox.append (main_paned);

        set_child (vbox);

        // Setup key bindings
        var controller = new Gtk.EventControllerKey ();
        controller.key_pressed.connect (on_key_pressed);
        source_view.add_controller (controller);

        // Initialize undo/redo
        setup_undo_redo ();

        // Set up the actions
        setup_actions ();
    }

    private void setup_unified_search_bar () {
        // Create unified search bar
        unified_search_bar = new Gtk.SearchBar ();
        unified_search_bar.add_css_class ("searchbar");
        unified_search_bar.set_search_mode (false);

        // Main container for all search bar content
        var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

        // Top box for search functionality
        var search_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        search_box.valign = Gtk.Align.CENTER;
        search_box.margin_start = search_box.margin_end = 4;

        // Search entry
        search_entry = new Gtk.Entry ();
        search_entry.valign = Gtk.Align.CENTER;
        search_entry.set_placeholder_text ("Search text...");
        search_entry.set_hexpand (true);
        search_entry.activate.connect (find_next);

        // Search buttons
        var find_prev_button = new Gtk.Button.with_label ("Prev");
        find_prev_button.valign = Gtk.Align.CENTER;
        find_prev_button.clicked.connect (find_previous);

        var find_next_button = new Gtk.Button.with_label ("Next");
        find_next_button.valign = Gtk.Align.CENTER;
        find_next_button.clicked.connect (find_next);

        // Close button
        var close_button = new Gtk.Button.from_icon_name ("window-close-symbolic");
        close_button.valign = Gtk.Align.CENTER;
        close_button.clicked.connect (() => {
            unified_search_bar.set_search_mode (false);
        });

        // Add everything to the search box
        search_box.append (search_entry);
        search_box.append (find_prev_button);
        search_box.append (find_next_button);
        search_box.append (close_button);

        // Bottom box for replace functionality
        replace_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        replace_box.valign = Gtk.Align.CENTER;
        replace_box.margin_start = replace_box.margin_end = 4;
        replace_box.margin_top = 4;
        replace_box.margin_bottom = 4;
        replace_box.visible = false; // Hidden by default

        // Replace entry
        replace_entry = new Gtk.Entry ();
        replace_entry.valign = Gtk.Align.CENTER;
        replace_entry.set_placeholder_text ("Replace with...");
        replace_entry.set_hexpand (true);

        // Replace buttons
        var replace_button = new Gtk.Button.with_label ("Replace");
        replace_button.valign = Gtk.Align.CENTER;
        replace_button.clicked.connect (replace_current);

        var replace_all_button = new Gtk.Button.with_label ("ReplAll");
        replace_all_button.valign = Gtk.Align.CENTER;
        replace_all_button.clicked.connect (replace_all);

        // Add everything to the replace box
        replace_box.append (replace_entry);
        replace_box.append (replace_button);
        replace_box.append (replace_all_button);

        // Stack everything in the main box
        main_box.append (search_box);
        main_box.append (replace_box);

        // Set the main box as the child of the unified search bar
        unified_search_bar.set_child (main_box);
    }

    private void setup_actions () {
        // Add toggle outline action
        var toggle_outline_action = new SimpleAction ("toggle_outline", null);
        toggle_outline_action.activate.connect (() => {
            if (symbol_tree.visible) {
                symbol_tree.visible = false;
            } else {
                symbol_tree.visible = true;
                // Update the symbol tree when showing
                symbol_tree.update_symbols ();
            }
        });
        ((Application) application).add_action (toggle_outline_action);

        var toggle_terminal_action = new SimpleAction ("toggle_terminal", null);
        toggle_terminal_action.activate.connect (() => {
            terminal_panel.visible = !terminal_panel.visible;

            // If showing the terminal and have a current file, set the working directory
            if (terminal_panel.visible) {
                var app = (App) application;
                if (app.get_current_file () != null) {
                    // Get parent directory (project directory)
                    var parent = app.get_current_file ().get_parent ();
                    if (parent != null) {
                        // Get grandparent directory
                        var grandparent = parent.get_parent ();
                        if (grandparent != null) {
                            string? dir_path = grandparent.get_path ();
                            if (dir_path != null) {
                                terminal_panel.set_working_directory (dir_path);
                            }
                        } else {
                            // If no grandparent, use parent
                            string? dir_path = parent.get_path ();
                            if (dir_path != null) {
                                terminal_panel.set_working_directory (dir_path);
                            }
                        }
                    }
                }
            }
        });
        ((Application) application).add_action (toggle_terminal_action);
    }

    public void toggle_terminal () {
        terminal_panel.visible = !terminal_panel.visible;
    }

    private void setup_source_view () {
        // Create source view for code editing
        source_view = new GtkSource.View ();
        source_buffer = new GtkSource.Buffer (null);
        source_view.set_buffer (source_buffer);

        var scheme_manager = GtkSource.StyleSchemeManager.get_default ();
        var scheme = scheme_manager.get_scheme ("varavara");
        source_buffer.set_style_scheme (scheme);

        // Configure source view for code editing
        source_view.set_monospace (true);
        source_view.set_show_line_numbers (true);
        source_view.set_auto_indent (true);
        source_view.set_indent_on_tab (true);
        source_view.set_insert_spaces_instead_of_tabs (true);
        source_view.set_tab_width (4);
        source_view.set_highlight_current_line (true);
        source_view.set_wrap_mode (Gtk.WrapMode.WORD_CHAR);

        // Enable smart backspace
        source_view.set_smart_backspace (true);

        // Show right margin at 80 characters
        source_view.set_show_right_margin (true);
        source_view.set_right_margin_position (80);

        // Make buffer use source_buffer methods
        buffer = source_buffer;

        // Disable bracket matching
        source_buffer.set_highlight_matching_brackets (false);

        // Make the cursor visible and enable overwrite mode
        source_view.set_cursor_visible (true);

        // Set up change monitoring
        buffer.changed.connect (() => {
            if (!modified) {
                modified = true;
                if (!title.has_prefix ("*")) {
                    title = "*" + title;
                }
            }
        });
    }

    // Search functions
    public void show_find_bar () {
        unified_search_bar.set_search_mode (true);
        replace_mode = false;
        replace_box.visible = false;
        search_entry.grab_focus ();

        // Pre-populate with current selection if any
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            search_entry.set_text (buffer.get_text (start, end, false));
        }
    }

    public void show_replace_bar () {
        unified_search_bar.set_search_mode (true);
        replace_mode = true;
        replace_box.visible = true;
        search_entry.grab_focus ();

        // Pre-populate with current selection if any
        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            search_entry.set_text (buffer.get_text (start, end, false));
        }
    }

    public void find_next () {
        find (true);
    }

    public void find_previous () {
        find (false);
    }

    private void find (bool forward) {
        string needle = search_entry.get_text ();
        if (needle == "")return;

        last_search = needle;

        Gtk.TextIter start_iter, match_start, match_end;
        buffer.get_iter_at_mark (out start_iter, buffer.get_insert ());

        // If we're searching forward, start from the end of current selection
        if (forward && buffer.get_selection_bounds (null, out start_iter)) {
            // Start from the end of the current selection
        }

        // If we're searching backward, start from the start of current selection
        if (!forward && buffer.get_selection_bounds (out start_iter, null)) {
            // Start from the beginning of the current selection
        }

        bool found;
        if (forward) {
            found = start_iter.forward_search (needle,
                                               Gtk.TextSearchFlags.CASE_INSENSITIVE,
                                               out match_start, out match_end, null);

            // If not found, wrap around to beginning
            if (!found) {
                buffer.get_start_iter (out start_iter);
                found = start_iter.forward_search (needle,
                                                   Gtk.TextSearchFlags.CASE_INSENSITIVE,
                                                   out match_start, out match_end, null);
            }
        } else {
            found = start_iter.backward_search (needle,
                                                Gtk.TextSearchFlags.CASE_INSENSITIVE,
                                                out match_start, out match_end, null);

            // If not found, wrap around to end
            if (!found) {
                buffer.get_end_iter (out start_iter);
                found = start_iter.backward_search (needle,
                                                    Gtk.TextSearchFlags.CASE_INSENSITIVE,
                                                    out match_start, out match_end, null);
            }
        }

        if (found) {
            buffer.select_range (match_start, match_end);
            source_view.scroll_to_mark (buffer.get_insert (), 0.25, false, 0.0, 0.5);
        }
    }

    private void replace_current () {
        string search_text = search_entry.get_text ();
        string replace_text = replace_entry.get_text ();

        if (search_text == "")return;

        Gtk.TextIter start, end;
        if (buffer.get_selection_bounds (out start, out end)) {
            string selected = buffer.get_text (start, end, false);
            if (selected.down () == search_text.down ()) {
                buffer.delete (ref start, ref end);
                buffer.insert (ref start, replace_text, -1);

                // Find the next occurrence
                find_next ();
            } else {
                // If the selection doesn't match, find first
                find_next ();
            }
        } else {
            // No selection, find first
            find_next ();
        }
    }

    private void replace_all () {
        string search_text = search_entry.get_text ();
        string replace_text = replace_entry.get_text ();

        if (search_text == "")return;

        // Start from the beginning
        Gtk.TextIter start_iter;
        buffer.get_start_iter (out start_iter);

        Gtk.TextIter match_start, match_end;
        bool found = true;
        int count = 0;

        // Start a single undo action for all replacements
        source_buffer.enable_undo = false;

        while (found) {
            found = start_iter.forward_search (search_text,
                                               Gtk.TextSearchFlags.CASE_INSENSITIVE,
                                               out match_start, out match_end, null);

            if (found) {
                buffer.delete (ref match_start, ref match_end);
                buffer.insert (ref match_start, replace_text, -1);
                start_iter = match_start;
                count++;
            }
        }

        source_buffer.enable_undo = true;

        // Show a message about replacements
        var dialog = new Gtk.AlertDialog ("");
        dialog.set_message ("Replace Complete");
        dialog.set_detail ("Replaced %d occurrences of \"%s\"".printf (count, search_text));
        dialog.set_modal (true);
        dialog.set_buttons ({ "OK" });

        dialog.choose.begin (this, null, (obj, res) => {
            try {
                dialog.choose.end (res);
            } catch (Error e) {
                // Ignore errors (like dismissal)
            }
        });
    }

    public void apply_syntax_highlighting (string file_path) {
        // Get the language based on file extension
        var manager = GtkSource.LanguageManager.get_default ();
        GtkSource.Language? language = null;
        bool supports_outline = false;

        // Determine language from file extension
        if (file_path.has_suffix (".vala") || file_path.has_suffix (".vapi")) {
            language = manager.get_language ("vala");
            supports_outline = true;
        } else if (file_path.has_suffix (".c") || file_path.has_suffix (".h")) {
            language = manager.get_language ("c");
            supports_outline = true;
        } else if (file_path.has_suffix (".cpp") || file_path.has_suffix (".hpp")) {
            language = manager.get_language ("cpp");
            supports_outline = true;
        } else if (file_path.has_suffix (".js")) {
            language = manager.get_language ("js");
            supports_outline = true;
        } else if (file_path.has_suffix (".py") || file_path.has_suffix (".build")) {
            language = manager.get_language ("python");
            supports_outline = true;
        } else if (file_path.has_suffix (".html") || file_path.has_suffix (".htm")) {
            language = manager.get_language ("html");
        } else if (file_path.has_suffix (".css")) {
            language = manager.get_language ("css");
        } else if (file_path.has_suffix (".xml")) {
            language = manager.get_language ("xml");
        } else if (file_path.has_suffix (".json")) {
            language = manager.get_language ("json");
        } else if (file_path.has_suffix (".md") || file_path.has_suffix (".markdown")) {
            language = manager.get_language ("markdown");
        } else if (file_path.has_suffix (".sh")) {
            language = manager.get_language ("sh");
        }

        // Apply the language
        source_buffer.set_language (language);

        // Apply style scheme
        var scheme_manager = GtkSource.StyleSchemeManager.get_default ();
        var scheme = scheme_manager.get_scheme ("varavara");
        source_buffer.set_style_scheme (scheme);

        // Only show outline for supported file types
        if (supports_outline) {
            refresh_symbols ();
            symbol_tree.visible = true;
        } else {
            symbol_tree.visible = false;
        }
    }

    private bool on_key_pressed (uint keyval, uint keycode, Gdk.ModifierType state) {
        bool ctrl_pressed = (state & Gdk.ModifierType.CONTROL_MASK) != 0;

        if (ctrl_pressed) {
            switch (keyval) {
            case Gdk.Key.f :
                show_find_bar ();
                return true;

            case Gdk.Key.h:
                show_replace_bar ();
                return true;

            case Gdk.Key.t:
                // Toggle terminal
                application.activate_action ("toggle_terminal", null);
                return true;

            case Gdk.Key.g:
                find_next ();
                return true;

            case Gdk.Key.s:
                application.activate_action ("save", null);
                return true;

            case Gdk.Key.r:
                refresh_symbols ();
                return true;
            }
        }

        if (keyval == Gdk.Key.F3) {
            find_next ();
            return true;
        } else if (keyval == Gdk.Key.Escape) {
            if (unified_search_bar.get_search_mode ()) {
                unified_search_bar.set_search_mode (false);
                replace_mode = false;
                replace_box.visible = false;
                source_view.grab_focus ();
                return true;
            }
        }

        return false;
    }

    public void refresh_symbols () {
        if (symbol_tree != null) {
            if (symbol_tree.visible) {
                symbol_tree.update_symbols ();
            }
        }
    }

    // File operation methods
    public void clear_text () {
        buffer.set_text ("", 0);
        reset_modified ();
    }

    public void set_text (string text) {
        buffer.set_text (text, text.length);
        refresh_symbols ();
    }

    public string get_text () {
        Gtk.TextIter start, end;
        buffer.get_bounds (out start, out end);
        return buffer.get_text (start, end, true);
    }

    public bool has_unsaved_changes () {
        return modified;
    }

    public void reset_modified () {
        modified = false;
        if (title.has_prefix ("*")) {
            title = title.substring (1);
        }
    }

    public void update_title (string? filename = null) {
        if (filename != null) {
            window_title = filename;
        } else {
            window_title = "Right";
        }

        title = window_title;
        title_label.label = window_title;
    }

    public bool confirm_discard_changes () {
        var dialog = new Gtk.AlertDialog ("");
        dialog.set_message ("Document has been modified.");
        dialog.set_detail ("Do you want to save your changes?");
        dialog.set_modal (true);
        dialog.set_buttons ({ "Save", "Discard", "Cancel" });
        dialog.set_cancel_button (2); // "Cancel" is button index 2
        dialog.set_default_button (0); // "Save" is button index 0

        int response = -1;
        bool completed = false;
        var save_action = application.lookup_action ("save");

        dialog.choose.begin (this, null, (obj, res) => {
            try {
                response = dialog.choose.end (res);

                if (response == 0) { // Save
                    save_action.activate (null);
                    completed = true;
                } else if (response == 1) { // Discard
                    completed = true;
                    this.close ();
                } else { // Cancel
                    completed = true;
                }
            } catch (Error e) {
                warning ("Error showing dialog: %s", e.message);
                completed = true;
            }
        });

        var main_context = MainContext.default ();
        while (!completed && main_context.pending ()) {
            main_context.iteration (true);
        }

        // Wait additional time for save to complete if needed
        if (response == 0) {
            for (int i = 0; i < 10 && main_context.pending (); i++) {
                main_context.iteration (true);
            }
        }

        return response == 0 || response == 1; // Return true for Save or Discard
    }

    // Edit operation methods
    private void setup_undo_redo () {
        undo_stack = new GLib.Queue<TextOperation?> ();
        redo_stack = new GLib.Queue<TextOperation?> ();

        buffer.insert_text.connect ((ref pos, text, len) => {
            if (ignore_changes)return;

            var operation = TextOperation ();
            operation.text = text;
            operation.start_pos = pos.get_offset ();
            operation.end_pos = pos.get_offset () + text.length;
            operation.type = OperationType.INSERT;

            undo_stack.push_head (operation);
            redo_stack.clear ();
        });

        buffer.delete_range.connect ((start, end) => {
            if (ignore_changes)return;

            var operation = TextOperation ();
            operation.start_pos = start.get_offset ();
            operation.end_pos = end.get_offset ();
            operation.text = buffer.get_text (start, end, true);
            operation.type = OperationType.DELETE;

            undo_stack.push_head (operation);
            redo_stack.clear ();
        });
    }

    public void undo () {
        if (undo_stack.is_empty ())return;

        ignore_changes = true;
        var operation = undo_stack.pop_head ();

        Gtk.TextIter start, end;

        if (operation.type == OperationType.INSERT) {
            buffer.get_iter_at_offset (out start, operation.start_pos);
            buffer.get_iter_at_offset (out end, operation.end_pos);
            buffer.delete (ref start, ref end);
        } else { // DELETE
            buffer.get_iter_at_offset (out start, operation.start_pos);
            buffer.insert (ref start, operation.text, operation.text.length);
        }

        redo_stack.push_head (operation);
        ignore_changes = false;
    }

    public void redo () {
        if (redo_stack.is_empty ())return;

        ignore_changes = true;
        var operation = redo_stack.pop_head ();

        Gtk.TextIter start, end;

        if (operation.type == OperationType.INSERT) {
            buffer.get_iter_at_offset (out start, operation.start_pos);
            buffer.insert (ref start, operation.text, operation.text.length);
        } else { // DELETE
            buffer.get_iter_at_offset (out start, operation.start_pos);
            buffer.get_iter_at_offset (out end, operation.end_pos);
            buffer.delete (ref start, ref end);
        }

        undo_stack.push_head (operation);
        ignore_changes = false;
    }

    public void cut () {
        Gdk.Clipboard clipboard = Gdk.Display.get_default ().get_clipboard ();
        source_view.buffer.cut_clipboard (clipboard, true);
    }

    public void copy () {
        Gdk.Clipboard clipboard = Gdk.Display.get_default ().get_clipboard ();
        source_view.buffer.copy_clipboard (clipboard);
    }

    public void paste () {
        Gdk.Clipboard clipboard = Gdk.Display.get_default ().get_clipboard ();
        source_view.buffer.paste_clipboard (clipboard, null, true);
    }

    public void select_all () {
        Gtk.TextIter start, end;
        buffer.get_bounds (out start, out end);
        buffer.select_range (start, end);
    }
}
