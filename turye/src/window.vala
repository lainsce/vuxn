using Gtk;

public class FontMakerWindow : Gtk.ApplicationWindow {
    private FontMakerApp app;

    // UI Elements
    private DrawingArea unified_edit_area;      // Combined editing/preview area
    private Grid char_selection_grid;           // 16x16 grid for character selection
    private DrawingArea pangram_area;           // Pangram preview area
    private Label editing_label;                // Shows the current character being edited
    private Box main_box;
    private DrawingArea[,] character_previews;
    
    // Preview texts (pangrams)
    private string[] preview_texts = {
        "Sphinx of black quartz, judge my vows."
    };
    
    // Track control dot dragging
    private bool is_dragging_spacing = false;
    
    // Track the current drawing state for drag operations
    private bool is_drawing = false;
    private bool is_erasing = false;
    private int last_grid_x = -1;
    private int last_grid_y = -1;
    
    // Clipboard for character data
    private uint16[] clipboard_data = null;
    private int clipboard_right_spacing = 0;
    private int clipboard_baseline = 0;
    
    private Theme.Manager theme;
    
    public FontMakerWindow(FontMakerApp app) {
        Object(
            application: app,
            title: "Turye",
            default_width: 554,
            default_height: 495,
            resizable: false
        );
        
        theme = Theme.Manager.get_default();
        theme.apply_to_display();
        setup_theme_management();
        theme.theme_changed.connect(() => {
            unified_edit_area.queue_draw ();
            pangram_area.queue_draw ();
        });

        this.app = app;
        this.set_titlebar (
            new Box (Gtk.Orientation.HORIZONTAL, 0) {
                visible = false
            }
        );

        // Build UI
        setup_ui();
        
        // Add keyboard shortcuts
        setup_keyboard_shortcuts();
        
                // Load CSS
        var provider = new Gtk.CssProvider();
        provider.load_from_resource("/com/example/turye/style.css");
        
        // Apply CSS to the app
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
    }
    
    private void setup_theme_management() {
        // Force initial theme load
        var theme_file = GLib.Path.build_filename(Environment.get_home_dir(), ".theme");

        // Set up the check
        GLib.Timeout.add(10, () => {
            if (FileUtils.test(theme_file, FileTest.EXISTS)) {
                try {
                    theme.load_theme_from_file(theme_file);
                } catch (Error e) {
                    warning("Theme load failed: %s", e.message);
                }
            }
            return true; // Continue the timeout
        });
    }

    private void setup_ui() {
        // Main container with vertical orientation
        main_box = new Box(Orientation.VERTICAL, 4);
        set_child(main_box);

        // === SECTION 1: Window title bar ===
        main_box.append (create_titlebar ());

        // === SECTION 2: Editing area with filename ===
        var edit_section = new Box(Orientation.VERTICAL, 4);
        var edit_frame = new Frame(null);
        edit_frame.add_css_class("section-frame");
        edit_frame.set_child(edit_section);
        main_box.append(edit_frame);
        
        // Unified editing + preview area with fixed dimensions (512x144)
        unified_edit_area = new DrawingArea() {
            width_request = 512,
            height_request = 144,
            hexpand = true
        };
        unified_edit_area.set_draw_func(draw_unified_edit_area);
        edit_section.append(unified_edit_area);
        
        // Mouse click and drag handling for the unified area
        var click_gesture = new GestureClick();
        click_gesture.set_button(1); // Left mouse button
        click_gesture.pressed.connect(on_unified_area_clicked);
        unified_edit_area.add_controller(click_gesture);
        
        // Add drag handling for drawing continuously
        var drag_controller = new GestureDrag();
        drag_controller.drag_begin.connect(on_drag_begin);
        drag_controller.drag_update.connect(on_drag_update);
        drag_controller.drag_end.connect(on_drag_end);
        unified_edit_area.add_controller(drag_controller);
        
        // Motion controller to track hovering
        var motion_controller = new EventControllerMotion();
        motion_controller.motion.connect(on_motion);
        unified_edit_area.add_controller(motion_controller);
        
        // === SECTION 3: 16x16 Grid of character selection with fixed dimensions (512x271) ===
        var selection_frame = new Frame(null);
        selection_frame.add_css_class("section-frame");
        selection_frame.add_css_class("character-grid");
        main_box.append(selection_frame);
        
        // Create scrolled window for the character grid
        var selection_scroll = new ScrolledWindow() {
            width_request = 512,
            height_request = 271,
            hscrollbar_policy = PolicyType.NEVER
        };
        selection_frame.set_child(selection_scroll);
        
        // Create a Grid for better spacing control (16x16)
        char_selection_grid = new Grid() {
            column_homogeneous = true,
            row_homogeneous = true,
            column_spacing = 0,
            row_spacing = 0
        };
        selection_scroll.set_child(char_selection_grid);
        
        character_previews = new DrawingArea[16, 16];
        
        // Populate the 16x16 grid with all 256 characters
        for (int row = 0; row < 16; row++) {
            for (int col = 0; col < 16; col++) {
                int char_code = row * 16 + col;
                
                // Create button with fixed size
                var button = new Button() {
                    width_request = 30,
                    height_request = 30
                };
                
                // Create a DrawingArea for custom character rendering
                var char_preview = new DrawingArea() {
                    width_request = 16,
                    height_request = 16,
                    halign = Align.CENTER,
                    valign = Align.CENTER
                };
                
                // Set up the drawing function with character code
                character_previews[row, col] = char_preview;
                char_preview.set_data("char_code", char_code);
                
                // Set up the drawing function without character code closure
                char_preview.set_draw_func(draw_character_preview);
                
                // Add the preview area to the button
                button.set_child(char_preview);
                
                // Add tooltip with character info
                button.set_tooltip_text("Code: %d (0x%02X)".printf(char_code, char_code));
                
                // Store character code for selection
                int code = char_code;
                button.clicked.connect(() => {
                    select_character(code);
                });
                
                // Add styling
                button.add_css_class("ascii-button");
                
                // Highlight if it's the current character
                if (char_code == app.current_char) {
                    button.add_css_class("current-char");
                }
                
                // Add to grid
                char_selection_grid.attach(button, col, row, 1, 1);
            }
        }
        
        // === SECTION 4: Pangram preview area with fixed dimensions (512x16) ===
        var pangram_frame = new Frame(null);
        pangram_frame.add_css_class("section-frame");
        main_box.append(pangram_frame);
        
        var pangram_box = new Box(Orientation.VERTICAL, 4) {
            width_request = 350,
            halign = Align.CENTER  // Center the pangram horizontally
        };
        pangram_frame.set_child(pangram_box);
        
        // The pangram drawing area with exact dimensions
        pangram_area = new DrawingArea() {
            width_request = 512,
            height_request = 16
        };
        pangram_area.set_draw_func(draw_pangram_preview);
        pangram_box.append(pangram_area);
    }
    
