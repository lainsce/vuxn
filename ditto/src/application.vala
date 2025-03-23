public class Application : Gtk.Application {
    private MainWindow? window = null;

    public Application () {
        Object (
            application_id: "com.example.ditto",
            flags: ApplicationFlags.HANDLES_OPEN
        );

        // Initialize CSS provider
        var provider = new Gtk.CssProvider ();
        try {
            var css_path = "/com/example/ditto/style.css";
            provider.load_from_resource (css_path);
            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 10
            );
        } catch (Error e) {
            warning ("Failed to load CSS: %s", e.message);
        }
    }

    protected override void activate () {
        if (window == null) {
            window = new MainWindow (this);
        }
        window.present ();
        
        // Apply theme
        var theme = Theme.Manager.get_default ();
        theme.apply_to_display ();
        setup_theme_management ();
    }
    
    protected override void open (File[] files, string hint) {
        // Handle file opening - activate the app first
        activate ();
        
        // Only handle the first file for now
        if (files.length > 0) {
            window.load_image_from_file (files[0]);
        }
    }
    
    private void setup_theme_management () {
        var theme = Theme.Manager.get_default ();
        var theme_file = Path.build_filename (Environment.get_home_dir (), ".theme");

        // Set up the theme file watcher
        GLib.Timeout.add (10, () => {
            if (GLib.FileUtils.test (theme_file, FileTest.EXISTS)) {
                try {
                    theme.load_theme_from_file (theme_file);
                } catch (Error e) {
                    warning ("Theme load failed: %s", e.message);
                }
            }
            return Source.CONTINUE;
        });
    }

    public static int main (string[] args) {
        return new Application ().run (args);
    }
}