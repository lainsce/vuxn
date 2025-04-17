// MenuComponent - manages application menus
public class MenuComponent : Gtk.Box {
    private VasuData chr_data;
    private VasuEditorView editor_view;
    private VasuNametableView nametable_view;
    private TopBarComponent top_bar;
    private Gtk.PopoverMenuBar menubar;
    
    // Signals that will be connected to main window
    public signal void request_save();
    public signal void request_open();
    public signal void request_save_mono();  // New signal for saving ICN
    public signal void request_open_mono();  // New signal for opening ICN
    public signal void request_rename();
    public signal void request_exit();
    public signal void tool_or_color_changed();
    
    // Action group for window actions
    private GLib.SimpleActionGroup action_group;
    
    private class ClipboardData {
        public int width;
        public int height;
        public int[,] pixels;
        
        public ClipboardData(int w, int h) {
            width = w;
            height = h;
            pixels = new int[w * 8, h * 8];
        }

         // Load data from a file - infer dimensions from file size
        public bool load_from_file(string filename) {
            try {
                var file = File.new_for_path(filename);
                if (!file.query_exists()) {
                    return false;
                }

                // Get file size to determine dimensions
                var file_info = file.query_info("*", FileQueryInfoFlags.NONE);
                int64 file_size = file_info.get_size();
                
                // Each 8x8 tile is 64 pixels, each pixel is 1 byte
                int total_pixels = (int)file_size;
                int total_tiles = total_pixels / 64;
                
                // Determine dimensions based on common tile arrangements
                if (total_tiles == 1) {
                    width = 1;
                    height = 1;
                } else if (total_tiles == 2) {
                    width = 2;
                    height = 1;
                } else if (total_tiles == 4) {
                    width = 2;
                    height = 2;
                } else {
                    // Try to make it as square as possible
                    int sqrt_tiles = (int)Math.sqrt(total_tiles);
                    if (sqrt_tiles * sqrt_tiles == total_tiles) {
                        width = sqrt_tiles;
                        height = sqrt_tiles;
                    } else {
                        // Find factors
                        for (int i = (int)Math.fmin(16, total_tiles); i >= 1; i--) {
                            if (total_tiles % i == 0) {
                                width = i;
                                height = total_tiles / i;
                                break;
                            }
                        }
                    }
                }
                
                // Recreate the pixel array with inferred dimensions
                pixels = new int[width * 8, height * 8];
                
                // Read all pixels
                var input = new DataInputStream(file.read());
                for (int y = 0; y < height * 8; y++) {
                    for (int x = 0; x < width * 8; x++) {
                        int color = input.read_byte();
                        pixels[x, y] = color;
                    }
                }
                
                input.close();
                return true;
            } catch (Error e) {
                print("Error loading clipboard data: %s\n", e.message);
                return false;
            }
        }
        
        // Save data to a file - just write the raw pixels
        public bool save_to_file(string filename) {
            try {
                var file = File.new_for_path(filename);
                var output = new DataOutputStream(file.replace(null, false, FileCreateFlags.REPLACE_DESTINATION));
                
                // Write all pixels directly, no header needed
                for (int y = 0; y < height * 8; y++) {
                    for (int x = 0; x < width * 8; x++) {
                        output.put_byte((uint8)pixels[x, y]);
                    }
                }
                
                output.close();
                return true;
            } catch (Error e) {
                print("Error saving clipboard data: %s\n", e.message);
                return false;
            }
        }
    }
    
    // Clipboard for copy/paste operations
    private ClipboardData? clipboard_data = null;
    
    public MenuComponent(VasuData data, VasuEditorView editor, VasuNametableView nametable, TopBarComponent top_bar) {
        Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        
        chr_data = data;
        editor_view = editor;
        nametable_view = nametable;
        this.top_bar = top_bar;

        margin_start = 4;
        margin_end = 8;
        margin_top = 3;
        margin_bottom = 0;
        
        // Create the action group first
        action_group = new GLib.SimpleActionGroup();
        
        // Setup the menu
        setup_menu();
    }
    
