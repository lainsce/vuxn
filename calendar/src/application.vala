public class CalApp : He.Application {
    private Theme.Manager theme;

    public CalApp () {
        Object (
                application_id: "com.example.calendarapp"
        );
    }

    protected override void startup () {
        Gdk.RGBA accent_color = { 0 };
        accent_color.parse ("#000");
        default_accent_color = { accent_color.red* 255, accent_color.green* 255, accent_color.blue* 255 };
        override_accent_color = true;
        is_content = true;

        resource_base_path = "/com/example/calendarapp";

        base.startup ();
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
        GLib.Timeout.add (10, () => {
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
        var app = new CalApp ();
        return app.run (args);
    }
}
