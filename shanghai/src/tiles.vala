using Cairo;

namespace Shanghai {
    // Enum for different tile categories
    public enum TileCategory {
        DOTS,       // Circles/Dots (1-9)
        BAMBOO,     // Bamboo (1-9)
        CHARACTER,  // Characters (1-9)
        WIND,       // Winds (East, South, West, North)
        DRAGON      // Dragons (Red, Green, White)
    }
    
    // Tile class - stores type and value
    public class Tile {
        public int x;
        public int y;
        public int z;
        public TileCategory category;
        public int tvalue;
        public bool visible;
        
        public Tile(int x, int y, int z, TileCategory category, int tvalue) {
            this.x = x;
            this.y = y;
            this.z = z;
            this.category = category;
            this.tvalue = tvalue;
            this.visible = true;
        }
        
        // Serializes tile to a unique identifier for comparison
        public string get_id() {
            return "%d-%d".printf((int)category, tvalue);
        }
        
        // Checks if two tiles match
        public bool matches(Tile other) {
            return this.category == other.category && this.tvalue == other.tvalue;
        }
    }

    // TileRenderer class - handles the drawing of tiles
    public class TileRenderer {
        // Theme-aware colors
        private Gdk.RGBA teal_color;
        private Gdk.RGBA blue_color;
        private Gdk.RGBA salmon_color;
        private Gdk.RGBA light_color;
        
        // Cached float color arrays for Cairo
        private float[] COLOR_TEAL = { 0.0f, 0.47f, 0.4f, 1.0f };
        private float[] COLOR_BLUE = { 0.2f, 0.0f, 0.73f, 1.0f };
        private float[] COLOR_SALMON = { 0.87f, 0.47f, 0.47f, 1.0f };
        private float[] COLOR_LIGHT = { 0.93f, 0.93f, 0.93f, 1.0f };
        
        // One-bit mode colors
        private float[] COLOR_BLACK = { 0.0f, 0.0f, 0.0f, 1.0f };
        private float[] COLOR_WHITE = { 1.0f, 1.0f, 1.0f, 1.0f };
        
        public TileRenderer() {
            // Initialize with default colors
            teal_color = new Gdk.RGBA();
            teal_color.red = 0.0f;
            teal_color.green = 0.47f;
            teal_color.blue = 0.4f;
            teal_color.alpha = 1.0f;
            
            blue_color = new Gdk.RGBA();
            blue_color.red = 0.2f;
            blue_color.green = 0.0f;
            blue_color.blue = 0.73f;
            blue_color.alpha = 1.0f;
            
            salmon_color = new Gdk.RGBA();
            salmon_color.red = 0.87f;
            salmon_color.green = 0.47f;
            salmon_color.blue = 0.47f;
            salmon_color.alpha = 1.0f;
            
            light_color = new Gdk.RGBA();
            light_color.red = 0.93f;
            light_color.green = 0.93f;
            light_color.blue = 0.93f;
            light_color.alpha = 1.0f;
        }
        
