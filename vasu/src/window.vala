public class MainWindow : Gtk.ApplicationWindow {
    private Gtk.Box main_box;
    private VasuData chr_data;
    private VasuFileHandler file_handler;
    private VasuEditorView editor_view;
    private VasuNametableView nametable_view;
    private MenuComponent menu_component;
    private TopBarComponent top_bar;
    private BottomToolbarComponent bottom_toolbar;
    private Theme.Manager theme;

    public MainWindow(Gtk.Application app) {
        Object(
            application: app,
            title: "Vasu",
            default_width: 306,
            default_height: 220,
            resizable: false 
        );
        
        // Remove GTK titlebar
        var _tmp = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        _tmp.visible = false;
        titlebar = _tmp;
        
        // Initialize data before UI
        chr_data = new VasuData();
        
        // Apply global styling
        apply_global_styles();
        
        // Setup the UI
        setup_ui();
        
        // Handle files after UI is done constructing
        file_handler = new VasuFileHandler(chr_data, editor_view, nametable_view);
        
        // Setup all gestures
        setup_controllers();
        
        theme = Theme.Manager.get_default();
        theme.apply_to_display();
        setup_theme_management();
        theme.theme_changed.connect(() => {
            apply_global_styles();
        });
        
        chr_data.palette_changed.connect(() => {
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
            Gdk.RGBA bg_color = chr_data.get_color(0);
            Gdk.RGBA fg_color = chr_data.get_color(1);
            Gdk.RGBA ac_color = chr_data.get_color(2);
            Gdk.RGBA se_color = chr_data.get_color(3);
            string bg_hex = rgba_to_hex(bg_color);
            string fg_hex = rgba_to_hex(fg_color);
            string se_hex = rgba_to_hex(se_color);
            string ac_hex = rgba_to_hex(ac_color);
            
            // Use string.printf for CSS with color variables
            string css_data = """
                window {
                    background: %s;
                }
                window.csd {
                    box-shadow:
                        0 0 0 2px %s;
                }
                .close-button {
                    box-shadow: none;
                    background: none;
                    border: 1px solid %s;
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
                .tool-bar,
                .tool-bar * {
                    margin: 0;
                    padding: 0;
                }
                .filename-label {
                    font-family: "atari8", monospace;
                    font-size: 8px;
                    line-height: 8px;
                    color: %s;
                    margin: 0;
                    padding: 0;
                }
                .data-grid,
                .data-grid * {
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
                .hex-label {
                    font-family: "atari8", monospace;
                    font-size: 8px;
                    line-height: 8px;
                    color: %s;
                    margin: 0;
                    padding: 0;
                }
                .hex-label2 {
                    font-family: "atari8", monospace;
                    font-size: 8px;
                    line-height: 8px;
                    color: %s;
                    margin: 0;
                    padding: 0;
                }
                menubar {
                    background: transparent;
                    padding: 0;
                    margin: 0;
                    border: none;
                }
                menubar label {
                    background: transparent;
                    min-height: 0;
                    min-width: 0;
                    padding: 2px 4px;
                    margin: 0;
                    font-family: "atari8", monospace;
                    font-size: 8px;
                }
                menubar label {
                    color: %s;
                }
                menubar button:hover {
                    background: %s;
                    color: %s;
                }
                popover {
                    background: %s;
                    color: %s;
                    border: 1px solid %s;
                    margin: 0;
                    padding: 0;
                }
                popover contents {
                    background: %s;
                    border: none;
                    padding: 0;
                    margin: 0;
                }
                popover modelbutton {
                    color: %s;
                    padding: 0;
                    min-height: 0;
                    margin: 0;
                    padding: 0;
                    background: transparent;
                }
                popover modelbutton label {
                    font-family: "atari8", monospace;
                    font-size: 8px;
                    margin: 0;
                    padding: 0;
                }
                popover modelbutton accelerator {
                    font-family: "atari8", monospace;
                    font-size: 8px;
                    margin-left: 16px;
                    margin-right: 1px;
                    padding: 0;
                    background: transparent;
                    color: %s;
                }
                popover modelbutton:hover {
                    background: %s;
                    color: %s;
                }
                button:not(.close-button) {
                    background: none;
                    color: %s;
                    border: none;
                    min-height: 0px;
                    min-width: 0px;
                    margin: 0;
                    padding: 0;
                    -gtk-icon-size: 0px;
                }
                button:not(.close-button) * {
                    margin: 0;
                    padding: 0;
                    min-height: 0px;
                    min-width: 0px;
                    -gtk-icon-size: 0px;
                }
                button:not(.close-button):hover {
                    background: none;
                    color: %s;
                }
                button:not(.close-button):active {
                    background: none;
                    color: %s;
                }
                button:not(.close-button):checked {
                    background: none;
                    color: %s;
                }
            """.printf(
                bg_hex,             // window background
                fg_hex,             // window.csd box-shadow
                fg_hex,             // .close-button border
                bg_hex,             // .status-bar background
                fg_hex,             // .filename-label color
                se_hex,             // .data-label color
                ac_hex,             // .hex-label color
                fg_hex,             // .hex-label2 color
                se_hex,             // menubar button color
                se_hex,             // menubar button:hover background
                fg_hex,             // menubar button:hover color
                ac_hex,             // popover background
                bg_hex,             // popover color
                ac_hex,             // popover border
                ac_hex,             // popover contents background
                ac_hex,             // popover button color
                se_hex,             // popover accel color
                fg_hex,             // popover button:hover background
                se_hex,             // popover button:hover color
                bg_hex,             // button:not(.close-button) color
                bg_hex,             // button:not(.close-button):hover color
                bg_hex,             // button:not(.close-button):active color
                fg_hex              // button:not(.close-button):checked color
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
        
        // Create the editor view first
        editor_view = new VasuEditorView(chr_data);
        
        // Create the nametable view with a reference to the editor
        nametable_view = new VasuNametableView(chr_data, editor_view);
        
        // Connect tile selection signal from editor to nametable
        editor_view.tile_selected.connect((tile_x, tile_y) => {
            nametable_view.set_selected_tile(tile_x, tile_y);
            nametable_view.queue_draw();
        });
        
        // Create top bar 
        top_bar = new TopBarComponent(chr_data, editor_view, nametable_view);
        
        top_bar.selected_color_changed.connect(() => {
            apply_global_styles();
        });
        
        // Main content area with editor and nametable
        var content_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
        content_box.halign = Gtk.Align.CENTER;
        
        // Create editor panel with frame
        var editor_panel = new FrameBox(chr_data, Gtk.Orientation.VERTICAL, 0, content_box);
        editor_panel.margin_top = 2;
        editor_panel.margin_start = 2;
        editor_panel.margin_bottom = 2;
        editor_panel.margin_end = 2;
        
        // Add the editor view to its panel
        editor_panel.append(editor_view);
        
        // Create nametable panel with frame
        var nametable_panel = new FrameBox(chr_data, Gtk.Orientation.VERTICAL, 0, content_box);
        nametable_panel.margin_top = 2;
        nametable_panel.margin_start = 2;
        nametable_panel.margin_bottom = 2;
        nametable_panel.margin_end = 2;
        
        // Add the nametable view to its panel
        nametable_panel.append(nametable_view);
        
        // Add panels to content box
        content_box.append(editor_panel);
        content_box.append(nametable_panel);
        
        // Create bottom toolbar
        bottom_toolbar = new BottomToolbarComponent(chr_data, editor_view, nametable_view);
        
        // Connect file operation signals
        bottom_toolbar.request_save.connect(() => {
            save_chr_file();
        });
        
        bottom_toolbar.request_open.connect(() => {
            open_file();
        });
        
        bottom_toolbar.selected_color_changed.connect(() => {
            top_bar.update_color_picker();
        });
        
        // Add all sections to main box
        main_box.append(create_titlebar());
        main_box.append(top_bar);
        main_box.append(content_box);
        main_box.append(bottom_toolbar);
        
        // Initialize file handler with all components
        file_handler = new VasuFileHandler(chr_data, editor_view, nametable_view);
    }
    
    private Gtk.Widget create_titlebar() {
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = 302;
        
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 4;
        close_button.clicked.connect(() => {
            close();
        });
        title_bar.append(close_button);
        
        // Create menu component
        menu_component = new MenuComponent(chr_data, editor_view, nametable_view, top_bar);
        
        // Connect menu signals
        menu_component.request_save.connect(() => {
            save_chr_file();
        });
        
        menu_component.request_open.connect(() => {
            open_file();
        });
        
        menu_component.request_save_mono.connect(() => {
            save_mono_file();
        });

        menu_component.request_open_mono.connect(() => {
            open_mono_file();
        });
        
        menu_component.request_rename.connect(() => {
            // Show rename dialog or activate filename editor
            // For now, we'll just focus on the filename component to trigger editing
            bottom_toolbar.focus_filename();
        });
        
        menu_component.request_exit.connect(() => {
            close();
        });
        
        menu_component.tool_or_color_changed.connect(() => {
            // Force redraw of the bottom toolbar when tool or color changes
            bottom_toolbar.update_tool_buttons();
            bottom_toolbar.queue_draw();
        });
        
        title_bar.append(menu_component);
        
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
    
    private void save_chr_file() {
        var save_dialog = new Gtk.FileDialog();
        save_dialog.set_title("Save CHR file");
        
        var filter = new Gtk.FileFilter();
        filter.set_filter_name("CHR Files");
        filter.add_pattern("*.chr");
        
        var filters = new ListStore(typeof(Gtk.FileFilter));
        filters.append(filter);
        save_dialog.set_filters(filters);
        
        save_dialog.save.begin(this, null, (obj, res) => {
            try {
                var file = save_dialog.save.end(res);
                string path = file.get_path();
                
                // Ensure .chr extension
                if (!path.has_suffix(".chr")) {
                    path += ".chr";
                }
                
                // Save the file
                if (file_handler.save_to_file(path)) {
                    chr_data.filename = File.new_for_path(path).get_basename();
                }
            } catch (Error e) {
                // User probably canceled the dialog
            }
        });
    }
    
    private void open_file() {
        var open_dialog = new Gtk.FileDialog();
        open_dialog.set_title("Open CHR file");
        
        var filter = new Gtk.FileFilter();
        filter.set_filter_name("CHR Files");
        filter.add_pattern("*.chr");
        
        var filters = new ListStore(typeof(Gtk.FileFilter));
        filters.append(filter);
        open_dialog.set_filters(filters);
        
        open_dialog.open.begin(this, null, (obj, res) => {
            try {
                var file = open_dialog.open.end(res);
                string path = file.get_path();
                
                // Load the file
                file_handler.load_from_file(path);
            } catch (Error e) {
                // User probably canceled the dialog
            }
        });
    }
    
    private void save_mono_file() {
        var save_dialog = new Gtk.FileDialog();
        save_dialog.set_title("Save ICN file");
        
        var filter = new Gtk.FileFilter();
        filter.set_filter_name("ICN Files");
        filter.add_pattern("*.icn");
        
        var filters = new ListStore(typeof(Gtk.FileFilter));
        filters.append(filter);
        save_dialog.set_filters(filters);
        
        save_dialog.save.begin(this, null, (obj, res) => {
            try {
                var file = save_dialog.save.end(res);
                string path = file.get_path();
                
                // Ensure .icn extension
                if (!path.has_suffix(".icn")) {
                    path += ".icn";
                }
                
                // Save the file
                if (file_handler.save_to_mono_file(path)) {
                    chr_data.filename = File.new_for_path(path).get_basename();
                }
            } catch (Error e) {
                // User probably canceled the dialog
            }
        });
    }

    private void open_mono_file() {
        var open_dialog = new Gtk.FileDialog();
        open_dialog.set_title("Open ICN file");
        
        var filter = new Gtk.FileFilter();
        filter.set_filter_name("ICN Files");
        filter.add_pattern("*.icn");
        
        var filters = new ListStore(typeof(Gtk.FileFilter));
        filters.append(filter);
        open_dialog.set_filters(filters);
        
        open_dialog.open.begin(this, null, (obj, res) => {
            try {
                var file = open_dialog.open.end(res);
                string path = file.get_path();
                
                // Load the file
                file_handler.load_from_mono_file(path);
            } catch (Error e) {
                // User probably canceled the dialog
            }
        });
    }
}