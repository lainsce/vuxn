public class ColorPickerApp : Gtk.Application {
    
    public ColorPickerApp() {
        Object(application_id: "com.example.colorpicker", flags: ApplicationFlags.FLAGS_NONE);
    }
    
    protected override void activate() {
        var win = new ColorPickerWindow(this);
        win.present();
    }
    
    // Set up keyboard accelerators
    protected override void startup() {
        base.startup();
        
        // Set keyboard shortcuts for the window actions
        set_accels_for_action("win.copy-color", {"<Control>c"});
        set_accels_for_action("win.paste-color", {"<Control>v"});
        set_accels_for_action("win.toggle-mode", {"<Control>t"});
        set_accels_for_action("win.cancel-pick", {"Escape"});
    }
    
    public static int main(string[] args) {
        return new ColorPickerApp().run(args);
    }
}