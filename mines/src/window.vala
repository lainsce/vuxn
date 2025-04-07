public class MinesweeperWindow : Gtk.ApplicationWindow {
    // Game constants
    private const int TILE_SIZE = 16;
    private const int MARGIN = 16;
    private const int DIGIT_WIDTH = 16;
    private const int DIGIT_HEIGHT = 16;
    
    // Game variables
    private int rows = 8;
    private int cols = 8;
    private int mines = 10;
    private bool game_over = false;
    private bool first_click = true;
    private int remaining_tiles;
    private int timer_value = 0;
    private bool timer_running = false;
    
    // Game grid
    private bool[,] mine_grid;
    private int[,] number_grid;
    private bool[,] revealed_grid;
    private bool[,] flagged_grid;
    
    // UI elements
    private Gtk.Grid main_grid;
    private Gtk.DrawingArea game_area;
    private Gtk.DrawingArea top_panel;
    private int mines_left = 0;
    private bool reset_button_pressed = false;
    
    private Theme.Manager theme;
    
    public MinesweeperWindow(Gtk.Application app) {
        Object(
            application: app,
            title: "Mines",
            resizable: false
        );
        
        var _tmp = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        _tmp.visible = false;
        titlebar = _tmp;
        
        theme = Theme.Manager.get_default();
        theme.apply_to_display();
        setup_theme_management();
        theme.theme_changed.connect(() => {
            game_area.queue_draw();
            top_panel.queue_draw();
        });
        
        // Load CSS
        var provider = new Gtk.CssProvider();
        provider.load_from_resource("/com/example/mines/style.css");
        
        // Apply CSS to the app
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );
  
        // Initialize game state
        initialize_game();
        
        // Create UI
        create_ui();
        
        // Add UI to window with margins
        Gtk.Box outer_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        outer_box.append(create_titlebar());
        outer_box.append(main_grid);

        this.set_child(outer_box);
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
    
    private Gtk.Widget create_titlebar() {
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        // Create close button
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_bottom = 8;
        close_button.margin_top = 8;
        close_button.margin_start = 8;
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
    
    private void initialize_game() {
        // Initialize grids
        mine_grid = new bool[rows, cols];
        number_grid = new int[rows, cols];
        revealed_grid = new bool[rows, cols];
        flagged_grid = new bool[rows, cols];
        
        // Reset game state
        game_over = false;
        first_click = true;
        remaining_tiles = rows * cols - mines;
        mines_left = mines;
        timer_value = 0;
        timer_running = false;
    }
    
    private void create_ui() {
        main_grid = new Gtk.Grid();
        main_grid.margin_bottom = MARGIN;
        main_grid.margin_end = MARGIN;
        main_grid.margin_start = MARGIN;
        
        // Create top panel as a single drawing area
        int panel_width = 132;
        top_panel = new Gtk.DrawingArea() {
            content_width = 132,
            content_height = 36
        };
        
        top_panel.set_draw_func(draw_top_panel);
        
        // Add click handler for the reset button in the top panel
        var click_controller = new Gtk.GestureClick();
        click_controller.pressed.connect((n_press, x, y) => {
            // Check if click is in the reset button area (center of panel)
            int button_x = panel_width / 2 - DIGIT_HEIGHT / 2;
            int button_width = DIGIT_HEIGHT;
            
            if (x >= button_x && x < button_x + button_width) {
                reset_button_pressed = true;
                top_panel.queue_draw();
            }
        });
        
        click_controller.released.connect((n_press, x, y) => {
            if (reset_button_pressed) {
                // Reset the game if the button was pressed
                reset_button_pressed = false;
                initialize_game();
                game_area.queue_draw();
                top_panel.queue_draw();
            }
        });
        
        top_panel.add_controller(click_controller);
        
        // Create game area
        game_area = new Gtk.DrawingArea() {
            content_width = cols * TILE_SIZE,
            content_height = rows * TILE_SIZE + 4 // Bevels are drawn
        };
        game_area.set_draw_func(draw_game_area);
        
        // Add click handlers for game area
        var game_click_controller1 = new Gtk.GestureClick();
        game_click_controller1.set_button(1);
        game_click_controller1.pressed.connect(handle_game_click);
        game_area.add_controller(game_click_controller1);
        var game_click_controller2 = new Gtk.GestureClick();
        game_click_controller2.set_button(3);
        game_click_controller2.pressed.connect(handle_game_right_click);
        game_area.add_controller(game_click_controller2);
        
        // Add elements to main grid
        main_grid.attach(top_panel, 0, 0, 1, 1);
        main_grid.attach(game_area, 0, 1, 1, 1);
        
        // Add a bit of spacing between elements
        main_grid.row_spacing = MARGIN;
        
        // Start the timer update
        GLib.Timeout.add(1000, () => {
            if (timer_running) {
                timer_value++;
                if (timer_value > 999)
                    timer_value = 999;
                top_panel.queue_draw();
            }
            return true;
        });
    }
    
    private void handle_game_click(int n_press, double x, double y) {
        if (game_over)
            return;
            
        int row = (int)(y / TILE_SIZE);
        int col = (int)(x / TILE_SIZE);
        
        if (row < 0 || row >= rows || col < 0 || col >= cols)
            return;
            
        // Start timer on first click
        if (first_click) {
            place_mines(row, col);
            first_click = false;
            timer_value = 0;
            timer_running = true;
        }

        if (!flagged_grid[row, col]) {
            reveal_tile(row, col);
            check_win_condition();
        }
        
        game_area.queue_draw();
    }
    private void handle_game_right_click(int n_press, double x, double y) {
        if (game_over)
            return;
            
        int row = (int)(y / TILE_SIZE);
        int col = (int)(x / TILE_SIZE);
        
        if (row < 0 || row >= rows || col < 0 || col >= cols)
            return;

        if (!revealed_grid[row, col]) {
            flagged_grid[row, col] = !flagged_grid[row, col];
            if (flagged_grid[row, col])
                mines_left--;
            else
                mines_left++;
                
            top_panel.queue_draw();
        }
        
        game_area.queue_draw();
    }
    
    private void place_mines(int safe_row, int safe_col) {
        int mines_placed = 0;
        while (mines_placed < mines) {
            int row = GLib.Random.int_range(0, rows);
            int col = GLib.Random.int_range(0, cols);
            
            // Ensure we don't place a mine on first click or where a mine already exists
            if ((row != safe_row || col != safe_col) && !mine_grid[row, col]) {
                mine_grid[row, col] = true;
                mines_placed++;
                
                // Update neighboring tile numbers
                for (int dr = -1; dr <= 1; dr++) {
                    for (int dc = -1; dc <= 1; dc++) {
                        int nr = row + dr;
                        int nc = col + dc;
                        
                        if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
                            number_grid[nr, nc]++;
                        }
                    }
                }
            }
        }
    }
    
    private void reveal_tile(int row, int col) {
        if (revealed_grid[row, col] || flagged_grid[row, col] || row < 0 || row >= rows || col < 0 || col >= cols)
            return;
            
        revealed_grid[row, col] = true;
        remaining_tiles--;
        
        if (mine_grid[row, col]) {
            // Hit a mine - game over
            game_over = true;
            timer_running = false;
            top_panel.queue_draw();
            return;
        }
        
        if (number_grid[row, col] == 0) {
            // Auto-reveal neighboring tiles for zero-count tiles
            for (int dr = -1; dr <= 1; dr++) {
                for (int dc = -1; dc <= 1; dc++) {
                    if (dr != 0 || dc != 0) {
                        reveal_tile(row + dr, col + dc);
                    }
                }
            }
        }
    }
    
    private void check_win_condition() {
        if (remaining_tiles == 0) {
            game_over = true;
            timer_running = false;
            // All non-mine tiles are revealed - player wins
            mines_left = 0;
            top_panel.queue_draw();
        }
    }
    
    private void draw_game_area(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        cr.set_antialias(Cairo.Antialias.NONE);
        // Clear background with alpha from our palette
        MinesweeperUtils.set_color(cr, 4);
        cr.paint();
        
        // Draw sunken panel for the entire background
        MinesweeperUtils.draw_sunken_panel(cr, 0, 0, width, height);
        
        // Draw tiles
        for (int row = 0; row < rows; row++) {
            for (int col = 0; col < cols; col++) {
                int x = col * TILE_SIZE + 2;
                int y = row * TILE_SIZE + 2;
                
                if (!revealed_grid[row, col]) {
                    // Draw unrevealed tile (bevelled and raised)
                    MinesweeperUtils.draw_raised_tile(cr, x, y, TILE_SIZE, TILE_SIZE);
                    
                    // Draw flag if flagged
                    if (flagged_grid[row, col]) {
                        MinesweeperUtils.draw_flag(cr, x, y);
                    }
                } else {
                    // Draw revealed tile (flat with border)
                    MinesweeperUtils.draw_flat_tile(cr, x, y, TILE_SIZE, TILE_SIZE);
                    
                    // Draw content
                    if (mine_grid[row, col]) {
                        // Draw mine
                        MinesweeperUtils.draw_mine(cr, x, y);
                    } else if (number_grid[row, col] > 0) {
                        // Draw number
                        MinesweeperUtils.draw_number(cr, x, y, number_grid[row, col]);
                    }
                }
            }
        }
    }
    
    private void draw_top_panel(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        cr.set_antialias(Cairo.Antialias.NONE);
        // Draw sunken panel for the entire background
        MinesweeperUtils.draw_sunken_panel(cr, 0, 0, width, height);
        
        // Draw mine counter (left)
        int value = int.max(0, mines_left);
        value = int.min(999, value);
        MinesweeperUtils.draw_seven_segment_number(cr, value, 10, 10);
        
        // Draw face
        int face_x = width / 2 - 8;
        int face_y = height / 2 - 8;

        MinesweeperUtils.set_color(cr, 0);
        // Fill
        cr.rectangle(face_x + 5, face_y + 2, 6, 1);
        cr.rectangle(face_x + 3, face_y + 3, 10, 1);
        cr.rectangle(face_x + 2, face_y + 4, 12, 1);
        cr.rectangle(face_x + 2, face_y + 5, 12, 1);
        cr.rectangle(face_x + 2, face_y + 6, 12, 1);
        cr.rectangle(face_x + 2, face_y + 7, 12, 1);
        cr.rectangle(face_x + 2, face_y + 8, 12, 1);
        cr.rectangle(face_x + 2, face_y + 9, 12, 1);
        cr.rectangle(face_x + 2, face_y + 10, 12, 1);
        cr.rectangle(face_x + 2, face_y + 11, 12, 1);
        cr.rectangle(face_x + 3, face_y + 12, 10, 1);
        cr.rectangle(face_x + 5, face_y + 13, 6, 1);
        cr.fill();

        MinesweeperUtils.set_color(cr, 3); // Black
        // Border
        cr.rectangle(face_x + 5, face_y + 1, 6, 1);
        cr.rectangle(face_x + 3, face_y + 2, 2, 1);
        cr.rectangle(face_x + 11, face_y + 2, 2, 1);
        cr.rectangle(face_x + 2, face_y + 3, 1, 2);
        cr.rectangle(face_x + 13, face_y + 3, 1, 2);
        cr.rectangle(face_x + 1, face_y + 5, 1, 6);
        cr.rectangle(face_x + 14, face_y + 5, 1, 6);
        cr.rectangle(face_x + 2, face_y + 11, 1, 2);
        cr.rectangle(face_x + 13, face_y + 11, 1, 2);
        cr.rectangle(face_x + 3, face_y + 13, 2, 1);
        cr.rectangle(face_x + 11, face_y + 13, 2, 1);
        cr.rectangle(face_x + 5, face_y + 14, 6, 1);
        cr.fill();
        
        // Mouth
        if (game_over && !reset_button_pressed) {
            // Sad face
            // X-shaped eyes
            // Left eye X
            cr.rectangle(face_x + 4, face_y + 4, 1, 1);
            cr.rectangle(face_x + 5, face_y + 5, 1, 1);
            cr.rectangle(face_x + 6, face_y + 6, 1, 1);
            
            cr.rectangle(face_x + 4, face_y + 6, 1, 1);
            cr.rectangle(face_x + 5, face_y + 5, 1, 1);
            cr.rectangle(face_x + 6, face_y + 4, 1, 1);
            
            // Right eye X
            cr.rectangle(face_x + 9, face_y + 4, 1, 1);
            cr.rectangle(face_x + 10, face_y + 5, 1, 1);
            cr.rectangle(face_x + 11, face_y + 6, 1, 1);
            
            cr.rectangle(face_x + 9, face_y + 6, 1, 1);
            cr.rectangle(face_x + 10, face_y + 5, 1, 1);
            cr.rectangle(face_x + 11, face_y + 4, 1, 1);
            
            // Frown (curved line made of pixels)
            cr.rectangle(face_x + 4, face_y + 12, 1, 1);
            cr.rectangle(face_x + 5, face_y + 11, 1, 1);
            cr.rectangle(face_x + 6, face_y + 10, 4, 1);
            cr.rectangle(face_x + 11, face_y + 12, 1, 1);
            cr.rectangle(face_x + 10, face_y + 11, 1, 1);
            
            cr.fill();
        } else if (mines_left == 0) {
            // Cool face
            // Row 1
            cr.rectangle(face_x + 5, face_y + 1, 6, 1);
            // Row 2
            cr.rectangle(face_x + 3, face_y + 2, 2, 1);
            cr.rectangle(face_x + 11, face_y + 2, 2, 1);
            // Row 3
            cr.rectangle(face_x + 2, face_y + 3, 1, 1);
            cr.rectangle(face_x + 13, face_y + 3, 1, 1);
            // Row 4
            cr.rectangle(face_x + 2, face_y + 4, 1, 1);
            cr.rectangle(face_x + 13, face_y + 4, 1, 1);
            // Row 5
            cr.rectangle(face_x + 1, face_y + 5, 1, 1);
            cr.rectangle(face_x + 14, face_y + 5, 1, 1);
            // Row 6
            cr.rectangle(face_x + 1, face_y + 6, 1, 1);
            cr.rectangle(face_x + 5, face_y + 6, 1, 1);
            cr.rectangle(face_x + 10, face_y + 6, 1, 1);
            cr.rectangle(face_x + 14, face_y + 6, 1, 1);
            // Row 7
            cr.rectangle(face_x + 1, face_y + 7, 1, 1);
            cr.rectangle(face_x + 4, face_y + 7, 1, 1);
            cr.rectangle(face_x + 6, face_y + 7, 1, 1);
            cr.rectangle(face_x + 9, face_y + 7, 1, 1);
            cr.rectangle(face_x + 11, face_y + 7, 1, 1);
            cr.rectangle(face_x + 14, face_y + 7, 1, 1);
            // Row 8
            cr.rectangle(face_x + 1, face_y + 8, 1, 1);
            cr.rectangle(face_x + 14, face_y + 8, 1, 1);
            // Row 9
            cr.rectangle(face_x + 1, face_y + 9, 1, 1);
            cr.rectangle(face_x + 14, face_y + 9, 1, 1);
            // Row 10
            cr.rectangle(face_x + 1, face_y + 10, 1, 1);
            cr.rectangle(face_x + 6, face_y + 10, 1, 1);
            cr.rectangle(face_x + 9, face_y + 10, 1, 1);
            cr.rectangle(face_x + 14, face_y + 10, 1, 1);
            // Row 11
            cr.rectangle(face_x + 2, face_y + 11, 1, 1);
            cr.rectangle(face_x + 7, face_y + 11, 1, 1);
            cr.rectangle(face_x + 8, face_y + 11, 1, 1);
            cr.rectangle(face_x + 13, face_y + 11, 1, 1);
            // Row 12
            cr.rectangle(face_x + 2, face_y + 12, 1, 1);
            cr.rectangle(face_x + 13, face_y + 12, 1, 1);
            // Row 13
            cr.rectangle(face_x + 3, face_y + 13, 2, 1);
            cr.rectangle(face_x + 11, face_y + 13, 2, 1);
            // Row 14
            cr.rectangle(face_x + 5, face_y + 14, 6, 1);
            cr.fill();
        } else {
            // Happy face
            // Eyes (two simple dots)
            cr.rectangle(face_x + 4, face_y + 5, 2, 2);
            cr.rectangle(face_x + 10, face_y + 5, 2, 2);
            
            // Smile (curved line made of pixels)
            cr.rectangle(face_x + 4, face_y + 9, 1, 1);
            cr.rectangle(face_x + 5, face_y + 10, 1, 1);
            cr.rectangle(face_x + 6, face_y + 11, 4, 1);
            cr.rectangle(face_x + 11, face_y + 9, 1, 1);
            cr.rectangle(face_x + 10, face_y + 10, 1, 1);
            
            cr.fill();
        }
        
        cr.fill();
        
        // Draw timer (right)
        int timer_x = DIGIT_WIDTH * 5 + 10;
        MinesweeperUtils.draw_seven_segment_number(cr, timer_value, timer_x - DIGIT_WIDTH, 10);
    }
}