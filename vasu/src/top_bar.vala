// TopBarComponent - manages the top bar UI with sprite size, color picker, pattern viewer
public class TopBarComponent : Gtk.Box {
    private VasuData chr_data;
    private VasuEditorView editor_view;
    private VasuPreviewView preview_view;
    
    public signal void selected_color_changed();
    
    // Public widgets that might need to be accessed by the MainWindow
    public Gtk.DrawingArea sprite_area { get; private set; }
    public Gtk.DrawingArea sprite_view_area { get; private set; }
    public Gtk.DrawingArea pattern_area { get; private set; }
    public Gtk.Label sprite_label { get; private set; }
    public Gtk.Label sprite_view_label { get; private set; }
    public Gtk.Label mirror_status { get; private set; }
    public Gtk.Label data_label { get; private set; }
    public Gtk.Grid hex_data { get; private set; }
    public ColorPickerWidget color_picker { get; private set; }
    
    public int shift_x = 0;
    public int shift_y = 0;
    public int click_x = 0;
    public int click_y = 0;
    
    // Delegate for drawing functions
    private delegate void DrawFunc(Cairo.Context cr, int width, int height);
    
    public TopBarComponent(VasuData data, VasuEditorView editor, VasuPreviewView preview) {
        Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 16);
    
        chr_data = data;
        editor_view = editor;
        preview_view = preview;
        
        // Set styling and margins
        margin_start = 16;
        margin_end = 16;
        margin_top = 13;
        margin_bottom = 8;
        add_css_class("tool-bar");
        
        // Create and arrange UI components
        setup_ui();
        
        // Connect signals
        // Update when specific data properties change
        chr_data.tile_changed.connect(() => {
            update_hex_data();
            pattern_area.queue_draw();
            sprite_area.queue_draw();
            sprite_view_area.queue_draw();
        });

        preview_view.preview_updated.connect(() => {
            update_hex_data();
            pattern_area.queue_draw();
            sprite_area.queue_draw();
            sprite_view_area.queue_draw();
        });

        // Connect color picker changes
        color_picker.color_set.connect(() => {
            // Update the current selected color in chr_data
            var rgba = color_picker.get_rgba();
            chr_data.set_color(chr_data.selected_color, rgba);
            selected_color_changed();
            
            // Update the display
            queue_draw();
            pattern_area.queue_draw();
            sprite_area.queue_draw();
            sprite_view_area.queue_draw();
        });
        
        // Connect tile selection to update the sprite view areas
        editor_view.tile_selected.connect((x, y) => {
            sprite_area.queue_draw();
            sprite_view_area.queue_draw();
        });

        // Connect mirror status changes
        chr_data.notify["mirror_horizontal"].connect(() => {
            update_mirror_status();
            pattern_area.queue_draw();
        });

        chr_data.notify["mirror_vertical"].connect(() => {
            update_mirror_status();
            pattern_area.queue_draw();
        });

        chr_data.notify["selected_pattern_tile"].connect(() => {
            update_mirror_status();
            update_pattern_tile(mirror_status);
            pattern_area.queue_draw();
        });
        
