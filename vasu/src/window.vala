public class MainWindow : Gtk.ApplicationWindow {
    private Gtk.Box main_box;
    private VasuData chr_data;
    private VasuFileHandler file_handler;
    private VasuEditorView editor_view;
    private VasuPreviewView preview_view;
    private MenuComponent menu_component;
    private TopBarComponent top_bar;
    private BottomToolbarComponent bottom_toolbar;
    private Theme.Manager theme;

    public MainWindow(Gtk.Application app) {
        Object(
            application: app,
            title: "Vasu",
            default_width: 302,
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
        file_handler = new VasuFileHandler(chr_data, editor_view);
        
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
            Gdk.RGBA fg_color = chr_data.get_color(0);
            Gdk.RGBA ac_color = chr_data.get_color(1);
            Gdk.RGBA se_color = chr_data.get_color(2);
            Gdk.RGBA bg_color = chr_data.get_color(3);
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
                    min-height: 8px;
                    margin: 0;
                    font-family: "atari8", monospace;
                    font-size: 8px;
                    background: transparent;
                }
                popover modelbutton:hover {
                    background: %s;
                    color: %s;
                }
                dialog {
                    background: %s;
                    color: %s;
                }
                dialog headerbar {
                    background: %s;
                    color: %s;
                }
                dialog button {
                    background: %s;
                    color: %s;
                    border: 1px solid %s;
                }
                button:not(.close-button) {
                    background: none;
                    color: %s;
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
                fg_hex,             // window background
                se_hex, fg_hex,     // window.csd box-shadow
                se_hex,             // .close-button border
                se_hex,             // .close-button:hover background
                ac_hex,             // .close-button:active background
                se_hex,             // .mini-panel-frame border
                se_hex,             // .panel-frame border
                fg_hex,             // .status-bar background
                ac_hex,             // .filename-label color
                bg_hex,             // .data-label color
                se_hex,             // .hex-label color
                ac_hex,             // .hex-label2 color
                bg_hex,             // menubar button color
                se_hex,             // menubar button:hover background
                fg_hex,             // menubar button:hover color
                fg_hex,             // popover background
                bg_hex,             // popover color
                se_hex,             // popover border
                fg_hex,             // popover contents background
                bg_hex,             // popover button color
                se_hex,             // popover button:hover background
                fg_hex,             // popover button:hover color
                fg_hex,             // dialog background
                bg_hex,             // dialog color
                fg_hex,             // dialog headerbar background
                bg_hex,             // dialog headerbar color
                se_hex,             // dialog button background
                bg_hex,             // dialog button color
                bg_hex,             // dialog button border
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
        
        // Create the preview view with a reference to the editor
        preview_view = new VasuPreviewView(chr_data, editor_view);
        
        // Connect tile selection signal from editor to preview
        editor_view.tile_selected.connect((tile_x, tile_y) => {
            preview_view.set_selected_tile(tile_x, tile_y);
            preview_view.queue_draw();
        });
        
        // Create top bar 
        top_bar = new TopBarComponent(chr_data, editor_view, preview_view);
        
        top_bar.selected_color_changed.connect(() => {
            apply_global_styles();
        });
        
        // Main content area with editor and preview
        var content_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
        content_box.halign = Gtk.Align.CENTER;
        
        // Create editor panel with frame
        var editor_panel = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        editor_panel.add_css_class("panel-frame");
        editor_panel.margin_start = 8;
        
        // Add the editor view to its panel
        editor_panel.append(editor_view);
        
        // Create preview panel with frame
        var preview_panel = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        preview_panel.add_css_class("panel-frame");
        preview_panel.margin_end = 8;
        
        // Add the preview view to its panel
        preview_panel.append(preview_view);
        
        // Add panels to content box
        content_box.append(editor_panel);
        content_box.append(preview_panel);
        
        // Create bottom toolbar
        bottom_toolbar = new BottomToolbarComponent(chr_data, editor_view, preview_view);
        
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
        close_button.clicked.connect(() => {
            close();
        });
        
        title_bar.append(close_button);
        
                // Create menu component
        menu_component = new MenuComponent(chr_data, editor_view, preview_view, top_bar);
        
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
        // Handle keyboard shortcuts
        if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
            if ((state & Gdk.ModifierType.SHIFT_MASK) != 0) {
                // Ctrl+Shift shortcuts
                switch (keyval) {
                    case Gdk.Key.S:
                        // Save mono file
                        save_mono_file();
                        return true;
                    case Gdk.Key.O:
                        // Open mono file
                        open_mono_file();
                        return true;
                }
            } else {
                // Ctrl shortcuts (no shift)
                switch (keyval) {
                    case Gdk.Key.q:
                        // Close window
                        close();
                        return true;
                    case Gdk.Key.s:
                        // Save file
                        save_chr_file();
                        return true;
                    case Gdk.Key.o:
                        // Open file
                        open_file();
                        return true;
                    case Gdk.Key.n:
                        // New file
                        editor_view.clear_editor();
                        preview_view.clear_canvas();
                        chr_data.filename = "untitled10x10.chr";
                        return true;
                    case Gdk.Key.r:
                        // Rename file
                        bottom_toolbar.focus_filename();
                        return true;
                    case Gdk.Key.a:
                        // Select all
                        editor_view.select_tile(0, 0);
                        return true;
                    case Gdk.Key.c:
                        // Copy - handled by menu component
                        var action = lookup_action("copy") as SimpleAction;
                        if (action != null) action.activate(null);
                        return true;
                    case Gdk.Key.p:
                        // Paste - handled by menu component
                        var action = lookup_action("paste") as SimpleAction;
                        if (action != null) action.activate(null);
                        return true;
                    case Gdk.Key.x:
                        // Cut - handled by menu component
                        var action = lookup_action("cut") as SimpleAction;
                        if (action != null) action.activate(null);
                        return true;
                    case Gdk.Key.i:
                        // Invert - handled by menu component
                        var action = lookup_action("invert") as SimpleAction;
                        if (action != null) action.activate(null);
                        return true;
                    case Gdk.Key.k:
                        // Colorize - handled by menu component
                        var action = lookup_action("colorize") as SimpleAction;
                        if (action != null) action.activate(null);
                        return true;
                    case Gdk.Key.b:
                        // Brush tool
                        chr_data.selected_tool = 0;
                        bottom_toolbar.queue_draw();
                        return true;
                    case Gdk.Key.t:
                        // Cursor tool
                        chr_data.selected_tool = 1;
                        bottom_toolbar.queue_draw();
                        return true;
                    case Gdk.Key.e:
                        // Zoom tool
                        chr_data.selected_tool = 2;
                        bottom_toolbar.queue_draw();
                        return true;
                    case Gdk.Key.@0:
                        // Background color
                        chr_data.selected_color = 0;
                        bottom_toolbar.queue_draw();
                        return true;
                    case Gdk.Key.@1:
                        // Color 1
                        chr_data.selected_color = 1;
                        bottom_toolbar.queue_draw();
                        return true;
                    case Gdk.Key.@2:
                        // Color 2
                        chr_data.selected_color = 2;
                        bottom_toolbar.queue_draw();
                        return true;
                    case Gdk.Key.@3:
                        // Color 3
                        chr_data.selected_color = 3;
                        bottom_toolbar.queue_draw();
                        return true;
                }
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