    private void refresh_character_preview(int char_code) {
        int row = char_code / 16;
        int col = char_code % 16;
        character_previews[row, col].queue_draw();
    }
    
    private void draw_character_preview(DrawingArea area, Cairo.Context cr, int width, int height) {
        // Get the character code from the widget's data
        int char_code = area.get_data("char_code");
        
        // Disable antialiasing for pixel-perfect rendering
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Theme Manager stuff
        Gdk.RGBA fg_color = theme.get_color("theme_fg");
        Gdk.RGBA bg_color = theme.get_color("theme_bg");
        
        // Clear background
        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
        cr.paint();
        
        // Get the baseline for this character
        int baseline = app.character_baseline[char_code];
        
        // Check if this character has any pixels set
        bool has_pixels = false;
        for (int y = 0; y < 16 && !has_pixels; y++) {
            if (app.character_data[char_code, y] > 0) {
                has_pixels = true;
            }
        }
        
        // If no pixels are set, handle differently based on character type
        if (!has_pixels) {
            if ((char_code < 32) || (char_code >= 128 && char_code < 160)) {
                // For non-printable characters, draw a cross
                cr.set_source_rgb(fg_color.red * 0.7, fg_color.green * 0.7, fg_color.blue * 0.7);
                cr.set_line_width(1);
                
                // Cross lines
                cr.move_to(4, 4);
                cr.line_to(12, 12);
                cr.stroke();
                
                cr.move_to(12, 4);
                cr.line_to(4, 12);
                cr.stroke();
            } else {
                // For printable characters, draw the system font character in selection color
                Gdk.RGBA sel_color = theme.get_color("theme_selection");
                cr.set_source_rgb(sel_color.red, sel_color.green, sel_color.blue);
                
                // Create the character string
                string char_text;
                if (char_code >= 32 && char_code < 128) {
                    // ASCII character
                    char_text = "%c".printf(char_code);
                } else {
                    // Latin-1 character
                    unichar uc = (unichar)char_code;
                    char_text = uc.to_string();
                }
                
                // Set up Chicago 12.1 font
                cr.select_font_face("Chicago 12.1", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
                cr.set_font_size(12);
                
                // Center the text
                Cairo.TextExtents extents;
                cr.text_extents(char_text, out extents);
                double x = (width - extents.width) / 2 - extents.x_bearing;
                double y = (height + extents.height) / 2;
                
                // Draw the text
                cr.move_to(x, y);
                cr.show_text(char_text);
            }
            
            return;
        }
        
        // Draw the character bitmap
        cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
        
        // Calculate scale factor to fit in the preview area
        double scale = Math.fmin(width / 16.0, height / 16.0);
        
        // Center the character horizontally
        double x_offset = (width - app.character_right_spacing[char_code] * scale) / 2;
        if (x_offset < 0) x_offset = 0;
        
        // Center the character vertically based on baseline
        double y_offset = (height - 16 * scale) / 2;
        
        for (int row = 0; row < 16; row++) {
            uint16 row_data = app.character_data[char_code, row];
            
            for (int col = 0; col < 16; col++) {
                // Check if this pixel is set
                if ((row_data & (1 << (15 - col))) > 0) {
                    // Calculate position with appropriate scaling
                    double pixel_x = x_offset + col * scale;
                    double pixel_y = y_offset + row * scale;
                    
                    // Draw the pixel
                    cr.rectangle(pixel_x, pixel_y, scale, scale);
                    cr.fill();
                }
            }
        }
    }
    
    // Title bar
    private Gtk.Widget create_titlebar() {
        // Create classic Mac-style title bar
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = 513;
        title_bar.add_css_class("title-bar");

        // Close button on the left
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;
        close_button.clicked.connect(() => {
            this.close();
        });

        var title_label = new Gtk.Label("Turye");
        title_label.add_css_class("title-box");
        title_label.hexpand = true;
        title_label.valign = Gtk.Align.CENTER;
        title_label.halign = Gtk.Align.CENTER;

        title_bar.append(close_button);
        title_bar.append(title_label);

        var winhandle = new Gtk.WindowHandle();
        winhandle.set_child(title_bar);

        // Main layout
        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        vbox.append(winhandle);

        return vbox;
    }
    
    private void draw_unified_edit_area(DrawingArea area, Cairo.Context cr, int width, int height) {
        // Disable antialiasing for pixel-perfect rendering
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Theme Manager stuff
        Gdk.RGBA fg_color = theme.get_color("theme_fg");
        Gdk.RGBA bg_color = theme.get_color("theme_bg");
        Gdk.RGBA sel_color = theme.get_color("theme_selection");
        
        // IMPORTANT: Calculate cell size for pixel-perfect squares
        // Using exact dimensions to ensure consistent sizing
        double cell_size = 8.0; // For fixed 512x128 size, 16x16 grid, with 8px per cell
        
        // Get the per-character right spacing
        int right_spacing = app.character_right_spacing[app.current_char];
        
        // Calculate position of the vertical spacing line
        double spacing_x = right_spacing * (cell_size + 1);
        
        // Draw background: light green for edit area, white for preview
        // Green edit area background
        cr.set_source_rgb(sel_color.red, sel_color.green, sel_color.blue);
        cr.rectangle(0, 0, spacing_x, height);
        cr.fill();
        
        // White preview area background
        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
        cr.rectangle(spacing_x, 0, width - spacing_x, height);
        cr.fill();
        
        // Get the per-character baseline
        int baseline = app.character_baseline[app.current_char];
        double baseline_y = baseline * (cell_size + 1);
        
        // Draw dashed line at the baseline (blue)
        cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, 1); 
        cr.set_line_width(1);
        
        // Set up dashed line pattern
        double[] dashes = { 3.0, 3.0 };
        cr.set_dash(dashes, 0);
        
        // Draw the horizontal dashed line spanning the entire width
        cr.move_to(0, baseline_y);
        cr.line_to(width, baseline_y);
        cr.stroke();
        
        // Reset dash pattern
        cr.set_dash(null, 0);
        
        // == DRAW THE CURRENT CHARACTER (EDIT AREA) ==
        cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
        
        // Draw the character bitmap in the edit area
        for (int row = 0; row < 16; row++) {
            uint16 row_data = app.character_data[app.current_char, row];
            
            for (int col = 0; col < right_spacing; col++) {
                // Check if this pixel is set
                if ((row_data & (1 << (15 - col))) > 0) {
                    // Calculate position - exact integer pixel coordinates for sharpness
                    double x1 = col * (cell_size + 1) + 1;
                    double y1 = row * (cell_size + 1) + 1;
                    
                    // Draw the pixel
                    cr.rectangle(x1, y1, cell_size, cell_size);
                    cr.fill();
                }
            }
        }
        
        // == DRAW THE SPACING LINE (RED VERTICAL LINE) ==
        cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, 1);
        cr.set_line_width(1);
        
