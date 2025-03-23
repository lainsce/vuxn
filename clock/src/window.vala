public class Window : He.ApplicationWindow {
    private Gtk.Label date_label;
    private Gtk.Label time_label;
    private Clock clock;

    public Window(He.Application app) {
        GLib.Object(application: app);
    }

    construct {
        title = "Clock";
        resizable = false;
        width_request = 200;

        setup_ui();
        update_time();

        // Update every second
        GLib.Timeout.add_seconds(1, () => {
            update_time();
            return true;
        });
    }

    private void setup_ui() {
        var main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8) {
            margin_bottom = 16
        };
        this.child = main_box;

        main_box.append(create_titlebar());

        // Date label
        date_label = new Gtk.Label("");
        main_box.append(date_label);

        // Clock
        clock = new Clock();
        main_box.append(clock);

        // Time label
        time_label = new Gtk.Label("");
        main_box.append(time_label);
    }

    // Title bar
    private Gtk.Widget create_titlebar() {
        // Create classic Mac-style title bar
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = 200;

        // Close button on the left
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.halign = Gtk.Align.START;
        close_button.margin_start = 8;
        close_button.margin_top = 8;
        close_button.clicked.connect(() => {
            this.close();
        });
        title_bar.append(close_button);

        var winhandle = new Gtk.WindowHandle();
        winhandle.set_child(title_bar);

        // Main layout
        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        vbox.append(winhandle);

        return vbox;
    }

    private void update_time() {
        var now = new GLib.DateTime.now_local();
        date_label.label = now.format("%a, %b %d");
        time_label.label = now.format("%H:%M:%S");
        clock.queue_draw();
    }
}
