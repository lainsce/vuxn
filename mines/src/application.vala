public class MinesweeperApp : Gtk.Application {
    // Main window
    private MinesweeperWindow window;
    
    public MinesweeperApp() {
        Object(application_id: "com.example.mines",
               flags: ApplicationFlags.FLAGS_NONE);
    }
    
    protected override void activate() {
        // Create main window if it doesn't exist
        if (window == null) {
            window = new MinesweeperWindow(this);
        }
        
        window.present();
    }
    
    public static int main(string[] args) {
        return new MinesweeperApp().run(args);
    }
}