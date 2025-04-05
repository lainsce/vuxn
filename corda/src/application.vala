public class CordaApp : Gtk.Application {
    public CordaApp() {
        Object(
            application_id: "com.example.corda",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void activate() {
        var window = new CordaWindow(this);
        window.present();
    }
    
    public static int main(string[] args) {
        return new CordaApp().run(args);
    }
}