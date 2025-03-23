public class App : He.Application {
    private File? current_file = null;
    private Theme.Manager theme;
    private Menu recent_files_menu; // Added for recent files
    private RecentFilesManager recent_files_manager;

    public App () {
        Object (
                application_id : "com.example.Right"
        );
    }

    protected override void startup () {
        Gdk.RGBA accent_color = { 0 };
        accent_color.parse ("#000");
        default_accent_color = { accent_color.red* 255, accent_color.green* 255, accent_color.blue* 255 };
        override_accent_color = true;
        is_content = true;

        resource_base_path = "/com/example/Right";

        // Add actions
        add_action_entries (get_action_entries (), this);

        // Initialize recent files manager
        recent_files_manager = RecentFilesManager.get_default();
        
        // Initialize recent files menu
        recent_files_menu = new Menu ();
        update_recent_files_menu ();

        base.startup ();
    }

    private ActionEntry[] get_action_entries () {
        ActionEntry[] entries = {
            // File menu actions
            { "new", action_new },
            { "open", action_open },
            { "save", action_save },
            { "save_as", action_save_as },
            { "open-recent", action_open_recent, "s" }, // Added for recent files

            // Edit menu actions
            { "undo", action_undo },
            { "redo", action_redo },
            { "cut", action_cut },
            { "copy", action_copy },
            { "paste", action_paste },
            { "select_all", action_select_all },

            // Search actions
            { "find", action_find },
            { "find_next", action_find_next },
            { "replace", action_replace },

            // View actions (for the terminal)
            { "toggle_terminal", action_toggle_terminal },
            { "toggle_outline", action_toggle_outline }
        };

        return entries;
    }

    // Added action for terminal toggle
    private void action_toggle_terminal() {
        var window = get_active_window() as Window;
        if (window != null) {
            window.toggle_terminal();
        }
    }
    
    // Added action for outline toggle
    private void action_toggle_outline() {
        // Toggle outline is already handled in Window class
    }

    // File menu action handlers
    private void action_new () {
        var window = get_active_window () as Window;
        if (window != null) {
            if (window.has_unsaved_changes () && !window.confirm_discard_changes ()) {
                return;
            }
            window.clear_text ();
            current_file = null;
            window.update_title ();
        }
    }

    private void action_open () {
        var window = get_active_window () as Window;
        if (window != null) {
            if (window.has_unsaved_changes () && !window.confirm_discard_changes ()) {
                return;
            }

            var file_dialog = new Gtk.FileDialog ();
            file_dialog.set_title ("Open File");

            file_dialog.open.begin (window, null, (obj, res) => {
                try {
                    File file = file_dialog.open.end (res);
                    if (open_file(file)) {
                        current_file = file;
                    }
                } catch (Error e) {
                    // User canceled or error occurred
                    if (!(e is Gtk.DialogError.DISMISSED)) {
                        Utils.show_info_dialog(window, "Error Opening File", 
                            "An error occurred while opening the file: " + e.message);
                    }
                }
            });
        }
    }

    private void action_save () {
        var window = get_active_window () as Window;
        if (window != null) {
            if (current_file == null) {
                action_save_as ();
            } else {
                string path = current_file.get_path();
                if (path != null) {
                    save_file(path);
                } else {
                    action_save_as();
                }
            }
        }
    }

    private void action_save_as () {
        var window = get_active_window () as Window;
        if (window != null) {
            var file_dialog = new Gtk.FileDialog ();
            file_dialog.set_title ("Save File");

            if (current_file != null) {
                file_dialog.set_initial_file (current_file);
            }

            file_dialog.save.begin (window, null, (obj, res) => {
                try {
                    File file = file_dialog.save.end (res);
                    string path = file.get_path();
                    if (path != null && save_file(path)) {
                        current_file = file;
                    }
                } catch (Error e) {
                    // User canceled or error occurred
                    if (!(e is Gtk.DialogError.DISMISSED)) {
                        Utils.show_info_dialog(window, "Error Saving File", 
                            "An error occurred while saving the file: " + e.message);
                    }
                }
            });
        }
    }

    // Added for recent files
	private void action_open_recent (SimpleAction action, Variant? parameter) {
	    if (parameter == null) return;
	
	    string file_path = parameter.get_string ();
	    var window = get_active_window () as Window;
	
	    if (window != null) {
	        if (window.has_unsaved_changes () && !window.confirm_discard_changes ()) {
	            return;
	        }
	
	        // Check if file exists before trying to open it
	        var file = File.new_for_path (file_path);
	        try {
	            if (!file.query_exists ()) {
	                Utils.show_info_dialog(window, "File Not Found", 
	                    "The file '%s' could not be found.".printf(file_path));
	
	                // Remove the non-existent file from recent files
	                recent_files_manager.remove_file (file_path);
	                
	                // Schedule menu update for later to avoid hanging
	                Idle.add(() => {
	                    update_recent_files_menu();
	                    return false; // Run once
	                });
	                
	                return;
	            }
	            
	            // File exists, open it
	            if (open_file(file)) {
	                current_file = file;
	            }
	            
	        } catch (Error e) {
	            Utils.show_info_dialog(window, "Error", 
	                "Error checking file: %s".printf(e.message));
	        }
	    }
	}
	
	private void update_recent_files_for_path(string path) {
	    // Add to recent files
	    recent_files_manager.add_file(path);
	    
	    // Schedule menu update for later to avoid hanging
	    Idle.add(() => {
	        update_recent_files_menu();
	        return false; // Run once
	    });
	}


    // Edit menu action handlers
    private void action_undo () {
        var window = get_active_window () as Window;
        if (window != null) {
            window.undo ();
        }
    }

    private void action_redo () {
        var window = get_active_window () as Window;
        if (window != null) {
            window.redo ();
        }
    }

    private void action_cut () {
        var window = get_active_window () as Window;
        if (window != null) {
            window.cut ();
        }
    }

    private void action_copy () {
        var window = get_active_window () as Window;
        if (window != null) {
            window.copy ();
        }
    }

    private void action_paste () {
        var window = get_active_window () as Window;
        if (window != null) {
            window.paste ();
        }
    }

    private void action_select_all () {
        var window = get_active_window () as Window;
        if (window != null) {
            window.select_all ();
        }
    }

    // Search actions
    private void action_find () {
        var window = get_active_window () as Window;
        if (window != null) {
            window.show_find_bar ();
        }
    }

    private void action_find_next () {
        var window = get_active_window () as Window;
        if (window != null) {
            window.find_next ();
        }
    }

    private void action_replace () {
        var window = get_active_window () as Window;
        if (window != null) {
            window.show_replace_bar ();
        }
    }

    // Added for recent files
    private async void update_recent_files_menu () {
	    // Clear existing items
	    while (recent_files_menu.get_n_items () > 0) {
	        recent_files_menu.remove (0);
	    }
	
	    unowned List<string> recent_files = recent_files_manager.get_recent_files ();
	
	    if (recent_files.length () == 0) {
	        // Add a disabled "No Recent Files" item
	        var item = new MenuItem ("No Recent Files", null);
	        item.set_attribute ("action-enabled", "b", false);
	        recent_files_menu.append_item (item);
	    } else {
	        // Add each recent file to the menu, but limit file checking
	        int count = 0;
	        foreach (string file_path in recent_files) {
	            if (count >= 5) break; // Limit to 5 items to avoid excessive file checking
	            
	            // Create a simpler menu item without checking file existence
	            // We'll verify existence only when the user actually selects the item
	            var basename = Path.get_basename(file_path);
	            var action_name = "app.open-recent";
	            var target = new Variant.string (file_path);
	
	            var item = new MenuItem (basename, null);
	            item.set_action_and_target_value (action_name, target);
	            
	            recent_files_menu.append_item (item);
	            count++;
	        }
	    }
	}

    // Getter for recent files menu
    public Menu get_recent_files_menu () {
        return recent_files_menu;
    }

    // Getter for current file
    public File? get_current_file () {
        return current_file;
    }

    // Helper methods
	private bool open_file (File file) {
	    var window = get_active_window () as Window;
	    if (window == null) {
	        return false;
	    }
	
	    try {
	        string path = file.get_path ();
	        if (path == null) {
	            return false;
	        }
	
	        string content;
	        bool load_success = Utils.load_from_file_improved (path, out content);
	        
	        if (!load_success) {
	            Utils.show_info_dialog (window, "Open Failed", 
	                "Could not open the file. The file might be corrupted or you may not have permission to read it.");
	            return false;
	        }
	
	        window.set_text (content);
	        window.reset_modified ();
	        window.update_title (get_basename (path));
	        window.apply_syntax_highlighting (path);
	        
	        // Use non-blocking update for recent files
	        update_recent_files_for_path(path);
	        
	        return true;
	    } catch (Error e) {
	        Utils.show_info_dialog (window, "Error Opening File", 
	            "An error occurred while opening the file: " + e.message);
	        return false;
	    }
	}

	private bool save_file (string path) {
	    var window = get_active_window () as Window;
	    if (window == null) {
	        return false;
	    }
	
	    string content = window.get_text ();
	    bool success = Utils.save_to_file (path, content);
	    
	    if (success) {
	        window.reset_modified ();
	        window.update_title (get_basename (path));
	        window.apply_syntax_highlighting (path);
	        
	        // Use non-blocking update for recent files
	        update_recent_files_for_path(path);
	        
	        return true;
	    } else {
	        // Show error dialog if save failed
	        Utils.show_info_dialog (window, "Save Failed", 
	            "Could not save the file. Please check if you have write permissions or if the disk is full.");
	        return false;
	    }
	}

    private string get_basename (string path) {
        return Path.get_basename (path);
    }

    public override void activate () {
        var window = new Window (this);
        window.present ();
        theme = Theme.Manager.get_default ();
        theme.apply_to_display ();
        setup_theme_management ();
    }

    private void setup_theme_management () {
        // Force initial theme load
        var theme_file = Path.build_filename (Environment.get_home_dir (), ".theme");

        // Set up the check
        GLib.Timeout.add (40, () => {
            if (FileUtils.test (theme_file, FileTest.EXISTS)) {
                try {
                    theme.load_theme_from_file (theme_file);
                } catch (Error e) {
                    warning ("Theme load failed: %s", e.message);
                }
            }
            return true; // Continue the timeout
        });
    }

    public static int main (string[] args) {
        var app = new App ();
        return app.run (args);
    }
}