        // Update colors from theme
        public void update_colors_from_theme(Gdk.RGBA bg_color, Gdk.RGBA fg_color, Gdk.RGBA accent_color, Gdk.RGBA selection_color) {
            // Check if we're in one-bit mode
            var theme_manager = Theme.Manager.get_default();
            if (theme_manager.color_mode == Theme.ColorMode.ONE_BIT) {
                // One-bit mode (black and white)
                COLOR_LIGHT = COLOR_WHITE;
                COLOR_BLUE = COLOR_BLACK;
                COLOR_TEAL = COLOR_WHITE;
                COLOR_SALMON = COLOR_BLACK;
            } else {
                // Use theme colors for the game pieces
                // Map the theme colors to our game colors:
                // theme_bg -> background (handled in window)
                // theme_fg -> blue color (for main tile elements)
                // theme_accent -> teal color (for secondary elements)
                // We'll derive salmon and light from these
                
                // Blue color (from foreground)
                COLOR_BLUE[0] = (float)fg_color.red;
                COLOR_BLUE[1] = (float)fg_color.green;
                COLOR_BLUE[2] = (float)fg_color.blue;
                COLOR_BLUE[3] = (float)fg_color.alpha;
                
                // Teal color (from accent)
                COLOR_TEAL[0] = (float)accent_color.red;
                COLOR_TEAL[1] = (float)accent_color.green;
                COLOR_TEAL[2] = (float)accent_color.blue;
                COLOR_TEAL[3] = (float)accent_color.alpha;
                
                // Salmon color
                COLOR_SALMON[0] = (float)selection_color.red;
                COLOR_SALMON[1] = (float)selection_color.green;
                COLOR_SALMON[2] = (float)selection_color.blue;
                COLOR_SALMON[3] = (float)selection_color.alpha;
                
                // Light color
                COLOR_LIGHT[0] = (float)bg_color.red;
                COLOR_LIGHT[1] = (float)bg_color.green;
                COLOR_LIGHT[2] = (float)bg_color.blue;
                COLOR_LIGHT[3] = (float)bg_color.alpha;
            }
            
            // Update the Gdk.RGBA objects for other methods that might need them
            teal_color.red = COLOR_TEAL[0];
            teal_color.green = COLOR_TEAL[1];
            teal_color.blue = COLOR_TEAL[2];
            teal_color.alpha = COLOR_TEAL[3];
            
            blue_color.red = COLOR_BLUE[0];
            blue_color.green = COLOR_BLUE[1];
            blue_color.blue = COLOR_BLUE[2];
            blue_color.alpha = COLOR_BLUE[3];
            
            salmon_color.red = COLOR_SALMON[0];
            salmon_color.green = COLOR_SALMON[1];
            salmon_color.blue = COLOR_SALMON[2];
            salmon_color.alpha = COLOR_SALMON[3];
            
            light_color.red = COLOR_LIGHT[0];
            light_color.green = COLOR_LIGHT[1];
            light_color.blue = COLOR_LIGHT[2];
            light_color.alpha = COLOR_LIGHT[3];
        }
        
        // Draw a complete tile with background, shadow, and pattern
        public void draw_tile(Context cr, Tile tile, int x, int y, bool selected = false) {
            // Draw shadow (shifted right and down)
            set_color(cr, COLOR_BLUE);
            draw_rounded_rect(cr, x + 1, y + 4, TILE_WIDTH, TILE_HEIGHT);
            draw_rounded_rect(cr, x - 1, y - 1, TILE_WIDTH, TILE_HEIGHT);
            
            // Draw tile background
            set_color(cr, COLOR_LIGHT);
            draw_rounded_rect(cr, x, y, TILE_WIDTH, TILE_HEIGHT);
            
            // Draw tile content based on category and value
            draw_tile_content(cr, tile.category, tile.tvalue, x, y, selected);
            
            // Highlight selected tile
            if (selected) {
                // Draw shadow (shifted right and down)
                set_color(cr, COLOR_LIGHT);
                draw_rounded_rect(cr, x + 1, y + 4, TILE_WIDTH, TILE_HEIGHT);
                draw_rounded_rect(cr, x - 1, y - 1, TILE_WIDTH, TILE_HEIGHT);

                // Draw tile background
                set_color(cr, COLOR_BLUE);
                draw_rounded_rect(cr, x, y, TILE_WIDTH, TILE_HEIGHT);
                
                // Draw tile content based on category and value
                draw_tile_content(cr, tile.category, tile.tvalue, x, y, selected);
            }
        }
        
        // Draw the inner content of the tile based on its type and value
        private void draw_tile_content(Context cr, TileCategory category, int tvalue, int x, int y, bool selected) {
            // Usable drawing area after accounting for borders
            int inner_x = x + 3;
            int inner_y = y + 4;
            
            switch (category) {
                case TileCategory.DOTS:
                    draw_dots_tile(cr, tvalue, inner_x, inner_y, selected);
                    break;
                    
                case TileCategory.BAMBOO:
                    draw_bamboo_tile(cr, tvalue, inner_x, inner_y, selected);
                    break;
                    
                case TileCategory.CHARACTER:
                    draw_character_tile(cr, tvalue, inner_x, inner_y, selected);
                    break;
                    
                case TileCategory.WIND:
                    draw_wind_tile(cr, tvalue, inner_x, inner_y, selected);
                    break;
                    
                case TileCategory.DRAGON:
                    draw_dragon_tile(cr, tvalue, inner_x, inner_y, selected);
                    break;
            }
        }
        
