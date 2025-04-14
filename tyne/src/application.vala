public class TyneApp : Gtk.Application {
    public TyneApp() {
        Object(
            application_id: "org.example.tyne",
            flags: ApplicationFlags.DEFAULT_FLAGS
        );
    }
    
    protected override void activate() {
        var window = new TyneWindow(this);
        window.present();
    }
    
    public static int main(string[] args) {
        return new TyneApp().run(args);
    }
}