    private void setup_menu() {
        // Create a menu model
        var menu_model = create_menu_model();
        
        // Create the menu bar
        menubar = new Gtk.PopoverMenuBar.from_model(menu_model);
        menubar.add_css_class("menubar");
        
        // Set up the appearance
        menubar.halign = Gtk.Align.START;
        menubar.valign = Gtk.Align.START;
        
        // Add menubar to this component
        append(menubar);
        
        // Set up action handlers
        add_actions();
    }
    
    private GLib.MenuModel create_menu_model() {
        var menu_bar = new GLib.Menu();
        
        // File menu
        var file_menu = new GLib.Menu();
        file_menu.append("About", "win.about");
        file_menu.append("New", "win.new");
        file_menu.append("Rename", "win.rename");
        file_menu.append("Open", "win.open");
        file_menu.append("OpenMono", "win.open-mono");
        file_menu.append("Save", "win.save");
        file_menu.append("SaveMono", "win.save-mono");
        file_menu.append("Exit", "win.exit");
        menu_bar.append_submenu("File", file_menu);
        
        // Edit menu
        var edit_menu = new GLib.Menu();
        edit_menu.append("Copy", "win.copy");
        edit_menu.append("Paste", "win.paste");
        edit_menu.append("Cut", "win.cut");
        edit_menu.append("Erase", "win.erase");
        edit_menu.append("Invert", "win.invert");
        edit_menu.append("Colorize", "win.colorize");
        edit_menu.append("Horizontal", "win.mirror-h");
        edit_menu.append("Vertical", "win.mirror-v");
        menu_bar.append_submenu("Edit", edit_menu);
        
        // View menu
        var view_menu = new GLib.Menu();
        view_menu.append("Zoom", "win.zoom");
        menu_bar.append_submenu("View", view_menu);
        
        // Move menu
        var move_menu = new GLib.Menu();
        move_menu.append("Up", "win.arrow-up");
        move_menu.append("Down", "win.arrow-down");
        move_menu.append("Left", "win.arrow-left");
        move_menu.append("Right", "win.arrow-right");
        move_menu.append("Decr.H", "win.shift-h-r");
        move_menu.append("Incr.H", "win.shift-h");
        move_menu.append("Decr.V", "win.shift-v-r");
        move_menu.append("Incr.V", "win.shift-v");
        move_menu.append("Reset", "win.shift-reset");
        move_menu.append("SelectAll", "win.select-all");
        menu_bar.append_submenu("Move", move_menu);
        
        // Tool menu
        var tool_menu = new GLib.Menu();
        tool_menu.append("Brush", "win.tool-brush");
        tool_menu.append("Selector", "win.tool-cursor");
        tool_menu.append("Zoom", "win.tool-zoom");
        tool_menu.append("Background", "win.color-0");
        tool_menu.append("Color 1", "win.color-1");
        tool_menu.append("Color 2", "win.color-2");
        tool_menu.append("Color 3", "win.color-3");
        menu_bar.append_submenu("Tool", tool_menu);
        
        return menu_bar;
    }
    
