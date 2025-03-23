public class TyneApp : Gtk.Application {
    private Theme.Manager theme;
    
    public TyneApp() {
        Object(
            application_id: "org.example.tyne",
            flags: ApplicationFlags.DEFAULT_FLAGS
        );
    }
    
    protected override void activate() {
        var window = new TyneWindow(this);
        window.present();
        
        theme = Theme.Manager.get_default();
        theme.apply_to_display();
        setup_theme_management();
    }
    
    private void setup_theme_management() {
        // Force initial theme load
        var theme_file = GLib.Path.build_filename(
            Environment.get_home_dir(),
            ".theme"
        );

        // Set up the check
        GLib.Timeout.add(10, () => {
            if (FileUtils.test(theme_file, FileTest.EXISTS)) {
                try {
                    theme.load_theme_from_file(theme_file);
                } catch (Error e) {
                    warning("Theme load failed: %s", e.message);
                }
            }
            return true; // Continue the timeout
        });
    }
    
    public static int main(string[] args) {
        return new TyneApp().run(args);
    }
}