        // Draw dots/circles tiles (1-9)
        private void draw_dots_tile(Context cr, int tvalue, int inner_x, int inner_y, bool selected) {
            if (selected) {
                set_color(cr, COLOR_LIGHT);
            } else {
                set_color(cr, COLOR_BLUE);
            }
            
            switch (tvalue) {
                case 1: // One dot in the center
                    draw_dot(cr, inner_x + 5, inner_y + 8, 2);
                    break;
                    
                case 2: // Two dots diagonal
                    draw_dot(cr, inner_x + 3, inner_y + 5, 1);
                    draw_dot(cr, inner_x + 7, inner_y + 11, 1);
                    break;
                    
                case 3: // Three dots diagonal
                    draw_dot(cr, inner_x + 2, inner_y + 4, 1);
                    draw_dot(cr, inner_x + 5, inner_y + 8, 1);
                    draw_dot(cr, inner_x + 8, inner_y + 12, 1);
                    break;
                    
                case 4: // Four dots in corners
                    draw_dot(cr, inner_x + 2, inner_y + 4, 1);
                    draw_dot(cr, inner_x + 8, inner_y + 4, 1);
                    draw_dot(cr, inner_x + 2, inner_y + 12, 1);
                    draw_dot(cr, inner_x + 8, inner_y + 12, 1);
                    break;
                    
                case 5: // Five dots (four in corners + center)
                    draw_dot(cr, inner_x + 2, inner_y + 4, 1);
                    draw_dot(cr, inner_x + 8, inner_y + 4, 1);
                    draw_dot(cr, inner_x + 5, inner_y + 8, 1);
                    draw_dot(cr, inner_x + 2, inner_y + 12, 1);
                    draw_dot(cr, inner_x + 8, inner_y + 12, 1);
                    break;
                    
                case 6: // Six dots (two rows of three)
                    draw_dot(cr, inner_x + 2, inner_y + 4, 1);
                    draw_dot(cr, inner_x + 5, inner_y + 4, 1);
                    draw_dot(cr, inner_x + 8, inner_y + 4, 1);
                    draw_dot(cr, inner_x + 2, inner_y + 12, 1);
                    draw_dot(cr, inner_x + 5, inner_y + 12, 1);
                    draw_dot(cr, inner_x + 8, inner_y + 12, 1);
                    break;
                    
                case 7: // Seven dots (six + one in center)
                    draw_dot(cr, inner_x + 2, inner_y + 4, 1);
                    draw_dot(cr, inner_x + 5, inner_y + 4, 1);
                    draw_dot(cr, inner_x + 8, inner_y + 4, 1);
                    draw_dot(cr, inner_x + 5, inner_y + 8, 1);
                    draw_dot(cr, inner_x + 2, inner_y + 12, 1);
                    draw_dot(cr, inner_x + 5, inner_y + 12, 1);
                    draw_dot(cr, inner_x + 8, inner_y + 12, 1);
                    break;
                    
                case 8: // Eight dots (three rows)
                    draw_dot(cr, inner_x + 2, inner_y + 4, 1);
                    draw_dot(cr, inner_x + 5, inner_y + 4, 1);
                    draw_dot(cr, inner_x + 8, inner_y + 4, 1);
                    draw_dot(cr, inner_x + 2, inner_y + 8, 1);
                    draw_dot(cr, inner_x + 8, inner_y + 8, 1);
                    draw_dot(cr, inner_x + 2, inner_y + 12, 1);
                    draw_dot(cr, inner_x + 5, inner_y + 12, 1);
                    draw_dot(cr, inner_x + 8, inner_y + 12, 1);
                    break;
                    
                case 9: // Nine dots (3x3 grid)
                    for (int row = 0; row < 3; row++) {
                        for (int col = 0; col < 3; col++) {
                            draw_dot(cr, inner_x + 2 + col * 3, 
                                     inner_y + 4 + row * 4, 1);
                        }
                    }
                    break;
                    
                default: // Fallback to a single dot
                    draw_dot(cr, inner_x + 5, inner_y + 8, 2);
                    break;
            }
        }
        