    private void add_actions() {
        // File menu actions
        var about_action = new SimpleAction("about", null);
        about_action.activate.connect(() => {
            show_about_dialog();
        });
        action_group.add_action(about_action);
        
        var new_action = new SimpleAction("new", null);
        new_action.activate.connect(() => {
            editor_view.clear_editor();
            nametable_view.clear_canvas();
            chr_data.filename = "untitled10x10.chr";
        });
        action_group.add_action(new_action);
        
        var rename_action = new SimpleAction("rename", null);
        rename_action.activate.connect(() => {
            request_rename();
        });
        action_group.add_action(rename_action);
        
        var open_action = new SimpleAction("open", null);
        open_action.activate.connect(() => {
            request_open();
        });
        action_group.add_action(open_action);

        // New ICN open action
        var open_mono_action = new SimpleAction("open-mono", null);
        open_mono_action.activate.connect(() => {
            request_open_mono();
        });
        action_group.add_action(open_mono_action);
        
        var save_action = new SimpleAction("save", null);
        save_action.activate.connect(() => {
            request_save();
        });
        action_group.add_action(save_action);

        // New ICN save action
        var save_mono_action = new SimpleAction("save-mono", null);
        save_mono_action.activate.connect(() => {
            request_save_mono();
        });
        action_group.add_action(save_mono_action);
        
        var exit_action = new SimpleAction("exit", null);
        exit_action.activate.connect(() => {
            request_exit();
        });
        action_group.add_action(exit_action);
        
        // Edit menu actions
        var copy_action = new SimpleAction("copy", null);
        copy_action.activate.connect(() => {
            copy_selected_tile();
        });
        action_group.add_action(copy_action);
        
        var paste_action = new SimpleAction("paste", null);
        paste_action.activate.connect(() => {
            paste_to_selected_tile();
        });
        action_group.add_action(paste_action);
        
        var cut_action = new SimpleAction("cut", null);
        cut_action.activate.connect(() => {
            cut_selected_tile();
        });
        action_group.add_action(cut_action);
        
        var erase_action = new SimpleAction("erase", null);
        erase_action.activate.connect(() => {
            erase_selected_tile();
        });
        action_group.add_action(erase_action);
        
        var invert_action = new SimpleAction("invert", null);
        invert_action.activate.connect(() => {
            invert_selected_tile();
        });
        action_group.add_action(invert_action);
        
        var colorize_action = new SimpleAction("colorize", null);
        colorize_action.activate.connect(() => {
            colorize_selected_tile();
        });
        action_group.add_action(colorize_action);
        
        var mirror_h_action = new SimpleAction("mirror-h", null);
        mirror_h_action.activate.connect(() => {
            chr_data.mirror_horizontal = !chr_data.mirror_horizontal;
            editor_view.queue_draw();
        });
        action_group.add_action(mirror_h_action);
        
        var mirror_v_action = new SimpleAction("mirror-v", null);
        mirror_v_action.activate.connect(() => {
            chr_data.mirror_vertical = !chr_data.mirror_vertical;
            editor_view.queue_draw();
        });
        action_group.add_action(mirror_v_action);
        
        // View menu actions
        var zoom_action = new SimpleAction("zoom", null);
        zoom_action.activate.connect(() => {
            toggle_zoom();
        });
        action_group.add_action(zoom_action);
        
        var shift_h_action = new SimpleAction("shift-h", null);
        shift_h_action.activate.connect(() => {
            chr_data.shift_horizontal();
            editor_view.update_from_current_tile();
        });
        action_group.add_action(shift_h_action);
        
        var shift_v_action = new SimpleAction("shift-v", null);
        shift_v_action.activate.connect(() => {
            chr_data.shift_vertical();
            editor_view.update_from_current_tile();
        });
        action_group.add_action(shift_v_action);
        
        var shift_h_reverse_action = new SimpleAction("shift-h-r", null);
        shift_h_reverse_action.activate.connect(() => {
            chr_data.shift_horizontal_reverse();
            editor_view.update_from_current_tile();
        });
        action_group.add_action(shift_h_reverse_action);

        var shift_v_reverse_action = new SimpleAction("shift-v-r", null);
        shift_v_reverse_action.activate.connect(() => {
            chr_data.shift_vertical_reverse();
            editor_view.update_from_current_tile();
        });
        action_group.add_action(shift_v_reverse_action);
        
        var shift_reset_action = new SimpleAction("shift-reset", null);
        shift_reset_action.activate.connect(() => {
            chr_data.reset_shift();
            editor_view.update_from_current_tile();
            
            // Visual shifts in the top bar component (if any)
            if (top_bar != null) {
                top_bar.shift_x = 0;
                top_bar.shift_y = 0;
                
                if (top_bar.pre_view_area != null) {
                    top_bar.pre_view_area.queue_draw();
                }
            }
        });
        action_group.add_action(shift_reset_action);
        
        var select_all_action = new SimpleAction("select-all", null);
        select_all_action.activate.connect(() => {
            select_all_tiles();
        });
        action_group.add_action(select_all_action);
        
        // Tool menu actions
        var tool_brush_action = new SimpleAction("tool-brush", null);
        tool_brush_action.activate.connect(() => {
            chr_data.selected_tool = 0; // Pen tool
            tool_or_color_changed();
        });
        action_group.add_action(tool_brush_action);
        
        var tool_cursor_action = new SimpleAction("tool-cursor", null);
        tool_cursor_action.activate.connect(() => {
            chr_data.selected_tool = 1; // Cursor tool
            tool_or_color_changed();
        });
        action_group.add_action(tool_cursor_action);
        
        var tool_zoom_action = new SimpleAction("tool-zoom", null);
        tool_zoom_action.activate.connect(() => {
            chr_data.selected_tool = 2; // Zoom tool
            tool_or_color_changed();
        });
        action_group.add_action(tool_zoom_action);
        
        // Color selection actions
        var color_0_action = new SimpleAction("color-0", null);
        color_0_action.activate.connect(() => {
            chr_data.selected_color = 0; // Background color
            tool_or_color_changed();
        });
        action_group.add_action(color_0_action);
        
        var color_1_action = new SimpleAction("color-1", null);
        color_1_action.activate.connect(() => {
            chr_data.selected_color = 1; // Color 1
            tool_or_color_changed();
        });
        action_group.add_action(color_1_action);
        
        var color_2_action = new SimpleAction("color-2", null);
        color_2_action.activate.connect(() => {
            chr_data.selected_color = 2; // Color 2
            tool_or_color_changed();
        });
        action_group.add_action(color_2_action);
        
        var color_3_action = new SimpleAction("color-3", null);
        color_3_action.activate.connect(() => {
            chr_data.selected_color = 3; // Color 3
            tool_or_color_changed();
        });
        action_group.add_action(color_3_action);
        
        // In menu_component.vala - Add to the action_group section of add_actions()

        // Add arrow key actions for 1px movement
        var arrow_up_action = new SimpleAction("arrow-up", null);
        arrow_up_action.activate.connect(() => {
            // Only apply in zoom mode
            if (chr_data.zoom_level == 16 && editor_view != null) {
                // Move crosshair up by 1px
                if (editor_view.zoom_origin_y > 0) {
                    editor_view.zoom_origin_y--;
                    editor_view.queue_draw();
                }
            }
        });
        action_group.add_action(arrow_up_action);

        var arrow_down_action = new SimpleAction("arrow-down", null);
        arrow_down_action.activate.connect(() => {
            if (chr_data.zoom_level == 16 && editor_view != null) {
                // Move crosshair down by 1px (stay within bounds)
                if (editor_view.zoom_origin_y + 16 < editor_view.GRID_HEIGHT * 8) {
                    editor_view.zoom_origin_y++;
                    editor_view.queue_draw();
                }
            }
        });
        action_group.add_action(arrow_down_action);

        var arrow_left_action = new SimpleAction("arrow-left", null);
        arrow_left_action.activate.connect(() => {
            if (chr_data.zoom_level == 16 && editor_view != null) {
                // Move crosshair left by 1px
                if (editor_view.zoom_origin_x > 0) {
                    editor_view.zoom_origin_x--;
                    editor_view.queue_draw();
                }
            }
        });
        action_group.add_action(arrow_left_action);

        var arrow_right_action = new SimpleAction("arrow-right", null);
        arrow_right_action.activate.connect(() => {
            if (chr_data.zoom_level == 16 && editor_view != null) {
                // Move crosshair right by 1px (stay within bounds)
                if (editor_view.zoom_origin_x + 16 < editor_view.GRID_WIDTH * 8) {
                    editor_view.zoom_origin_x++;
                    editor_view.queue_draw();
                }
            }
        });
        action_group.add_action(arrow_right_action);
        
        // When the widget is attached to a window, insert the action group
        realize.connect(() => {
            var window = get_root() as Gtk.Window;
            if (window != null) {
                window.insert_action_group("win", action_group);
                add_keyboard_shortcuts(window);
            }
        });
    }
    
