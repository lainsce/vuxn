public class App : Gtk.Application {

    // Main window
    private Window window;

    // Constructor
    public App () {
        Object (
                application_id: "com.example.notesapp",
                flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void startup () {
        resource_base_path = "/com/example/notesapp";

        base.startup ();
    }

    protected override void activate () {
        window = new Window (this);
        window.present ();
    }

    // Application entry point
    public static int main (string[] args) {
        var app = new App ();
        return app.run (args);
    }
}