        // Helper to draw a single dot
        private void draw_dot(Context cr, int x, int y, int size) {
            cr.rectangle(x, y, size, size);
            cr.fill();
        }
        
        // Draw bamboo tiles (1-9)
        private void draw_bamboo_tile(Context cr, int tvalue, int inner_x, int inner_y, bool selected) {
            if (selected) {
                set_color(cr, COLOR_SALMON);
            } else {
                set_color(cr, COLOR_TEAL);
            }
            
            switch (tvalue) {
                case 1: // One bamboo (special - often a bird)
                    // Simplified bird shape using rectangles
                    cr.rectangle(inner_x + 4, inner_y + 5, 3, 1); // Head
                    cr.fill();
                    cr.rectangle(inner_x + 3, inner_y + 6, 5, 3); // Body
                    cr.fill();
                    cr.rectangle(inner_x + 5, inner_y + 9, 1, 2); // Tail
                    cr.fill();
                    break;
                    
                case 2: // Two bamboo
                    draw_bamboo_stalk(cr, inner_x + 3, inner_y + 4);
                    draw_bamboo_stalk(cr, inner_x + 7, inner_y + 4);
                    break;
                    
                case 3: // Three bamboo
                    draw_bamboo_stalk(cr, inner_x + 2, inner_y + 4);
                    draw_bamboo_stalk(cr, inner_x + 5, inner_y + 4);
                    draw_bamboo_stalk(cr, inner_x + 8, inner_y + 4);
                    break;
                    
                case 4: // Four bamboo
                    draw_bamboo_stalk(cr, inner_x + 2, inner_y + 4);
                    draw_bamboo_stalk(cr, inner_x + 6, inner_y + 4);
                    draw_bamboo_stalk(cr, inner_x + 2, inner_y + 9);
                    draw_bamboo_stalk(cr, inner_x + 6, inner_y + 9);
                    break;
                    
                case 5: // Five bamboo (four + one in center)
                    draw_bamboo_stalk(cr, inner_x + 2, inner_y + 4);
                    draw_bamboo_stalk(cr, inner_x + 7, inner_y + 4);
                    draw_bamboo_stalk(cr, inner_x + 5, inner_y + 7);
                    draw_bamboo_stalk(cr, inner_x + 2, inner_y + 10);
                    draw_bamboo_stalk(cr, inner_x + 7, inner_y + 10);
                    break;
                    
                case 6: // Six bamboo (two rows of three)
                    draw_bamboo_stalk(cr, inner_x + 2, inner_y + 4);
                    draw_bamboo_stalk(cr, inner_x + 5, inner_y + 4);
                    draw_bamboo_stalk(cr, inner_x + 8, inner_y + 4);
                    draw_bamboo_stalk(cr, inner_x + 2, inner_y + 9);
                    draw_bamboo_stalk(cr, inner_x + 5, inner_y + 9);
                    draw_bamboo_stalk(cr, inner_x + 8, inner_y + 9);
                    break;
                    
                case 7: // Seven bamboo (six + one)
                    draw_bamboo_stalk(cr, inner_x + 2, inner_y + 3);
                    draw_bamboo_stalk(cr, inner_x + 5, inner_y + 3);
                    draw_bamboo_stalk(cr, inner_x + 8, inner_y + 3);
                    draw_bamboo_stalk(cr, inner_x + 5, inner_y + 6);
                    draw_bamboo_stalk(cr, inner_x + 2, inner_y + 9);
                    draw_bamboo_stalk(cr, inner_x + 5, inner_y + 9);
                    draw_bamboo_stalk(cr, inner_x + 8, inner_y + 9);
                    break;
                    
                case 8: // Eight bamboo
                    for (int i = 0; i < 8; i++) {
                        int row = i / 4;
                        int col = i % 4;
                        draw_bamboo_stalk(cr, inner_x + 2 + col * 2, inner_y + 4 + row * 6);
                    }
                    break;
                    
                case 9: // Nine bamboo (3x3 grid)
                    for (int row = 0; row < 3; row++) {
                        for (int col = 0; col < 3; col++) {
                            draw_bamboo_stalk(cr, inner_x + 2 + col * 3, 
                                             inner_y + 3 + row * 4);
                        }
                    }
                    break;
                    
                default: // Fallback to three bamboo
                    draw_bamboo_stalk(cr, inner_x + 2, inner_y + 4);
                    draw_bamboo_stalk(cr, inner_x + 5, inner_y + 4);
                    draw_bamboo_stalk(cr, inner_x + 8, inner_y + 4);
                    break;
            }
        }
        
