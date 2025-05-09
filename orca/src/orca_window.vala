public class OrcaWindow : Gtk.ApplicationWindow {
    private OrcaGrid grid;
    private OrcaEngine engine;
    private OrcaSynth synth;
    private Gtk.DrawingArea drawing_area;
    private Gtk.Box main_box;
    private Theme.Manager theme_manager;

    private int cursor_x = 0;
    private int cursor_y = 0;
    private uint timer_id = 0;
    private int bpm = 100; // Default BPM
    private const int STATUS_BAR_HEIGHT = 32;

    private bool has_selection = false;
    private int selection_start_x = -1;
    private int selection_start_y = -1;
    private int selection_end_x = -1;
    private int selection_end_y = -1;
    private double drag_start_x = 0;
    private double drag_start_y = 0;

    private List<string> midi_outputs;
    private string filename = "untitled.orca";
    private bool is_editing_filename = false;
    private string editing_text = "";
    private int editing_cursor_pos = 0;
    private Gdk.Rectangle filename_area = { 0, 0, 0, 0 };

    private const string SPECIAL_OPERATORS = "=:!?%;$~";
    private const string OPERATORS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    
    // Drawing optimization variables
    private bool[,] previously_banged_cells;
    private Gee.HashMap<string, Cairo.TextExtents?> text_extents_cache;
    private int64 last_draw_time = 0;
    private Cairo.Surface? dot_surface = null;
    private Cairo.Surface? plus_surface = null;
    private double cached_cell_width = 0;
    private double cached_cell_height = 0;

    public OrcaWindow(Gtk.Application app) {
        Object(application: app);

        set_title("ORCA");
        set_default_size(800, -1);
        set_resizable(false);

        theme_manager = Theme.Manager.get_default();
        theme_manager.apply_to_display();
        setup_theme_management();
        theme_manager.theme_changed.connect(() => {
            drawing_area.queue_draw();
        });
    }

    construct {
        grid = new OrcaGrid();
        synth = new OrcaSynth();
        engine = new OrcaEngine(grid, synth);

        // Initialize optimization structures
        previously_banged_cells = new bool[OrcaGrid.WIDTH, OrcaGrid.HEIGHT];
        text_extents_cache = new Gee.HashMap<string, Cairo.TextExtents?>();
        
        engine.start();
        start_timer();

        var _tmp = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        _tmp.visible = false;
        titlebar = _tmp;

        // Create the UI
        main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        set_child(main_box);

        main_box.append(create_titlebar());

        // Add drawing area
        drawing_area = new Gtk.DrawingArea();
        drawing_area.set_draw_func(draw);
        drawing_area.set_size_request(800, 600);
        drawing_area.set_focusable(true);
        drawing_area.grab_focus();
        drawing_area.margin_start = 1;
        drawing_area.margin_top = 1;
        drawing_area.margin_end = 1;
        drawing_area.margin_bottom = 1;
        main_box.append(drawing_area);

        var click_controller = new Gtk.GestureClick();
        click_controller.button = 1; // Primary button (left click)
        click_controller.pressed.connect(on_click_pressed);
        drawing_area.add_controller(click_controller);

        var drag_controller = new Gtk.GestureDrag();
        drag_controller.drag_begin.connect(on_drag_begin);
        drag_controller.drag_update.connect(on_drag_update);
        drag_controller.drag_end.connect(on_drag_end);
        drawing_area.add_controller(drag_controller);

        // Set up keyboard input
        var key_controller = new Gtk.EventControllerKey();
        key_controller.key_pressed.connect(on_key_pressed);
        main_box.add_controller(key_controller);

        // Add to OrcaWindow constructor after existing initialization
        initialize_midi_outputs();

        engine.bpm_change_requested.connect((new_bpm) => {
            set_bpm(new_bpm);
        });
    }

    private void initialize_midi_outputs() {
        midi_outputs = new List<string>();
        midi_outputs.append("Synth");
        midi_outputs.append("System");
        midi_outputs.append("USB");
        midi_outputs.append("IAC Driver");
        midi_outputs.append("Virtual MIDI");

        // Set the first output as default
        synth.set_midi_output(midi_outputs.first().data);
    }

    // Track banged cells for change detection
    private void update_banged_cells_tracking() {
        for (int x = 0; x < OrcaGrid.WIDTH; x++) {
            for (int y = 0; y < OrcaGrid.HEIGHT; y++) {
                bool is_currently_banged = engine.is_cell_banged(x, y);
                previously_banged_cells[x, y] = is_currently_banged;
            }
        }
    }

    private void toggle_midi_output() {
        // Find current output in the list
        string current = synth.get_midi_output();
        unowned List<string> current_node = midi_outputs.find_custom(current,
                                                                     (a, b) => strcmp(a, b));

        // Move to next output or wrap around
        if (current_node != null && current_node.next != null) {
            synth.set_midi_output(current_node.next.data);
        } else {
            synth.set_midi_output(midi_outputs.first().data);
        }

        drawing_area.queue_draw();
    }

    private void start_filename_editing() {
        is_editing_filename = true;
        editing_text = filename;
        editing_cursor_pos = editing_text.length;
        drawing_area.queue_draw();
    }

    private void end_filename_editing(bool apply_changes) {
        if (!apply_changes) {
            // Cancel editing without applying changes
            is_editing_filename = false;
            drawing_area.queue_draw();
            return;
        }

        if (editing_text == filename) {
            // No changes made
            is_editing_filename = false;
            drawing_area.queue_draw();
            return;
        }

        // Ensure filename has .orca extension
        string new_filename = editing_text;
        if (!new_filename.down().has_suffix(".orca")) {
            new_filename = new_filename + ".orca";
        }

        // Determine if this is an absolute path or just a filename
        bool is_path = new_filename.contains("/") || new_filename.contains("\\");

        if (is_path) {
            // This is a path, check if the file exists
            var file = File.new_for_path(new_filename);
            if (file.query_exists()) {
                // If file exists, load it
                load_orca_file(file);
                // Update the filename to match the file we just loaded
                filename = file.get_path();
            } else {
                // File doesn't exist, just update the filename for next save
                filename = new_filename;
            }
        } else {
            // Just a filename, update for next save
            filename = new_filename;
        }

        // End editing mode
        is_editing_filename = false;
        drawing_area.queue_draw();
    }

    private void adjust_bpm(int delta) {
        // Calculate new BPM
        int new_bpm = bpm + delta;

        // Apply constraints: min 60, max 300
        new_bpm = (int) Math.fmin(Math.fmax(new_bpm, 60), 300);

        // Only update if value actually changed
        if (new_bpm != bpm) {
            bpm = new_bpm;
            start_timer(); // Restart timer with new rate
            drawing_area.queue_draw(); // Update display (status bar shows BPM)
            print("BPM changed to %d\n", bpm);
        }
    }

    private bool handle_filename_key(uint keyval, uint keycode, Gdk.ModifierType state) {
        if (!is_editing_filename) {
            return false;
        }

        switch (keyval) {
        case Gdk.Key.Return:
        case Gdk.Key.KP_Enter:
            end_filename_editing(true);
            return true;

        case Gdk.Key.Escape:
            end_filename_editing(false);
            return true;

        case Gdk.Key.BackSpace:
            if (editing_cursor_pos > 0) {
                editing_text = editing_text.substring(0, editing_cursor_pos - 1)
                    + editing_text.substring(editing_cursor_pos);
                editing_cursor_pos--;
                drawing_area.queue_draw();
            }
            return true;

        case Gdk.Key.Delete:
            if (editing_cursor_pos < editing_text.length) {
                editing_text = editing_text.substring(0, editing_cursor_pos)
                    + editing_text.substring(editing_cursor_pos + 1);
                drawing_area.queue_draw();
            }
            return true;

        case Gdk.Key.Left:
            if (editing_cursor_pos > 0) {
                editing_cursor_pos--;
                drawing_area.queue_draw();
            }
            return true;

        case Gdk.Key.Right:
            if (editing_cursor_pos < editing_text.length) {
                editing_cursor_pos++;
                drawing_area.queue_draw();
            }
            return true;

        default:
            // Accept printable ASCII characters
            if (keyval >= 32 && keyval <= 126) {
                char c = (char) keyval;
                editing_text = editing_text.substring(0, editing_cursor_pos)
                    + c.to_string()
                    + editing_text.substring(editing_cursor_pos);
                editing_cursor_pos++;
                drawing_area.queue_draw();
                return true;
            }
            break;
        }

        return false;
    }

    private void setup_theme_management() {
        string theme_file = GLib.Path.build_filename(Environment.get_home_dir(), ".theme");

        Timeout.add(10, () => {
            if (FileUtils.test(theme_file, FileTest.EXISTS)) {
                try {
                    theme_manager.load_theme_from_file(theme_file);
                } catch (Error e) {
                    warning("Theme load failed: %s", e.message);
                }
            }
            return true;
        });
    }

    private Gtk.Widget create_titlebar() {
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = 800;

        // Create close button
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;
        close_button.margin_top = 8;
        close_button.margin_bottom = 8;
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

    private void on_click_pressed(int n_press, double x, double y) {
        // Convert screen coordinates to grid coordinates
        int grid_height = drawing_area.get_height() - STATUS_BAR_HEIGHT;

        // Check if we're in the status bar area
        if (y >= grid_height) {
            // We're in the status bar - handle status bar clicks

            // Check if click is in the filename area
            if (x >= filename_area.x &&
                x <= filename_area.x + filename_area.width &&
                y >= filename_area.y &&
                y <= filename_area.y + filename_area.height) {

                start_filename_editing();
            } else if (is_editing_filename) {
                // Click outside filename area while editing
                end_filename_editing(true);
            }

            return; // Don't process further as grid click
        }

        // Below this point is the original grid click handling

        double cell_width = (double) drawing_area.get_width() / OrcaGrid.WIDTH;
        double cell_height = (double) grid_height / OrcaGrid.HEIGHT;

        int grid_x = (int) (x / cell_width);
        int grid_y = (int) (y / cell_height);

        // Ensure coordinates are within bounds
        grid_x = (int) Math.fmin(Math.fmax(grid_x, 0), OrcaGrid.WIDTH - 1);
        grid_y = (int) Math.fmin(Math.fmax(grid_y, 0), OrcaGrid.HEIGHT - 1);

        // Set cursor position
        cursor_x = grid_x;
        cursor_y = grid_y;

        drawing_area.queue_draw();
    }

    private void on_drag_begin(double start_x, double start_y) {
        // Convert screen coordinates to grid coordinates
        int grid_height = drawing_area.get_height() - STATUS_BAR_HEIGHT;

        // Skip if we're in the status bar area
        if (start_y >= grid_height)return;

        // Save the exact pixel coordinates where the drag started
        drag_start_x = start_x;
        drag_start_y = start_y;

        double cell_width = (double) drawing_area.get_width() / OrcaGrid.WIDTH;
        double cell_height = (double) grid_height / OrcaGrid.HEIGHT;

        int grid_x = (int) (start_x / cell_width);
        int grid_y = (int) (start_y / cell_height);

        // Bounds check
        grid_x = (int) Math.fmin(Math.fmax(grid_x, 0), OrcaGrid.WIDTH - 1);
        grid_y = (int) Math.fmin(Math.fmax(grid_y, 0), OrcaGrid.HEIGHT - 1);

        // Start selection and set cursor
        cursor_x = grid_x;
        cursor_y = grid_y;
        selection_start_x = grid_x;
        selection_start_y = grid_y;
        selection_end_x = grid_x;
        selection_end_y = grid_y;
        has_selection = true;

        drawing_area.queue_draw();
    }

    private void on_drag_update(double offset_x, double offset_y) {
        if (!has_selection)return;

        // Get the grid dimensions
        int grid_height = drawing_area.get_height() - STATUS_BAR_HEIGHT;
        double cell_width = (double) drawing_area.get_width() / OrcaGrid.WIDTH;
        double cell_height = (double) grid_height / OrcaGrid.HEIGHT;

        // Calculate current pixel position using the exact drag start position
        double current_x = drag_start_x + offset_x;
        double current_y = drag_start_y + offset_y;

        // Clamp y-coordinate to grid area for calculation
        double clamped_y = Math.fmin(current_y, grid_height - 1);

        // Convert to grid coordinates
        int grid_x = (int) (current_x / cell_width);
        int grid_y = (int) (clamped_y / cell_height);

        // Bounds check
        grid_x = (int) Math.fmin(Math.fmax(grid_x, 0), OrcaGrid.WIDTH - 1);
        grid_y = (int) Math.fmin(Math.fmax(grid_y, 0), OrcaGrid.HEIGHT - 1);

        // Check if selection end point has changed
        if (grid_x != selection_end_x || grid_y != selection_end_y) {
            // Update selection end point
            selection_end_x = grid_x;
            selection_end_y = grid_y;
            
            // Update cursor position to follow the drag
            cursor_x = grid_x;
            cursor_y = grid_y;
            
            drawing_area.queue_draw();
        }
    }

    private void on_drag_end(double offset_x, double offset_y) {
        if (!has_selection)return;

        // Update the selection one last time
        on_drag_update(offset_x, offset_y);

        // Ensure cursor is at the end of the selection
        cursor_x = selection_end_x;
        cursor_y = selection_end_y;

        drawing_area.queue_draw();
    }

    private void clear_selection() {
        if (!has_selection) return;
        
        has_selection = false;
        selection_start_x = -1;
        selection_start_y = -1;
        selection_end_x = -1;
        selection_end_y = -1;
        
        drawing_area.queue_draw();
    }

    private void delete_selection() {
        if (!has_selection)return;

        // Get the bounds of the selection
        int min_x = int.min(selection_start_x, selection_end_x);
        int max_x = int.max(selection_start_x, selection_end_x);
        int min_y = int.min(selection_start_y, selection_end_y);
        int max_y = int.max(selection_start_y, selection_end_y);

        // Delete all characters in the selection by setting them to '.'
        for (int y = min_y; y <= max_y; y++) {
            for (int x = min_x; x <= max_x; x++) {
                grid.set_char(x, y, '.');
            }
        }

        // Move cursor to beginning of selection
        cursor_x = min_x;
        cursor_y = min_y;

        // Clear the selection state
        clear_selection();

        print("Deleted selection: %d,%d to %d,%d\n", min_x, min_y, max_x, max_y);
        
        drawing_area.queue_draw();
    }

    // Update the timer method to call the visualization update
    private int bpm_to_frame_rate(int bpm) {
        // Standard conversion: 4 frames per beat
        return (int) Math.floor(bpm / 60.0 * 4);
    }

    private void start_timer() {
        if (timer_id != 0) {
            Source.remove(timer_id);
        }

        // 10 frames per second (100ms per frame)
        int frame_rate = bpm_to_frame_rate(bpm);

        // Tell the synth about our frame rate
        synth.set_frame_rate(frame_rate);

        timer_id = Timeout.add(1000 / frame_rate, () => {
            // Update engine state
            engine.tick();
            
            // Update visualization data
            synth.update_visualization();
            
            // Track changes from bangs
            update_banged_cells_tracking();
            
            // Redraw the entire grid
            drawing_area.queue_draw();
            return true;
        });

        print("Timer started at %d fps\n", frame_rate);
    }

    private bool is_special_operator(char c) {
        return SPECIAL_OPERATORS.contains(c.to_string());
    }

    private bool is_operator(char c) {
        return OPERATORS.contains(c.to_string());
    }

    // Drawing optimization methods
    
    // Ensure cached surfaces are created and sized correctly
    private void ensure_cached_surfaces(double cell_width, double cell_height) {
        // Only recreate if cell size changed
        if (cached_cell_width == cell_width && cached_cell_height == cell_height &&
            dot_surface != null && plus_surface != null) {
            return;
        }
        
        // Update cache dimensions
        cached_cell_width = cell_width;
        cached_cell_height = cell_height;
        
        // Create dot surface
        if (dot_surface != null) {
            dot_surface.finish();
        }
        
        dot_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, 
                                           (int)cell_width, (int)cell_height);
        var dot_cr = new Cairo.Context(dot_surface);
        
        // Clear surface
        dot_cr.set_source_rgba(0, 0, 0, 0);
        dot_cr.set_operator(Cairo.Operator.SOURCE);
        dot_cr.paint();
        
        // Draw dot
        Gdk.RGBA fg_color = theme_manager.get_color("theme_fg");
        dot_cr.set_source_rgb(0.5, 0.5, 0.5);
        dot_cr.set_antialias(Cairo.Antialias.NONE);
        dot_cr.arc(cell_width / 2, cell_height / 2, 1, 0, 2 * Math.PI);
        dot_cr.fill();
        
        // Create plus surface
        if (plus_surface != null) {
            plus_surface.finish();
        }
        
        plus_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, 
                                            (int)cell_width, (int)cell_height);
        var plus_cr = new Cairo.Context(plus_surface);
        
        // Clear surface
        plus_cr.set_source_rgba(0, 0, 0, 0);
        plus_cr.set_operator(Cairo.Operator.SOURCE);
        plus_cr.paint();
        
        // Draw plus
        plus_cr.set_source_rgb(0.5, 0.5, 0.5);
        plus_cr.set_antialias(Cairo.Antialias.NONE);
        plus_cr.set_font_size(17);
        plus_cr.select_font_face("Orca", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        
        Cairo.TextExtents extents;
        plus_cr.text_extents("+", out extents);
        double text_x = (cell_width - extents.width) / 2;
        double text_y = (cell_height + extents.height) / 2;
        plus_cr.move_to(text_x, text_y);
        plus_cr.show_text("+");
    }
    
    // Get text extents with caching
    private Cairo.TextExtents get_text_extents(Cairo.Context cr, string text) {
        if (!text_extents_cache.has_key(text)) {
            Cairo.TextExtents extents;
            cr.text_extents(text, out extents);
            text_extents_cache[text] = extents;
            return extents;
        }
        return text_extents_cache[text];
    }
    
    // Optimized text rendering
    private void render_text(Cairo.Context cr, string text, double x, double y, double cell_width, double cell_height) {
        Cairo.TextExtents extents = get_text_extents(cr, text);
        double text_x = x + (cell_width - extents.width) / 2;
        double text_y = y + (cell_height + extents.height) / 2;
        cr.move_to(text_x, text_y);
        cr.show_text(text);
    }

    // Draw a cell background
    private void draw_cell_background(Cairo.Context cr, double x, double y, double width, double height, Gdk.RGBA color) {
        cr.set_source_rgb(color.red, color.green, color.blue);
        cr.rectangle(x, y, width, height);
        cr.fill();
    }

    // Main draw method now simplified to coordinate the optimized drawing
    private void draw(Gtk.DrawingArea da, Cairo.Context cr, int width, int height) {
        // Start timing
        int64 start_time = get_monotonic_time();
        
        int grid_height = height - STATUS_BAR_HEIGHT;
        double cell_width = (double) width / OrcaGrid.WIDTH;
        double cell_height = (double) grid_height / OrcaGrid.HEIGHT;
        
        // Ensure cached surfaces are created and up-to-date
        ensure_cached_surfaces(cell_width, cell_height);

        // Colors
        Gdk.RGBA bg_color = theme_manager.get_color("theme_fg");
        Gdk.RGBA fg_color = theme_manager.get_color("theme_bg");
        Gdk.RGBA selection_color = theme_manager.get_color("theme_accent");
        Gdk.RGBA accent_color = theme_manager.get_color("theme_selection");

        // Determine active quadrant
        int quadrant_x = (cursor_x / 10) * 10;
        int quadrant_y = (cursor_y / 9) * 9;

        // Draw background
        cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
        cr.paint();

        cr.set_antialias(Cairo.Antialias.NONE);
        cr.set_line_width(1);
        cr.select_font_face("Orca", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        cr.set_font_size(17);

        // Process the grid with optimized drawing approach
        draw_grid_optimized(cr, width, grid_height, cell_width, cell_height, 
                           quadrant_x, quadrant_y, bg_color, fg_color, 
                           accent_color, selection_color);

        // Draw cursor
        draw_cursor(cr, cell_width, cell_height, selection_color, fg_color);

        // Draw status bar
        draw_status_bar(cr, width, height, grid_height);
        
        // End timing
        int64 end_time = get_monotonic_time();
        int64 draw_duration = end_time - start_time;
        
        // Log performance periodically
        if (engine.get_frame_count() % 30 == 0) {
            print("Draw time: %.2f ms\n", draw_duration / 1000.0);
        }
        
        last_draw_time = draw_duration;
    }

    // Draw the entire grid with optimized batching
    private void draw_grid_optimized(Cairo.Context cr, int width, int grid_height, 
                                    double cell_width, double cell_height,
                                    int quadrant_x, int quadrant_y,
                                    Gdk.RGBA bg_color, Gdk.RGBA fg_color, 
                                    Gdk.RGBA accent_color, Gdk.RGBA selection_color) {
        
        // First pass: Draw backgrounds and selection highlights
        for (int x = 0; x < OrcaGrid.WIDTH; x++) {
            for (int y = 0; y < OrcaGrid.HEIGHT; y++) {
                char c = grid.get_char(x, y);
                double pos_x = x * cell_width;
                double pos_y = y * cell_height;
                
                bool is_selected = has_selection &&
                    x >= int.min(selection_start_x, selection_end_x) &&
                    x <= int.max(selection_start_x, selection_end_x) &&
                    y >= int.min(selection_start_y, selection_end_y) &&
                    y <= int.max(selection_start_y, selection_end_y);
                
                // Draw selection highlight if applicable
                if (is_selected) {
                    draw_cell_background(cr, pos_x, pos_y, cell_width, cell_height, selection_color);
                }
                
                // Draw backgrounds for operators
                if (c != '.') {
                    bool is_data = grid.is_data_cell(x, y);
                    bool is_special = is_special_operator(c);
                    bool is_operator = is_operator(c);
                    bool is_banged = engine.is_cell_banged(x, y);
                    bool is_commented = grid.is_commented_cell(x, y);
                    bool is_left_input = is_left_input_of_operator(x, y);
                    bool is_right_input = is_right_input_of_operator(x, y);
                    bool near_bang = is_near_bang(x, y);
                    bool is_bangee_op = is_input_to_operator(x, y, "CUDFV;:~");
                    bool outputs_bang_bool = outputs_bang(x, y);
                    bool is_t_active_input = false;
                    bool is_t_input = false;
                    
                    // Check for MIDI + T operators
                    for (int tx = x - 1; tx >= 0; tx--) {
                        if (grid.get_char(tx, y) == 'T' || grid.get_char(tx, y) == ';') {
                            // Calculate active input position
                            int active_pos = get_t_active_input_position(tx, y);
                            
                            // Check if this is the active input
                            if (x == active_pos) {
                                is_t_active_input = true;
                            }
                            
                            // Get length parameter to determine input range
                            int len = (tx > 0) ? get_value(tx - 1, y) : 1;
                            if (len <= 0) len = 1;
                            
                            // Check if this is any input to T
                            if (x > tx && x <= tx + len) {
                                is_t_input = true;
                            }
                            
                            break; // Found a T
                        }
                        
                        // Stop if we hit another operator
                        if (!grid.is_data_cell(tx, y) && grid.get_char(tx, y) != '.') {
                            break;
                        }
                    }
                    
                    // Draw operator backgrounds with appropriate colors
                    if ((is_operator && is_t_input) || (is_operator && is_t_active_input)) {
                            draw_cell_background(cr, pos_x, pos_y, cell_width, cell_height, fg_color);
                    } else if (is_special && !is_data) {
                        if (is_banged || near_bang || is_data || is_left_input || is_operator || is_right_input || (is_operator && is_t_input) || (is_operator && is_t_active_input)) {
                            draw_cell_background(cr, pos_x, pos_y, cell_width, cell_height, bg_color);
                        } else {
                            cr.set_source_rgb(0.5, 0.5, 0.5);
                            cr.rectangle(pos_x, pos_y, cell_width, cell_height);
                            cr.fill();
                        }
                    } else if (outputs_bang_bool || (is_operator && !is_commented) || (is_operator && is_bangee_op && !is_commented)) {
                        draw_cell_background(cr, pos_x, pos_y, cell_width, cell_height, accent_color);
                    } else if (!is_selected) {
                        draw_cell_background(cr, pos_x, pos_y, cell_width, cell_height, fg_color);
                    }
                }
            }
        }
        
        // Second pass: Draw dots and plus signs
        for (int x = 0; x < OrcaGrid.WIDTH; x++) {
            for (int y = 0; y < OrcaGrid.HEIGHT; y++) {
                char c = grid.get_char(x, y);
                double pos_x = x * cell_width;
                double pos_y = y * cell_height;
                
                // Is this cell inside the active quadrant?
                bool in_active_quadrant = (x >= quadrant_x && x < quadrant_x + 11) &&
                    (y >= quadrant_y && y < quadrant_y + 10);
                
                // Is this a quadrant corner? (applies to all quadrants)
                bool is_quadrant_corner = (x % 10 == 0 && y % 9 == 0);
                
                if (c == '.') {
                    if (is_quadrant_corner) {
                        // Use the cached plus surface
                        cr.set_source_surface(plus_surface, pos_x, pos_y);
                        cr.paint();
                    } else {
                        // Use the cached dot surface
                        cr.set_source_surface(dot_surface, pos_x, pos_y);
                        cr.paint();
                    }
                }
            }
        }
        
        // Third pass: Draw characters (text)
        for (int x = 0; x < OrcaGrid.WIDTH; x++) {
            for (int y = 0; y < OrcaGrid.HEIGHT; y++) {
                char c = grid.get_char(x, y);
                double pos_x = x * cell_width;
                double pos_y = y * cell_height;
                
                if (c != '.') {
                    bool is_data = grid.is_data_cell(x, y);
                    bool is_special = is_special_operator(c);
                    bool is_operator = is_operator(c);
                    bool is_banged = engine.is_cell_banged(x, y);
                    bool is_commented = grid.is_commented_cell(x, y);
                    bool near_bang = is_near_bang(x, y);
                    bool is_left_input = is_left_input_of_operator(x, y);
                    bool is_right_input = is_right_input_of_operator(x, y);
                    bool is_bangee_op = is_input_to_operator(x, y, "CUDFV");
                    bool is_t_active_input = false;
                    bool is_t_input = false;
                    bool outputs_bang_bool = outputs_bang(x, y);
                    
                    // Check for MIDI + T operators
                    for (int tx = x - 1; tx >= 0; tx--) {
                        if (grid.get_char(tx, y) == 'T' || grid.get_char(tx, y) == ';') {
                            // Calculate active input position
                            int active_pos = get_t_active_input_position(tx, y);
                            
                            // Check if this is the active input
                            if (x == active_pos) {
                                is_t_active_input = true;
                            }
                            
                            // Get length parameter to determine input range
                            int len = (tx > 0) ? get_value(tx - 1, y) : 1;
                            if (len <= 0) len = 1;
                            
                            // Check if this is any input to T
                            if (x > tx && x <= tx + len) {
                                is_t_input = true;
                            }
                            
                            break; // Found a T
                        }
                        
                        // Stop if we hit another operator
                        if (!grid.is_data_cell(tx, y) && grid.get_char(tx, y) != '.') {
                            break;
                        }
                    }
                    
                    // Set the appropriate text color
                    if (is_t_input && !is_t_active_input) {
                        // T inputs that aren't active - background text color
                        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
                    } else if (is_t_input && !is_t_active_input && is_operator) {
                        // T inputs that aren't active - background text color
                        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
                    } else if (is_data) {
                        // Data cells
                        cr.set_source_rgb(accent_color.red, accent_color.green, accent_color.blue);
                    } else if (is_commented) {
                        // Commented cells
                        cr.set_source_rgb(0.5, 0.5, 0.5);
                    } else if (is_commented && is_operator) {
                        // Commented cells
                        cr.set_source_rgb(0.5, 0.5, 0.5);
                    } else if (is_commented && is_bangee_op) {
                        // Commented cells
                        cr.set_source_rgb(0.5, 0.5, 0.5);
                    } else if (is_t_active_input) {
                        // Active input to T operator - accent text color
                        cr.set_source_rgb(accent_color.red, accent_color.green, accent_color.blue);
                    } else if (is_right_input || (is_left_input && !is_bangee_op)) {
                        // Other operator inputs - background text color
                        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
                    } else if (is_special && !is_data) {
                        // Special operators
                        cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
                    } else if (outputs_bang_bool || (is_operator && !is_commented)) {
                        // Operators
                        cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
                    } else {
                        // Default case
                        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
                    }
                    
                    // Draw the character with optimized text rendering
                    string s = c.to_string();
                    render_text(cr, s, pos_x, pos_y, cell_width, cell_height);
                }
            }
        }
    }
    
    // Draw the cursor separately for clarity
    private void draw_cursor(Cairo.Context cr, double cell_width, double cell_height, 
                            Gdk.RGBA selection_color, Gdk.RGBA fg_color) {
        double cursor_x_pos = cursor_x * cell_width;
        double cursor_y_pos = cursor_y * cell_height;
        
        cr.set_source_rgb(selection_color.red, selection_color.green, selection_color.blue);
        cr.rectangle(cursor_x_pos, cursor_y_pos, cell_width, cell_height);
        cr.fill();
        
        cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
        string s = "@";
        render_text(cr, s, cursor_x_pos, cursor_y_pos, cell_width, cell_height);
    }

    // Check if a cell is a left input to an operator
    private bool is_left_input_of_operator(int x, int y) {
        // Most operators take inputs from their left
        if (x < OrcaGrid.WIDTH - 1) {
            char right_char = grid.get_char(x + 1, y);
            if (is_operator(right_char) && grid.is_data_cell(x, y)) {
                return true;
            }
        }
        return false;
    }

    // Check if a cell is a right input to an operator
    private bool is_right_input_of_operator(int x, int y) {
        // Most operators take inputs from their right
        if (x > 0) {
            char left_char = grid.get_char(x - 1, y);
            if (is_operator(left_char) && grid.is_data_cell(x, y)) {
                return true;
            }
        }
        return false;
    }

    // Check if cell is input to a specific operator
    private bool is_input_to_operator(int x, int y, string operator_chars) {
        if (x > 0 && x < OrcaGrid.WIDTH - 1) {
            char left_char = grid.get_char(x - 1, y);
            char right_char = grid.get_char(x + 1, y);

            return (operator_chars.contains(left_char.to_string()) ||
                    operator_chars.contains(right_char.to_string())) &&
                   grid.is_data_cell(x, y);
        }
        return false;
    }

    // Check if an operator outputs bangs
    private bool outputs_bang(int x, int y) {
        char c = grid.get_char(x, y);
        // Operators that output bangs: D, F, U
        return (c == 'D' || c == 'F' || c == 'U');
    }

    // Helper method to calculate T's active input position
    private int get_t_active_input_position(int t_x, int t_y) {
        // Read T's parameters
        int key = (t_x > 1) ? get_value(t_x - 2, t_y) : 0;
        int len = (t_x > 0) ? get_value(t_x - 1, t_y) : 1;
        if (len <= 0)len = 1;

        // Calculate offset using the same formula as in engine
        int offset = (key % len) + 1;

        // Return the position T reads from
        return t_x + offset;
    }

    // Helper to convert characters to values (same as in OrcaEngine)
    private int get_value(int x, int y) {
        if (x < 0 || x >= OrcaGrid.WIDTH || y < 0 || y >= OrcaGrid.HEIGHT) {
            return 0;
        }

        char c = grid.get_char(x, y);

        if (c >= '0' && c <= '9') {
            return c - '0';
        } else if (c >= 'a' && c <= 'z') {
            return (c - 'a') + 10;
        } else if (c >= 'A' && c <= 'Z') {
            return (c - 'A') + 10;
        }

        return 0;
    }

    // Helper method to check if a cell is near a bang
    private bool is_near_bang(int x, int y) {
        // Check adjacent cells for bangs
        for (int dx = -1; dx <= 1; dx++) {
            for (int dy = -1; dy <= 1; dy++) {
                if (dx == 0 && dy == 0)continue;

                int nx = x + dx;
                int ny = y + dy;

                if (nx >= 0 && nx < OrcaGrid.WIDTH && ny >= 0 && ny < OrcaGrid.HEIGHT) {
                    if (engine.is_cell_banged(nx, ny) || grid.get_char(nx, ny) == '*') {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    public void set_bpm(int new_bpm) {
        // Ensure BPM is within valid range
        new_bpm = (int) Math.fmin(Math.fmax(new_bpm, 60), 300);

        // Update BPM and restart timer
        if (new_bpm != bpm) {
            bpm = new_bpm;
            start_timer();
            drawing_area.queue_draw(); // Update display
            print("BPM set to %d\n", bpm);
        }
    }

    private void draw_status_bar(Cairo.Context cr, int width, int height, int grid_height) {
        Gdk.RGBA bg_color = theme_manager.get_color("theme_fg");
        Gdk.RGBA fg_color = theme_manager.get_color("theme_bg");

        // Status bar background
        cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
        cr.rectangle(0, grid_height, width, STATUS_BAR_HEIGHT);
        cr.fill();

        // Prepare to draw text
        cr.select_font_face("Chicago 12.1", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        cr.set_font_size(16);
        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);

        // Format cursor position in base36
        string cursor_x_base36 = int_to_base36(cursor_x);
        string cursor_y_base36 = int_to_base36(cursor_y);

        // Left side: cursor position
        string cursor_text = cursor_x_base36 + " x " + cursor_y_base36;
        cr.move_to(16, grid_height + 20);
        cr.show_text(cursor_text);

        // Left-middle: frame count
        string frame_text = "%dF".printf(engine.get_frame_count());
        cr.move_to(80, grid_height + 20);
        cr.show_text(frame_text);

        // Middle: BPM
        string bpm_text = "%dBPM".printf(bpm);
        cr.move_to(140, grid_height + 20);
        cr.show_text(bpm_text);

        // Right-middle: MIDI output
        string midi_text = synth.get_midi_output();
        cr.move_to(220, grid_height + 20);
        cr.show_text(midi_text);

        // Right: Filename (with edit cursor if editing)
        Cairo.TextExtents filename_extents;
        string display_text;

        if (is_editing_filename) {
            // When editing, show the raw text
            display_text = editing_text;
        } else {
            // When displaying, show the formatted path
            display_text = format_display_path(filename);
        }

        cr.text_extents(display_text, out filename_extents);
        double filename_x = 350;
        double filename_y = grid_height + 20;

        // More accurate calculation of the text bounding box
        // Cairo text is positioned at the baseline, so we need to calculate the top properly
        double text_top = filename_y + filename_extents.y_bearing; // y_bearing is negative
        double text_height = filename_extents.height;

        // Store filename area for click detection using accurate coordinates
        filename_area = {
            (int) filename_x,
            (int) text_top,
            (int) filename_extents.width,
            (int) text_height
        };

        // Draw filename
        cr.move_to(filename_x, filename_y);
        cr.show_text(display_text);

        // Draw edit cursor if editing
        if (is_editing_filename) {
            // Calculate cursor position
            string text_before_cursor = editing_text.substring(0, editing_cursor_pos);
            Cairo.TextExtents cursor_extents;
            cr.text_extents(text_before_cursor, out cursor_extents);
            cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);

            // Draw cursor line
            cr.set_antialias(Cairo.Antialias.NONE);
            cr.set_line_width(1);
            cr.move_to(filename_x + cursor_extents.width + 4, filename_y - 16);
            cr.line_to(filename_x + cursor_extents.width + 4, filename_y);
            cr.stroke();
        }

        // Draw sound visualization on the right side of the status bar
        draw_sound_visualization(cr, width, grid_height);
    }

    // Optimized method to draw the sound visualization
    private void draw_sound_visualization(Cairo.Context cr, int width, int grid_height) {
        // Get visualization data from synth
        float[] amplitude_data;
        int data_count;
        synth.get_visualization_data(out amplitude_data, out data_count);

        // Set visualization position and dimensions
        int viz_width = 80; // Increased width for better visibility
        int viz_x = width - viz_width - 16;
        int viz_y = grid_height + 16;

        // Show more bars for a denser visualization
        int display_count = 8;
        int step = data_count / display_count;
        if (step < 1)step = 1;

        // Set the font for visualization characters
        cr.select_font_face("Chicago 12.1", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        cr.set_font_size(14);

        // Calculate character width
        double char_width = (double) viz_width / display_count;

        // Batch drawing by character type to reduce state changes
        string[] viz_chars = {"-", "=", "+", "#", "*", "|"};
        
        // Draw each type of character in a batch
        foreach (string viz_char in viz_chars) {
            // First gather positions where this character should be drawn
            int[] positions = {};
            
            for (int i = 0; i < display_count; i++) {
                int data_idx = (i * step) % data_count;
                float amp = amplitude_data[data_idx];
                
                string char_to_use;
                if (amp < 0.01f) char_to_use = "-";
                else if (amp < 0.3f) char_to_use = "=";
                else if (amp < 0.5f) char_to_use = "+";
                else if (amp < 0.7f) char_to_use = "#";
                else if (amp < 0.9f) char_to_use = "*";
                else char_to_use = "|";
                
                if (char_to_use == viz_char) {
                    positions += i;
                }
            }
            
            // Now draw all instances of this character type
            if (positions.length > 0) {
                Cairo.TextExtents extents;
                cr.text_extents(viz_char, out extents);
                
                foreach (int pos in positions) {
                    double x_pos = viz_x + (pos * char_width);
                    double text_x = x_pos + (char_width - extents.width) / 2;
                    cr.move_to(text_x, viz_y);
                    cr.show_text(viz_char);
                }
            }
        }
    }

    private string format_display_path(string full_path) {
        var file = File.new_for_path(full_path);
        string filename = file.get_basename();

        // If it's just a filename with no directory, return it as is
        if (!full_path.contains(Path.DIR_SEPARATOR_S)) {
            return filename;
        }

        // Get the parent directory
        var parent = file.get_parent();
        if (parent == null) {
            return filename;
        }

        // Get parent's basename (immediate parent folder)
        string parent_name = parent.get_basename();

        // For root directories or empty parent names
        if (parent_name == "") {
            return Path.DIR_SEPARATOR_S + filename;
        }

        // Format as "/parent_folder/filename"
        return Path.DIR_SEPARATOR_S + parent_name + Path.DIR_SEPARATOR_S + filename;
    }

    private void copy_selection() {
        if (!has_selection)return;

        // Get the bounds of the selection
        int min_x = int.min(selection_start_x, selection_end_x);
        int max_x = int.max(selection_start_x, selection_end_x);
        int min_y = int.min(selection_start_y, selection_end_y);
        int max_y = int.max(selection_start_y, selection_end_y);

        // Build the text representation
        StringBuilder sb = new StringBuilder();

        for (int y = min_y; y <= max_y; y++) {
            for (int x = min_x; x <= max_x; x++) {
                sb.append_c(grid.get_char(x, y));
            }

            // Add newline between rows (except the last row)
            if (y < max_y) {
                sb.append_c('\n');
            }
        }

        // Set the clipboard content
        var clipboard = get_clipboard();
        clipboard.set_text(sb.str);

        print("Copied selection to clipboard: %d,%d to %d,%d\n",
              min_x, min_y, max_x, max_y);
    }

    private void paste_from_clipboard() {
        var clipboard = get_clipboard();

        clipboard.read_text_async.begin(null, (obj, res) => {
            try {
                string? text = clipboard.read_text_async.end(res);

                if (text == null || text.length == 0) {
                    return;
                }

                // Split the text into lines
                string[] lines = text.split("\n");

                // Paste at cursor position
                int paste_x = cursor_x;
                int paste_y = cursor_y;

                for (int y = 0; y < lines.length; y++) {
                    string line = lines[y];

                    for (int x = 0; x < line.length; x++) {
                        int grid_x = paste_x + x;
                        int grid_y = paste_y + y;

                        // Check if we're still within grid bounds
                        if (grid_x >= 0 && grid_x < OrcaGrid.WIDTH &&
                            grid_y >= 0 && grid_y < OrcaGrid.HEIGHT) {
                            grid.set_char(grid_x, grid_y, line[x]);
                        }
                    }
                }

                print("Pasted text at %d,%d\n", paste_x, paste_y);

                // Update display
                drawing_area.queue_draw();
            } catch (Error e) {
                warning("Error pasting from clipboard: %s", e.message);
            }
        });
    }

    private void open_file() {
        var file_dialog = new Gtk.FileDialog();
        file_dialog.title = "Open ORCA File";
        var filter = new Gtk.FileFilter();
        filter.set_filter_name("ORCA Files");
        filter.add_pattern("*.orca");

        var filters = new GLib.ListStore(typeof (Gtk.FileFilter));
        filters.append(filter);
        file_dialog.filters = filters;

        file_dialog.open.begin(this, null, (obj, res) => {
            try {
                var file = file_dialog.open.end(res);
                load_orca_file(file);
                filename = file.get_path();
                drawing_area.queue_draw();
            } catch (Error e) {
                warning("Error opening file dialog: %s", e.message);
            }
        });
    }

    private void save_file() {
        // If we already have a valid filename that's not the default, use it
        if (filename != "untitled.orca") {
            var file = File.new_for_path(filename);
            save_orca_file(file);
            return;
        }

        // Otherwise open a dialog
        var file_dialog = new Gtk.FileDialog();
        file_dialog.title = "Save ORCA File";
        file_dialog.initial_name = filename;

        var filter = new Gtk.FileFilter();
        filter.set_filter_name("ORCA Files");
        filter.add_pattern("*.orca");

        var filters = new GLib.ListStore(typeof (Gtk.FileFilter));
        filters.append(filter);
        file_dialog.filters = filters;

        file_dialog.save.begin(this, null, (obj, res) => {
            try {
                var file = file_dialog.save.end(res);
                // Ensure filename has .orca extension
                if (!filename.down().has_suffix(".orca")) {
                    filename = filename + ".orca";
                    file = File.new_for_path(filename);
                    save_orca_file(file);
                }
                filename = file.get_path();
                drawing_area.queue_draw();
            } catch (Error e) {
                warning("Error opening save dialog: %s", e.message);
            }
        });
    }

    private void load_orca_file(File file) {
        try {
            // Clear the grid
            grid.clear();

            // Read the file
            uint8[] contents;
            file.load_contents(null, out contents, null);
            string text = (string) contents;

            // Split into lines
            string[] lines = text.split("\n");

            // Load into the grid, starting at position (0, 0)
            for (int y = 0; y < lines.length && y < OrcaGrid.HEIGHT; y++) {
                string line = lines[y];

                for (int x = 0; x < line.length && x < OrcaGrid.WIDTH; x++) {
                    grid.set_char(x, y, line[x]);
                }
            }

            print("Loaded file: %s\n", file.get_path());
            drawing_area.queue_draw();
        } catch (Error e) {
            warning("Error loading file: %s", e.message);
        }
    }

    private void save_orca_file(File file) {
        try {
            // Build the text representation of the grid
            StringBuilder sb = new StringBuilder();

            for (int y = 0; y < OrcaGrid.HEIGHT; y++) {
                for (int x = 0; x < OrcaGrid.WIDTH; x++) {
                    sb.append_c(grid.get_char(x, y));
                }

                // Add newline between rows (except the last row)
                if (y < OrcaGrid.HEIGHT - 1) {
                    sb.append_c('\n');
                }
            }

            // Write to file
            file.replace_contents(sb.str.data, null, false,
                                  FileCreateFlags.NONE, null, null);

            print("Saved file: %s\n", file.get_path());
        } catch (Error e) {
            warning("Error saving file: %s", e.message);
        }
    }

    // Add helper method to convert decimal to base-36
    private string int_to_base36(int value) {
        if (value < 0)return "0";
        if (value < 10)return value.to_string();
        if (value < 36)return ((char) ('a' + (value - 10))).to_string();
        return int_to_base36(value / 36) + int_to_base36(value % 36);
    }

    private bool on_key_pressed(uint keyval, uint keycode, Gdk.ModifierType state) {
        // Check for Ctrl key combinations
        bool ctrl_pressed = (state & Gdk.ModifierType.CONTROL_MASK) != 0;
        bool shift_pressed = (state & Gdk.ModifierType.SHIFT_MASK) != 0;

        if (is_editing_filename) {
            return handle_filename_key(keyval, keycode, state);
        }

        if (ctrl_pressed) {
            if (keyval == Gdk.Key.b || keyval == Gdk.Key.B) {
                if (shift_pressed) {
                    // Ctrl+Shift+B: Decrease BPM by 10
                    adjust_bpm(-10);
                } else {
                    // Ctrl+B: Increase BPM by 10
                    adjust_bpm(10);
                }
                return true;
            }

            switch (keyval) {
            case Gdk.Key.c:
                // Copy selection to clipboard
                copy_selection();
                return true;
            case Gdk.Key.v:
                // Paste from clipboard
                paste_from_clipboard();
                return true;
            case Gdk.Key.o:
                // Open file
                open_file();
                return true;
            case Gdk.Key.s:
                // Save file
                save_file();
                return true;
            case Gdk.Key.m:
                // Toggle MIDI output
                toggle_midi_output();
                return true;
            }
        }

        switch (keyval) {
        case Gdk.Key.Left:
            // Clear selection when using arrow keys
            clear_selection();
            cursor_x = (int) Math.fmax(0, cursor_x - 1);
            break;
        case Gdk.Key.Right:
            clear_selection();
            cursor_x = (int) Math.fmin(OrcaGrid.WIDTH - 1, cursor_x + 1);
            break;
        case Gdk.Key.Up:
            clear_selection();
            cursor_y = (int) Math.fmax(0, cursor_y - 1);
            break;
        case Gdk.Key.Down:
            clear_selection();
            cursor_y = (int) Math.fmin(OrcaGrid.HEIGHT - 1, cursor_y + 1);
            break;
        case Gdk.Key.BackSpace:
            if (has_selection) {
                // Delete the entire selection
                delete_selection();
            } else {
                // Delete character and move cursor back
                grid.set_char(cursor_x, cursor_y, '.');
                cursor_x = (int) Math.fmax(0, cursor_x - 1);
            }
            break;
        case Gdk.Key.Escape:
            // Clear selection if exists, otherwise clear grid
            if (has_selection) {
                clear_selection();
            } else {
                grid.clear();
            }
            break;
        default:
            // Only accept printable ASCII
            if (keyval >= 32 && keyval <= 126) {
                // Just place the character in the grid without any interpretation
                grid.set_char(cursor_x, cursor_y, (char) keyval);
                cursor_x = (int) Math.fmin(OrcaGrid.WIDTH - 1, cursor_x + 1);
            }
            break;
        }

        drawing_area.queue_draw();
        return true;
    }
}