        // Draw the vertical solid spacing line
        cr.move_to(spacing_x, 0);
        cr.line_to(spacing_x, height);
        cr.stroke();
        
        // Draw control dots for dragging
        // Spacing control dot (red dot at top of red line)
        cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, 1);
        cr.arc(spacing_x, 4, 4, 0, 2 * Math.PI);
        cr.fill();
        
        // == DRAW THE NEXT CHARACTERS (PREVIEW AREA) ==
        // Starting position for the next character is immediately after the spacing line
        double x_pos = spacing_x;
        
        // Draw the next characters
        cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
        int chars_drawn = 0;
        int next_char = (app.current_char + 1) % 256; // Start with the next character
        
        while (chars_drawn < 64 && x_pos < width - cell_size) {
            // Check if this character has any pixels drawn
            bool has_pixels = false;
            for (int y = 0; y < 16 && !has_pixels; y++) {
                if (app.character_data[next_char, y] > 0) {
                    has_pixels = true;
                }
            }
            
            // Draw the character
            if (has_pixels) {
                // Get the baseline for this character
                int char_baseline = app.character_baseline[next_char];
                
                // Draw the character
                for (int row = 0; row < 16; row++) {
                    uint16 row_data = app.character_data[next_char, row];
                    
                    for (int col = 0; col < 16; col++) {
                        // Check if this pixel is set
                        if ((row_data & (1 << (15 - col))) > 0) {
                            // Calculate position with identical cell size as edit area
                            double pixel_x = x_pos + col * (cell_size + 1) + 1;
                            // Adjust for the character's own baseline
                            double pixel_y = (row - char_baseline + baseline) * (cell_size + 1) + 1;
                            
                            // Draw the pixel using identical size as edit area
                            cr.rectangle(pixel_x, pixel_y, cell_size, cell_size);
                            cr.fill();
                        }
                    }
                }
                
                // Get the spacing for this character
                int char_width = app.character_right_spacing[next_char];
                
                // Move position for next character using the scaled spacing
                x_pos += char_width * (cell_size + 1);
            } else {
                // Skip characters with no pixels, but still count them
                x_pos += app.character_right_spacing[next_char] * (cell_size + 1);
            }
            
            // Move to next character
            next_char = (next_char + 1) % 256;
            chars_drawn++;
        }
    }
    
    private void draw_pangram_preview(DrawingArea area, Cairo.Context cr, int width, int height) {
        // Disable antialiasing
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Theme Manager stuff
        Gdk.RGBA fg_color = theme.get_color("theme_fg");
        Gdk.RGBA bg_color = theme.get_color("theme_bg");
        
        // Background
        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
        cr.paint();
        
        // Calculate text dimensions first to center properly
        double text_width = 0;
        double text_height = 0;
        double scale = 1;
        
        // First pass - calculate total width
        foreach (string text in preview_texts) {
            double line_width = 0;
            
            for (int i = 0; i < text.length; i++) {
                int char_code = text[i];
                
                // Only consider valid characters
                if (char_code >= 0 && char_code < 256) {
                    // Get the spacing for this character
                    int char_width = app.character_right_spacing[char_code];
                    line_width += char_width * scale;
                }
            }
            
            // Keep track of the longest line
            if (line_width > text_width) {
                text_width = line_width;
            }
            
            // Add line height to total height
            text_height += 16 * scale;
        }
        
        // Calculate starting position to center text
        double start_x = (width - text_width) / 2;
        double start_y = (height - text_height) / 2 + 12; // Add baseline offset for proper vertical centering
        
        // Ensure we don't start too far left
        if (start_x < 5) start_x = 5;
        
        // Second pass - actual drawing with centered position
        cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
        double y_pos = start_y;
        
        foreach (string text in preview_texts) {
            double x_pos = start_x;
            
            // Iterate through the text character by character
            for (int i = 0; i < text.length; i++) {
                int char_code = text[i];
                
                // Skip characters outside the range we can display
                if (char_code < 0 || char_code >= 256) {
                    continue;
                }
                
                // Only attempt to display if the character has a glyph
                if ((char_code >= 32 && char_code < 128) || (char_code >= 160 && char_code <= 255)) {
                    // Check if this character has any pixels drawn
                    bool has_pixels = false;
                    for (int y = 0; y < 16 && !has_pixels; y++) {
                        if (app.character_data[char_code, y] > 0) {
                            has_pixels = true;
                        }
                    }
                    
                    // Only draw if the character has pixels
                    if (has_pixels) {
                        // Draw the character
                        draw_character(cr, char_code, x_pos, y_pos, scale);
                    }
                }
                
                // Move to next character position using character-specific width
                int char_width = app.character_right_spacing[char_code];
                x_pos += char_width * scale;
            }
            
            // Move to next line
            y_pos += 12 * scale;
        }
    }

    private void draw_character(Cairo.Context cr, int char_code, double x, double y, double scale) {
        // Ensure antialiasing is disabled
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Get the baseline for this character (for vertical positioning)
        int baseline = app.character_baseline[char_code];
        
        // Draw a character bitmap at the specified position and scale
        for (int row = 0; row < 16; row++) {
            uint16 row_data = app.character_data[char_code, row];

            for (int col = 0; col < 16; col++) {
                // Check if the pixel is set
                if ((row_data & (1 << (15 - col))) > 0) {
                    // Draw the pixel as a solid rectangle
                    // For y-position, adjust based on character-specific baseline
                    double y_offset = (row - baseline) * scale;
                    
                    cr.rectangle(
                        x + col * scale,
                        y + y_offset, // Use baseline for vertical positioning
                        scale,
                        scale
                    );
                    cr.fill();
                }
            }
        }
    }
    
    // Starting position for drag
    private double drag_start_x = 0;
    private double drag_start_y = 0;
    
    private void on_drag_begin(double start_x, double start_y) {
        // Save the starting position
        drag_start_x = start_x;
        drag_start_y = start_y;
        
        // Check if we're starting to drag a control dot
        if (is_clicking_spacing_control(start_x, start_y)) {
            is_dragging_spacing = true;
        }
        // Otherwise, the click handler will handle toggling pixels
    }
    
    private void on_drag_update(double offset_x, double offset_y) {
        // Get the cursor position
        double x = offset_x + drag_start_x;
        double y = offset_y + drag_start_y;
        
        // Use fixed cell size of 8px for 512x128 area with 16x16 grid
        double cell_size = 8.0;
        
        // Handle dragging control dots
        if (is_dragging_spacing) {
            // Calculate the column index based on x position
            int spacing_column = (int)Math.round((x - 1) / (cell_size + 1));
            
            // Ensure it's within valid range (columns 1-15)
            if (spacing_column >= 1 && spacing_column <= 15) {
                int old_spacing = app.character_right_spacing[app.current_char];
                app.character_right_spacing[app.current_char] = spacing_column;
                
                // If spacing was reduced, we need to clear any pixels beyond the new spacing
                if (spacing_column < old_spacing) {
                    for (int col = spacing_column; col < old_spacing; col++) {
                        for (int row = 0; row < 16; row++) {
                            // Clear pixel data that's now beyond the spacing
                            if (app.get_pixel_value(app.current_char, col, row) > 0) {
                                app.toggle_pixel(app.current_char, col, row);
                                unified_edit_area.queue_draw();
                                pangram_area.queue_draw();
                                refresh_character_preview(app.current_char);
                            }
                        }
                    }
                }
                
                unified_edit_area.queue_draw();
                pangram_area.queue_draw();
                refresh_character_preview(app.current_char);
            }
            return;
        }
        
        // If not dragging controls, handle normal pixel drawing
        // Get the right spacing (width of edit area)
        int right_spacing = app.character_right_spacing[app.current_char];
        double spacing_x = right_spacing * (cell_size + 1);
        
        // Only allow drawing in the edit area (left of spacing line)
        if (x >= 0 && x < spacing_x && y >= 0 && y < unified_edit_area.get_height()) {
            // Update pixels under the drag
            process_drawing_at(x, y);
        }
    }
    
    private void on_drag_end(double offset_x, double offset_y) {
        // Reset dragging flags
        is_dragging_spacing = false;
    }
    
    private void on_motion(double x, double y) {
        // Only process motion if button is pressed (handled by drag controller)
        // This just tracks the position for highlighting in the future
    }
    
    // Check if we're clicking on control dots
    private bool is_clicking_spacing_control(double x, double y) {
        // Use fixed cell size of 8px
        double cell_size = 8.0;
        int right_spacing = app.character_right_spacing[app.current_char];
        double line_x = right_spacing * (cell_size + 1);
        
        // Check if we're clicking within the control dot area at top of red line
        return Math.sqrt(Math.pow(x - line_x, 2) + Math.pow(y - 5, 2)) <= 5;
    }

    private void on_unified_area_clicked(int n_press, double x, double y) {
        // First check if we're clicking on control dots
        if (is_clicking_spacing_control(x, y)) {
            is_dragging_spacing = true;
            return;
        }
        
        // Use fixed cell size of 8px
        double cell_size = 8.0;
        
        // Get the right spacing of the current character
        int right_spacing = app.character_right_spacing[app.current_char];
        double spacing_x = right_spacing * (cell_size + 1);
        
        // Only handle clicks in the edit area (left of spacing line)
        if (x >= 0 && x < spacing_x) {
            // Calculate which cell was clicked
            int grid_x = (int)Math.floor((x - 1) / (cell_size + 1));
            int grid_y = (int)Math.floor((y - 1) / (cell_size + 1));
            
            // Only update pixels within valid boundaries
            if (grid_x >= 0 && grid_x < right_spacing && grid_y >= 0 && grid_y < 16) {
                // Remember the starting state for drag operations
                uint current_value = app.get_pixel_value(app.current_char, grid_x, grid_y);
                is_drawing = current_value == 0; // We're drawing if the pixel was off
                is_erasing = !is_drawing;        // We're erasing if the pixel was on
                
                // Set the pixel to the new state (toggle)
                app.toggle_pixel(app.current_char, grid_x, grid_y);
                unified_edit_area.queue_draw();
                pangram_area.queue_draw();
                refresh_character_preview(app.current_char);
                
                // Remember last position for drag operations
                last_grid_x = grid_x;
                last_grid_y = grid_y;
                
                unified_edit_area.queue_draw();
                pangram_area.queue_draw();
                refresh_character_preview(app.current_char);
            }
        }
    }
    
    private void process_drawing_at(double x, double y) {
        // Use fixed cell size of 8px
        double cell_size = 8.0;
        
        // Calculate cell coordinates with Math.floor to ensure discrete cells
        int grid_x = (int)Math.floor((x - 1) / (cell_size + 1));
        int grid_y = (int)Math.floor((y - 1) / (cell_size + 1));
        
        // Get the right spacing of the current character
        int right_spacing = app.character_right_spacing[app.current_char];
        
        // Only process if we're on a valid cell within the right spacing boundary
        // and it's different from the last processed cell
        if (grid_x >= 0 && grid_x < right_spacing && grid_y >= 0 && grid_y < 16 &&
            (grid_x != last_grid_x || grid_y != last_grid_y)) {
            
            // Get current cell value
            uint current_value = app.get_pixel_value(app.current_char, grid_x, grid_y);
            
            // Apply the drawing or erasing operation based on the initial action
            if (is_drawing && current_value == 0) {
                // Turn pixel ON if we're drawing and it's currently off
                app.toggle_pixel(app.current_char, grid_x, grid_y);
                unified_edit_area.queue_draw();
                pangram_area.queue_draw();
                refresh_character_preview(app.current_char);
            } else if (is_erasing && current_value > 0) {
                // Turn pixel OFF if we're erasing and it's currently on
                app.toggle_pixel(app.current_char, grid_x, grid_y);
                unified_edit_area.queue_draw();
                pangram_area.queue_draw();
                refresh_character_preview(app.current_char);
            }
            
            // Remember this cell
            last_grid_x = grid_x;
            last_grid_y = grid_y;

            unified_edit_area.queue_draw();
            pangram_area.queue_draw();
            refresh_character_preview(app.current_char);
        }
    }
    
    private void select_character(int code) {
        app.current_char = code;
        
        // Update the editing label
        string char_display = "";
        
        // Show character representation for printable characters
        if ((code >= 32 && code < 127) || (code >= 160 && code <= 255)) {
            // For Latin-1 supplement, convert properly to UTF-8
            if (code >= 160) {
                unichar uc = (unichar)code;
                char_display = " '" + uc.to_string() + "'";
            } else {
                char_display = " '%c'".printf(code);
            }
        }
        
        editing_label.set_text("Code: %d (0x%02X)%s".printf(code, code, char_display));

        // Update the highlight in the character grid
        for (int row = 0; row < 16; row++) {
            for (int col = 0; col < 16; col++) {
                int i = row * 16 + col;
                var child = char_selection_grid.get_child_at(col, row);
                if (child != null) {
                    if (i == code) {
                        child.add_css_class("current-char");
                    } else {
                        child.remove_css_class("current-char");
                    }
                }
            }
        }

        // Redraw everything
        unified_edit_area.queue_draw();
        pangram_area.queue_draw();
        refresh_character_preview(app.current_char);
    }
    
    private void setup_keyboard_shortcuts() {
        // Add keyboard event controller to the window
        var key_controller = new EventControllerKey();
        key_controller.key_pressed.connect(on_key_pressed);
        main_box.add_controller(key_controller);
        
        // Set up keyboard actions
        var action_group = new SimpleActionGroup();
        
        // File operations
        var open_action = new SimpleAction("open", null);
        open_action.activate.connect(() => open_font_file());
        action_group.add_action(open_action);
        
        var save_action = new SimpleAction("save", null);
        save_action.activate.connect(() => save_font_file());
        action_group.add_action(save_action);
        
        // Edit operations
        var cut_action = new SimpleAction("cut", null);
        cut_action.activate.connect(() => cut_glyph());
        action_group.add_action(cut_action);
        
        var copy_action = new SimpleAction("copy", null);
        copy_action.activate.connect(() => copy_glyph());
        action_group.add_action(copy_action);
        
        var paste_action = new SimpleAction("paste", null);
        paste_action.activate.connect(() => paste_glyph());
        action_group.add_action(paste_action);
        
        // Erase operation
        var erase_action = new SimpleAction("erase", null);
        erase_action.activate.connect(() => erase_glyph());
        action_group.add_action(erase_action);
        
        this.insert_action_group("font", action_group);
        
        // Add keyboard shortcuts using the actions
        application.set_accels_for_action("font.open", {"<Control>o"});
        application.set_accels_for_action("font.save", {"<Control>s"});
        application.set_accels_for_action("font.cut", {"<Control>x"});
        application.set_accels_for_action("font.copy", {"<Control>c"});
        application.set_accels_for_action("font.paste", {"<Control>v"});
        application.set_accels_for_action("font.erase", {"BackSpace"});
    }
    
    private bool on_key_pressed(uint keyval, uint keycode, Gdk.ModifierType state) {
        // Handle arrow keys for navigation
        if (keyval == Gdk.Key.Left) {
            move_to_prev_character();
            return true;
        } else if (keyval == Gdk.Key.Right) {
            move_to_next_character();
            return true;
        } else if (keyval == Gdk.Key.Up) {
            move_to_character_above();
            return true;
        } else if (keyval == Gdk.Key.Down) {
            move_to_character_below();
            return true;
        }
        
        // Let other keys be processed normally
        return false;
    }
    
    private void move_to_prev_character() {
        int new_char = app.current_char - 1;
        if (new_char < 0) {
            new_char = 255;
        }
        select_character(new_char);
    }
    
    private void move_to_next_character() {
        int new_char = app.current_char + 1;
        if (new_char > 255) {
            new_char = 0;
        }
        select_character(new_char);
    }
    
    private void move_to_character_above() {
        // Move 16 characters up (one row in our 16x16 grid)
        int new_char = app.current_char - 16;
        if (new_char < 0) {
            // Wrap around to the bottom row at same column
            int column = app.current_char % 16;
            new_char = 240 + column; // Last row, same column
        }
        select_character(new_char);
    }
    
    private void move_to_character_below() {
        // Move 16 characters down (one row in our 16x16 grid)
        int new_char = app.current_char + 16;
        if (new_char > 255) {
            // Wrap around to the top row at same column
            int column = app.current_char % 16;
            new_char = column; // First row, same column
        }
        select_character(new_char);
    }
    
    private void copy_glyph() {
        // Create a copy of the current character's bitmap data
        clipboard_data = new uint16[16];
        for (int y = 0; y < 16; y++) {
            clipboard_data[y] = app.character_data[app.current_char, y];
        }
        
        // Copy spacing and baseline too
        clipboard_right_spacing = app.character_right_spacing[app.current_char];
        clipboard_baseline = app.character_baseline[app.current_char];
        
        // Show notification in the editing label
        string orig_label = editing_label.get_label();
        editing_label.set_label("Character copied to clipboard");
        
        // Restore original label after a delay
        Timeout.add(1500, () => {
            editing_label.set_label(orig_label);
            return false;
        });
    }
    
    private void cut_glyph() {
        // First copy the character
        copy_glyph();
        
        // Then clear it
        app.clear_character(app.current_char);
        
        // Update UI
        unified_edit_area.queue_draw();
        pangram_area.queue_draw();
        refresh_character_preview(app.current_char);
        
        // Show notification in the editing label
        string orig_label = editing_label.get_label();
        editing_label.set_label("Character cut to clipboard");
        
        // Restore original label after a delay
        Timeout.add(1500, () => {
            editing_label.set_label(orig_label);
            return false;
        });
    }
    
    private void paste_glyph() {
        // Check if we have data in the clipboard
        if (clipboard_data == null) {
            // Show notification in the editing label
            string orig_label = editing_label.get_label();
            editing_label.set_label("No character data in clipboard");
            
            // Restore original label after a delay
            Timeout.add(1500, () => {
                editing_label.set_label(orig_label);
                return false;
            });
            return;
        }
        
        // Paste bitmap data
        for (int y = 0; y < 16; y++) {
            app.character_data[app.current_char, y] = clipboard_data[y];
        }
        
        // Paste spacing and baseline
        app.character_right_spacing[app.current_char] = clipboard_right_spacing;
        app.character_baseline[app.current_char] = clipboard_baseline;
        
        // Update UI
        unified_edit_area.queue_draw();
        pangram_area.queue_draw();
        refresh_character_preview(app.current_char);
        
        // Show notification in the editing label
        string orig_label = editing_label.get_label();
        editing_label.set_label("Character pasted from clipboard");
        
        // Restore original label after a delay
        Timeout.add(1500, () => {
            editing_label.set_label(orig_label);
            return false;
        });
    }
    
    private void erase_glyph() {
        // Clear the current character
        app.clear_character(app.current_char);
        unified_edit_area.queue_draw();
        pangram_area.queue_draw();
        refresh_character_preview(app.current_char);
    }
    
    // Font file operations with fixed BDF loading
    private void open_font_file() {
        var file_dialog = new FileDialog();
        file_dialog.set_title("Open Font File");
        
        // Create filters for font files
        var filter_list = new GLib.ListStore(typeof(FileFilter));
        
        var bdf_filter = new FileFilter();
        bdf_filter.add_pattern("*.bdf");
        bdf_filter.set_filter_name("BDF Font Files");
        filter_list.append(bdf_filter);
        
        var all_filter = new FileFilter();
        all_filter.add_pattern("*");
        all_filter.set_filter_name("All Files");
        filter_list.append(all_filter);
        
        file_dialog.set_filters(filter_list);
        
        // Show open dialog
        file_dialog.open.begin(
            this,
            null,
            (obj, res) => {
                try {
                    var file = file_dialog.open.end(res);
                    if (file != null) {
                        load_font_file(file.get_path());
                    }
                } catch (Error e) {
                    var dialog = new AlertDialog("Error opening font file");
                    dialog.set_detail("Error: %s".printf(e.message));
                    dialog.show(this);
                }
            }
        );
    }
    
    private void load_font_file(string filepath) {
        try {
            if (filepath.has_suffix(".bdf")) {
                load_bdf_file(filepath);
            } else {
                var dialog = new AlertDialog("Unsupported File Format");
                dialog.set_detail("Currently only BDF files are supported for loading.");
                dialog.show(this);
            }
        } catch (Error e) {
            var dialog = new AlertDialog("Error Loading Font File");
            dialog.set_detail("Error: %s".printf(e.message));
            dialog.show(this);
        }
    }
    
    private void load_bdf_file(string filepath) throws Error {
        var file = File.new_for_path(filepath);
        var dis = new DataInputStream(file.read());
        
        // Temporary storage for loading
        uint16[,] new_char_data = new uint16[256, 16];
        int[] new_right_spacing = new int[256];
        int[] new_baseline = new int[256];
        
        // Initialize with defaults
        for (int i = 0; i < 256; i++) {
            new_right_spacing[i] = 9;  // Default spacing
            new_baseline[i] = 12;      // Default baseline
            
            for (int y = 0; y < 16; y++) {
                new_char_data[i, y] = 0;
            }
        }
        
        // Parse BDF file
        string? line = null;
        int current_char = -1;
        int row = 0;
        bool in_bitmap = false;
        
        while ((line = dis.read_line()) != null) {
            line = line.strip();
            
            if (line.has_prefix("ENCODING")) {
                // Parse character code
                current_char = int.parse(line.substring(9).strip());
                row = 0;
                in_bitmap = false;
                
                // Ensure the character is in valid range
                if (current_char < 0 || current_char > 255) {
                    current_char = -1; // Skip this character
                }
            } else if (line.has_prefix("DWIDTH")) {
                if (current_char >= 0 && current_char <= 255) {
                    // Parse spacing value
                    string[] parts = line.substring(7).strip().split(" ");
                    if (parts.length >= 1) {
                        int width = int.parse(parts[0]);
                        
                        // Store right spacing (subtracting any kerning value)
                        new_right_spacing[current_char] = width - app.kerning;
                    }
                }
            } else if (line.has_prefix("BBX")) {
                if (current_char >= 0 && current_char <= 255) {
                    // Parse bounding box to determine baseline
                    string[] parts = line.substring(4).strip().split(" ");
                    if (parts.length >= 4) {
                        int y_offset = int.parse(parts[3]);
                        
                        // Let's set fixed baseline
                        int baseline = app.ascender_height + app.x_height + y_offset;
                        if (baseline >= 0 && baseline <= 15) {
                            new_baseline[current_char] = baseline;
                        } else {
                            new_baseline[current_char] = 12;
                        }
                    }
                }
            } else if (line == "BITMAP") {
                in_bitmap = true;
                row = 0;
            } else if (line == "ENDCHAR") {
                in_bitmap = false;
                current_char = -1;
            } else if (in_bitmap && current_char >= 0 && current_char <= 255) {
                // Parse bitmap data
                if (row < 16) {
                    // Convert hex string to uint16
                    uint16 row_data = (uint16)uint64.parse("0x" + line);
                    new_char_data[current_char, row] = row_data;
                    row++;
                }
            }
        }
        
        // Apply the loaded data to our app
        for (int i = 0; i < 256; i++) {
            app.character_right_spacing[i] = new_right_spacing[i];
            app.character_baseline[i] = new_baseline[i];
            
            for (int y = 0; y < 16; y++) {
                app.character_data[i, y] = new_char_data[i, y];
            }
        }
        
        // Update UI
        unified_edit_area.queue_draw();
        pangram_area.queue_draw();
        
        // Display success message
        var dialog = new AlertDialog("Font Loaded Successfully");
        dialog.set_detail("Loaded font file: %s".printf(filepath));
        dialog.show(this);
    }
    
    private void save_font_file() {
        var file_dialog = new FileDialog();
        file_dialog.set_title("Save Font File");
        file_dialog.set_initial_name("myfont.bdf");

        // Create filters for font files
        var filter_list = new GLib.ListStore(typeof(FileFilter));
        
        var bdf_filter = new FileFilter();
        bdf_filter.add_pattern("*.bdf");
        bdf_filter.set_filter_name("BDF Font Files");
        filter_list.append(bdf_filter);
        
        file_dialog.set_filters(filter_list);
        
        // Show save dialog
        file_dialog.save.begin(
            this,
            null,
            (obj, res) => {
                try {
                    var file = file_dialog.save.end(res);
                    if (file != null) {
                        FontMakerUtils.generate_bdf_file(file.get_path(), app);
                    }
                } catch (Error e) {
                    var dialog = new AlertDialog("Error saving font file");
                    dialog.set_detail("Error: %s".printf(e.message));
                    dialog.show(this);
                }
            }
        );
    }
}