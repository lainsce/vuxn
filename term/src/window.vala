public class Window : He.ApplicationWindow {
    private Gtk.Box root_box;
    private Vte.Terminal terminal;
    private Theme.Manager theme;
    private Gtk.EventControllerKey key_controller;

    public Window(He.Application app) {
        GLib.Object(application: app);
        
        
        // Enable/disable copy based on selection
        var copy_action = new GLib.SimpleAction ("copy", null);
        copy_action.activate.connect (() => {
            if (terminal.get_has_selection ()) {
                terminal.copy_clipboard_format (Vte.Format.TEXT);
            }
        });

        var paste_action = new GLib.SimpleAction ("paste", null);
        paste_action.activate.connect (() => {
            terminal.paste_clipboard ();
        });

        // Register actions on the app
        app.add_action (copy_action);
        app.add_action (paste_action);
    }

    construct {
        theme = Theme.Manager.get_default();
        setup_window();
        setup_terminal();
        setup_keyboard_shortcuts();
        setup_context_menu ();
    }

    private void setup_window() {
        title = "Term";
        default_width = 640;
        default_height = 480;

        root_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        root_box.prepend(Utils.create_mac_titlebar(title, this));
        set_child(root_box);
    }

    private void setup_terminal() {
        terminal = new Vte.Terminal();
        terminal.margin_start = terminal.margin_end = terminal.margin_bottom = 2;
        terminal.set_vexpand(true);
        terminal.set_hexpand(true);
        root_box.append(terminal);

        Utils.setup_terminal_appearance(terminal, theme);
        theme.theme_changed.connect(() => {
            Utils.setup_terminal_appearance(terminal, theme);
        });
        Utils.spawn_terminal_process(terminal);
        
        // Connect to terminal size changes to adjust window size
        var size_controller = new Gtk.EventControllerMotion();
        terminal.add_controller(size_controller);
        size_controller.motion.connect(() => {
            constrain_window_to_terminal();
        });
    }
    
    private void setup_keyboard_shortcuts () {
        key_controller = new Gtk.EventControllerKey ();
        terminal.add_controller (key_controller);

        key_controller.key_pressed.connect ((keyval, keycode, state) => {
            // Require Ctrl + Shift modifiers
            bool ctrl_shift = ((state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK)) ==
                               (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.SHIFT_MASK));

            if (!ctrl_shift)
                return false;

            // Ctrl+Shift+C (copy)
            if (keyval == Gdk.Key.c) {
                if (terminal.get_has_selection ()) {
                    terminal.copy_clipboard_format (Vte.Format.TEXT);
                    return true;
                }
            }

            // Ctrl+Shift+V (paste)
            if (keyval == Gdk.Key.v) {
                terminal.paste_clipboard ();
                return true;
            }

            return false;
        });
    }
    
    private void setup_context_menu () {
        var gesture = new Gtk.GestureClick () {
          button = Gdk.BUTTON_SECONDARY,
        };
        
        gesture.pressed.connect (show_terminal_context_menu);

        terminal.add_controller (gesture);
    }
    
    private void show_terminal_context_menu (int n_pressed, double x, double y) {
        var menu = new Menu ();
        var edit_section = new Menu ();

        edit_section.append (_("Copy"), "app.copy");
        edit_section.append (_("Paste"), "app.paste");
        menu.append_section (null, edit_section);

        var pop = new Gtk.PopoverMenu.from_model (menu);

        Gdk.Rectangle r = { 0 };

        r.x = (int) (x);
        r.y = (int) (y);

        pop.closed.connect_after (() => {
          pop.destroy ();
        });

        pop.set_parent (terminal);
        pop.set_has_arrow (false);
        pop.set_pointing_to (r);
        pop.popup ();
    }
    
    private void constrain_window_to_terminal() {
        // Get the terminal's column and row count
        long column_count = terminal.get_column_count();
        long row_count = terminal.get_row_count();
        
        // Get character cell dimensions
        int char_width = (int)terminal.get_char_width();
        int char_height = (int)terminal.get_char_height();
        
        // Calculate the terminal's pixel requirements (add a small margin)
        int term_width = (int)(column_count * char_width) + terminal.margin_start + terminal.margin_end + 4;
        int term_height = (int)(row_count * char_height) + terminal.margin_bottom + 4;
        
        // Get the window's non-terminal content sizes
        int titlebar_height = root_box.get_first_child().get_allocated_height();
        
        // Set minimum window size to fit the terminal exactly
        set_size_request(term_width, term_height + titlebar_height);
    }
}