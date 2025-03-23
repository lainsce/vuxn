public class TerminalPanel : Gtk.Box {
    private Vte.Terminal terminal;
    private string current_working_directory;
    private Theme.Manager theme;

    public signal void close_requested ();

    public TerminalPanel () {
        Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);

        // Create terminal
        terminal = new Vte.Terminal ();
        terminal.hexpand = true;
        terminal.set_size_request (-1, 200);  // Set height to 200 pixels, not half the window
        terminal.vexpand = false;

        // Set terminal options
        terminal.set_cursor_blink_mode (Vte.CursorBlinkMode.SYSTEM);
        terminal.set_scroll_on_output (false);
        terminal.set_scroll_on_keystroke (true);

        // Set the terminal font to Monaco 12px
        var font_desc = Pango.FontDescription.from_string ("Monaco 9");
        terminal.set_font (font_desc);

        // You might need to adjust colors for better visibility with Monaco
        // Get theme colors (BG and FG are inverted for style purposes)
        Gdk.RGBA fg_color = theme.get_color ("theme_fg");
        Gdk.RGBA bg_color = theme.get_color ("theme_bg");
        Gdk.RGBA accent_color = theme.get_color ("theme_accent");
        Gdk.RGBA sel_color = theme.get_color ("theme_selection");

        terminal.set_font (font_desc);
        terminal.set_colors (
                             fg_color, // Foreground (black)
                             bg_color, // Background (white)
        {
            bg_color, // Black
            accent_color, // Red (#FF6622)
            sel_color, // Cyan (#75DEC2)
            accent_color, // Red (#FF6622)
            sel_color, // Cyan (#75DEC2)
            accent_color, // Red (#FF6622)
            sel_color, // Cyan (#75DEC2)
            accent_color, // Red (#FF6622)
            sel_color, // Cyan (#75DEC2)
            sel_color, // Cyan (#75DEC2)
            sel_color, // Cyan (#75DEC2)
            accent_color, // Red (#FF6622)
            sel_color, // Cyan (#75DEC2)
            sel_color, // Cyan (#75DEC2)
            sel_color, // Cyan (#75DEC2)
            fg_color // White
        } // 2-bit Palette (4 colors)
        );

        // Add scrollbar
        var scrolled = new Gtk.ScrolledWindow ();
        scrolled.set_child (terminal);
        scrolled.hexpand = true;
        scrolled.vexpand = false;  // Don't expand vertically
        scrolled.set_max_content_height(300); // Maximum height
        scrolled.set_min_content_height(200); // Minimum height

        // Separator
        var sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);

        // Add everything to the main container
        append (sep);
        append (scrolled);

        terminal.child_exited.connect (() => {
            start_shell ();
        });

        // Start shell
        start_shell ();
    }

    private void start_shell () {
        try {
            // Get user shell
            string shell = Environment.get_variable ("SHELL") ?? "/bin/bash";

            // Setup environment
            string[] env = Environ.get ();

            // Set terminal title
            env += "TERM=xterm-256color";

            // Start process
            string[] argv = { shell };

            // Spawn the terminal process
            terminal.spawn_async (
                                  Vte.PtyFlags.DEFAULT,
                                  current_working_directory,
                                  argv,
                                  env,
                                  GLib.SpawnFlags.SEARCH_PATH,
                                  null,
                                  -1,
                                  null,
                                  null
            );
        } catch (Error e) {
            warning ("Failed to start terminal: %s", e.message);
        }
    }

    public void set_working_directory (string directory) {
        // Update current directory
        current_working_directory = directory;

        // If terminal is running, restart it with the new directory
        if (terminal.get_pty () != null) {
            start_shell ();
        }
    }
}
