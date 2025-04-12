public class Iconchar : Gtk.Application {
    public Iconchar() {
        Object(
            application_id: "com.example.icnchr",
            flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void activate() {
        var main_window = new MainWindow(this);
        main_window.present();
    }

    public static int main(string[] args) {
        Gtk.init();
        return new Iconchar().run(args);
    }
}