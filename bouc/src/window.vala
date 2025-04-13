public class MainWindow : Gtk.ApplicationWindow {
    // UI elements
    private Gtk.DrawingArea drawing_area;
    private Gtk.Box main_box;
    private Theme.Manager theme;
    
    // Book data
    private string book_title = "";
    private string book_content = "";
    private int scroll_position = 0;
    private int total_lines = 0;
    private int current_line = 0;
    private int line_height = AppConstants.LINE_HEIGHT;
    
    // UI state
    private bool is_up_arrow_pressed = false;
    private bool is_down_arrow_pressed = false;
    private uint hold_timeout_id = 0;
    private bool is_file_list_visible = false;
    private FileInfo[] directory_files = new FileInfo[0];
    private int hover_file_index = -1;
    
    // Colors
    private Gdk.RGBA color_white;
    private Gdk.RGBA color_black;
    private Gdk.RGBA color_cyan;
    private Gdk.RGBA color_red;

    public MainWindow(Gtk.Application app) {
        Object(
            application: app,
            title: "Bouc",
            default_width: AppConstants.DEFAULT_WIDTH,
            default_height: AppConstants.DEFAULT_HEIGHT
        );
        resizable = false;
        
        theme = Theme.Manager.get_default();
        theme.apply_to_display();
        setup_theme_management();
        drawing_area.queue_draw();
        theme.theme_changed.connect(() => {
            drawing_area.queue_draw();
        });
    }
    
    construct {
        var _tmp = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        _tmp.visible = false;
        titlebar = _tmp;

        initialize_colors();
        setup_ui();
        setup_controllers();
        
        // Load CSS
        var provider = new Gtk.CssProvider();
        provider.load_from_resource("/com/example/bouc/style.css");
        
        // Apply CSS to the app
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
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
    
    private void initialize_colors() {
        theme = Theme.Manager.get_default();
        color_white = theme.get_color ("theme_bg");
        color_black = theme.get_color ("theme_fg");
        color_cyan = theme.get_color ("theme_accent");
        color_red = theme.get_color ("theme_selection");
        drawing_area.queue_draw();
        
        theme.theme_changed.connect(() => {
            drawing_area.queue_draw();
        });
    }
    
    private void setup_ui() {
        // Create main vertical box
        main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        set_child(main_box);
        
        // Create drawing area
        drawing_area = new Gtk.DrawingArea();
        drawing_area.set_draw_func(draw_func);
        drawing_area.set_content_width(AppConstants.DEFAULT_WIDTH);
        drawing_area.set_content_height(AppConstants.DEFAULT_HEIGHT);
        drawing_area.vexpand = true;
        drawing_area.hexpand = true;
        
        var click_controller = new Gtk.GestureClick();
        drawing_area.add_controller(click_controller);
        click_controller.pressed.connect(on_click_pressed);
        
        main_box.append(create_titlebar());
        main_box.append(drawing_area);
    }
    
    private Gtk.Widget create_titlebar() {
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = AppConstants.DEFAULT_WIDTH;
        
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
        
        var winhandle = new Gtk.WindowHandle();
        winhandle.set_child(title_bar);
        
        // Create vertical layout
        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        vbox.append(winhandle);
        
        return vbox;
    }
    
    private void setup_controllers() {
        // Add keyboard controller to main_box (not window) per requirements
        var key_controller = new Gtk.EventControllerKey();
        main_box.add_controller(key_controller);
        key_controller.key_pressed.connect(on_key_pressed);
        
        // Add scroll controller
        var scroll_controller = new Gtk.EventControllerScroll(Gtk.EventControllerScrollFlags.VERTICAL);
        main_box.add_controller(scroll_controller);
        scroll_controller.scroll.connect(on_scroll);
        
        // Add mouse motion controller for hover effects
        var motion_controller = new Gtk.EventControllerMotion();
        drawing_area.add_controller(motion_controller);
        motion_controller.motion.connect(on_mouse_motion);
        motion_controller.leave.connect(() => {
            hover_file_index = -1;
            drawing_area.queue_draw();
        });
    }
    
    private void on_click_pressed(Gtk.GestureClick gesture, int n_press, double x, double y) {
        int height = drawing_area.get_height();
     
        // Check if click is within the diamond area (top-left)
        if (x >= 0 && x <= 16 && y >= 0 && y <= 16) {
            // Toggle file list visibility
            is_file_list_visible = !is_file_list_visible;
            
            if (is_file_list_visible) {
                // Load files from current directory
                load_directory_files();
            }
            
            drawing_area.queue_draw();
            return;
        }
        
        // If file list is visible, check if we clicked on a file
        if (is_file_list_visible && hover_file_index >= 0 && hover_file_index < directory_files.length) {
            // User clicked on a file, load it
            FileInfo file_info = directory_files[hover_file_index];
            string filename = file_info.get_name();
            File file = File.new_for_path(Path.build_filename(Environment.get_home_dir() + "/Documents/docs/", filename));
            load_file(file);
            
            // Hide file list
            is_file_list_visible = false;
            drawing_area.queue_draw();
            return;
        }
        
        // Don't process scrollbar clicks if file list is visible
        if (is_file_list_visible) {
            return;
        }
        
        // Calculate arrow button areas
        int up_arrow_y = AppConstants.SCROLLBAR_Y;
        int down_arrow_y = height - AppConstants.ARROW_BUTTON_HEIGHT;
        
        // Check if click is on the up arrow button
        if (x >= AppConstants.SCROLLBAR_X && x <= AppConstants.SCROLLBAR_X + AppConstants.SCROLLBAR_WIDTH && 
            y >= up_arrow_y && y <= up_arrow_y + AppConstants.ARROW_BUTTON_HEIGHT) {
            
            // Start scrolling up
            is_up_arrow_pressed = true;
            handle_arrow_button_press(true);
            
            // Set up a timeout to continue scrolling while the button is held
            if (hold_timeout_id == 0) {
                hold_timeout_id = Timeout.add(100, () => {
                    if (is_up_arrow_pressed) {
                        handle_arrow_button_press(true);
                        return true;
                    } else {
                        hold_timeout_id = 0;
                        return false;
                    }
                });
            }
            
            // Connect to the release event
            gesture.released.connect((n_press, x, y) => {
                is_up_arrow_pressed = false;
            });
            
            return;
        }
        
        // Check if click is on the down arrow button
        if (x >= AppConstants.SCROLLBAR_X && x <= AppConstants.SCROLLBAR_X + AppConstants.SCROLLBAR_WIDTH && 
            y >= down_arrow_y && y <= down_arrow_y + AppConstants.ARROW_BUTTON_HEIGHT) {
            
            // Start scrolling down
            is_down_arrow_pressed = true;
            handle_arrow_button_press(false);
            
            // Set up a timeout to continue scrolling while the button is held
            if (hold_timeout_id == 0) {
                hold_timeout_id = Timeout.add(100, () => {
                    if (is_down_arrow_pressed) {
                        handle_arrow_button_press(false);
                        return true;
                    } else {
                        hold_timeout_id = 0;
                        return false;
                    }
                });
            }
            
            // Connect to the release event
            gesture.released.connect((n_press, x, y) => {
                is_down_arrow_pressed = false;
            });
            
            return;
        }
        
        // Check if click is on the scrollbar (between arrow buttons)
        if (x >= AppConstants.SCROLLBAR_X && x <= AppConstants.SCROLLBAR_X + AppConstants.SCROLLBAR_WIDTH && 
            y >= AppConstants.SCROLLBAR_Y + AppConstants.ARROW_BUTTON_HEIGHT && 
            y <= down_arrow_y) {
            
            handle_scrollbar_click(y, height);
        }
    }
    
    private void on_mouse_motion(Gtk.EventControllerMotion controller, double x, double y) {
        if (!is_file_list_visible) {
            return;
        }
        
        // Get the file index under the cursor
        int new_hover_index = -1;
        
        int file_y = AppConstants.CONTENT_Y_START;
        
        for (int i = 0; i < directory_files.length; i++) {
            // Calculate file entry bounds
            int entry_height = line_height + 4;
            
            if (y >= file_y && y < file_y + entry_height) {
                new_hover_index = i;
                break;
            }
            
            file_y += entry_height;
        }
        
        if (new_hover_index != hover_file_index) {
            hover_file_index = new_hover_index;
            drawing_area.queue_draw();
        }
    }
    
    private void handle_arrow_button_press(bool is_up_arrow) {
        if (is_file_list_visible) {
            return;
        }
        
        if (is_up_arrow) {
            // Scroll up
            scroll_position -= AppConstants.SCROLL_SPEED_HOLD;
        } else {
            // Scroll down
            scroll_position += AppConstants.SCROLL_SPEED_HOLD;
        }
        
        // Make sure scroll position stays within bounds
        int visible_lines = calculate_visible_lines(drawing_area.get_height());
        adjust_scroll_position(visible_lines);
        
        drawing_area.queue_draw();
    }
    
    private void handle_scrollbar_click(double y, int height) {
        if (is_file_list_visible) {
            return;
        }
        
        // Calculate the target scroll position based on click position
        int visible_lines = calculate_visible_lines(height);
        
        // Adjust for arrow buttons
        double scroll_area_height = height - 2 * AppConstants.ARROW_BUTTON_HEIGHT;
        double relative_y = y - (AppConstants.SCROLLBAR_Y + AppConstants.ARROW_BUTTON_HEIGHT);
        double ratio = relative_y / scroll_area_height;
        
        if (total_lines > 0) {
            int new_position = (int)(ratio * (total_lines - visible_lines));
            scroll_position = new_position;
            adjust_scroll_position(visible_lines);
            drawing_area.queue_draw();
        }
    }
    
    private int calculate_visible_lines(int height) {
        return (int)((height - 100) / line_height);
    }
    
    private void adjust_scroll_position(int visible_lines) {
        if (scroll_position < 0) scroll_position = 0;
        if (total_lines > 0 && scroll_position > total_lines - visible_lines) {
            scroll_position = total_lines - visible_lines;
            if (scroll_position < 0) scroll_position = 0;
        }
    }
    
    private void draw_func(Gtk.DrawingArea drawing_area, Cairo.Context cr, int width, int height) {
        // Clear the background
        initialize_colors();
        cr.set_source_rgba(color_white.red, color_white.green, color_white.blue, color_white.alpha);
        cr.paint();
        
        // Set anti-aliasing to none for sharper drawing (per requirements)
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Draw the diamond menu button in the top-left corner
        DrawingHelpers.draw_diamond(cr, color_red, AppConstants.DIAMOND_X, AppConstants.DIAMOND_Y, AppConstants.DIAMOND_SIZE);
        
        // Draw based on current mode
        if (is_file_list_visible) {
            draw_directory_file_list(cr, width, height);
        } else {
            // Draw custom scrollbar
            draw_scrollbar(cr, AppConstants.SCROLLBAR_X, AppConstants.SCROLLBAR_Y, 
                       AppConstants.SCROLLBAR_WIDTH, height - AppConstants.SCROLLBAR_Y);
        
            // Calculate text boundaries
            int text_x_start = AppConstants.SCROLLBAR_WIDTH + AppConstants.TEXT_MARGIN;
            int text_x_end = width - AppConstants.TEXT_MARGIN;
            int text_width = text_x_end - text_x_start;
            
            // Draw the line counter
            draw_line_counter(cr, width - AppConstants.LINE_COUNTER_X_OFFSET, AppConstants.DIAMOND_Y);
            
            // Draw the book title
            if (book_title != "") {
                DrawingHelpers.draw_text(cr, book_title, text_x_start, AppConstants.TITLE_Y_POSITION, 
                                        false, color_black, text_width);
            }
            
            // Draw the book content
            draw_book_content(cr, text_x_start, text_width, height);
        }
    }
    
    private void draw_directory_file_list(Cairo.Context cr, int width, int height) {
        int x_start = AppConstants.TEXT_MARGIN;
        int y_pos = AppConstants.CONTENT_Y_START;
        
        // Draw directory files
        for (int i = 0; i < directory_files.length; i++) {
            FileInfo file_info = directory_files[i];
            string filename = file_info.get_name();
            int64 file_size = file_info.get_size();
            
            string display_text = "%s, %lld bytes".printf(filename, file_size);
            
            // Draw hover highlight if this is the hovered file
            if (i == hover_file_index) {
                // Calculate text size to determine highlight area
                cr.save();
                cr.select_font_face("New York 14", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
                cr.set_font_size(14);
                
                Cairo.TextExtents extents;
                cr.text_extents(display_text, out extents);
                
                double rect_width = extents.width + 20; // Add some padding
                double rect_height = line_height + 4;
                
                // Draw highlight rectangle with triangle
                cr.set_source_rgba(color_black.red, color_black.green, color_black.blue, 1.0);
                
                // Draw rectangle
                cr.rectangle(x_start, y_pos, rect_width, rect_height);
                
                // Draw triangle on the side
                cr.move_to(x_start + rect_width, y_pos);
                cr.line_to(x_start + rect_width + 10, y_pos + rect_height / 2);
                cr.line_to(x_start + rect_width, y_pos + rect_height);
                cr.close_path();
                
                cr.fill();
                
                // Use inverted color for text
                DrawingHelpers.draw_text(cr, display_text, x_start + 7, y_pos + 10, true, color_white);
                
                cr.restore();
            } else {
                // Normal text
                DrawingHelpers.draw_text(cr, display_text, x_start + 7, y_pos + 10, true, color_black);
            }
            
            y_pos += line_height + 4;
        }
    }
    
    private void draw_book_content(Cairo.Context cr, int x_start, int text_width, int height) {
        int y_pos = AppConstants.CONTENT_Y_START;
        
        if (book_content == "")
            return;
            
        // Create wrapped lines array by processing original lines
        string[] wrapped_lines = create_wrapped_lines(cr, text_width);
        
        // Update total_lines with the wrapped line count
        total_lines = wrapped_lines.length;
        
        // Calculate visible lines based on height
        int visible_lines = calculate_visible_lines(height);
        
        // Ensure scroll position is within bounds
        adjust_scroll_position(visible_lines);
        
        // Calculate current line (shown in the middle of the view)
        current_line = scroll_position + visible_lines / 2;
        if (current_line >= total_lines) current_line = total_lines - 1;
        if (current_line < 0) current_line = 0;
        
        // Draw visible lines
        for (int i = scroll_position; i < scroll_position + visible_lines && i < wrapped_lines.length; i++) {
            DrawingHelpers.draw_text(cr, wrapped_lines[i], x_start, y_pos, true, color_black);
            y_pos += line_height;
        }
    }
    
    private string[] create_wrapped_lines(Cairo.Context cr, int text_width) {
        string[] original_lines = book_content.split("\n");
        string[] wrapped_lines = new string[0];
        
        // Prepare font for measurement
        cr.save();
        cr.select_font_face("New York 14", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        cr.set_font_size(14);
        
        // Process each original line and add wrapped lines to our array
        foreach (string line in original_lines) {
            // Skip empty lines
            if (line.strip() == "") {
                wrapped_lines += line;
                continue;
            }
            
            // Split the line into words
            string[] words = line.split(" ");
            string current_line = "";
            
            foreach (string word in words) {
                // Try adding the next word
                string test_line = current_line;
                if (test_line != "") {
                    test_line += " ";
                }
                test_line += word;
                
                // Measure line width
                Cairo.TextExtents extents;
                cr.text_extents(test_line, out extents);
                
                // If it fits, add the word
                if (extents.width <= text_width) {
                    current_line = test_line;
                } else {
                    // Line doesn't fit, store current line and start a new one
                    if (current_line != "") {
                        wrapped_lines += current_line;
                        current_line = word;
                    } else {
                        // Single word is too long, need to truncate
                        wrapped_lines += word;
                        current_line = "";
                    }
                }
            }
            
            // Add the last line if there's content
            if (current_line != "") {
                wrapped_lines += current_line;
            }
        }
        
        cr.restore();
        return wrapped_lines;
    }
    
    private void draw_scrollbar(Cairo.Context cr, double x, double y, double width, double height) {
        // Calculate the locations for arrow buttons
        int up_arrow_y = (int)y;
        int down_arrow_y = (int)(y + height - AppConstants.ARROW_BUTTON_HEIGHT);
        
        // Draw scrollbar trough with checkerboard pattern (excluding arrow button areas)
        cr.save();
        
        // Draw checkerboard pattern for the middle part only
        cr.set_source_rgba(color_black.red, color_black.green, color_black.blue, 1.0);
        for (int i = 0; i < height - 2 * AppConstants.ARROW_BUTTON_HEIGHT; i++) {
            for (int j = 0; j < width; j++) {
                if ((i + j) % 2 == 0) {
                    cr.rectangle(x + j, y + AppConstants.ARROW_BUTTON_HEIGHT + i, 1, 1);
                }
            }
        }
        cr.fill();
        
        // Calculate thumb position and size - adjusted for arrow buttons
        if (total_lines > 0) {
            double track_height = height - 2 * AppConstants.ARROW_BUTTON_HEIGHT;
            double visible_lines = (height / line_height);
            double thumb_ratio = Math.fmin(visible_lines / total_lines, 1.0);
            double thumb_height = Math.fmax(track_height * thumb_ratio, AppConstants.MIN_THUMB_HEIGHT);
            
            // Ensure thumb doesn't overlap arrow buttons
            thumb_height = Math.fmin(thumb_height, track_height);
            
            double max_scroll = Math.fmax(1.0, total_lines - visible_lines);
            double scroll_ratio = (double)scroll_position / max_scroll;
            
            // Position thumb between the arrow buttons
            double thumb_pos = y + AppConstants.ARROW_BUTTON_HEIGHT + 
                               (track_height - thumb_height) * scroll_ratio;
            
            // Draw the scrollbar thumb
            cr.set_source_rgba(color_black.red, color_black.green, color_black.blue, 1.0);
            cr.rectangle(x, thumb_pos, width, thumb_height);
            cr.fill();
        }
        
        // Draw arrow buttons
        DrawingHelpers.draw_arrow_button(cr, color_black, x, up_arrow_y, 
                                       width, AppConstants.ARROW_BUTTON_HEIGHT, true);
        DrawingHelpers.draw_arrow_button(cr, color_black, x, down_arrow_y, 
                                       width, AppConstants.ARROW_BUTTON_HEIGHT, false);
        
        cr.restore();
    }
    
    private void draw_line_counter(Cairo.Context cr, double x, double y) {
        if (total_lines > 0) {
            string line_text = "%X".printf(current_line);
            DrawingHelpers.draw_text(cr, line_text, x, y, true, color_cyan);
        }
    }
    
    private bool on_key_pressed(Gtk.EventControllerKey controller, uint keyval, uint keycode, Gdk.ModifierType state) {
        // Hide file list view when Escape is pressed
        if (keyval == Gdk.Key.Escape && is_file_list_visible) {
            is_file_list_visible = false;
            drawing_area.queue_draw();
            return true;
        }
        
        // Don't process other keyboard shortcuts in file list mode
        if (is_file_list_visible) {
            return false;
        }
        
        bool need_redraw = true;
        
        switch (keyval) {
            case Gdk.Key.Up:
                scroll_position--;
                break;
                
            case Gdk.Key.Down:
                scroll_position++;
                break;
                
            case Gdk.Key.Page_Up:
                scroll_position -= 10;
                break;
                
            case Gdk.Key.Page_Down:
                scroll_position += 10;
                break;
                
            case Gdk.Key.Home:
                scroll_position = 0;
                break;
                
            case Gdk.Key.End:
                scroll_position = int.max(0, total_lines - 1);
                break;
                
            default:
                need_redraw = false;
                break;
        }
        
        if (need_redraw) {
            int visible_lines = calculate_visible_lines(drawing_area.get_height());
            adjust_scroll_position(visible_lines);
            drawing_area.queue_draw();
            return true;
        }
        
        return false;
    }
    
    private bool on_scroll(Gtk.EventControllerScroll controller, double dx, double dy) {
        // Don't handle scrolling in file list mode
        if (is_file_list_visible) {
            return false;
        }
        
        // Update scroll position, adjusting the scroll speed
        scroll_position += (int)(dy * 3); // Multiply by 3 for faster scrolling
        
        // Make sure scroll position stays within bounds
        int visible_lines = calculate_visible_lines(drawing_area.get_height());
        adjust_scroll_position(visible_lines);
        
        drawing_area.queue_draw();
        return true;
    }
    
    private void load_directory_files() {
        try {
            // Get current directory
            string current_dir = Environment.get_home_dir() + "/Documents/docs/";
            File dir = File.new_for_path(current_dir);
            
            // Create a new array to store file info
            directory_files = new FileInfo[0];
            
            // Enumerate all files in the directory
            FileEnumerator enumerator = dir.enumerate_children(
                "standard::*",
                FileQueryInfoFlags.NONE
            );
            
            // Get file information for each entry
            FileInfo info = null;
            while ((info = enumerator.next_file()) != null) {
                string filename = info.get_name();
                
                // Only include .txt files
                if (filename.has_suffix(".txt") || filename.has_suffix(".TXT")) {
                    directory_files += info;
                }
            }
            
        } catch (Error e) {
            stderr.printf("Error reading directory: %s\n", e.message);
        }
    }
    
    private void load_file(File file) {
        try {
            string content;
            FileUtils.get_contents(file.get_path(), out content);
            
            // Set the book title using helper method
            book_title = DrawingHelpers.create_title_from_filename(file.get_basename());
            book_content = content;
            
            // Reset scroll position
            scroll_position = 0;
            
            // Redraw
            drawing_area.queue_draw();
            
        } catch (Error e) {
            stderr.printf("Error loading file: %s\n", e.message);
        }
    }
}