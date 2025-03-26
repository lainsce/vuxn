using Gtk;

public class OrcaApp : Gtk.Application {
    public OrcaApp() {
        Object(application_id: "com.example.orca", flags: ApplicationFlags.FLAGS_NONE);
    }

    protected override void activate() {
        var win = new OrcaWindow(this);
        win.present();
    }
}