        chr_data.notify["selected_color"].connect(() => {
            update_color_picker();
        });
    }

    private void setup_ui() {
        // Create UI components
        var sprite_view_component = create_sprite_view_component();
        var sprite_size_component = create_sprite_size_component();
        color_picker = new ColorPickerWidget();
        var pattern_preview_component = create_pattern_preview_component();
        hex_data = create_hex_data_display("0000");
        
        // Initial setup
        update_color_picker();
        update_hex_data();
        
        // Add all elements to the bar
        append(sprite_view_component);
        append(sprite_size_component);
        append(color_picker);
        append(pattern_preview_component);
        append(hex_data);
    }
    
    // Create the sprite view indicator component
    private Gtk.Box create_sprite_view_component() {
        var sprite_size = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        
        var sprite_view_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        sprite_view_box.add_css_class("mini-panel-frame");
        
        sprite_view_area = new Gtk.DrawingArea();
        sprite_view_area.set_size_request(32, 32);
        sprite_view_area.set_draw_func(draw_sprite_view_area);
        
        sprite_view_box.append(sprite_view_area);
        
        var shift_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        shift_box.halign = Gtk.Align.START;
        
        // Horizontal shift toggle button
        var h_shift_button = create_toolbar_item(7, 7, (cr, width, height) => {
            draw_horizontal_shift_button(cr, width, height);
        });
        h_shift_button.margin_top = 5;
        h_shift_button.margin_start = 1;
        
        h_shift_button.clicked.connect(() => {
            // Shift the tile pixels in chr_data
            chr_data.shift_horizontal();
            
            // Update the editor pixels
            editor_view.update_from_current_tile();
            
            // Redraw
            sprite_view_area.queue_draw();
        });
        
        // Vertical shift toggle button
        var v_shift_button = create_toolbar_item(7, 7, (cr, width, height) => {
            draw_vertical_shift_button(cr, width, height);
        });
        v_shift_button.margin_top = 5;
        v_shift_button.margin_start = 1;

        v_shift_button.clicked.connect(() => {
            // Shift the tile pixels in chr_data
            chr_data.shift_vertical();
            
            // Update the editor pixels
            editor_view.update_from_current_tile();
            
            // Redraw
            sprite_view_area.queue_draw();
        });

        shift_box.append(v_shift_button);
        shift_box.append(h_shift_button);

        sprite_size.append(sprite_view_box);
        sprite_size.append(shift_box);
        
        return sprite_size;
    }
    
    // Draw the horizontal shift button
    private void draw_horizontal_shift_button(Cairo.Context cr, int width, int height) {
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Draw horizontal shift arrow icon
        Gdk.RGBA color = chr_data.get_color(3);
        cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
        
        // Arrow body
        // Row 0
        cr.rectangle(0, 3, 1, 1);
        
        // Row 1
        cr.rectangle(1, 3, 1, 1);
        
        // Row 2
        cr.rectangle(2, 3, 1, 1);
        
        // Row 3
        cr.rectangle(3, 0, 1, 1);
        cr.rectangle(3, 1, 1, 1);
        cr.rectangle(3, 2, 1, 1);
        cr.rectangle(3, 3, 1, 1);
        cr.rectangle(3, 4, 1, 1);
        cr.rectangle(3, 5, 1, 1);
        cr.rectangle(3, 6, 1, 1);
        
        // Row 4
        cr.rectangle(4, 1, 1, 1);
        cr.rectangle(4, 2, 1, 1);
        cr.rectangle(4, 3, 1, 1);
        cr.rectangle(4, 4, 1, 1);
        cr.rectangle(4, 5, 1, 1);
        
        // Row 5
        cr.rectangle(5, 2, 1, 1);
        cr.rectangle(5, 3, 1, 1);
        cr.rectangle(5, 4, 1, 1);
        
        // Row 6
        cr.rectangle(6, 3, 1, 1);
        cr.fill();
    }
    
    // Draw the vertical shift button
    private void draw_vertical_shift_button(Cairo.Context cr, int width, int height) {
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Draw vertical shift arrow icon
        Gdk.RGBA color = chr_data.get_color(3);
        cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
        
        // Arrow body
        // Row 0
        cr.rectangle(3, 0, 1, 1);
        
        // Row 1
        cr.rectangle(2, 1, 1, 1);
        cr.rectangle(3, 1, 1, 1);
        cr.rectangle(4, 1, 1, 1);
        
        // Row 2
        cr.rectangle(1, 2, 1, 1);
        cr.rectangle(2, 2, 1, 1);
        cr.rectangle(3, 2, 1, 1);
        cr.rectangle(4, 2, 1, 1);
        cr.rectangle(5, 2, 1, 1);
        
        // Row 3
        cr.rectangle(0, 3, 1, 1);
        cr.rectangle(1, 3, 1, 1);
        cr.rectangle(2, 3, 1, 1);
        cr.rectangle(3, 3, 1, 1);
        cr.rectangle(4, 3, 1, 1);
        cr.rectangle(5, 3, 1, 1);
        cr.rectangle(6, 3, 1, 1);
        
        // Row 4
        cr.rectangle(3, 4, 1, 1);
        
        // Row 5
        cr.rectangle(3, 5, 1, 1);
        
        // Row 6
        cr.rectangle(3, 6, 1, 1);
        cr.fill();
    }
    
    // Draw function for the sprite view area
    private void draw_sprite_view_area(Gtk.DrawingArea da, Cairo.Context cr, int width, int height) {
        cr.set_antialias(Cairo.Antialias.NONE);
        int scale_factor = 4; // 8x4 = 32, but accounting for half pixels
        
        // Get the selected tile coordinates
        int selected_tile_x = editor_view.selected_tile_x;
        int selected_tile_y = editor_view.selected_tile_y;
        
        // Draw the selected tile pixels scaled up
        for (int y = 0; y < VasuData.TILE_HEIGHT; y++) {
            for (int x = 0; x < VasuData.TILE_WIDTH; x++) {
                // Calculate the source pixel position in the editor
                int source_x = selected_tile_x * VasuData.TILE_WIDTH + x;
                int source_y = selected_tile_y * VasuData.TILE_HEIGHT + y;
                
                // Get color value from the editor
                int color = editor_view.get_pixel(source_x, source_y);
                
                // Draw the pixel with the appropriate color, scaled to fill the area
                Gdk.RGBA pixel_color = chr_data.get_color(color);
                cr.set_source_rgb(pixel_color.red, pixel_color.green, pixel_color.blue);
                
                // Draw a scaled rectangle for each pixel
                cr.rectangle((x + shift_x) * scale_factor, (y + shift_y) * scale_factor, scale_factor, scale_factor);
                cr.fill();
            }
        }
    }
    
    // Create the sprite size indicator component
    private Gtk.Box create_sprite_size_component() {
        var sprite_size = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        
        sprite_area = new Gtk.DrawingArea();
        sprite_area.set_size_request(32, 32);
        sprite_area.set_draw_func(draw_sprite_area);

        sprite_label = new Gtk.Label("%d%d".printf(chr_data.sprite_width, chr_data.sprite_height));
        sprite_label.add_css_class("data-label");
        sprite_label.valign = Gtk.Align.END;
        sprite_label.halign = Gtk.Align.START;

        // Add click & drag functionality for sprite size adjustment
        var click_gesture = new Gtk.GestureClick();
        click_gesture.pressed.connect((n_press, x, y) => {
            update_size_from_coordinates(x, y);
        });
        sprite_area.add_controller(click_gesture);

        var drag_gesture = new Gtk.GestureDrag();
        drag_gesture.drag_update.connect((offset_x, offset_y) => {
            update_size_from_coordinates(offset_x, offset_y);
        });
        sprite_area.add_controller(drag_gesture);

        sprite_size.append(sprite_area);
        sprite_size.append(sprite_label);
        
        return sprite_size;
    }
    
    // Draw function for the sprite area
    private void draw_sprite_area(Gtk.DrawingArea da, Cairo.Context cr, int width, int height) {
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Constants for checkerboard
        const int CHECKERBOARD_SIZE = 2;
        
        // First draw the checkerboard background
        for (int y = 0; y < height; y += CHECKERBOARD_SIZE) {
            for (int x = 0; x < width; x += CHECKERBOARD_SIZE) {
                bool is_light = ((x / CHECKERBOARD_SIZE) + (y / CHECKERBOARD_SIZE)) % 2 == 0;
                
                if (is_light) {
                    Gdk.RGBA bg_color = chr_data.get_color(3);
                    cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
                } else {
                    Gdk.RGBA bg_color = chr_data.get_color(0);
                    cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
                }
                
                double cell_width = Math.fmin(CHECKERBOARD_SIZE, width - x);
                double cell_height = Math.fmin(CHECKERBOARD_SIZE, height - y);
                
                cr.rectangle(x, y, cell_width, cell_height);
                cr.fill();
            }
        }
        
        // Calculate block dimensions based on the sprite size
        int block_width = width / 4;
        int block_height = height / 4;
        
        // Fill the active area (the current sprite size)
        Gdk.RGBA bg_color = chr_data.get_color(0);
        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
        cr.rectangle(0, 0, 
            chr_data.sprite_width * block_width,
            chr_data.sprite_height * block_height);
        cr.fill();
        
        // Draw the sprite pixels
        for (int y = 0; y < chr_data.sprite_height * block_height; y++) {
            for (int x = 0; x < chr_data.sprite_width * block_width; x++) {
                // Get original color value from the pattern
                int color = editor_view.get_pixel(x, y);
                
                // Draw the pixel with the appropriate color
                Gdk.RGBA pixel_color = chr_data.get_color(color);
                cr.set_source_rgb(pixel_color.red, pixel_color.green, pixel_color.blue);
                
                cr.rectangle(x, y, 1, 1);
                cr.fill();
            }
        }
    }
    
    // Create the pattern preview component with mirroring controls
    private Gtk.Box create_pattern_preview_component() {
        var pattern_preview = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        
        // Create mirror controls
        var mirror_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        mirror_box.halign = Gtk.Align.CENTER;
        
        // Mirror status label (2-hexdigit)
        mirror_status = new Gtk.Label("80");
        mirror_status.add_css_class("data-label");
        
        // Horizontal mirror toggle button
        var h_mirror_button = create_toolbar_item(7, 7, (cr, width, height) => {
            draw_horizontal_mirror_button(cr, width, height);
        });
        h_mirror_button.margin_top = 7;
        h_mirror_button.margin_start = 1;
        
        h_mirror_button.clicked.connect(() => {
            chr_data.mirror_horizontal = !chr_data.mirror_horizontal;
            update_mirror_status(mirror_status);
            pattern_area.queue_draw();
            editor_view.queue_draw();
            preview_view.queue_draw();
        });
        
        // Vertical mirror toggle button
        var v_mirror_button = create_toolbar_item(7, 7, (cr, width, height) => {
            draw_vertical_mirror_button(cr, width, height);
        });
        v_mirror_button.margin_top = 7;
        v_mirror_button.margin_start = 1;
        
        v_mirror_button.clicked.connect(() => {
            chr_data.mirror_vertical = !chr_data.mirror_vertical;
            update_mirror_status(mirror_status);
            pattern_area.queue_draw();
            editor_view.queue_draw();
            preview_view.queue_draw();
        });
        
        mirror_box.append(mirror_status);
        mirror_box.append(v_mirror_button);
        mirror_box.append(h_mirror_button);
        
        // Create the pattern area
        pattern_area = new Gtk.DrawingArea();
        pattern_area.set_size_request(32, 32);
        pattern_area.set_draw_func(draw_pattern_area);
        
        // Add click gesture to pattern_area for tile selection
        var pattern_click = new Gtk.GestureClick();
        pattern_click.pressed.connect((n_press, x, y) => {
            click_x = (int)x;
            click_y = (int)y;
            select_pattern_tile(x, y, mirror_status);
            update_mirror_status(mirror_status);
        });
        pattern_area.add_controller(pattern_click);
        
        // Build the component
        pattern_preview.append(pattern_area);
        pattern_preview.append(mirror_box);
        
        // Initialize mirror status
        update_mirror_status(mirror_status);
        
        return pattern_preview;
    }
    
    // Draw the horizontal mirror button
    private void draw_horizontal_mirror_button(Cairo.Context cr, int width, int height) {
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Draw horizontal mirror arrow icon
        Gdk.RGBA color = chr_data.get_color(chr_data.mirror_horizontal ? 1 : 3);
        cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
        
        // Arrow body
        if (!chr_data.mirror_horizontal) {
            // Row 0
            cr.rectangle(0, 3, 1, 1);
            
            // Row 1
            cr.rectangle(1, 3, 1, 1);
            
            // Row 2
            cr.rectangle(2, 3, 1, 1);
            
            // Row 3
            cr.rectangle(3, 0, 1, 1);
            cr.rectangle(3, 1, 1, 1);
            cr.rectangle(3, 2, 1, 1);
            cr.rectangle(3, 3, 1, 1);
            cr.rectangle(3, 4, 1, 1);
            cr.rectangle(3, 5, 1, 1);
            cr.rectangle(3, 6, 1, 1);
            
            // Row 4
            cr.rectangle(4, 1, 1, 1);
            cr.rectangle(4, 2, 1, 1);
            cr.rectangle(4, 3, 1, 1);
            cr.rectangle(4, 4, 1, 1);
            cr.rectangle(4, 5, 1, 1);
            
            // Row 5
            cr.rectangle(5, 2, 1, 1);
            cr.rectangle(5, 3, 1, 1);
            cr.rectangle(5, 4, 1, 1);
            
            // Row 6
            cr.rectangle(6, 3, 1, 1);
        } else { // invert columns!
            // Row 0
            cr.rectangle(6, 3, 1, 1);
            
            // Row 1
            cr.rectangle(5, 3, 1, 1);
            
            // Row 2
            cr.rectangle(4, 3, 1, 1);
            
            // Row 3
            cr.rectangle(3, 0, 1, 1);
            cr.rectangle(3, 1, 1, 1);
            cr.rectangle(3, 2, 1, 1);
            cr.rectangle(3, 3, 1, 1);
            cr.rectangle(3, 4, 1, 1);
            cr.rectangle(3, 5, 1, 1);
            cr.rectangle(3, 6, 1, 1);
            
            // Row 4
            cr.rectangle(2, 1, 1, 1);
            cr.rectangle(2, 2, 1, 1);
            cr.rectangle(2, 3, 1, 1);
            cr.rectangle(2, 4, 1, 1);
            cr.rectangle(2, 5, 1, 1);
            
            // Row 5
            cr.rectangle(1, 2, 1, 1);
            cr.rectangle(1, 3, 1, 1);
            cr.rectangle(1, 4, 1, 1);
            
            // Row 6
            cr.rectangle(0, 3, 1, 1);
        }
        
        cr.fill();
    }
    
    // Draw the vertical mirror button
    private void draw_vertical_mirror_button(Cairo.Context cr, int width, int height) {
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Draw vertical mirror arrow icon
        Gdk.RGBA color = chr_data.get_color(chr_data.mirror_vertical ? 1 : 3);
        cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
        
        // Arrow body
        if (!chr_data.mirror_vertical) {
            // Row 0
            cr.rectangle(3, 0, 1, 1);
            
            // Row 1
            cr.rectangle(2, 1, 1, 1);
            cr.rectangle(3, 1, 1, 1);
            cr.rectangle(4, 1, 1, 1);
            
            // Row 2
            cr.rectangle(1, 2, 1, 1);
            cr.rectangle(2, 2, 1, 1);
            cr.rectangle(3, 2, 1, 1);
            cr.rectangle(4, 2, 1, 1);
            cr.rectangle(5, 2, 1, 1);
            
            // Row 3
            cr.rectangle(0, 3, 1, 1);
            cr.rectangle(1, 3, 1, 1);
            cr.rectangle(2, 3, 1, 1);
            cr.rectangle(3, 3, 1, 1);
            cr.rectangle(4, 3, 1, 1);
            cr.rectangle(5, 3, 1, 1);
            cr.rectangle(6, 3, 1, 1);
            
            // Row 4
            cr.rectangle(3, 4, 1, 1);
            
            // Row 5
            cr.rectangle(3, 5, 1, 1);
            
            // Row 6
            cr.rectangle(3, 6, 1, 1);
        } else { // Invert rows!
            // Row 0
            cr.rectangle(3, 6, 1, 1);
            
            // Row 1
            cr.rectangle(2, 5, 1, 1);
            cr.rectangle(3, 5, 1, 1);
            cr.rectangle(4, 5, 1, 1);
            
            // Row 2
            cr.rectangle(1, 4, 1, 1);
            cr.rectangle(2, 4, 1, 1);
            cr.rectangle(3, 4, 1, 1);
            cr.rectangle(4, 4, 1, 1);
            cr.rectangle(5, 4, 1, 1);
            
            // Row 3
            cr.rectangle(0, 3, 1, 1);
            cr.rectangle(1, 3, 1, 1);
            cr.rectangle(2, 3, 1, 1);
            cr.rectangle(3, 3, 1, 1);
            cr.rectangle(4, 3, 1, 1);
            cr.rectangle(5, 3, 1, 1);
            cr.rectangle(6, 3, 1, 1);
            
            // Row 4
            cr.rectangle(3, 2, 1, 1);
            
            // Row 5
            cr.rectangle(3, 1, 1, 1);
            
            // Row 6
            cr.rectangle(3, 0, 1, 1);
        }
        
        cr.fill();
    }
    
    // Draw the pattern area with color transformations
    private void draw_pattern_area(Gtk.DrawingArea da, Cairo.Context cr, int width, int height) {
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Draw 4x4 grid showing all possible palette configurations
        int cell_width = width / 4;
        int cell_height = height / 4;
        
        // Define color mappings for each cell in the 4x4 grid
        // [row, col][original_color] = mapped_color
        int[,] color_mappings = {
            // Row 1 (ch=0)
            {0, 0, 1, 2}, // Col 1 (col=0): 0->0, 1->0, 2->1, 3->2
            {0, 1, 2, 3}, // Col 2 (col=1): 0->0, 1->1, 2->2, 3->3
            {0, 2, 3, 1}, // Col 3 (col=2): 0->0, 1->2, 2->3, 3->1
            {0, 3, 1, 2}, // Col 4 (col=3): 0->0, 1->3, 2->1, 3->2
            
            // Row 2 (ch=1)
            {1, 0, 1, 2}, // Col 1 (col=0): 0->1, 1->0, 2->1, 3->2
            {0, 1, 2, 3}, // Col 2 (col=1): 0->0, 1->1, 2->2, 3->3
            {1, 2, 3, 1}, // Col 3 (col=2): 0->1, 1->2, 2->3, 3->1
            {1, 3, 1, 2}, // Col 4 (col=3): 0->1, 1->3, 2->1, 3->2
            
            // Row 3 (ch=2)
            {2, 0, 1, 2}, // Col 1 (col=0): 0->2, 1->0, 2->1, 3->2
            {2, 1, 2, 3}, // Col 2 (col=1): 0->2, 1->1, 2->2, 3->3
            {0, 2, 3, 1}, // Col 3 (col=2): 0->0, 1->2, 2->3, 3->1
            {2, 3, 1, 2}, // Col 4 (col=3): 0->2, 1->3, 2->1, 3->2
            
            // Row 4 (ch=3)
            {3, 0, 1, 2}, // Col 1 (col=0): 0->3, 1->0, 2->1, 3->2
            {3, 1, 2, 3}, // Col 2 (col=1): 0->3, 1->1, 2->2, 3->3
            {3, 2, 3, 1}, // Col 3 (col=2): 0->3, 1->2, 2->3, 3->1
            {0, 3, 1, 2}  // Col 4 (col=3): 0->0, 1->3, 2->1, 3->2
        };
        
        // Tile dimensions in pixels
        const int TILE_WIDTH = 8;
        const int TILE_HEIGHT = 8;
        
        // For each of the 4x4 grid cells
        for (int ch = 0; ch < 4; ch++) {
            for (int col = 0; col < 4; col++) {
                // Calculate cell position
                double cell_x = col * cell_width;
                double cell_y = ch * cell_height;
                
                // Calculate the mapping index
                int mapping_index = ch * 4 + col;
                
                // Draw the tile with the correct color mapping and mirroring
                for (int y = 0; y < TILE_HEIGHT; y++) {
                    for (int x = 0; x < TILE_WIDTH; x++) {
                        // Apply mirroring to get source coordinates
                        int source_x = x;
                        int source_y = y;
                        
                        if (chr_data.mirror_horizontal) {
                            // Horizontally mirrored: flip x within tile bounds
                            source_x = TILE_WIDTH - 1 - x;
                        }
                        
                        if (chr_data.mirror_vertical) {
                            // Vertically mirrored: flip y within tile bounds
                            source_y = TILE_HEIGHT - 1 - y;
                        }
                        
                        // Get original color value from the pattern with mirrored coordinates
                        int color = chr_data.get_pixel(source_x, source_y);
                        
                        // Map the color using our defined mapping
                        int final_color = color_mappings[mapping_index, color];
                        
                        // Draw the pixel with the mapped color
                        Gdk.RGBA pixel_color = chr_data.get_color(final_color);
                        cr.set_source_rgba(pixel_color.red, pixel_color.green, pixel_color.blue, pixel_color.alpha);
                        
                        // Calculate pixel position within the cell
                        double pixel_x = cell_x + (x * cell_width / TILE_WIDTH);
                        double pixel_y = cell_y + (y * cell_height / TILE_HEIGHT);
                        double pixel_width = Math.fmax(1.0, cell_width / TILE_WIDTH);
                        double pixel_height = Math.fmax(1.0, cell_height / TILE_HEIGHT);
                        
                        cr.rectangle(pixel_x, pixel_y, pixel_width, pixel_height);
                        cr.fill();
                    }
                }
            }
        }
    }
    
    // Select a pattern tile based on click coordinates
    private void select_pattern_tile(double x, double y, Gtk.Label mirror_status) {
        // Calculate which pattern tile was clicked
        int width = pattern_area.get_width();
        int height = pattern_area.get_height();
        int cell_width = width / 4;
        int cell_height = height / 4;
        
        int col = (int)(x / cell_width);
        int row = (int)(y / cell_height);
        
        // Clamp to valid range
        col = (int)Math.fmax(0, Math.fmin(3, col));
        row = (int)Math.fmax(0, Math.fmin(3, row));
        
        // Calculate tile index (0-15, or 0-f in hex)
        int tile_index = row * 4 + col;
        
        // Update selected pattern tile
        chr_data.selected_pattern_tile = tile_index;
        
        // Update mirror status
        update_mirror_status(mirror_status);
        update_pattern_tile(mirror_status);
        
        // Redraw
        pattern_area.queue_draw();
    }
    
    private void update_pattern_tile(Gtk.Label mirror_status) {
        // Calculate which pattern tile was clicked
        int width = pattern_area.get_width();
        int height = pattern_area.get_height();
        int cell_width = width / 4;
        int cell_height = height / 4;
        
        int col = (int)(click_x / cell_width);
        int row = (int)(click_y / cell_height);
        
        // Clamp to valid range
        col = (int)Math.fmax(0, Math.fmin(3, col));
        row = (int)Math.fmax(0, Math.fmin(3, row));
        
        // Calculate tile index (0-15, or 0-f in hex)
        int tile_index = row * 4 + col;
        
        // Update selected pattern tile
        chr_data.selected_pattern_tile = tile_index;
        
        // Update mirror status
        update_mirror_status(mirror_status);
        
        // Redraw
        pattern_area.queue_draw();
    }
    
    // Update the mirror status display
    private void update_mirror_status(Gtk.Label? label = null) {
        if (label == null) {
            // Find the mirror status label in the container
            var mirror_box = pattern_area.get_parent().get_first_child();
            if (mirror_box == null) return;
            
            label = mirror_box.get_first_child() as Gtk.Label;
            if (label == null) return;
        }
        
        // First hex digit: 8 (no mirror), 9 (h-mirror), a (v-mirror), b (both)
        char first_char = '8';
        if (chr_data.mirror_horizontal && chr_data.mirror_vertical) {
            first_char = 'b';
        } else if (chr_data.mirror_horizontal) {
            first_char = '9';
        } else if (chr_data.mirror_vertical) {
            first_char = 'a';
        }
        
        // Second hex digit: selected tile index (0-f)
        int second_char = chr_data.selected_pattern_tile < 10 ? 
                         '0' + chr_data.selected_pattern_tile : 
                         'a' + (chr_data.selected_pattern_tile - 10);
        
        label.set_text("%c%c".printf(first_char, (char)second_char));
    }
    
    // Update sprite size based on click/drag coordinates
    private void update_size_from_coordinates(double x, double y) {
        // Get the block size
        int width = sprite_area.get_width();
        int height = sprite_area.get_height();
        int block_width = width / 4;
        int block_height = height / 4;
        
        // Calculate which block was clicked/dragged to
        int block_x = (int)(x / block_width) + 1;
        int block_y = (int)(y / block_height) + 1;
        
        // Clamp to valid range
        block_x = (int)Math.fmax(1, Math.fmin(4, block_x));
        block_y = (int)Math.fmax(1, Math.fmin(4, block_y));
        
        // Update sprite size if changed
        if (block_x != chr_data.sprite_width || block_y != chr_data.sprite_height) {
            chr_data.sprite_width = block_x;
            chr_data.sprite_height = block_y;
            sprite_area.queue_draw();
            sprite_label.set_text("%d%d".printf(block_x, block_y));
        }
    }
    
    // Update color picker with currently selected color
    public void update_color_picker() {
        if (color_picker == null) return;
        
        // Get the selected color
        Gdk.RGBA color = chr_data.get_color(chr_data.selected_color);
        color_picker.set_rgba(color);
        
        // Force redraw
        color_picker.queue_draw();
    }

    // Helper method to create toolbar items
    private Gtk.ToggleButton create_toolbar_item(int width, int height, owned DrawFunc draw_func) {
        var drawing_area = new Gtk.DrawingArea();
        drawing_area.set_size_request(width, height);
        drawing_area.set_draw_func((area, cr, w, h) => {
            draw_func(cr, w, h);
        });
        
        var click_gesture = new Gtk.GestureClick();
        drawing_area.add_controller(click_gesture);
        
        // Add the drawing area to a container
        var event_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        event_box.append(drawing_area);
        
        // Store the drawing area for redrawing
        click_gesture.set_data("drawing-area", drawing_area);
        click_gesture.set_data("container", event_box);
        
        var button = new Gtk.ToggleButton();
        button.set_child(event_box);
        
        // Store drawing area in button data for later access
        button.set_data("drawing-area", drawing_area);
        
        return button;
    }
    
    // Helper method to create hex data displays
    private Gtk.Grid create_hex_data_display(string initial_value) {
        var hex_data = new Gtk.Grid();
        hex_data.add_css_class("data-grid");
        hex_data.column_spacing = 8;
        
        // Create 8 rows for the 8 rows of tile data
        for (int i = 0; i < 4; i++) {
            // Editor column
            var editor_label = new Gtk.Label(initial_value);
            editor_label.add_css_class("hex-label2");
            editor_label.halign = Gtk.Align.START;
            hex_data.attach(editor_label, 0, i);
            
            // Preview column
            var preview_label = new Gtk.Label(initial_value);
            preview_label.add_css_class("hex-label");
            preview_label.halign = Gtk.Align.START;
            hex_data.attach(preview_label, 1, i);
        }
        
        data_label = new Gtk.Label("");
        data_label.add_css_class("data-label");
        data_label.xalign = 0;
        hex_data.attach(data_label, 0, 4);

        data_label.set_label ("%x%x".printf(editor_view.selected_tile_x, editor_view.selected_tile_y));
        
        return hex_data;
    }
    
    // Update the hex data display
    public void update_hex_data() {
        // Get position of the currently selected tile
        int sel_tile_x = editor_view.selected_tile_x;
        int sel_tile_y = editor_view.selected_tile_y;
        
        // Calculate base position
        int base_x = sel_tile_x * VasuData.TILE_WIDTH;
        int base_y = sel_tile_y * VasuData.TILE_HEIGHT;
        
        // Arrays to store all bytes for the tile
        uint8[] low_bytes = new uint8[8];
        uint8[] high_bytes = new uint8[8];
        
        // First get all 16 bytes (8 for low plane, 8 for high plane)
        for (int row = 0; row < 8; row++) {
            uint8 low_byte = 0;
            uint8 high_byte = 0;
            
            for (int col = 0; col < 8; col++) {
                int pixel_x = base_x + col;
                int pixel_y = base_y + row;
                int pixel = editor_view.get_pixel(pixel_x, pixel_y);
                
                if ((pixel & 0x01) != 0) {
                    low_byte |= (uint8)(1 << (7 - col));
                }
                
                if ((pixel & 0x02) != 0) {
                    high_byte |= (uint8)(1 << (7 - col));
                }
            }
            
            low_bytes[row] = low_byte;
            high_bytes[row] = high_byte;
        }
        
        // Display as 4-digit hex words, pairing consecutive rows
        for (int i = 0; i < 4; i++) {
            // Left column: pair of bytes from low bit plane
            uint16 left_word = (uint16)((low_bytes[i*2+1] << 8) | low_bytes[i*2]);
            
            // Right column: pair of bytes from high bit plane
            uint16 right_word = (uint16)((high_bytes[i*2+1] << 8) | high_bytes[i*2]);
            
            // Update the display
            var left_label = hex_data.get_child_at(0, i) as Gtk.Label;
            var right_label = hex_data.get_child_at(1, i) as Gtk.Label;
            
            if (left_label != null && right_label != null) {
                left_label.set_text("%04x".printf(left_word));
                right_label.set_text("%04x".printf(right_word));
            }
        }
        
        // Update the tile position display
        data_label.set_label("%x%x".printf(sel_tile_x, sel_tile_y));
    }
}