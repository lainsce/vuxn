namespace App {
    public class Application : Gtk.Application {
        private Window window;

        public Application() {
            Object(
                   application_id: "com.example.cccc",
                   flags: ApplicationFlags.FLAGS_NONE
            );
        }

        protected override void activate() {
            if (window == null) {
                window = new Window(this);
            }
            window.present();
        }

        public static int main(string[] args) {
            var app = new Application();
            Gst.init(ref args); // Simplified initialization
            return app.run(args);
        }
    }
}
