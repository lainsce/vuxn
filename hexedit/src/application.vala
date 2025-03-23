using Gtk;

namespace HexEdit {
    public class Application : Gtk.Application {
        public Application() {
            Object(
                   application_id: "com.example.hexedit",
                   flags: ApplicationFlags.DEFAULT_FLAGS
            );
        }

        public override void activate() {
            var window = this.get_window();
            if (window == null) {
                window = new Window(this);
                window.present();
            } else {
                window.present();
            }

            var theme = Theme.Manager.get_default();
            theme.apply_to_display();
            setup_theme_management();
        }

        private void setup_theme_management() {
            var theme = Theme.Manager.get_default();
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
                return Source.CONTINUE; // More semantic than true
            });
        }

        private Window? get_window() {
            unowned GLib.List<Gtk.Window> windows = this.get_windows();
            if (windows.length() > 0) {
                return windows.data as Window;
            }
            return null;
        }

        public static int main(string[] args) {
            return new HexEdit.Application().run(args);
        }
    }
}
