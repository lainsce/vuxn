public class TyneWindow : Gtk.ApplicationWindow {
    private Gtk.DrawingArea grid_area;
    private Gtk.ScrolledWindow scroll;
    private Gtk.Label title_label;
    private FontUtils font_utils;
    private Theme.Manager theme;
    
    public TyneWindow(Gtk.Application app) {
        Object(
            application: app,
            title: "Tyne",
            default_width: 800,
            default_height: 600,
            resizable: false
        );
        
        set_titlebar(
            new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0) { 
                visible = false
            }
        );
        
        font_utils = new FontUtils();
        setup_ui();
        
        theme.theme_changed.connect(grid_area.queue_draw);
    }
    
    private void setup_ui() {
        var main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0) {
            vexpand = true,
            hexpand = true
        };
        
        main_box.append(create_titlebar());
        
        // Create grid view
        grid_area = new Gtk.DrawingArea() {
            valign = Gtk.Align.CENTER,
            halign = Gtk.Align.CENTER
        };
        grid_area.set_draw_func(draw_grid_func);
        
        scroll = new Gtk.ScrolledWindow() {
            vexpand = true,
            hexpand = true,
            hscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
            vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
            min_content_height = 600
        };
        scroll.set_child(grid_area);
        
        main_box.append(scroll);
        
        // Add keyboard shortcuts to main_box
        var key_controller = new Gtk.EventControllerKey();
        key_controller.key_pressed.connect((keyval, keycode, state) => {
            // Check if Control key is pressed
            if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                if (keyval == Gdk.Key.o || keyval == Gdk.Key.O) {
                    // Ctrl+O: Open file
                    on_load_button_clicked();
                    return true;
                } else if (keyval == Gdk.Key.s || keyval == Gdk.Key.S) {
                    // Ctrl+S: Save file as BDF
                    on_save_button_clicked();
                    return true;
                }
            }
            return false;
        });
        main_box.add_controller(key_controller);
        
        this.set_child(main_box);
    }
    
    // Title bar
    private Gtk.Widget create_titlebar() {
        // Create classic Mac-style title bar
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = 225;
        title_bar.add_css_class("title-bar");

        // Add event controller for right-click to toggle calendar visibility
        var click_controller = new Gtk.GestureClick();
        click_controller.set_button(1); // 1 = right mouse button
        click_controller.released.connect(() => {
            if (scroll.visible) {
                scroll.visible = false;
            } else {
                scroll.visible = true;
            }
        });

        // Close button on the left
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;
        close_button.clicked.connect(() => {
            this.close();
        });

        title_label = new Gtk.Label("Tyne");
        title_label.add_css_class("title-box");
        title_label.hexpand = true;
        title_label.margin_end = 8;
        title_label.valign = Gtk.Align.CENTER;
        title_label.halign = Gtk.Align.CENTER;

        title_label.add_controller(click_controller);

        title_bar.append(close_button);
        title_bar.append(title_label);

        var winhandle = new Gtk.WindowHandle();
        winhandle.set_child(title_bar);

        // Main layout
        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        vbox.append(winhandle);

        return vbox;
    }
    
    private void on_load_button_clicked() {
        var file_dialog = new Gtk.FileDialog() {
            title = "Load Font File",
            modal = true
        };
        
        var filter = new Gtk.FileFilter();
        filter.set_filter_name("UFX Font Files");
        filter.add_pattern("*.uf1");
        filter.add_pattern("*.uf2");
        filter.add_pattern("*.uf3");
        
        var filters = new ListStore(typeof(Gtk.FileFilter));
        filters.append(filter);
        file_dialog.set_filters(filters);
        
        file_dialog.open.begin(this, null, (obj, res) => {
            try {
                var file = file_dialog.open.end(res);
                font_utils.load_font_file(file, grid_area);
                title_label.label = 
                    Path.get_basename(font_utils.current_filename);
            } catch (Error e) {
                warning("Error selecting file: %s", e.message);
            }
        });
    }
    
    private void on_save_button_clicked() {
        if (font_utils.font_data == null) {
            return;
        }
        
        var file_dialog = new Gtk.FileDialog() {
            title = "Save as BDF",
            modal = true
        };
        
        var filter = new Gtk.FileFilter() {};
        filter.set_filter_name("BDF Font Files");
        filter.add_pattern("*.bdf");
        
        var filters = new ListStore(typeof(Gtk.FileFilter)) {};
        filters.append(filter);
        file_dialog.set_filters(filters);
        
        // Suggest filename based on current file
        if (font_utils.current_filename != null) {
            string basename = Path.get_basename(font_utils.current_filename);
            string dirname = Path.get_dirname(font_utils.current_filename);
            string name_without_ext = basename.substring(
                0, basename.last_index_of("."));
            file_dialog.set_initial_name(name_without_ext + ".bdf");
            file_dialog.set_initial_folder(File.new_for_path(dirname));
        } else {
            file_dialog.set_initial_name("font.bdf");
        }
        
        file_dialog.save.begin(this, null, (obj, res) => {
            try {
                var file = file_dialog.save.end(res);
                font_utils.save_bdf_file(file);
            } catch (Error e) {
                warning("Error selecting save location: %s", e.message);
            }
        });
    }
    
    private void draw_grid_func(Gtk.DrawingArea drawing_area, 
                               Cairo.Context cr, int width, int height) {
        // Clear the canvas
        Gdk.RGBA bg_color = theme.get_color("theme_bg");
        Gdk.RGBA fg_color = theme.get_color("theme_fg");

        cr.set_source_rgba(bg_color.red, bg_color.green, bg_color.blue, 0);
        cr.paint();
        
        // Set up drawing parameters
        cr.set_line_width(1);
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Draw each glyph in a grid
        cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
        int bytes_per_glyph = font_utils.get_bytes_per_glyph();
        
        // Start from character 32 (space) and skip the first 32 control characters
        for (int i = 0; i < font_utils.get_glyph_count(); i++) {
            // Calculate grid position (adjusted for skipping first 32 chars)
            int grid_index = i - 32;
            int row = grid_index / FontUtils.GRID_COLS;
            int col = grid_index % FontUtils.GRID_COLS;
            
            int x = col * (font_utils.GLYPH_WIDTH / 2) * FontUtils.GRID_SCALE;
            int y = row * (font_utils.GLYPH_HEIGHT / 2) * FontUtils.GRID_SCALE;
            
            // Store current_glyph temporarily
            int temp_current_glyph = font_utils.current_glyph;
            // Set current_glyph to i for the draw_glyph function
            font_utils.current_glyph = i;
            
            // Calculate adjusted offset for the font data
            int adjusted_offset = FontUtils.HEADER_SIZE + 
                                 (i * bytes_per_glyph);
            
            // Get the actual width of this glyph
            uint8 actual_width = i < font_utils.GLYPH_WIDTHS.length ? 
                                font_utils.GLYPH_WIDTHS[i] : 
                                (uint8)font_utils.GLYPH_WIDTH;
            
            // Draw the glyph at the calculated position
            font_utils.draw_glyph_at_position(
                cr, 
                adjusted_offset, 
                x + 8, 
                y + 8, 
                FontUtils.GRID_SCALE, 
                actual_width
            );
            
            // Restore current_glyph
            font_utils.current_glyph = temp_current_glyph;
        }
    }
}