    private void add_keyboard_shortcuts(Gtk.Window window) {
        // Define keyboard shortcuts
        var app = window.get_application();
        if (app == null) return;
        
        // File menu shortcuts
        app.set_accels_for_action("win.new", {"<Control>n"});
        app.set_accels_for_action("win.open", {"<Control>o"});
        app.set_accels_for_action("win.save", {"<Control>s"});
        app.set_accels_for_action("win.rename", {"<Control>r"});
        app.set_accels_for_action("win.exit", {"<Control>q"});
        
        // Edit menu shortcuts
        app.set_accels_for_action("win.copy", {"<Control>c"});
        app.set_accels_for_action("win.paste", {"<Control>v"});
        app.set_accels_for_action("win.cut", {"<Control>x"});
        app.set_accels_for_action("win.erase", {"Backspace"});
        app.set_accels_for_action("win.invert", {"i"});
        app.set_accels_for_action("win.colorize", {"c"});
        
        // View menu shortcuts
        app.set_accels_for_action("win.arrow-up", {"Up"});
        app.set_accels_for_action("win.arrow-down", {"Down"});
        app.set_accels_for_action("win.arrow-left", {"Left"});
        app.set_accels_for_action("win.arrow-right", {"Right"});
        app.set_accels_for_action("win.select-all", {"<Control>a"});
        
        // Move menu shortcuts
        app.set_accels_for_action("win.shift-h", {"<Shift>Right"});
        app.set_accels_for_action("win.shift-h-r", {"<Shift>Left"});
        app.set_accels_for_action("win.shift-v", {"<Shift>Down"});
        app.set_accels_for_action("win.shift-v-r", {"<Shift>Up"});
        app.set_accels_for_action("win.shift-reset", {"Escape"});
    }
    
