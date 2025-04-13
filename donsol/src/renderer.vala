using Cairo;

/**
 * Donsol card game renderer.
 * Handles rendering of cards and other game elements.
 */
public class Renderer {
    private Cairo.Context cr;
    private CardData card_data;
    
    /**
     * Create a new renderer
     */
    public Renderer(Cairo.Context ctx) {
        cr = ctx;
        cr.set_antialias(Cairo.Antialias.NONE);
        cr.set_line_width(1.0);
        
        // Initialize card data
        card_data = new CardData();
    }
    
    // Theme color methods
    public double theme_black_r() { return DonsolTheme.get_default().get_black_r(); }
    public double theme_black_g() { return DonsolTheme.get_default().get_black_g(); }
    public double theme_black_b() { return DonsolTheme.get_default().get_black_b(); }
    
    public double theme_white_r() { return DonsolTheme.get_default().get_white_r(); }
    public double theme_white_g() { return DonsolTheme.get_default().get_white_g(); }
    public double theme_white_b() { return DonsolTheme.get_default().get_white_b(); }
    
    public double theme_red_r() { return DonsolTheme.get_default().get_red_r(); }
    public double theme_red_g() { return DonsolTheme.get_default().get_red_g(); }
    public double theme_red_b() { return DonsolTheme.get_default().get_red_b(); }
    
    public double theme_gray_r() { return DonsolTheme.get_default().get_gray_r(); }
    public double theme_gray_g() { return DonsolTheme.get_default().get_gray_g(); }
    public double theme_gray_b() { return DonsolTheme.get_default().get_gray_b(); }
    
    // Core drawing primitives
    public void pixel(int x, int y, double r, double g, double b) {
        cr.set_source_rgb(r, g, b);
        cr.rectangle(x, y, 1, 1);
        cr.fill();
    }
    
    public void rect(int x, int y, int w, int h, double r, double g, double b) {
        cr.set_source_rgb(r, g, b);
        cr.rectangle(x, y, w, h);
        cr.fill();
    }
    
    public void rect_outline(int x, int y, int w, int h, double r, double g, double b) {
        for (int i = 0; i < w; i++) {
            pixel(x + i, y, r, g, b);
            pixel(x + i, y + h - 1, r, g, b);
        }
        for (int j = 0; j < h; j++) {
            pixel(x, y + j, r, g, b);
            pixel(x + w - 1, y + j, r, g, b);
        }
    }
    
    public void circle(int x, int y, int radius, double r, double g, double b) {
        for (int i = -radius; i <= radius; i++)
            for (int j = -radius; j <= radius; j++)
                if (i*i + j*j <= radius*radius)
                    pixel(x + i, y + j, r, g, b);
    }
    
    /**
     * Draw a card using the CHR spritesheet
     */
    public void card(int x, int y, Card card) {
        // Get card data from the CardData class
        uint8[]? sprite_data;
        
        if (card.folded) {
            // Use blank sprite for folded cards instead of custom drawing
            sprite_data = card_data.blank;
        } else {
            // Get normal card data for unfolded cards
            sprite_data = get_card_data(card);
        }
        
        if (sprite_data == null || sprite_data.length < 54) {
            return;
        }
        
        // Create a sprite renderer
        var sprite_renderer = new SpriteRenderer(cr);
        
        // Each card is a 6×9 grid of 8×8 sprites
        int sprite_size = 8; // 8×8 pixels per sprite
        
        // Calculate scaling factor
        double scale_x = 1.0;
        double scale_y = 1.0;
        
        // Process each tile in the card data (6×9 grid)
        for (int i = 0; i < 54 && i < sprite_data.length; i++) {
            // Calculate position in the grid
            int grid_x = i % 6;
            int grid_y = i / 6;
            
            // Calculate pixel position
            int sprite_x = x + (int)(grid_x * sprite_size * scale_x);
            int sprite_y = y + (int)(grid_y * sprite_size * scale_y);
            
            // Get the sprite index from the card data
            uint8 sprite_index = sprite_data[i];
            
            // According to donsol.tal, sprite index is offset by 0x40
            int adjusted_index = sprite_index - 0x40;
            
            // Draw this sprite
            sprite_renderer.draw_sprite(
                sprite_x, sprite_y, adjusted_index, 
                (int)(sprite_size * scale_x), 
                (int)(sprite_size * scale_y)
            );
        }
    }
    
