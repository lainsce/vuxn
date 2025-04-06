using Gtk;

namespace ShavianKeyboard {
    // Main application class
    public class ShavianApplication : Gtk.Application {
        public ShavianApplication() {
            Object(application_id: "com.example.shav",
                   flags: ApplicationFlags.FLAGS_NONE);
        }
        
        protected override void activate() {
            // Create and show the window
            var window = new ShavianWindow(this);
            window.present();
        }
        
        public static int main(string[] args) {
            return new ShavianApplication().run(args);
        }
    }
}