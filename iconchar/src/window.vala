public class MainWindow : Gtk.ApplicationWindow {
    private Gtk.Box main_box;
    private IconcharData char_data;
    private FileHandler file_handler;
    private IconcharView viewer;
    private Theme.Manager theme;
    private BottomToolbarComponent bottom_toolbar;

    public MainWindow(Gtk.Application app) {
        Object(
            application: app,
            title: "Iconchar",
            default_width: 400,
            default_height: 300,
            resizable: true
        );
        
        // Remove GTK titlebar
        var _tmp = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        _tmp.visible = false;
        titlebar = _tmp;
        
        // Important! Initialize data first and ensure it's fully set up
        char_data = new IconcharData();
        
        // Verify data is initialized
        if (char_data.grid_width <= 0 || char_data.grid_height <= 0) {
            print("WARNING: Invalid grid dimensions, resetting to defaults\n");
            char_data.grid_width = 10;
            char_data.grid_height = 10;
            char_data.resize_grid(10, 10);
        }
        
        // Apply global styling
        apply_global_styles();
        
        // Setup the UI
        setup_ui();
        
        // Handle files after UI is done constructing
        file_handler = new FileHandler(char_data, viewer);
        
        // Setup all gestures
        setup_controllers();
        
        theme = Theme.Manager.get_default();
        theme.apply_to_display();
        setup_theme_management();
        theme.theme_changed.connect(() => {
            apply_global_styles();
        });
    }
    
    private void setup_theme_management() {
        string theme_file = Path.build_filename(Environment.get_home_dir(), ".theme");
        
        Timeout.add(10, () => {
            if (FileUtils.test(theme_file, FileTest.EXISTS)) {
                try {
                    theme.load_theme_from_file(theme_file);
                } catch (Error e) {
                    warning("Theme load failed: %s", e.message);
                }
            }
            return true;
        });
    }
    
    private string rgba_to_hex(Gdk.RGBA rgba) {
        int r = (int)(rgba.red * 255);
        int g = (int)(rgba.green * 255);
        int b = (int)(rgba.blue * 255);
        
        return "#%02x%02x%02x".printf(r, g, b);
    }
    
    private void apply_global_styles() {
        // Apply CSS styling
        var css_provider = new Gtk.CssProvider();
        try {
            Gdk.RGBA fg_color = char_data.get_color(0);
            Gdk.RGBA bg_color = char_data.get_color(1);
            Gdk.RGBA ac_color = char_data.get_color(2);
            Gdk.RGBA se_color = char_data.get_color(3);
            string fg_hex = rgba_to_hex(fg_color);
            string ac_hex = rgba_to_hex(ac_color);
            string se_hex = rgba_to_hex(se_color);
            string bg_hex = rgba_to_hex(bg_color);
            
            // Use string.printf for CSS with color variables
            string css_data = """
                window {
                    background: %s;
                }
                window.csd {
                    box-shadow:
                        inset 0 0 0 1px %s,
                        0 0 0 2px %s;
                }
                .close-button {
                    background: transparent;
                    border: 1px solid %s;
                    box-shadow: none;
                }
                .close-button:hover {
                    background: %s;
                }
                .close-button:active {
                    background: %s;
                }
                .mini-panel-frame {
                    border: 1px solid %s;
                    border-radius: 2px;
                    padding: 1px;
                }
                .panel-frame {
                    border: 1px solid %s;
                    border-radius: 4px;
                    padding: 2px;
                }
                button:not(.close-button) {
                    background: none;
                    border: none;
                    min-height: 0px;
                    min-width: 0px;
                    -gtk-icon-size: 0px;
                }
                button:not(.close-button) * {
                    margin: 0;
                    padding: 0;
                    min-height: 0px;
                    min-width: 0px;
                    -gtk-icon-size: 0px;
                }
                .status-bar {
                    padding: 4px;
                }
                .status-bar * {
                    background: %s;
                    margin: 0;
                    padding: 0;
                    min-height: 0px;
                    min-width: 0px;
                    -gtk-icon-size: 0px;
                }
                .filename-label {
                    font-family: "atari8", monospace;
                    font-size: 8px;
                    line-height: 8px;
                    color: %s;
                    margin: 0;
                    padding: 0;
                }
                .data-label {
                    font-family: "atari8", monospace;
                    font-size: 8px;
                    color: %s;
                    margin: 7px 0 0 0;
                    padding: 0;
                }
            """.printf(
                fg_hex,             // window background
                bg_hex, fg_hex,     // window.csd box-shadow
                bg_hex,             // .close-button border
                bg_hex,             // .close-button:hover background
                bg_hex,             // .close-button:active background
                ac_hex,             // .mini-panel-frame border
                ac_hex,             // .panel-frame border
                fg_hex,             // .status-bar background
                bg_hex,             // .filename-label color
                bg_hex              // .data-label color
            );
            
            css_provider.load_from_data(css_data.data);
            
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(),
                css_provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        } catch (Error e) {
            warning("Failed to load CSS: %s", e.message);
        }
    }
    
    private void setup_ui() {
        main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        set_child(main_box);
        
        // Create the viewer
        viewer = new IconcharView(char_data);
        
        // Main content area with viewer
        var content_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
        
        // Create viewer panel with frame
        var viewer_panel = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        viewer_panel.add_css_class("panel-frame");
        viewer_panel.margin_start = 8;
        viewer_panel.margin_end = 8;
        
        // Add the viewer to its panel
        viewer_panel.append(viewer);
        
        // Add panel to content box
        content_box.append(viewer_panel);
        
        // Create bottom toolbar
        bottom_toolbar = new BottomToolbarComponent(char_data, viewer);
        
        bottom_toolbar.request_open.connect(() => {
            open_file();
        });
        
        // Add all sections to main box
        main_box.append(create_titlebar());
        main_box.append(content_box);
        main_box.append(bottom_toolbar);
    }
    
    private Gtk.Widget create_titlebar() {
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = 302;
        
        // Create close button
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;
        close_button.margin_top = 8;
        close_button.margin_bottom = 4;
        close_button.clicked.connect(() => {
            close();
        });
        
        title_bar.append(close_button);
        
        var winhandle = new Gtk.WindowHandle();
        winhandle.set_child(title_bar);
        
        // Create vertical layout
        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        vbox.append(winhandle);
        
        return vbox;
    }
    
    private void setup_controllers() {
        // Setup keyboard events on main_box
        var key_controller = new Gtk.EventControllerKey();
        key_controller.key_pressed.connect(on_key_pressed);
        main_box.add_controller(key_controller);
        
        // Setup drag-and-drop for file loading
        var drop_controller = new Gtk.DropTarget(typeof(File), Gdk.DragAction.COPY);
        drop_controller.drop.connect(on_drop);
        main_box.add_controller(drop_controller);
    }
    
    private bool on_key_pressed(Gtk.EventControllerKey controller, uint keyval, uint keycode, Gdk.ModifierType state) {
        // Handle keyboard shortcuts
        if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
            switch (keyval) {
                case Gdk.Key.q:
                    // Close window
                    close();
                    return true;
                case Gdk.Key.o:
                    // Open file
                    open_file();
                    return true;
                case Gdk.Key.n:
                    // New file/Clear
                    viewer.clear_view();
                    char_data.filename = "untitled10x10.chr";
                    return true;
            }
        }
        
        return false;
    }
    
    private bool on_drop(Gtk.DropTarget target, Value value, double x, double y) {
        if (value.type() == typeof(File)) {
            var file = (File)value;
            string path = file.get_path();
            
            if (path.down().has_suffix(".chr")) {
                file_handler.load_from_file(path);
                return true;
            } else if (path.down().has_suffix(".icn")) {
                file_handler.load_from_mono_file(path);
                return true;
            }
        }
        
        return false;
    }
    
    private void open_file() {
        var open_dialog = new Gtk.FileDialog();
        open_dialog.set_title("Open File");
        
        var chr_filter = new Gtk.FileFilter();
        chr_filter.set_filter_name("CHR Files");
        chr_filter.add_pattern("*.chr");
        
        var icn_filter = new Gtk.FileFilter();
        icn_filter.set_filter_name("ICN Files");
        icn_filter.add_pattern("*.icn");
        
        var filters = new ListStore(typeof(Gtk.FileFilter));
        filters.append(chr_filter);
        filters.append(icn_filter);
        open_dialog.set_filters(filters);
        
        open_dialog.open.begin(this, null, (obj, res) => {
            try {
                var file = open_dialog.open.end(res);
                string path = file.get_path();
                
                if (path.down().has_suffix(".chr")) {
                    file_handler.load_from_file(path);
                } else if (path.down().has_suffix(".icn")) {
                    file_handler.load_from_mono_file(path);
                }
            } catch (Error e) {
                // User probably canceled the dialog
            }
        });
    }
}