    // Implementation of menu actions
    
    private void show_about_dialog() {
        var about_dialog = new Gtk.AboutDialog();
        about_dialog.set_transient_for(get_root() as Gtk.Window);
        about_dialog.set_modal(true);
        
        about_dialog.program_name = "Vasu";
        about_dialog.version = "1.0";
        about_dialog.copyright = "© 2025";
        about_dialog.comments = "A tiny character/sprite editor";
        
        about_dialog.present();
    }
    
    private void copy_selected_tile() {
        // Get the selection bounds
        int sel_left, sel_top, sel_width, sel_height;
        editor_view.get_selection_bounds(out sel_left, out sel_top, out sel_width, out sel_height);
        
        // Create clipboard data to match selection size
        clipboard_data = new ClipboardData(sel_width, sel_height);
        
        // Copy all pixels from the selected region
        for (int y = 0; y < sel_height * 8; y++) {
            for (int x = 0; x < sel_width * 8; x++) {
                int editor_x = sel_left * 8 + x;
                int editor_y = sel_top * 8 + y;
                int color = editor_view.get_pixel(editor_x, editor_y);
                clipboard_data.pixels[x, y] = color;
            }
        }
        
        // Save to .snarf file
        string snarf_path = Path.build_filename(Environment.get_home_dir(), ".snarf");
        clipboard_data.save_to_file(snarf_path);
        
        print("Copied %dx%d tile selection to %s\n", sel_width, sel_height, snarf_path);
    }
    
