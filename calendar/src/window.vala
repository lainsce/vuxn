using Gtk;
using GLib;

public class Window : He.ApplicationWindow {
    private CalendarView calendar_view;
    public Gtk.Label title_label;

    public Window (He.Application app) {
        Object (application: app);
        this.title = "Calendar";
        this.width_request = 578;
        this.resizable = false;

        // Load events from .csv on startup
        calendar_view = new CalendarView ();

        // Main content
        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.valign = Gtk.Align.START;
        box.halign = Gtk.Align.START;
        box.append (create_titlebar ());
        box.append (calendar_view);

        calendar_view.set_title_label (title_label);

        this.set_child (box);

        this.close_request.connect (() => {
            print ("Window closing, flushing event manager\n");
            EventManager.get_instance ().flush ();
            return false; // Allow the window to close
        });
    }

    // Title bar
    private Gtk.Widget create_titlebar () {
        // Create classic Mac-style title bar
        var title_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = 578;
        title_bar.add_css_class ("title-bar");

        // Add event controller for right-click to toggle calendar visibility
        var click_controller = new Gtk.GestureClick ();
        click_controller.set_button (1); // 1 = right mouse button
        click_controller.released.connect (() => {
            if (calendar_view.visible) {
                calendar_view.visible = false;
            } else {
                calendar_view.visible = true;
            }
        });
        title_bar.add_controller (click_controller);

        // Close button on the left
        var close_button = new Gtk.Button ();
        close_button.add_css_class ("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;
        close_button.clicked.connect (() => {
            this.close ();
        });
		title_bar.append (close_button);

		title_label = new Gtk.Label (null);
        title_label.add_css_class ("title-box");
        title_label.hexpand = true;
        title_label.valign = Gtk.Align.CENTER;
		title_label.halign = Gtk.Align.CENTER;
		title_bar.append (title_label);

        var winhandle = new Gtk.WindowHandle ();
        winhandle.set_child (title_bar);

        // Main layout
        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.append (winhandle);

        return vbox;
    }
}
