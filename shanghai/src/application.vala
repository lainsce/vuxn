using Gtk;
using Cairo;

public class Shanghai.App : Gtk.Application {
    private Theme.Manager theme_manager;
    private GameWindow window;
    
    public App() {
        Object(
            application_id: "com.example.shanghai",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }
    
    protected override void activate() {
        // Initialize theme manager first thing
        theme_manager = Theme.Manager.get_default();
        
        // Listen to theme changes to update the UI
        theme_manager.theme_changed.connect(() => {
            // Update window style if it exists
            if (window != null) {
                window.queue_draw();
            }
        });
        
        // Create the main window (or reuse existing one)
        if (window == null) {
            window = new GameWindow(this);
        }
        
        window.present();
    }
    
    public static int main(string[] args) {
        // Create and run the application
        var app = new App();
        return app.run(args);
    }
}