    private void paste_to_selected_tile() {
        // First try to load from .snarf file if we don't have clipboard data
        if (clipboard_data == null) {
            clipboard_data = new ClipboardData(1, 1);
            string snarf_path = Path.build_filename(Environment.get_home_dir(), ".snarf");
            if (!clipboard_data.load_from_file(snarf_path)) {
                print("No clipboard data available.\n");
                return;
            }
        }
        
        // Get the current selection as paste target
        int sel_left, sel_top, sel_width, sel_height;
        editor_view.get_selection_bounds(out sel_left, out sel_top, out sel_width, out sel_height);
        
        // Get source dimensions
        int src_width = clipboard_data.width;
        int src_height = clipboard_data.height;
        int src_tiles = src_width * src_height;
        
        // Get target dimensions
        int tgt_width = sel_width;
        int tgt_height = sel_height;
        int tgt_tiles = tgt_width * tgt_height;
        
        print("Flex paste: source %dx%d (%d tiles) to target %dx%d (%d tiles)\n", 
              src_width, src_height, src_tiles, 
              tgt_width, tgt_height, tgt_tiles);
        
        // Initialize arrays to track source and target tiles
        int[] src_tile_indices = new int[src_tiles];
        int[] src_tile_x = new int[src_tiles];
        int[] src_tile_y = new int[src_tiles];
        
        int[] tgt_tile_indices = new int[tgt_tiles];
        int[] tgt_tile_x = new int[tgt_tiles];
        int[] tgt_tile_y = new int[tgt_tiles];
        
        // Fill source arrays
        for (int y = 0; y < src_height; y++) {
            for (int x = 0; x < src_width; x++) {
                int index = y * src_width + x;
                src_tile_indices[index] = index;
                src_tile_x[index] = x;
                src_tile_y[index] = y;
            }
        }
        
        // Fill target arrays
        for (int y = 0; y < tgt_height; y++) {
            for (int x = 0; x < tgt_width; x++) {
                int index = y * tgt_width + x;
                tgt_tile_indices[index] = index;
                tgt_tile_x[index] = x;
                tgt_tile_y[index] = y;
            }
        }
        
        // Determine how many tiles to actually paste
        int tiles_to_paste = int.min(src_tiles, tgt_tiles);
        
        // Track which tiles have been pasted
        bool[] pasted = new bool[tgt_tiles];
        for (int i = 0; i < tgt_tiles; i++) {
            pasted[i] = false;
        }
        
        // Intelligently map from source to target
        for (int i = 0; i < tiles_to_paste; i++) {
            // Get source tile coordinate
            int src_x = src_tile_x[i];
            int src_y = src_tile_y[i];
            
            // Try to match relative position
            // Calculate normalized position (0-1 range)
            float src_norm_x = (float)src_x / (src_width > 1 ? (src_width - 1) : 1);
            float src_norm_y = (float)src_y / (src_height > 1 ? (src_height - 1) : 1);
            
            // Map to target dimensions
            int mapped_x = (int)(src_norm_x * (tgt_width > 1 ? (tgt_width - 1) : 0));
            int mapped_y = (int)(src_norm_y * (tgt_height > 1 ? (tgt_height - 1) : 0));
            
            // Calculate target index
            int tgt_index = mapped_y * tgt_width + mapped_x;
            
            // If the target position is already taken, find nearest available space
            if (tgt_index >= tgt_tiles || pasted[tgt_index]) {
                // Find first available space with a simple approach
                for (int j = 0; j < tgt_tiles; j++) {
                    if (!pasted[j]) {
                        tgt_index = j;
                        break;
                    }
                }
            }
            
            // Mark as pasted
            if (tgt_index < tgt_tiles) {
                pasted[tgt_index] = true;
                
                // Get target coordinates
                int tgt_x = tgt_index % tgt_width;
                int tgt_y = tgt_index / tgt_width;
                
                // Paste the tile
                paste_single_tile(clipboard_data, src_x, src_y, sel_left + tgt_x, sel_top + tgt_y);
            }
        }
        
        print("Pasted %d tiles from %dx%d source to %dx%d target selection\n", 
              tiles_to_paste, src_width, src_height, tgt_width, tgt_height);
    }
    
    private void paste_single_tile(ClipboardData data, int src_tile_x, int src_tile_y, int dst_tile_x, int dst_tile_y) {
        for (int y = 0; y < 8; y++) {
            for (int x = 0; x < 8; x++) {
                // Calculate source position in clipboard
                int clip_x = src_tile_x * 8 + x;
                int clip_y = src_tile_y * 8 + y;
                
                // Calculate destination position in editor
                int editor_x = dst_tile_x * 8 + x;
                int editor_y = dst_tile_y * 8 + y;
                
                // Get color from clipboard
                int color = data.pixels[clip_x, clip_y];
                
                // Set pixel in editor
                editor_view.set_pixel(editor_x, editor_y, color);
                
                // If this is targeting the current CHR tile, update it directly
                if (dst_tile_x == editor_view.selected_tile_x && dst_tile_y == editor_view.selected_tile_y) {
                    chr_data.set_pixel(x, y, color);
                }
            }
        }
    }
    
