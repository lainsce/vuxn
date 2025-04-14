using Gtk;

public class DonsolWindow : Gtk.ApplicationWindow {
    private Gtk.DrawingArea game_area;
    private DonsolGame game;
    private bool in_title_screen;
    private int menu_selection;
    private int hovered_card;
    private string hovered_card_name = "";
    private uint game_over_timer_id;
    
    public DonsolWindow(Gtk.Application app) {
        Object(
            application: app,
            title: "Donsol",
            default_width: DonsolConstants.WIDTH * DonsolConstants.PIXEL_SCALE,
            resizable: false
        );
        
        set_titlebar(
            new Gtk.Box(Gtk.Orientation.VERTICAL, 0) {
                visible = false
            }
        );

        // Setup game
        game = new DonsolGame();
        
        // Initialize state variables
        in_title_screen = true;
        menu_selection = 0;
        hovered_card = -1;
        game_over_timer_id = 0;
        
        DonsolTheme.get_default().theme_manager.theme_changed.connect(() => {
            game_area.queue_draw();
        });
        
        // Setup UI
        var main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        
        main_box.append(create_titlebar());
        
        game_area = new Gtk.DrawingArea();
        game_area.set_draw_func(draw_game);
        game_area.set_content_width(DonsolConstants.WIDTH * DonsolConstants.PIXEL_SCALE);
        game_area.set_content_height(DonsolConstants.HEIGHT * DonsolConstants.PIXEL_SCALE);
        main_box.append(game_area);
        
        // Setup input handlers
        setup_input();
        
        // Add keyboard handler for theme toggle
        var theme_key = new Gtk.EventControllerKey();
        theme_key.key_pressed.connect((keyval, keycode, state) => {
            if (keyval == Gdk.Key.t && (state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                // Ctrl+T to toggle theme mode
                DonsolTheme.get_default().toggle_1bit_mode();
                return true;
            }
            return false;
        });
        main_box.add_controller(theme_key);
        
        // Set window content
        this.set_child(main_box);
    }
    
    // Title bar
    private Gtk.Widget create_titlebar() {
        // Create classic Mac-style title bar
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = DonsolConstants.WIDTH * DonsolConstants.PIXEL_SCALE;

        // Close button on the left
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;
        close_button.margin_top = 8;
        close_button.clicked.connect(() => {
            this.close();
        });

        title_bar.append(close_button);

        var winhandle = new Gtk.WindowHandle();
        winhandle.set_child(title_bar);

        // Main layout
        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        vbox.append(winhandle);

        return vbox;
    }
    
    // Setup input handlers
    private void setup_input() {
        // Mouse click handler
        var click = new Gtk.GestureClick();
        click.set_button(1);
        click.pressed.connect(on_click);
        game_area.add_controller(click);
        
        // Keyboard handler
        var key = new Gtk.EventControllerKey();
        key.key_pressed.connect(on_key);
        game_area.add_controller(key);
        
        // Add mouse motion tracking for hover detection
        var motion = new Gtk.EventControllerMotion();
        motion.motion.connect((x, y) => {
            if (!in_title_screen) {
                int vx = (int)(x / DonsolConstants.PIXEL_SCALE);
                int vy = (int)(y / DonsolConstants.PIXEL_SCALE);
                
                int old_hover = hovered_card;
                hovered_card = -1;
                
                for (int i = 0; i < 4; i++) {
                    int cx = DonsolConstants.CARD_X + i * (DonsolConstants.CARD_W + DonsolConstants.CARD_GAP);
                    if (vx >= cx && vx < cx + DonsolConstants.CARD_W && 
                        vy >= DonsolConstants.CARD_Y && vy < DonsolConstants.CARD_Y + DonsolConstants.CARD_H) {
                        if (i < game.current_room.cards.length && !game.current_room.cards[i].folded) {
                            hovered_card = i;
                            
                            // Get the card information for the hovered card
                            Card card = game.current_room.cards[i];
                            if (card.is_potion()) {
                                hovered_card_name = card.potion_name();
                            } else if (card.is_shield()) {
                                hovered_card_name = card.shield_name();
                            } else if (card.is_monster()) {
                                hovered_card_name = card.monster_name();
                            } else {
                                hovered_card_name = "";
                            }
                        } else {
                            hovered_card_name = "";
                        }
                        break;
                    }
                }
                
                if (old_hover != hovered_card || hovered_card == -1) {
                    // Clear hovered card name if not hovering any card
                    if (hovered_card == -1) {
                        hovered_card_name = "";
                    }
                    game_area.queue_draw();
                }
            } else {
                // Title screen hover detection for menu items
                int vx = (int)(x / DonsolConstants.PIXEL_SCALE);
                int vy = (int)(y / DonsolConstants.PIXEL_SCALE);
                
                int title_y = DonsolConstants.HEIGHT / 4;
                int menu_y = title_y + 40;
                int old_selection = menu_selection;
                
                for (int i = 0; i < 3; i++) {
                    if (vy >= menu_y + i * 20 - 10 && vy <= menu_y + i * 20 + 10 &&
                        vx >= DonsolConstants.WIDTH / 2 - 40 && vx <= DonsolConstants.WIDTH / 2 + 40) {
                        menu_selection = i;
                        if (old_selection != menu_selection) {
                            game_area.queue_draw();
                        }
                        break;
                    }
                }
            }
        });
        game_area.add_controller(motion);
    }
    
    // Handle mouse clicks
    private void on_click(int n_press, double x, double y) {
        int vx = (int)(x / DonsolConstants.PIXEL_SCALE);
        int vy = (int)(y / DonsolConstants.PIXEL_SCALE);
        
        if (in_title_screen) {
            // Title screen menu clicks
            int title_y = DonsolConstants.HEIGHT / 4;
            int menu_y = title_y + 40;
            for (int i = 0; i < 3; i++) {
                if (vy >= menu_y + i * 20 - 10 && vy <= menu_y + i * 20 + 10 &&
                    vx >= DonsolConstants.WIDTH / 2 - 40 && vx <= DonsolConstants.WIDTH / 2 + 40) {
                    start_game_with_difficulty(i);
                    return;
                }
            }
            return;
        }
        
        // Run button detection - updated bounding box
        if (vx >= DonsolConstants.WIDTH - 42 && vx < DonsolConstants.WIDTH - 10 && 
            vy >= DonsolConstants.STATUS_Y && vy < DonsolConstants.STATUS_Y + 16) {
            game.escape_room();
            check_game_conditions();
            game_area.queue_draw();
            return;
        }
        
        // Card detection
        for (int i = 0; i < 4; i++) {
            int cx = DonsolConstants.CARD_X + i * (DonsolConstants.CARD_W + DonsolConstants.CARD_GAP);
            if (vx >= cx && vx < cx + DonsolConstants.CARD_W && 
                vy >= DonsolConstants.CARD_Y && vy < DonsolConstants.CARD_Y + DonsolConstants.CARD_H) {
                
                if (i < game.current_room.cards.length && !game.current_room.cards[i].folded) {
                    game.take_card(i);
                    check_game_conditions();
                    game_area.queue_draw();
                }
                break;
            }
        }
    }
    
    // Handle keyboard input
    private bool on_key(uint keyval, uint keycode, Gdk.ModifierType state) {
        if (in_title_screen) {
            // Title screen navigation
            switch (keyval) {
                case Gdk.Key.Up:
                    menu_selection = (menu_selection + 2) % 3; // Wrap around
                    game_area.queue_draw();
                    return true;
                
                case Gdk.Key.Down:
                    menu_selection = (menu_selection + 1) % 3;
                    game_area.queue_draw();
                    return true;
                
                case Gdk.Key.Return:
                case Gdk.Key.space:
                    start_game_with_difficulty(menu_selection);
                    return true;
            }
            return false;
        }
        
        // Cards (1-4)
        if (keyval >= 49 && keyval <= 52) {
            int idx = (int)(keyval - 49);
            if (idx < game.current_room.cards.length && !game.current_room.cards[idx].folded) {
                game.take_card(idx);
                check_game_conditions();
                game_area.queue_draw();
                return true;
            }
        }
        
        // Run (Escape or R)
        if (keyval == Gdk.Key.Escape || keyval == 'r') {
            game.escape_room();
            check_game_conditions();
            game_area.queue_draw();
            return true;
        }
        
        return false;
    }
    
    // Start game with selected difficulty
    private void start_game_with_difficulty(int difficulty) {
        in_title_screen = false;
        
        // Convert menu selection to DonsolDifficulty
        DonsolDifficulty level = DonsolDifficulty.NORMAL;
        switch (difficulty) {
            case 0:
                level = DonsolDifficulty.EASY;
                break;
            case 1:
                level = DonsolDifficulty.NORMAL;
                break;
            case 2:
                level = DonsolDifficulty.HARD;
                break;
        }
        
        // Start new game with selected difficulty
        game.new_game(level);
        game_area.queue_draw();
    }
    
    // Check for game over or victory conditions
    private void check_game_conditions() {
        // Check for game over (player death)
        if (game.player.health <= 0) {
            // Set game over message
            game.status_message = "You have died! Game over.";
            
            // Cancel any existing timer
            if (game_over_timer_id > 0) {
                Source.remove(game_over_timer_id);
                game_over_timer_id = 0;
            }
            
            // Set up timer to return to title screen after 2 seconds
            game_over_timer_id = Timeout.add_seconds(2, () => {
                in_title_screen = true;
                game_over_timer_id = 0;
                game_area.queue_draw();
                return Source.REMOVE;
            });
        }
        
        // Check for victory (XP >= 100)
        if (game.player.xp >= DonsolConstants.MAX_XP) {
            // Set victory message
            game.status_message = "Victory! You've mastered the dungeon!";
            
            // Cancel any existing timer
            if (game_over_timer_id > 0) {
                Source.remove(game_over_timer_id);
                game_over_timer_id = 0;
            }
            
            // Set up timer to return to title screen after 2 seconds
            game_over_timer_id = Timeout.add_seconds(2, () => {
                in_title_screen = true;
                game_over_timer_id = 0;
                game_area.queue_draw();
                return Source.REMOVE;
            });
        }
    }
    
    // Main drawing function
    private void draw_game(Gtk.DrawingArea da, Cairo.Context cr, int width, int height) {
        // Scale up and disable antialiasing
        cr.scale(DonsolConstants.PIXEL_SCALE, DonsolConstants.PIXEL_SCALE);
        
        // Create renderer
        var r = new Renderer(cr);
        
        // Draw appropriate screen
        if (in_title_screen) {
            draw_title_screen(r);
        } else {
            // Draw black background
            r.rect(0, 0, DonsolConstants.WIDTH, DonsolConstants.HEIGHT, r.theme_black_r(), r.theme_black_g(), r.theme_black_b());
            
            // Draw game components
            draw_status_area(r);
            draw_cards(r);
            draw_message_area(r);
        }
    }
    
    // Draw title screen
    private void draw_title_screen(Renderer r) {
        // Draw background
        r.rect(0, 0, DonsolConstants.WIDTH, DonsolConstants.HEIGHT, 
               r.theme_black_r(), r.theme_black_g(), r.theme_black_b());
        
        // Draw title
        int title_y = DonsolConstants.HEIGHT / 4;
        r.text(DonsolConstants.WIDTH / 2 - 40, title_y, "DONSOL", 
               r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
        
        // Draw menu options
        int menu_y = title_y + 40;
        string[] options = {"Easy", "Normal", "Hard"};
        
        for (int i = 0; i < options.length; i++) {
            // Selection indicator
            if (i == menu_selection) {
                r.text(DonsolConstants.WIDTH / 2 - 50, menu_y + i * 20, ">", 
                       r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
            }
            
            // Menu option text
            r.text(DonsolConstants.WIDTH / 2 - 30, menu_y + i * 20, options[i], 
                   r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
        }
    }
    
    // Draw status area (HP/SP/XP)
    private void draw_status_area(Renderer r) {
        // HP bar
        if (DonsolTheme.get_default().theme_manager.color_mode == Theme.ColorMode.ONE_BIT) {
            r.status_bar(DonsolConstants.MARGIN, DonsolConstants.STATUS_Y, 
            (double)game.player.health / DonsolConstants.MAX_HEALTH,
            r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
        } else {
            r.status_bar(DonsolConstants.MARGIN, DonsolConstants.STATUS_Y, 
            (double)game.player.health / DonsolConstants.MAX_HEALTH,
            r.theme_red_r(), r.theme_red_g(), r.theme_red_b());
        }
        
        // Add potion indicator if player has potion sickness
        if (game.player.potion_sickness) {
            r.circle(DonsolConstants.MARGIN + 19, DonsolConstants.STATUS_Y + 13, 3, 
                     r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
        }
        
        // SP bar
        r.status_bar(DonsolConstants.MARGIN + 70, DonsolConstants.STATUS_Y,
            (double)game.player.shield_value / DonsolConstants.MAX_SHIELD,
            r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
        
        // XP bar
        r.status_bar(DonsolConstants.MARGIN + 140, DonsolConstants.STATUS_Y,
            (double)game.player.xp / DonsolConstants.MAX_XP,
            r.theme_gray_r(), r.theme_gray_g(), r.theme_gray_b());
        
        // Labels and values
        r.text(DonsolConstants.MARGIN, DonsolConstants.STATUS_Y + 10, "HP", 
               r.theme_gray_r(), r.theme_gray_g(), r.theme_gray_b());
        if (DonsolTheme.get_default().theme_manager.color_mode == Theme.ColorMode.ONE_BIT) {
               r.text(DonsolConstants.MARGIN + 25, DonsolConstants.STATUS_Y + 10, 
               "%02d".printf(game.player.health), 
               r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
        } else {
               r.text(DonsolConstants.MARGIN + 25, DonsolConstants.STATUS_Y + 10, 
               "%02d".printf(game.player.health), 
               r.theme_red_r(), r.theme_red_g(), r.theme_red_b());
        }
        
        r.text(DonsolConstants.MARGIN + 70, DonsolConstants.STATUS_Y + 10, "SP", 
               r.theme_gray_r(), r.theme_gray_g(), r.theme_gray_b());
        r.text(DonsolConstants.MARGIN + 95, DonsolConstants.STATUS_Y + 10, 
               "%02d".printf(game.player.shield_value), 
               r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
        
        r.text(DonsolConstants.MARGIN + 140, DonsolConstants.STATUS_Y + 10, "XP", 
               r.theme_gray_r(), r.theme_gray_g(), r.theme_gray_b());
        r.text(DonsolConstants.MARGIN + 165, DonsolConstants.STATUS_Y + 10, 
               "%02d".printf(game.player.xp), 
               r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
        
        // Run indicator with B inside circle and RUN text
        double r_color = game.can_escape && game.current_room.has_monsters() ? 
                        r.theme_red_r() : r.theme_gray_r();
        double g_color = game.can_escape && game.current_room.has_monsters() ? 
                        r.theme_red_g() : r.theme_gray_g();
        double b_color = game.can_escape && game.current_room.has_monsters() ? 
                        r.theme_red_b() : r.theme_gray_b();
                        
        double rf_color = game.can_escape && game.current_room.has_monsters() ? 
                        r.theme_white_r() : r.theme_black_r();
        double gf_color = game.can_escape && game.current_room.has_monsters() ? 
                        r.theme_white_g() : r.theme_black_g();
        double bf_color = game.can_escape && game.current_room.has_monsters() ? 
                        r.theme_white_b() : r.theme_black_b();

        // Background circle for the run button
        if (DonsolTheme.get_default().theme_manager.color_mode == Theme.ColorMode.ONE_BIT) {
            // In 1-bit mode, use white for the circle
            r.circle(DonsolConstants.WIDTH - 36, DonsolConstants.STATUS_Y + 6, 6, 
                r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
            
            // Draw B character on top
            r.text(DonsolConstants.WIDTH - 39, DonsolConstants.STATUS_Y + 3, "B", 
                r.theme_black_r(), r.theme_black_g(), r.theme_black_b());
            
            // Draw RUN text next to the circle
            r.text(DonsolConstants.WIDTH - 29, DonsolConstants.STATUS_Y + 3, "RUN", 
                r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
        } else {
            // In color mode, use the appropriate color
            r.circle(DonsolConstants.WIDTH - 36, DonsolConstants.STATUS_Y + 6, 6, 
                r_color, g_color, b_color);
            
            // Draw B character on top
            r.text(DonsolConstants.WIDTH - 39, DonsolConstants.STATUS_Y + 3, "B", 
                rf_color, gf_color, bf_color);
            
            // Draw RUN text next to the circle
            r.text(DonsolConstants.WIDTH - 29, DonsolConstants.STATUS_Y + 3, "RUN", 
                r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
        }

        // Monster name
        if (hovered_card_name != "") {
            // If a card is being hovered, show that card's info
            r.text(DonsolConstants.MARGIN, DonsolConstants.STATUS_Y + 24, 
                   hovered_card_name, 
                   r.theme_gray_r(), r.theme_gray_g(), r.theme_gray_b());
        } else if (game.current_monster_name != "") {
            // Otherwise, if a monster was encountered, show its name
            r.text(DonsolConstants.MARGIN, DonsolConstants.STATUS_Y + 24, 
                   game.current_monster_name, 
                   r.theme_gray_r(), r.theme_gray_g(), r.theme_gray_b());
        }
    }
    
    // Draw cards
    private void draw_cards(Renderer r) {
        for (int i = 0; i < 4; i++) {
            int x = DonsolConstants.CARD_X + i * (DonsolConstants.CARD_W + DonsolConstants.CARD_GAP);
            
            if (i < game.current_room.cards.length)
                r.card(x, DonsolConstants.CARD_Y, game.current_room.cards[i]);
            else
                r.card(x, DonsolConstants.CARD_Y, game.current_room.cards[54]);
                
            // Draw triangle indicator below hovered card
            if (i == hovered_card) {
                int base_x = x + DonsolConstants.CARD_W / 2 - 4; // Center the 8x8 grid
                int base_y = DonsolConstants.CARD_Y + DonsolConstants.CARD_H + 12;
                
                // Points at: (4,1); (5,1); (4,2); (5,2); (3,3); (4,3); (5,3); (6,3); (2,4); (3,4); (4,4);
                // (5,4); (6,4); (7,4); (2,5); (3,5); (6,5); (7,5); (1,6); (2,6); (7,6); (8,6)
                
                // Row 1
                r.pixel(base_x + 3, base_y + 0, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                r.pixel(base_x + 4, base_y + 0, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                
                // Row 2
                r.pixel(base_x + 3, base_y + 1, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                r.pixel(base_x + 4, base_y + 1, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                
                // Row 3
                r.pixel(base_x + 2, base_y + 2, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                r.pixel(base_x + 3, base_y + 2, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                r.pixel(base_x + 4, base_y + 2, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                r.pixel(base_x + 5, base_y + 2, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                
                // Row 4
                r.pixel(base_x + 1, base_y + 3, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                r.pixel(base_x + 2, base_y + 3, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                r.pixel(base_x + 3, base_y + 3, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                r.pixel(base_x + 4, base_y + 3, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                r.pixel(base_x + 5, base_y + 3, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                r.pixel(base_x + 6, base_y + 3, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                
                // Row 5
                r.pixel(base_x + 1, base_y + 4, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                r.pixel(base_x + 2, base_y + 4, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                r.pixel(base_x + 5, base_y + 4, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                r.pixel(base_x + 6, base_y + 4, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                
                // Row 6
                r.pixel(base_x + 0, base_y + 5, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                r.pixel(base_x + 1, base_y + 5, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                r.pixel(base_x + 6, base_y + 5, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                r.pixel(base_x + 7, base_y + 5, r.theme_white_r(), r.theme_white_g(), r.theme_white_b());
                
                
                // Show what card is hovered
                if (game.current_monster_name != "")
                r.text(DonsolConstants.MARGIN, DonsolConstants.STATUS_Y + 24, 
                       game.current_monster_name, 
                       r.theme_gray_r(), r.theme_gray_g(), r.theme_gray_b());
            }
        }
    }
    
    
    // Draw message area
    private void draw_message_area(Renderer r) {
        // Status message - adjusted vertical position
        string msg = game.status_message != "" ? game.status_message : "Select card.";
        r.text(DonsolConstants.WIDTH/2 - 120, DonsolConstants.HEIGHT - 16, msg, 
               r.theme_gray_r(), r.theme_gray_g(), r.theme_gray_b());
    }
}