        // Helper to draw a bamboo stalk
        private void draw_bamboo_stalk(Context cr, int x, int y) {
            cr.rectangle(x, y, 1, 6); // Stem - 1px thick line
            cr.fill();
            cr.rectangle(x - 1, y + 1, 3, 1); // Top node
            cr.fill();
            cr.rectangle(x - 1, y + 3, 3, 1); // Middle node
            cr.fill();
            cr.rectangle(x - 1, y + 5, 3, 1); // Bottom node
            cr.fill();
        }
        
        // Draw character tiles (1-9)
        private void draw_character_tile(Context cr, int tvalue, int inner_x, int inner_y, bool selected) {
            if (selected) {
                set_color(cr, COLOR_TEAL);
            } else {
                set_color(cr, COLOR_SALMON);
            }
            
            switch (tvalue) {
                case 1: // 一 (one)
                    cr.rectangle(inner_x + 2, inner_y + 8, 7, 1);
                    cr.fill();
                    break;
                    
                case 2: // 二 (two)
                    cr.rectangle(inner_x + 2, inner_y + 5, 7, 1);
                    cr.fill();
                    cr.rectangle(inner_x + 2, inner_y + 10, 7, 1);
                    cr.fill();
                    break;
                    
                case 3: // 三 (three)
                    cr.rectangle(inner_x + 2, inner_y + 4, 7, 1);
                    cr.fill();
                    cr.rectangle(inner_x + 2, inner_y + 8, 7, 1);
                    cr.fill();
                    cr.rectangle(inner_x + 2, inner_y + 12, 7, 1);
                    cr.fill();
                    break;
                    
                case 4: // 四 (four)
                    // Horizontal strokes
                    cr.rectangle(inner_x + 2, inner_y + 4, 7, 1);
                    cr.fill();
                    // Vertical enclosure
                    cr.rectangle(inner_x + 2, inner_y + 4, 1, 8);
                    cr.fill();
                    cr.rectangle(inner_x + 8, inner_y + 4, 1, 8);
                    cr.fill();
                    // Bottom horizontal
                    cr.rectangle(inner_x + 2, inner_y + 12, 7, 1);
                    cr.fill();
                    break;
                    
                case 5: // 五 (five)
                    // Top horizontal
                    cr.rectangle(inner_x + 2, inner_y + 4, 7, 1);
                    cr.fill();
                    // Middle horizontal
                    cr.rectangle(inner_x + 2, inner_y + 8, 7, 1);
                    cr.fill();
                    // Bottom horizontal
                    cr.rectangle(inner_x + 2, inner_y + 12, 7, 1);
                    cr.fill();
                    // Vertical sides
                    cr.rectangle(inner_x + 2, inner_y + 4, 1, 8);
                    cr.fill();
                    cr.rectangle(inner_x + 8, inner_y + 4, 1, 8);
                    cr.fill();
                    break;
                    
                case 6: // 六 (six)
                    // Top
                    cr.rectangle(inner_x + 2, inner_y + 4, 7, 1);
                    cr.fill();
                    // Left vertical
                    cr.rectangle(inner_x + 2, inner_y + 4, 1, 8);
                    cr.fill();
                    // Bottom horizontal
                    cr.rectangle(inner_x + 2, inner_y + 12, 7, 1);
                    cr.fill();
                    break;
                    
                case 7: // 七 (seven)
                    // Top horizontal
                    cr.rectangle(inner_x + 2, inner_y + 4, 7, 1);
                    cr.fill();
                    // Middle horizontal
                    cr.rectangle(inner_x + 3, inner_y + 8, 5, 1);
                    cr.fill();
                    // Vertical
                    cr.rectangle(inner_x + 5, inner_y + 4, 1, 8);
                    cr.fill();
                    break;
                    
                case 8: // 八 (eight)
                    // Left diagonal (simplified with rectangles)
                    cr.rectangle(inner_x + 3, inner_y + 4, 1, 8);
                    cr.fill();
                    cr.rectangle(inner_x + 4, inner_y + 8, 1, 1);
                    cr.fill();
                    // Right diagonal (simplified with rectangles)
                    cr.rectangle(inner_x + 7, inner_y + 4, 1, 8);
                    cr.fill();
                    cr.rectangle(inner_x + 6, inner_y + 8, 1, 1);
                    cr.fill();
                    break;
                    
                case 9: // 九 (nine)
                    // Vertical left
                    cr.rectangle(inner_x + 3, inner_y + 4, 1, 8);
                    cr.fill();
                    // Hook at top right
                    cr.rectangle(inner_x + 6, inner_y + 4, 1, 4);
                    cr.fill();
                    cr.rectangle(inner_x + 6, inner_y + 4, 2, 1);
                    cr.fill();
                    break;
                    
                default: // Fallback
                    cr.rectangle(inner_x + 2, inner_y + 8, 7, 1);
                    cr.fill();
                    break;
            }
        }
        
