/*
 * Turquoise - A pattern drawing application
 */

namespace Turquoise {
    public class Application : Gtk.Application {
        public Application() {
            Object(
                application_id: "com.example.turquoise",
                flags: ApplicationFlags.FLAGS_NONE
            );
        }

        protected override void activate() {
            var window = new MainWindow(this);
            window.present();
        }

        public static int main(string[] args) {
            Gtk.init();
            return new Application().run(args);
        }
    }
}