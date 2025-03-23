public class Window : Gtk.ApplicationWindow {
    private Gtk.Overlay overlay;
    private CheckboxTextView text_view;
    private Gtk.TextBuffer buffer;
    private ThemeManager theme;
    
    // Drawing areas for visual elements
    private Gtk.DrawingArea background_area;
    
    // Page navigation elements
    private Gtk.Label page_label;
    private Gtk.DrawingArea page_curl;
    private Gee.ArrayList<string> pages = new Gee.ArrayList<string>();
    private int current_page = 0;
    
    // Checkbox data storage
    private Gee.Map<int, Gee.List<CheckboxTextViewCheckboxData>> checkbox_data_by_page 
        = new Gee.HashMap<int, Gee.List<CheckboxTextViewCheckboxData>>();

    public Window(Gtk.Application app) {
        Object(application: app);
        theme = ThemeManager.get_default();
        theme.apply_to_display();
        setup_theme_management();
        theme.theme_changed.connect(() => {
            background_area.queue_draw();
        });
    }
    
    construct {
        title = "Note Pad";
        resizable = false;
        
        var _tmp = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        _tmp.visible = false;
        titlebar = _tmp;
        
        // Load CSS
        var provider = new Gtk.CssProvider();
        provider.load_from_resource("/com/example/notepadapp/style.css");
        
        // Apply CSS to the app
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
        
        // Initialize pages
        pages = new Gee.ArrayList<string>();
        for (int i = 0; i < 8; i++) {
            pages.add("");
        }
        
        setup_page_system();
        
        load_file();
        current_page = 0;
        load_page();
        update_display();
        
        // Setup keyboard shortcuts
        var shortcut_controller = new Gtk.ShortcutController();
        text_view.add_controller(shortcut_controller);
        
        shortcut_controller.add_shortcut(
            new Gtk.Shortcut(
                Gtk.ShortcutTrigger.parse_string("<Control>S"),
                new Gtk.CallbackAction((widget) => {
                    save_file();
                    return true;
                })
            )
        );
        
        shortcut_controller.add_shortcut(
            new Gtk.Shortcut(
                Gtk.ShortcutTrigger.parse_string("<Control>O"),
                new Gtk.CallbackAction((widget) => {
                    load_file();
                    return true;
                })
            )
        );
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
    
    private void setup_page_system() {
        overlay = new Gtk.Overlay();
        overlay.height_request = 225;
        
        // Background area for styling
        background_area = new Gtk.DrawingArea() {
            valign = Gtk.Align.END,
            height_request = 30,
            hexpand = true
        };
        
        background_area.set_draw_func(draw_background);
        
        // Text view for notes
        text_view = new CheckboxTextView() {
            margin_bottom = 30,
            vexpand = true
        };
        
        text_view.add_css_class("mac-textview");
        
        buffer = text_view.buffer;
        
        // Gesture for handling checkbox toggling
        var double_click = new Gtk.GestureClick();
        double_click.button = 1;
        double_click.set_propagation_phase(Gtk.PropagationPhase.CAPTURE);
        
        double_click.pressed.connect((n_press, x, y) => {
            if (n_press == 2) {
                // Convert window coordinates to buffer coordinates
                int buffer_x, buffer_y;
                text_view.window_to_buffer_coords(
                    Gtk.TextWindowType.TEXT,
                    (int)x, (int)y,
                    out buffer_x, out buffer_y
                );
                
                Gtk.TextIter iter;
                text_view.get_iter_at_location(out iter, buffer_x, buffer_y);
                
                toggle_line_marker(iter);
            }
        });
        
        text_view.add_controller(double_click);
        
        // Create main layout box 
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        box.append(create_titlebar());
        box.append(text_view);
        
        // Create page curl widget
        page_curl = new Gtk.DrawingArea() {
            width_request = 30,
            height_request = 30,
            halign = Gtk.Align.START,
            valign = Gtk.Align.END,
            margin_bottom = 7
        };
        
        var click = new Gtk.GestureClick();
        click.pressed.connect(() => {
            switch_page();
        });
        page_curl.add_controller(click);
        
        // Page number label
        page_label = new Gtk.Label("1") {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.END,
            margin_bottom = 12
        };
        
        page_label.add_css_class("page-counter");
        
        overlay.set_child(box);
        overlay.add_overlay(background_area);
        overlay.add_overlay(page_curl);
        overlay.add_overlay(page_label);
        
        set_child(overlay);
    }
    
    /**
     * Toggles a line marker at the beginning of the current line.
     * Changes '>' to '-' or '-' to '>' at the start of a line.
     * 
     * @param iter The TextIter position where action is initiated
     */
    public void toggle_line_marker(Gtk.TextIter iter) {
        text_view.toggle_line_marker(iter);
        save_file();
    }
    
    private void draw_background(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        var bg_color = theme.get_color("theme_bg");
        var sel_color = theme.get_color("theme_selection");
        var fg_color = theme.get_color("theme_fg");
        double square_size = 20;
        cr.set_antialias(Cairo.Antialias.NONE);
        cr.set_line_width(1);
        cr.set_line_cap(Cairo.LineCap.SQUARE);
        cr.set_line_join(Cairo.LineJoin.MITER);
        
        // Clear background
        cr.set_source_rgba(bg_color.red, bg_color.green, bg_color.blue, 0);
        cr.paint();
        
        // Draw triangle corner
        cr.set_source_rgb(sel_color.red, sel_color.green, sel_color.blue);
        cr.new_path();
        cr.move_to(0, height - 27);
        cr.line_to(square_size, height - 27);
        cr.line_to(square_size, height - 7);
        cr.close_path();
        cr.fill();
        
        // Draw outline
        cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
        cr.new_path();
        cr.move_to(0, height - 27);
        cr.line_to(square_size, height - 27);
        cr.line_to(square_size, height - 7);
        cr.close_path();
        cr.stroke();
        
        // Draw bottom lines for visual effect 
        cr.new_path();
        cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
        
        cr.move_to(square_size, height - 7);
        cr.line_to(width, height - 7);
        cr.stroke();
        
        cr.move_to(0, height);
        cr.line_to(width, height);
        cr.stroke();
        
        cr.move_to(0, height - 1);
        cr.line_to(width, height - 1);
        cr.stroke();
        
        cr.move_to(0, height - 3);
        cr.line_to(width, height - 3);
        cr.stroke();
        
        cr.move_to(0, height - 5);
        cr.line_to(width, height - 5);
        cr.stroke();
    }
    
    private void switch_page() {
        // Save current page state
        save_current_page_state();
        
        // Switch to next page
        current_page = (current_page + 1) % 8;
        
        // Load the next page
        load_page();
    }
    
    private void save_current_page_state() {
        if (current_page < 0 || current_page >= 8) {
            return;
        }
        
        // Get the text from buffer
        Gtk.TextIter start, end;
        text_view.buffer.get_bounds(out start, out end);
        pages[current_page] = text_view.buffer.get_text(start, end, false);
        
        // Get checkbox data from the view
        var cb_view = (CheckboxTextView)text_view;
        checkbox_data_by_page[current_page] = cb_view.get_checkbox_data();
    }
    
    private void load_page() {
        if (current_page >= 0 && current_page < 8) {
            // Set text buffer
            text_view.buffer.text = pages[current_page];
            
            // Restore checkbox data if there is any
            if (checkbox_data_by_page.has_key(current_page)) {
                var cb_view = (CheckboxTextView)text_view;
                cb_view.add_checkboxes_from_data(checkbox_data_by_page[current_page]);
            }
            
            update_display();
        }
    }
    
    private void update_display() {
        page_label.label = "%i".printf(current_page + 1);
        background_area.queue_draw();
        queue_draw();
    }
    
    public void save_file() {
        save_current_page_state();
        
        // Create JSON builder
        var builder = new Json.Builder();
        builder.begin_array();
        
        for (int page_idx = 0; page_idx < 8; page_idx++) {
            var page_builder = new Json.Builder();
            page_builder.begin_object();
            
            // Add page text
            page_builder.set_member_name("text");
            page_builder.add_string_value(pages[page_idx]);
            
            // Add checkboxes if they exist
            if (checkbox_data_by_page.has_key(page_idx)) {
                var checkbox_data = checkbox_data_by_page[page_idx];
                
                page_builder.set_member_name("checkboxes");
                page_builder.begin_array();
                
                foreach (var cb in checkbox_data) {
                    page_builder.begin_object();
                    page_builder.set_member_name("line");
                    page_builder.add_int_value(cb.line);
                    page_builder.set_member_name("offset");
                    page_builder.add_int_value(cb.offset);
                    page_builder.set_member_name("checked");
                    page_builder.add_boolean_value(cb.is_checked);
                    page_builder.end_object();
                }
                
                page_builder.end_array();
            }
            
            page_builder.end_object();
            builder.add_value(page_builder.get_root());
        }
        
        builder.end_array();
        
        string filepath = Utils.get_data_path("notes.json");
        string json_content = Json.to_string(builder.get_root(), true);
        Utils.save_to_file(filepath, json_content);
    }
    
    private void load_file() {
        try {
            string filepath = Utils.get_data_path("notes.json");
            string content = Utils.load_from_file(filepath);
            if (content == "") {
                return;
            }
            
            var parser = new Json.Parser();
            parser.load_from_data(content);
            
            pages.clear();
            
            // Clear all checkbox data
            checkbox_data_by_page.clear();
            
            var root = parser.get_root().get_array();
            root.foreach_element((array, page_idx, node) => {
                if (page_idx >= 8) return;
                
                var page_obj = node.get_object();
                string page_text = page_obj.get_string_member("text");
                pages.add(page_text);
                
                if (page_obj.has_member("checkboxes")) {
                    var checkboxes = new Gee.ArrayList<CheckboxTextViewCheckboxData>();
                    
                    var cb_array = page_obj.get_array_member("checkboxes");
                    cb_array.foreach_element((cb_arr, idx, cb_node) => {
                        var cb_obj = cb_node.get_object();
                        int line = (int)cb_obj.get_int_member("line");
                        int offset = (int)cb_obj.get_int_member("offset");
                        bool is_checked = cb_obj.get_boolean_member("checked");
                        
                        checkboxes.add(new CheckboxTextViewCheckboxData(line, offset, is_checked));
                    });
                    
                    checkbox_data_by_page[page_idx] = checkboxes;
                }
            });
            
            // Ensure we have 8 pages
            while (pages.size < 8) {
                pages.add("");
            }
            
            current_page = 0;
            load_page();
            update_display();
        } catch (Error e) {
            warning("Error loading file: %s", e.message);
        }
    }
    
    private Gtk.Widget create_titlebar() {
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = 225;
        title_bar.add_css_class("title-bar");
        
        // Add gesture to toggle visibility
        var click_controller = new Gtk.GestureClick();
        click_controller.button = 1;
        click_controller.released.connect(() => {
            if (text_view.visible) {
                page_label.visible = false;
                text_view.visible = false;
                background_area.visible = false;
                overlay.height_request = 0;
            } else {
                page_label.visible = true;
                text_view.visible = true;
                background_area.visible = true;
                overlay.height_request = 225;
            }
        });
        
        // Create close button
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;
        close_button.clicked.connect(() => {
            close();
        });
        
        // Create title label
        var title_label = new Gtk.Label("Note Pad");
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
        
        // Create vertical layout
        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        vbox.append(winhandle);
        
        return vbox;
    }
}