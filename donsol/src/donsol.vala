using Gtk;

public class DonsolApp : Gtk.Application {
    public DonsolApp() {
        Object(
            application_id: "com.example.donsol",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }
    
    protected override void startup() {
        base.startup();
        
        // Initialize Theme Manager
        DonsolTheme.get_default().init();
    }

    protected override void activate() {
        var win = new DonsolWindow(this);
        win.present();
    }

    public static int main(string[] args) {
        return new DonsolApp().run(args);
    }
}