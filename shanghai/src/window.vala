using Gtk;
using Cairo;

namespace Shanghai {
    public class GameWindow : Gtk.ApplicationWindow {
        private DrawingArea drawing_area;
        private int matches;
        private int total_tiles;
        
        // Game state
        private Tile[,,] tiles;
        private Tile? selected_tile = null;
        private TileRenderer tile_renderer;
        private Gtk.Box main_box;

        // Theme-aware colors
        private Gdk.RGBA background_color;
        private Gdk.RGBA text_color;
        private Gdk.RGBA accent_color;
        private Gdk.RGBA selection_color;
        
        private Theme.Manager theme_manager;
        
        public GameWindow(Gtk.Application app) {
            Object(
                application: app,
                title: "Shanghai",
                default_width: NES_WIDTH,
                resizable: false
            );
            
            // Initialize the tile renderer
            tile_renderer = new TileRenderer();
            
            // Initialize colors from theme
            update_theme_colors();
            
            // Connect to theme changes
            var theme_manager = Theme.Manager.get_default();
            theme_manager.theme_changed.connect(update_theme_colors);
            
            initialize_ui();
            initialize_game();
        }
        
        // Updates theme-aware colors from the Theme Manager
        private void update_theme_colors() {
            var theme_manager = Theme.Manager.get_default();
            
            // Get colors from theme
            background_color = theme_manager.get_color("theme_bg");
            text_color = theme_manager.get_color("theme_fg");
            accent_color = theme_manager.get_color("theme_accent");
            selection_color = theme_manager.get_color("theme_selection");
            
            // Update the renderer with the new colors
            tile_renderer.update_colors_from_theme(background_color, text_color, accent_color, selection_color);
            
            // Request redraw
            if (drawing_area != null) {
                drawing_area.queue_draw();
            }
        }
        
        private void initialize_ui() {
            // Create header bar
            set_titlebar(new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                visible = false
            });
            
            // Create main box
            main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            
            main_box.append(create_titlebar ());
            
            drawing_area = new DrawingArea();
            drawing_area.set_draw_func(draw);
            drawing_area.set_content_width(NES_WIDTH);
            drawing_area.set_content_height(NES_HEIGHT);
            
            var gesture = new Gtk.GestureClick();
            gesture.set_button(1);
            gesture.pressed.connect(on_click);
            drawing_area.add_controller(gesture);
            
            // Add keyboard shortcut support
            var key_controller = new Gtk.EventControllerKey();
            key_controller.key_pressed.connect(on_key_pressed);
            main_box.add_controller(key_controller);
            
            main_box.append(drawing_area);
            set_child(main_box);
        }
        
