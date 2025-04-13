public class BoucApp : Gtk.Application {
    public BoucApp() {
        Object(
            application_id: "com.example.bouc",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void activate() {
        var window = new MainWindow(this);
        window.present();
    }

    public static int main(string[] args) {
        return new BoucApp().run(args);
    }
}