    private void cut_selected_tile() {
        // First copy the tile
        copy_selected_tile();
        
        // Then clear it
        erase_selected_tile();
    }
    
    private void erase_selected_tile() {
        // Get the selection bounds
        int sel_left, sel_top, sel_width, sel_height;
        editor_view.get_selection_bounds(out sel_left, out sel_top, out sel_width, out sel_height);
        
        // Clear all tiles in the selection
        for (int tile_y = 0; tile_y < sel_height; tile_y++) {
            for (int tile_x = 0; tile_x < sel_width; tile_x++) {
                int editor_tile_x = sel_left + tile_x;
                int editor_tile_y = sel_top + tile_y;
                
                // Clear the tile
                for (int y = 0; y < 8; y++) {
                    for (int x = 0; x < 8; x++) {
                        int editor_x = editor_tile_x * 8 + x;
                        int editor_y = editor_tile_y * 8 + y;
                        editor_view.set_pixel(editor_x, editor_y, 0); // Set to background color
                    }
                }
                
                // If this is the currently active tile, update the CHR data as well
                if (editor_tile_x == editor_view.selected_tile_x && editor_tile_y == editor_view.selected_tile_y) {
                    chr_data.clear_tile();
                }
            }
        }
    }
    
    private void invert_selected_tile() {
        // Get the selected tile
        int tile_x = editor_view.selected_tile_x;
        int tile_y = editor_view.selected_tile_y;
        
        // Invert the selected tile
        for (int y = 0; y < 8; y++) {
            for (int x = 0; x < 8; x++) {
                int editor_x = tile_x * 8 + x;
                int editor_y = tile_y * 8 + y;
                int color = editor_view.get_pixel(editor_x, editor_y);
                
                // Invert the color (0->3, 1->2, 2->1, 3->0)
                int inverted_color = 3 - color;
                
                editor_view.set_pixel(editor_x, editor_y, inverted_color);
            }
        }
        
        // If this is the currently active tile, update the CHR data as well
        if (tile_x == 0 && tile_y == 0) {
            for (int y = 0; y < 8; y++) {
                for (int x = 0; x < 8; x++) {
                    int color = chr_data.get_pixel(x, y);
                    int inverted_color = 3 - color;
                    chr_data.set_pixel(x, y, inverted_color);
                }
            }
        }
    }
    
    private void colorize_selected_tile() {
        // Get the selected tile
        int tile_x = editor_view.selected_tile_x;
        int tile_y = editor_view.selected_tile_y;
        
        // Get the current selected color
        int new_color = chr_data.selected_color;
        
        // Colorize the selected tile
        for (int y = 0; y < 8; y++) {
            for (int x = 0; x < 8; x++) {
                int editor_x = tile_x * 8 + x;
                int editor_y = tile_y * 8 + y;
                int color = editor_view.get_pixel(editor_x, editor_y);
                
                // Only change non-transparent pixels
                if (color != 0) {
                    editor_view.set_pixel(editor_x, editor_y, new_color);
                }
            }
        }
        
        // If this is the currently active tile, update the CHR data as well
        if (tile_x == 0 && tile_y == 0) {
            for (int y = 0; y < 8; y++) {
                for (int x = 0; x < 8; x++) {
                    int color = chr_data.get_pixel(x, y);
                    if (color != 0) {
                        chr_data.set_pixel(x, y, new_color);
                    }
                }
            }
        }
    }
    
    private void toggle_zoom() {
        // Toggle zoom mode
        if (chr_data.zoom_level == 8) {
            chr_data.zoom_level = 16;
        } else {
            chr_data.zoom_level = 8;
        }
        
        // Force redraw
        editor_view.queue_draw();
    }
    
    private void select_all_tiles() {
        // This function would typically select all tiles for a multi-tile operation
        // For now, we'll just select the first tile
        editor_view.select_tile(0, 0);
    }
}