        // Title bar
        private Gtk.Widget create_titlebar() {
            // Create classic Mac-style title bar
            var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            title_bar.width_request = NES_WIDTH;
            title_bar.add_css_class("title-bar");

            // Add event controller for right-click to toggle calendar visibility
            var click_controller = new Gtk.GestureClick();
            click_controller.set_button(1); // 1 = right mouse button
            click_controller.released.connect(() => {
                if (drawing_area.visible) {
                    drawing_area.visible = false;
                    drawing_area.content_height = 0;
                    default_height = 0;
                } else {
                    drawing_area.visible = true;
                    default_width = NES_HEIGHT;
                    drawing_area.content_height = NES_HEIGHT;
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

            var title_label = new Gtk.Label("Shanghai");
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
        
        private bool on_key_pressed(uint keyval, uint keycode, Gdk.ModifierType state) {
            if (keyval == Gdk.Key.r) {
                // Reset the game
                initialize_game();
                return true;
            }
            if (keyval == Gdk.Key.t && (state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                // Ctrl+T to toggle theme mode
                toggle_1bit_mode();
                return true;
            }

            
            return false;
        }
        
        public void toggle_1bit_mode() {
            if (theme_manager.color_mode == Theme.ColorMode.ONE_BIT) {
                theme_manager.color_mode = Theme.ColorMode.TWO_BIT;
            } else {
                theme_manager.color_mode = Theme.ColorMode.ONE_BIT;
            }
            theme_manager.save_color_mode();
        }
        
        private void initialize_game() {
            // Use the original size for simplicity
            tiles = new Tile[16, 16, 5];
            matches = 0;
            selected_tile = null;
            
            // Create standard layout
            create_layout();
            
            // Fill the layout with real Mahjong tiles
            TileFactory.fill_turtle_layout(ref tiles, true);
            
            // Count the total number of tiles
            total_tiles = count_total_tiles();
            
            // Queue redraw
            drawing_area.queue_draw();
        }
        
        private int count_total_tiles() {
            int count = 0;
            for (int z = 0; z < 5; z++) {
                for (int y = 0; y < 16; y++) {
                    for (int x = 0; x < 16; x++) {
                        if (tiles[x, y, z] != null && tiles[x, y, z].visible) {
                            count++;
                        }
                    }
                }
            }
            return count;
        }
        
        private void create_layout() {
            // Create the traditional Turtle layout based on the reference image
            
            // --- Layer 0 (bottom layer) - Base of the Turtle ---
            // Second row
            for (int x = 4; x < 12; x++) {
                add_placeholder(x, 1, 0);
            }
            
            // Third row
            for (int x = 2; x < 14; x++) {
                add_placeholder(x, 2, 0);
            }
            
            // Fourth row (front flippers)
            for (int x = 1; x < 15; x++) {
                add_placeholder(x, 3, 0);
            }
            
            // Middle rows (body)
            for (int y = 4; y < 8; y++) {
                for (int x = 2; x < 14; x++) {
                    add_placeholder(x, y, 0);
                }
            }
            
            // Back flippers
            for (int x = 1; x < 15; x++) {
                add_placeholder(x, 7, 0);
            }
            
            // Bottom rows (tail)
            for (int x = 2; x < 14; x++) {
                add_placeholder(x, 8, 0);
            }
            
            for (int x = 4; x < 12; x++) {
                add_placeholder(x, 9, 0);
            }
            
            // --- Layer 1 - Middle layer ---
            
            // Second row
            for (int x = 5; x < 11; x++) {
                add_placeholder(x, 1, 1);
            }
            
            // Third row
            for (int x = 3; x < 13; x++) {
                add_placeholder(x, 2, 1);
            }
            
            // Middle rows
            for (int y = 3; y < 8; y++) {
                for (int x = 3; x < 13; x++) {
                    add_placeholder(x, y, 1);
                }
            }
            
            // Bottom rows
            for (int x = 3; x < 13; x++) {
                add_placeholder(x, 8, 1);
            }
            
            // --- Layer 2 - Upper middle layer ---
            
            // Top part
            for (int x = 4; x < 12; x++) {
                add_placeholder(x, 2, 2);
            }
            
            // Middle parts
            for (int y = 3; y < 7; y++) {
                for (int x = 4; x < 12; x++) {
                    add_placeholder(x, y, 2);
                }
            }
            
            // Bottom part
            for (int x = 4; x < 12; x++) {
                add_placeholder(x, 7, 2);
            }
            
            // --- Layer 3 - Top layer ---
            
            // Middle rows only
            for (int y = 3; y < 6; y++) {
                for (int x = 5; x < 11; x++) {
                    add_placeholder(x, y, 3);
                }
            }
            
            // --- Layer 4 - Peak ---
            
            // Just a couple tiles at the very top
            add_placeholder(7, 4, 4);
            add_placeholder(8, 4, 4);
        }
        
        private void add_placeholder(int x, int y, int z) {
            // Create a placeholder tile - actual type will be filled in later
            tiles[x, y, z] = new Tile(x, y, z, TileCategory.DOTS, 1);
        }
        
        private bool is_free(Tile tile) {
            // A tile is free if:
            // 1. It has no tiles directly above it (on any higher layer)
            // 2. Either its left OR right side is completely clear

            if (tile == null || !tile.visible) {
                return false;
            }

            // Check for tiles above on ANY higher layer
            for (int z = tile.z + 1; z < 5; z++) {
                for (int y = 0; y < 16; y++) {
                    for (int x = 0; x < 16; x++) {
                        Tile? above = tiles[x, y, z];
                        
                        if (above != null && above.visible) {
                            // Check if the above tile overlaps with this one
                            // Tiles in Shanghai typically have a slight horizontal and vertical offset
                            // They block if their position overlaps with the current tile
                            if (Math.fabs(tile.x - x) < 1 && Math.fabs(tile.y - y) < 1) {
                                return false; // Blocked from above
                            }
                        }
                    }
                }
            }
            
            // If we get here, there are no tiles above blocking this one
            // Now check if either the left OR right side is free
            bool left_clear = true;
            bool right_clear = true;
            
            // Check all tiles on the same level for blocking
            for (int y = 0; y < 16; y++) {
                for (int x = 0; x < 16; x++) {
                    // Skip checking the tile against itself
                    if (x == tile.x && y == tile.y) continue;
                    
                    Tile? other = tiles[x, y, tile.z];
                    if (other != null && other.visible) {
                        // Check left side blocking
                        if (x < tile.x && Math.fabs(y - tile.y) < 1) {
                            left_clear = false;
                        }
                        
                        // Check right side blocking
                        if (x > tile.x && Math.fabs(y - tile.y) < 1) {
                            right_clear = false;
                        }
                        
                        // If both sides are blocked, no need to continue checking
                        if (!left_clear && !right_clear) {
                            return false;
                        }
                    }
                }
            }
            
            // A tile is free if either the left OR right side is completely clear
            return left_clear || right_clear;
        }
        
        private void on_click(int n_press, double x, double y) {
            // Convert coordinates to grid positions
            int grid_x = (int)(x / GRID_SIZE);
            int grid_y = (int)(y / GRID_SIZE);
            
            // Find the top-most visible tile at this position
            Tile? clicked_tile = find_top_tile_at(grid_x, grid_y);
            
            if (clicked_tile != null) {
                handle_tile_selection(clicked_tile);
                drawing_area.queue_draw();
                
                // Check if game is complete
                if (matches * 2 >= total_tiles) {
                    show_win_message();
                }
            }
        }
        
        private void show_win_message() {
            var dialog = new Gtk.MessageDialog(
                this,
                Gtk.DialogFlags.MODAL,
                Gtk.MessageType.INFO,
                Gtk.ButtonsType.OK,
                "Congratulations! You've completed the puzzle!"
            );
            dialog.secondary_text = "Press 'R' to start a new game.";
            dialog.response.connect ((response_id) => {
                dialog.destroy();
            });
            dialog.show();
        }
        
        private Tile? find_top_tile_at(int grid_x, int grid_y) {
            Tile? result = null;
            
            // Check from top to bottom layer (z=4 is top)
            for (int z = 4; z >= 0; z--) {
                // Get the pixel coordinates
                int pixel_x = grid_x * GRID_SIZE;
                int pixel_y = grid_y * GRID_SIZE;
                
                // Scan all tiles on this layer to find one under the cursor
                for (int y = 0; y < 16; y++) {
                    for (int x = 0; x < 16; x++) {
                        Tile? tile = tiles[x, y, z];
                        
                        if (tile != null && tile.visible) {
                            // Calculate the tile's pixel boundaries
                            int tile_left = x * GRID_SIZE * 2;
                            int tile_right = tile_left + TILE_WIDTH;
                            int tile_top = y * GRID_SIZE * 3;
                            int tile_bottom = tile_top + TILE_HEIGHT;
                            
                            // Check if the click is within the tile boundaries
                            if (pixel_x >= tile_left && pixel_x < tile_right &&
                                pixel_y >= tile_top && pixel_y < tile_bottom) {
                                
                                // Check if this is the highest free tile at this position
                                if (is_free(tile)) {
                                    // If we already found a tile and this one is higher z, or
                                    // we haven't found a tile yet, use this one
                                    if (result == null || tile.z > result.z) {
                                        result = tile;
                                    }
                                }
                            }
                        }
                    }
                }
                
                // If we found a free tile on this layer, stop looking at lower layers
                if (result != null) {
                    break;
                }
            }
            
            return result;
        }
        
        private void handle_tile_selection(Tile clicked_tile) {
            if (selected_tile == null) {
                // First tile selected
                selected_tile = clicked_tile;
            } else if (selected_tile == clicked_tile) {
                // Clicked the same tile twice - deselect it
                selected_tile = null;
            } else {
                // Check if the tiles match
                if (selected_tile.matches(clicked_tile)) {
                    // Match found, remove both tiles
                    selected_tile.visible = false;
                    clicked_tile.visible = false;
                    selected_tile = null;
                    matches++;
                } else {
                    // No match, update selection to new tile
                    selected_tile = clicked_tile;
                }
            }
        }
        
        private void draw(DrawingArea da, Context cr, int width, int height) {
            // Set antialias mode to NONE for pixel-perfect drawing
            cr.set_antialias(Cairo.Antialias.NONE);
            
            // Fill background with theme selection color
            cr.set_source_rgba(selection_color.red, selection_color.green, 
                              selection_color.blue, selection_color.alpha);
            cr.rectangle(0, 0, width, height);
            cr.fill();
            
            // Draw tiles from bottom to top
            for (int z = 0; z <= 4; z++) {
                for (int y = 0; y < 16; y++) {
                    for (int x = 0; x < 16; x++) {
                        Tile? tile = tiles[x, y, z];
                        if (tile != null && tile.visible) {
                            // Pass to the tile renderer but position according to grid
                            tile_renderer.draw_tile(
                                cr, 
                                tile, 
                                (x * GRID_SIZE * 2), // Use 2x grid spacing horizontally
                                (y * GRID_SIZE * 3), // Use 3x grid spacing vertically 
                                selected_tile == tile
                            );
                        }
                    }
                }
            }
            
            // Draw "M: XXX" text at bottom left to signify Matches done
            cr.set_source_rgba(background_color.red, background_color.green, background_color.blue, background_color.alpha);
            cr.select_font_face("Venice", FontSlant.NORMAL, FontWeight.NORMAL);
            cr.set_font_size(16);
            cr.move_to(12, NES_HEIGHT - 12);
            cr.show_text("M: %03d".printf(matches));
        }
    }

     // Factory to create tiles
    public class TileFactory {
        // Create a standard Mahjong tile set
        public static Tile[] create_standard_set() {
            // Create a list to hold all tiles
            var tiles = new Gee.ArrayList<Tile>();
            
            // Circles/Dots
            for (int v = 1; v <= 9; v++) {
                for (int i = 0; i < 4; i++) {
                    tiles.add(new Tile(0, 0, 0, TileCategory.DOTS, v));
                }
            }
            
            // Bamboo
            for (int v = 1; v <= 9; v++) {
                for (int i = 0; i < 4; i++) {
                    tiles.add(new Tile(0, 0, 0, TileCategory.BAMBOO, v));
                }
            }
            
            // Characters
            for (int v = 1; v <= 9; v++) {
                for (int i = 0; i < 4; i++) {
                    tiles.add(new Tile(0, 0, 0, TileCategory.CHARACTER, v));
                }
            }
            
            // Winds (East, South, West, North)
            for (int v = 1; v <= 4; v++) {
                for (int i = 0; i < 4; i++) {
                    tiles.add(new Tile(0, 0, 0, TileCategory.WIND, v));
                }
            }
            
            // Dragons (Red, Green, White)
            for (int v = 1; v <= 3; v++) {
                for (int i = 0; i < 4; i++) {
                    tiles.add(new Tile(0, 0, 0, TileCategory.DRAGON, v));
                }
            }
            
            return tiles.to_array();
        }
        
        // Helper function to check if a position has any existing neighbors
        private static bool has_neighbor(ref Tile[,,] layout, int x, int y, int z) {
            // Check the 8 surrounding positions
            for (int dx = -1; dx <= 1; dx++) {
                for (int dy = -1; dy <= 1; dy++) {
                    if (dx == 0 && dy == 0) continue; // Skip self
                    
                    int nx = x + dx;
                    int ny = y + dy;
                    
                    // Check bounds
                    if (nx >= 0 && nx < layout.length[0] && 
                        ny >= 0 && ny < layout.length[1]) {
                        if (layout[nx, ny, z] != null) {
                            return true;
                        }
                    }
                }
            }
            
            // Also check the position directly below and above
            if (z > 0 && layout[x, y, z-1] != null) return true;
            if (z < layout.length[2]-1 && layout[x, y, z+1] != null) return true;
            
            return false;
        }
        
        // Ensure we have an even distribution of tile types (each type needs a matching pair)
        private static void ensure_even_distribution(ref Tile[] tiles, int total_positions) {
            // Count the occurrences of each tile type
            var counts = new Gee.HashMap<string, int>();
            
            foreach (var tile in tiles) {
                string id = tile.get_id();
                if (counts.has_key(id)) {
                    counts[id] = counts[id] + 1;
                } else {
                    counts[id] = 1;
                }
            }
            
            // Fix any tile types with odd counts
            for (int i = 0; i < tiles.length; i++) {
                string id = tiles[i].get_id();
                if (counts[id] % 2 != 0) {
                    // Find another tile with odd count to pair with
                    for (int j = i + 1; j < tiles.length; j++) {
                        string other_id = tiles[j].get_id();
                        if (other_id != id && counts[other_id] % 2 != 0) {
                            // Set this tile to match the other
                            tiles[j].category = tiles[i].category;
                            tiles[j].tvalue = tiles[i].tvalue;
                            
                            // Update counts
                            counts.set(id, counts.get(id) + 1);
                            counts.set(other_id, counts.get(other_id) - 1);
                            
                            if (counts[other_id] == 0) {
                                counts.unset(other_id);
                            }
                            break;
                        }
                    }
                }
            }
        }
        
        // Create a randomized layout based on a tile distribution
        public static void fill_turtle_layout(ref Tile[,,] layout, bool ensure_solvable = true) {
            // Get a standard set of tiles
            var tiles = create_standard_set();
            
            // Count the total positions in the layout
            int total_positions = count_layout_positions(layout);
            
            // Make sure we have an even number of positions for pairs
            if (total_positions % 2 != 0) {
                stdout.printf("Warning: Layout has an odd number of positions (%d). Adding one more.\n", 
                              total_positions);
                // Find an empty spot to add a tile
                bool added = false;
                for (int z = 0; z < layout.length[2] && !added; z++) {
                    for (int y = 0; y < layout.length[1] && !added; y++) {
                        for (int x = 0; x < layout.length[0] && !added; x++) {
                            // If position is empty and has neighbors
                            if (layout[x, y, z] == null && has_neighbor(ref layout, x, y, z)) {
                                layout[x, y, z] = new Tile(x, y, z, TileCategory.DOTS, 1);
                                added = true;
                                total_positions++;
                            }
                        }
                    }
                }
            }
            
            // We need to ensure we have enough tiles
            // A standard set has 144 tiles, but we might need more
            if (total_positions > tiles.length) {
                stdout.printf("Layout needs %d tiles, creating more from standard set\n", 
                              total_positions);
                
                // Create duplicates as needed
                var new_tiles = new Tile[total_positions];
                for (int i = 0; i < tiles.length; i++) {
                    new_tiles[i] = tiles[i];
                }
                
                // Fill remaining positions with duplicates
                int base_set_size = tiles.length;
                for (int i = base_set_size; i < total_positions; i++) {
                    // Take a tile from the standard set and duplicate it
                    int source_idx = i % base_set_size;
                    var source_tile = tiles[source_idx];
                    new_tiles[i] = new Tile(0, 0, 0, source_tile.category, source_tile.tvalue);
                }
                
                tiles = new_tiles;
            }
            
            // Make sure we have an even number of each tile type
            ensure_even_distribution(ref tiles, total_positions);
            
            // Shuffle the tiles
            shuffle_tiles(ref tiles);
            
            // Track which tiles have been placed
            int tile_index = 0;
            
            // Fill the layout
            for (int z = 0; z < layout.length[2]; z++) {
                for (int y = 0; y < layout.length[1]; y++) {
                    for (int x = 0; x < layout.length[0]; x++) {
                        if (layout[x, y, z] != null) {
                            // Position has a tile placeholder, replace with a real tile
                            layout[x, y, z] = new Tile(
                                x, y, z, 
                                tiles[tile_index].category, 
                                tiles[tile_index].tvalue
                            );
                            tile_index++;
                            
                            if (tile_index >= tiles.length) {
                                stdout.printf("Warning: Ran out of tiles at position %d,%d,%d\n", x, y, z);
                                // Reset to the beginning if we run out
                                tile_index = 0;
                            }
                        }
                    }
                }
            }
            
            // If we need to ensure the puzzle is solvable, check and fix it
            if (ensure_solvable) {
                ensure_layout_is_solvable(ref layout);
            }
        }
        
        // Count total positions in the layout that have tiles
        private static int count_layout_positions(Tile[,,] layout) {
            int count = 0;
            for (int z = 0; z < layout.length[2]; z++) {
                for (int y = 0; y < layout.length[1]; y++) {
                    for (int x = 0; x < layout.length[0]; x++) {
                        if (layout[x, y, z] != null) {
                            count++;
                        }
                    }
                }
            }
            return count;
        }
        
        // Shuffle tiles randomly
        private static void shuffle_tiles(ref Tile[] tiles) {
            // Fisher-Yates shuffle
            for (int i = tiles.length - 1; i > 0; i--) {
                int j = Random.int_range(0, i + 1);
                var temp = tiles[i];
                tiles[i] = tiles[j];
                tiles[j] = temp;
            }
        }
        
        // Ensure the layout is solvable by making sure each tile has a match
        private static void ensure_layout_is_solvable(ref Tile[,,] layout) {
            // Track tiles by their type and value to ensure pairs
            var tile_map = new Gee.HashMap<string, Gee.ArrayList<Tile>>();
            
            // First pass: catalog all tiles
            for (int z = 0; z < layout.length[2]; z++) {
                for (int y = 0; y < layout.length[1]; y++) {
                    for (int x = 0; x < layout.length[0]; x++) {
                        var tile = layout[x, y, z];
                        if (tile != null && tile.visible) {
                            string id = tile.get_id();
                            if (!tile_map.has_key(id)) {
                                tile_map[id] = new Gee.ArrayList<Tile>();
                            }
                            tile_map[id].add(tile);
                        }
                    }
                }
            }
            
            // Second pass: ensure even numbers of each tile type
            var ids = new Gee.ArrayList<string>();
            foreach (var entry in tile_map.entries) {
                ids.add(entry.key);
            }
            
            // Process tiles with odd counts
            for (int i = 0; i < ids.size; i++) {
                string id = ids[i];
                var tiles = tile_map[id];
                
                if (tiles.size % 2 != 0) {
                    // Try to find another tile type with odd count
                    for (int j = i + 1; j < ids.size; j++) {
                        string other_id = ids[j];
                        var other_tiles = tile_map[other_id];
                        
                        if (other_tiles.size % 2 != 0) {
                            // Change the last tile of the other type to match this type
                            var tile_to_change = other_tiles[other_tiles.size - 1];
                            
                            // Parse the current ID
                            string[] parts = id.split("-");
                            TileCategory cat = (TileCategory)int.parse(parts[0]);
                            int value = int.parse(parts[1]);
                            
                            // Update the tile
                            tile_to_change.category = cat;
                            tile_to_change.tvalue = value;
                            
                            // Update the collections
                            other_tiles.remove(tile_to_change);
                            tiles.add(tile_to_change);
                            
                            break;
                        }
                    }
                }
            }
            
            // Final check - if any type still has an odd count, find any tile and change it
            foreach (var entry in tile_map.entries) {
                if (entry.value.size % 2 != 0) {
                    // Find a tile type with more than 2 tiles
                    foreach (var other_entry in tile_map.entries) {
                        if (other_entry.key != entry.key && other_entry.value.size >= 3) {
                            // Take one tile from this group
                            var tile_to_change = other_entry.value[other_entry.value.size - 1];
                            
                            // Parse the ID
                            string[] parts = entry.key.split("-");
                            TileCategory cat = (TileCategory)int.parse(parts[0]);
                            int value = int.parse(parts[1]);
                            
                            // Update the tile
                            tile_to_change.category = cat;
                            tile_to_change.tvalue = value;
                            
                            // Update the collections
                            other_entry.value.remove(tile_to_change);
                            entry.value.add(tile_to_change);
                            
                            break;
                        }
                    }
                }
            }
        }
    }
}