        // Draw wind tiles (1-4: East, South, West, North)
        private void draw_wind_tile(Context cr, int tvalue, int inner_x, int inner_y, bool selected) {
            if (selected) {
                set_color(cr, COLOR_LIGHT);
            } else {
                set_color(cr, COLOR_BLUE);
            }
            
            switch (tvalue) {
                case 1: // East (東) - simplified
                    // Box
                    cr.rectangle(inner_x + 2, inner_y + 4, 7, 1); // Top
                    cr.fill();
                    cr.rectangle(inner_x + 2, inner_y + 4, 1, 7); // Left
                    cr.fill();
                    cr.rectangle(inner_x + 8, inner_y + 4, 1, 7); // Right
                    cr.fill();
                    cr.rectangle(inner_x + 2, inner_y + 11, 7, 1); // Bottom
                    cr.fill();
                    
                    // Cross inside
                    cr.rectangle(inner_x + 5, inner_y + 6, 1, 3); // Vertical
                    cr.fill();
                    cr.rectangle(inner_x + 4, inner_y + 7, 3, 1); // Horizontal
                    cr.fill();
                    break;
                    
                case 2: // South (南) - simplified
                    // Top
                    cr.rectangle(inner_x + 3, inner_y + 4, 5, 1);
                    cr.fill();
                    
                    // Box
                    cr.rectangle(inner_x + 3, inner_y + 5, 1, 3);
                    cr.fill();
                    cr.rectangle(inner_x + 7, inner_y + 5, 1, 3);
                    cr.fill();
                    cr.rectangle(inner_x + 3, inner_y + 8, 5, 1);
                    cr.fill();
                    
                    // Bottom fork
                    cr.rectangle(inner_x + 4, inner_y + 9, 1, 3);
                    cr.fill();
                    cr.rectangle(inner_x + 6, inner_y + 9, 1, 3);
                    cr.fill();
                    cr.rectangle(inner_x + 4, inner_y + 12, 3, 1);
                    cr.fill();
                    break;
                    
                case 3: // West (西) - box with Pi symbol
                    // Pi symbol on top
                    cr.rectangle(inner_x + 2, inner_y + 4, 7, 2);
                    cr.fill();
                    cr.rectangle(inner_x + 4, inner_y + 6, 2, 3);
                    cr.fill();
                    
                    // Box below
                    cr.rectangle(inner_x + 2, inner_y + 9, 7, 1); // Top
                    cr.fill();
                    cr.rectangle(inner_x + 2, inner_y + 9, 1, 6); // Left
                    cr.fill();
                    cr.rectangle(inner_x + 8, inner_y + 9, 1, 6); // Right
                    cr.fill();
                    cr.rectangle(inner_x + 2, inner_y + 14, 7, 1); // Bottom
                    cr.fill();
                    break;
                    
                case 4: // North (北) - simplified
                    // Top horizontal
                    cr.rectangle(inner_x + 2, inner_y + 4, 7, 1);
                    cr.fill();
                    
                    // Vertical sides
                    cr.rectangle(inner_x + 2, inner_y + 4, 1, 7);
                    cr.fill();
                    cr.rectangle(inner_x + 8, inner_y + 4, 1, 7);
                    cr.fill();
                    
                    // Middle horizontal
                    cr.rectangle(inner_x + 2, inner_y + 8, 7, 1);
                    cr.fill();
                    
                    // Bottom
                    cr.rectangle(inner_x + 4, inner_y + 8, 1, 3);
                    cr.fill();
                    cr.rectangle(inner_x + 6, inner_y + 8, 1, 3);
                    cr.fill();
                    break;
                    
                default: // Fallback
                    // Box
                    cr.rectangle(inner_x + 2, inner_y + 4, 7, 1);
                    cr.fill();
                    cr.rectangle(inner_x + 2, inner_y + 4, 1, 7);
                    cr.fill();
                    cr.rectangle(inner_x + 8, inner_y + 4, 1, 7);
                    cr.fill();
                    cr.rectangle(inner_x + 2, inner_y + 11, 7, 1);
                    cr.fill();
                    break;
            }
        }
        
