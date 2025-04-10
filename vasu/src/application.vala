public class VasuEditor : Gtk.Application {
    public VasuEditor() {
        Object(
            application_id: "com.example.vasu",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void activate() {
        var main_window = new MainWindow(this);
        main_window.present();
    }

    public static int main(string[] args) {
        Gtk.init();
        return new VasuEditor().run(args);
    }
}