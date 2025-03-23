/* application.vala
 *
 * Drawing application main class
 */
using Gtk;
using GLib;

public class App : Gtk.Application {
    private Window window;
    
    public App() {
        Object(
          application_id: "com.example.voodle",
          flags: ApplicationFlags.FLAGS_NONE
        );
    }
    
    protected override void activate() {
        window = new Window(this);
        window.present();
    }
    
    public static int main(string[] args) {
        return new App().run(args);
    }
}