        // Draw dragon tiles (1-3: Red, Green, White)
        private void draw_dragon_tile(Context cr, int tvalue, int inner_x, int inner_y, bool selected) {
            switch (tvalue) {
                case 1: // Red Dragon - 5px high box with taller vertical line
                    if (selected) {
                        set_color(cr, COLOR_TEAL);
                    } else {
                        set_color(cr, COLOR_SALMON);
                    }
                    
                    // Box outline (5px high)
                    cr.rectangle(inner_x + 2, inner_y + 6, 7, 1); // Top
                    cr.fill();
                    cr.rectangle(inner_x + 2, inner_y + 6, 1, 5); // Left
                    cr.fill();
                    cr.rectangle(inner_x + 8, inner_y + 6, 1, 5); // Right
                    cr.fill();
                    cr.rectangle(inner_x + 2, inner_y + 10, 7, 1); // Bottom
                    cr.fill();
                    
                    // Vertical line through center (taller than the box)
                    cr.rectangle(inner_x + 5, inner_y + 3, 1, 11);
                    cr.fill();
                    break;
                    
                case 2: // Green Dragon - 發 (Fa) character
                    if (selected) {
                        set_color(cr, COLOR_SALMON);
                    } else {
                        set_color(cr, COLOR_TEAL);
                    }
                    
                    // Top horizontal stroke
                    cr.rectangle(inner_x + 1, inner_y + 4, 9, 1);
                    cr.fill();
                    
                    // Left vertical stroke (main stem)
                    cr.rectangle(inner_x + 3, inner_y + 4, 1, 9);
                    cr.fill();
                    
                    // Middle horizontal stroke
                    cr.rectangle(inner_x + 3, inner_y + 8, 5, 1);
                    cr.fill();
                    
                    // Bottom horizontal stroke
                    cr.rectangle(inner_x + 1, inner_y + 12, 9, 1);
                    cr.fill();
                    
                    // Right side "bow" shape elements
                    // Upper right part
                    cr.rectangle(inner_x + 7, inner_y + 5, 1, 3);
                    cr.fill();
                    
                    // Lower right part
                    cr.rectangle(inner_x + 7, inner_y + 9, 1, 3);
                    cr.fill();
                    
                    // Right side small vertical stroke
                    cr.rectangle(inner_x + 5, inner_y + 5, 1, 7);
                    cr.fill();
                    
                    // Two small dots on right side of character
                    cr.rectangle(inner_x + 8, inner_y + 6, 1, 1);
                    cr.fill();
                    cr.rectangle(inner_x + 8, inner_y + 10, 1, 1);
                    cr.fill();
                    break;
                    
                case 3: // White Dragon - box with comma at top and horizontal line
                    // Outer frame (blue)
                    if (selected) {
                        set_color(cr, COLOR_LIGHT);
                    } else {
                        set_color(cr, COLOR_BLUE);
                    }
                    cr.rectangle(inner_x + 2, inner_y + 4, 7, 1); // Top
                    cr.fill();
                    cr.rectangle(inner_x + 2, inner_y + 4, 1, 9); // Left
                    cr.fill();
                    cr.rectangle(inner_x + 8, inner_y + 4, 1, 9); // Right
                    cr.fill();
                    cr.rectangle(inner_x + 2, inner_y + 12, 7, 1); // Bottom
                    cr.fill();
                    
                    // Inner area (light)
                    if (selected) {
                        set_color(cr, COLOR_BLUE);
                    } else {
                        set_color(cr, COLOR_LIGHT);
                    }
                    cr.rectangle(inner_x + 3, inner_y + 5, 5, 7);
                    cr.fill();
                    
                    // Horizontal line connecting vertical sides
                    if (selected) {
                        set_color(cr, COLOR_LIGHT);
                    } else {
                        set_color(cr, COLOR_BLUE);
                    }
                    cr.rectangle(inner_x + 3, inner_y + 9, 5, 1); // Middle horizontal line
                    cr.fill();
                    
                    // "Comma" shape at the top touching the box (blue)
                    cr.rectangle(inner_x + 5, inner_y + 2, 1, 2); // Vertical part of comma
                    cr.fill();
                    break;
                    
                default: // Fallback to red dragon
                    if (selected) {
                        set_color(cr, COLOR_TEAL);
                    } else {
                        set_color(cr, COLOR_SALMON);
                    }
                    
                    // Box shape
                    cr.rectangle(inner_x + 2, inner_y + 6, 7, 1); // Top
                    cr.fill();
                    cr.rectangle(inner_x + 2, inner_y + 6, 1, 5); // Left
                    cr.fill();
                    cr.rectangle(inner_x + 8, inner_y + 6, 1, 5); // Right
                    cr.fill();
                    cr.rectangle(inner_x + 2, inner_y + 10, 7, 1); // Bottom
                    cr.fill();
                    
                    // Vertical line
                    cr.rectangle(inner_x + 5, inner_y + 4, 1, 9);
                    cr.fill();
                    break;
            }
        }
        
        // Helper method to set color
        private void set_color(Context cr, float[] color) {
            cr.set_source_rgba(color[0], color[1], color[2], color[3]);
        }
        
        // Helper method to draw a rounded rectangle
        private void draw_rounded_rect(Context cr, int x, int y, int width, int height, bool fill = true) {
            // Draw a rectangle with cut corners (1px from each corner)
            cr.move_to(x + 1, y);
            cr.line_to(x + width - 1, y);
            cr.line_to(x + width, y + 1);
            cr.line_to(x + width, y + height - 1);
            cr.line_to(x + width - 1, y + height);
            cr.line_to(x + 1, y + height);
            cr.line_to(x, y + height - 1);
            cr.line_to(x, y + 1);
            cr.close_path();
            
            if (fill) {
                cr.fill();
            } else {
                cr.stroke();
            }
        }
        
        // Helper to get the number of tiles for each type in a standard Mahjong set
        public static int get_tile_count(TileCategory category, int tvalue) {
            // A traditional Mahjong set has 4 copies of each numbered tile
            return 4;
        }
    }
}