    /**
     * Helper method to get card data from CardData
     */
    private uint8[]? get_card_data(Card card) {
        // Determine card array based on suit and value
        switch (card.suit) {
            case CardSuit.HEARTS:
                switch (card.value) {
                    case 1: return card_data.heart1;
                    case 2: return card_data.heart2;
                    case 3: return card_data.heart3;
                    case 4: return card_data.heart4;
                    case 5: return card_data.heart5;
                    case 6: return card_data.heart6;
                    case 7: return card_data.heart7;
                    case 8: return card_data.heart8;
                    case 9: return card_data.heart9;
                    case 10: return card_data.heart10;
                    case 11: return card_data.heart11;
                    case 12: return card_data.heart12;
                    case 13: return card_data.heart13;
                }
                break;
                
            case CardSuit.DIAMONDS:
                switch (card.value) {
                    case 1: return card_data.diamond1;
                    case 2: return card_data.diamond2;
                    case 3: return card_data.diamond3;
                    case 4: return card_data.diamond4;
                    case 5: return card_data.diamond5;
                    case 6: return card_data.diamond6;
                    case 7: return card_data.diamond7;
                    case 8: return card_data.diamond8;
                    case 9: return card_data.diamond9;
                    case 10: return card_data.diamond10;
                    case 11: return card_data.diamond11;
                    case 12: return card_data.diamond12;
                    case 13: return card_data.diamond13;
                }
                break;
                
            case CardSuit.SPADES:
                switch (card.value) {
                    case 1: return card_data.spade1;
                    case 2: return card_data.spade2;
                    case 3: return card_data.spade3;
                    case 4: return card_data.spade4;
                    case 5: return card_data.spade5;
                    case 6: return card_data.spade6;
                    case 7: return card_data.spade7;
                    case 8: return card_data.spade8;
                    case 9: return card_data.spade9;
                    case 10: return card_data.spade10;
                    case 11: return card_data.spade11;
                    case 12: return card_data.spade12;
                    case 13: return card_data.spade13;
                }
                break;
                
            case CardSuit.CLUBS:
                switch (card.value) {
                    case 1: return card_data.club1;
                    case 2: return card_data.club2;
                    case 3: return card_data.club3;
                    case 4: return card_data.club4;
                    case 5: return card_data.club5;
                    case 6: return card_data.club6;
                    case 7: return card_data.club7;
                    case 8: return card_data.club8;
                    case 9: return card_data.club9;
                    case 10: return card_data.club10;
                    case 11: return card_data.club11;
                    case 12: return card_data.club12;
                    case 13: return card_data.club13;
                }
                break;
                
            case CardSuit.JOKER:
                switch (card.value) {
                    case 1: return card_data.joker1;
                    case 2: return card_data.joker2;
                }
                break;
        }
        
        return card_data.blank; // Default to blank if no match
    }
    
    // Composite UI components
    public void status_bar(int x, int y, double fill, double r, double g, double b) {
        // Bar outline
        rect_outline(x, y, DonsolConstants.BAR_WIDTH, DonsolConstants.BAR_HEIGHT, 
                    theme_gray_r(), theme_gray_g(), theme_gray_b());
        
        // Bar fill based on percentage
        int fill_width = (int)((DonsolConstants.BAR_WIDTH - 2) * fill);
        for (int i = 0; i < fill_width; i++)
            for (int j = 0; j < DonsolConstants.BAR_HEIGHT - 2; j++)
                pixel(x + 1 + i, y + 1 + j, r, g, b);
    }
    
    // Text rendering 
    public void text(int x, int y, string text, double r, double g, double b, bool mini = false) {
        cr.save(); // Save current state
        
        // Set color
        cr.set_source_rgb(r, g, b);
        
        // Set font
        cr.select_font_face("atari8", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        
        // Set font size based on mini parameter
        int font_size = 8;
        cr.set_font_size(font_size);
        
        // Add baseline offset for proper vertical alignment
        int baseline_offset = 8;
        
        // Position text with baseline correction
        cr.move_to(x, y + baseline_offset);
        
        // Render text
        cr.show_text(text);
        
        cr.restore(); // Restore previous state
    }
}