public class Utils {
    public static void setup_terminal_appearance (Vte.Terminal terminal, Theme.Manager theme) {
        var font_desc = Pango.FontDescription.from_string ("Monaco Regular 9");
        // Get theme colors (BG and FG are inverted for style purposes)
        Gdk.RGBA fg_color = theme.get_color ("theme_fg");
        Gdk.RGBA bg_color = theme.get_color ("theme_bg");
        Gdk.RGBA accent_color = theme.get_color ("theme_accent");
        Gdk.RGBA sel_color = theme.get_color ("theme_selection");

        terminal.set_font (font_desc);
        terminal.set_colors (
                             bg_color, // Foreground (black)
                             fg_color, // Background (white)
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
        
        // Allow selection by word or line with double/triple click
        terminal.set_word_char_exceptions ("-A-Za-z0-9_.$+@%&/:~#=?");
    }

// Terminal process utilities
    public static void spawn_terminal_process (Vte.Terminal terminal) {
        try {
            // Set up environment variables
            string[] env = Environ.get ();
            
            // Add TERM environment variable to ensure proper terminal capabilities
            env = Environ.set_variable (env, "TERM", "xterm-256color");
            
            // Spawn the user's shell
            terminal.spawn_async (
                                  Vte.PtyFlags.DEFAULT,
                                  null,
                                  { Vte.get_user_shell () },
                                  env,
                                  GLib.SpawnFlags.SEARCH_PATH,
                                  null,
                                  -1,
                                  null,
                                  (terminal, pid, error) => {
                                      if (error != null) {
                                          warning ("Failed to spawn terminal: %s", error.message);
                                      }
                                  }
            );
        } catch (Error e) {
            warning ("Error setting up terminal: %s", e.message);
        }
    }

// UI creation utilities
    public static Gtk.Widget create_mac_titlebar (string title, Gtk.Window window) {
        // Create classic Mac-style title bar
        var title_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = 223;
        title_bar.add_css_class ("title-bar");

        // Close button on the left
        var close_button = new Gtk.Button ();
        close_button.add_css_class ("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;
        close_button.clicked.connect (() => {
            window.close ();
        });

        var title_label = new Gtk.Label (title);
        title_label.add_css_class ("title-box");
        title_label.hexpand = true;
        title_label.valign = Gtk.Align.CENTER;
        title_label.halign = Gtk.Align.CENTER;

        title_bar.append (close_button);
        title_bar.append (title_label);

        var winhandle = new Gtk.WindowHandle ();
        winhandle.set_child (title_bar);

        // Main layout
        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.append (winhandle);

        return vbox;
    }
}