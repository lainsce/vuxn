using Gtk;

public class App : He.Application {
    private Window window;
    private Theme.Manager theme;

    public App() {
        Object(
               application_id: "com.example.Numfor",
               flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void startup() {
        Gdk.RGBA accent_color = { 0 };
        accent_color.parse("#000");
        default_accent_color = { accent_color.red* 255, accent_color.green* 255, accent_color.blue* 255 };
        override_accent_color = true;
        is_content = true;

        resource_base_path = "/com/example/Numfor";

        base.startup();
    }

    protected override void activate() {
        // Create main window with classic look
        window = new Window(this);

        // Set up keyboard shortcuts
        setup_keyboard_shortcuts();

        window.present();

        theme = Theme.Manager.get_default();
        theme.apply_to_display();
        setup_theme_management();
    }

    private void setup_theme_management() {
        // Force initial theme load
        var theme_file = Path.build_filename(Environment.get_home_dir(), ".theme");

        // Set up the check
        GLib.Timeout.add(40, () => {
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

    private void setup_keyboard_shortcuts() {
        // Create action for saving (Ctrl+S)
        var save_action = new SimpleAction("save", null);
        save_action.activate.connect(window.save_csv);
        add_action(save_action);

        // Create action for opening (Ctrl+O)
        var open_action = new SimpleAction("open", null);
        open_action.activate.connect(window.open_csv);
        add_action(open_action);

        // Set accelerators for actions
        set_accels_for_action("app.save", { "<Control>s" });
        set_accels_for_action("app.open", { "<Control>o" });
    }

    public static int main(string[] args) {
        return new App().run(args);
    }
}
