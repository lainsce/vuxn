public class OrcaApp : Gtk.Application {
    public OrcaApp () {
        Object (application_id: "com.example.orca", flags: ApplicationFlags.FLAGS_NONE);
    }

    protected override void activate () {
        // Load CSS
        var provider = new Gtk.CssProvider ();
        provider.load_from_resource ("/com/example/orca/style.css");

        // Apply CSS to the app
        Gtk.StyleContext.add_provider_for_display (
                                                   Gdk.Display.get_default (),
                                                   provider,
                                                   Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        var win = new OrcaWindow (this);
        win.present ();
    }

    protected override void startup () {
        resource_base_path = "/com/example/orca";

        base.startup ();
    }
}
