using Cairo;

/**
 * Sprite renderer for CHR format sprites.
 * Handles loading and rendering sprites from the spritesheet.
 */
public class SpriteRenderer {
    private Cairo.Context cr;
    private static uint16[] spritesheet_data = {};
    private static string spritesheet_hex = """efc7 8301 01ab c7ff efc7 8301 01ab c7ff
c7c7 0101 01ef c7ff c7c7 0101 01ef c7ff
ffff ffff ffff ffff 9301 0101 83c7 efff
ffff ffff ffff ffff efc7 8301 83c7 efff
c739 3939 3939 39c7 c739 3939 3939 39c7
7387 e7e7 e7e7 e781 7387 e7e7 e7e7 e781
c3b1 79f1 e3c7 8901 c3b1 79f1 e3c7 8901
7f81 f3ef 93f1 7183 7f81 f3ef 93f1 7183
f1e3 e3c3 9300 f3e1 f1e3 e3c3 9300 f3e1
3907 bf3f 03f1 3183 3907 bf3f 03f1 3183
c53b 3f3f 0331 3183 c53b 3f3f 0331 3183
7f81 c1f3 e7cf 9f3f 7f81 c1f3 e7cf 9f3f
7f83 3131 8331 3183 7f83 3131 8331 3183
7f83 3131 83e7 cf9f 7f83 3131 83e7 cf9f
3c3c 99c3 c399 3c3c 3c3c 99c3 c399 3c3c
e1f3 f3f3 f3e3 c79f e1f3 f3f3 f3e3 c79f
8319 3939 3939 3180 8319 3939 3939 3180
3993 9387 8793 9339 3993 9387 8793 9339
87e3 c3c9 c199 993c 87e3 c3c9 c199 993c
118c 9c9c 9c9c 9c21 118c 9c9c 9c9c 9c21
f8f8 f8f0 e000 0000 f8fa fdfa e52a 150a
1f1f 1f0f 0700 0000 1fbf 5faf 57ac 54a8
0713 ffff e7ff ffff 0f1f 7f83 e7fe ff7e
e0c8 ffff e7ff ffff f0f8 fec1 e77f ff7e
051d ffff e7ff ffff 071f 7f83 e7fe ff7c
a0b8 ffff e7ff ffff e0f8 fec1 e77f ff3e
0719 ffff e7ff ffff 071f 7f83 e7ff fe7f
e098 ffff f3ff ffff e0f8 fec1 f3ff 7ffe
ffff f8f8 f8ff f8f9 bfef f8f8 f8fb f8f9
ffff 1f1f 1fff 1f9f fdf7 1f1f 1fdf 1f9f
ffff f8f8 f8ff f8f8 beef f8f8 f8fb f8f8
ffff 1f1f 1fff 1f1f 7df7 1f1f 1fdf 9f9f
3f40 8080 8080 403f 3f40 8080 8080 403f
ff00 0000 0000 00ff ff00 0000 0000 00ff
fc02 0101 0101 02fc fc02 0101 0101 02fc
ff00 e0f0 f0e0 00ff ff00 0000 0000 00ff
3f40 9fbf bf9f 403f 3f40 8080 8080 403f
ff00 ffff ffff 00ff ff00 0000 0000 00ff
fc02 f9fd fdf9 02fc fc02 0101 0101 02fc
3f40 98bc bc98 403f 3f40 8080 8080 403f
0000 0000 0000 0000 0c0c 1818 0030 3000
0000 0000 0000 0000 0000 0000 0030 3000
001c 37ea 77fe 3f3a 001c 37ea 77fe 3f3e
3f2e 3f3a 3f3e 373f 3f3e 3f3e 3f3e 3f3f
3c66 dbdb c3db 5a3c 0000 0000 0000 0000
3c46 dbc7 dbdb 463c 0000 0000 0000 0000
002f 0002 0000 0000 002f 023f 1f02 0a0a
0000 0000 00ff ffff 0000 0000 00ff ffff
ffff fcf0 e0c0 8000 ffff fcf0 e0c0 8000
c000 0007 0f1f 1f1f c000 0007 0f1c 1818
0300 00e0 f0f8 f8f8 0300 00e0 f038 1818
ffff 3f0f 0703 0100 ffff 3f0f 0703 0100
0080 c0e0 f0fc ffff 0080 c0e0 f0fc ffff
1f1f 1f0f 0700 00c0 1818 1c0f 0700 00c0
f8f8 f8f0 e000 0003 1818 38f0 e000 0003
0001 0307 0f3f ffff 0001 0307 0f3f ffff
ffff ffff ffff ffff ffff fcf0 e0c0 8000
ffff ffff fffc f8f8 c000 0007 0f1c 1818
ffff ffff ff3f 1f1f 0300 00e0 f038 1818
ffff ffff ffff ffff ffff 3f0f 0703 0100
ffff ffff ffff ffff 0080 c0e0 f0fc ffff
f8f8 fcff ffff ffff 1818 1c0f 0700 00c0
1f1f 3fff ffff ffff 1818 38f0 e000 0003
ffff ffff ffff ffff 0001 0307 0f3f ffff
0000 0024 6676 ffff 0000 0024 6676 ffff
0000 0f1f 3f3f 3f3f 0000 0f1f 3f3f 3f3f
0000 ffff ffff ffff 0000 ffff ffff ffff
0000 f0f8 fcfc fcfc 0000 f0f8 fcfc fcfc
e7db e77e 183c 3e56 e7db e77e 183c 3858
3f3f 3f3f 3f3f 3f3f 3f3f 3f3f 3f3f 3f3f
ffff ffff ffff ffff ffff ffff ffff ffff
fcfc fcfc fcfc fcfc fcfc fcfc fcfc fcfc
0000 0000 0000 0000 0500 0000 0000 ffff
3f3f 3f3f 1f0f 0000 3f3f 3f3f 3f3f 3f1f
ffff ffff ffff 0000 ffff ffff ffff ffff
fcfc fcfc f8f0 0000 fcfc fcfc fcfc fcf8
ffff 7fff e7ff ff7f 0719 ff83 e7ff feff
fffb ffff f3ff fffe e09c fec1 f3ff 7fff
ffff 7fff e7ff ff7f 0713 ff83 e7fe fffe
fffb ffff e7ff fffe e0cc fec1 e77f ff7f
04fc fcf8 f000 0000 04fc fcf8 f8f0 0000
0000 0f10 2020 2020 0000 0f10 2020 2020
0000 ff00 0000 0000 0000 ff00 0000 00ff
0000 f008 0404 0404 0000 f008 0404 0404
0000 0000 4020 20c0 0000 0000 0000 0000
2020 2020 2020 2020 2121 2121 2121 2121
0000 0000 0000 0000 8142 2418 1824 4281
0404 0404 0404 0404 8484 8484 8484 8484
0000 0002 9041 04ff 0000 0002 9041 04ff
2020 2020 100f 0000 2020 2020 303f 3f1f
0000 0000 00ff 0000 ff00 0000 00ff ffff
0404 0404 08f0 0000 0404 0404 0cfc fcf8
ffff 7fff e7ff ff7f 051d ff83 e7fe fffc
fffb ffff e7ff fffe a0bc fec1 e77f ff3f
ffff ffff ffff 0000 1800 1800 0000 ffff
1800 1800 0000 0000 1800 1800 0000 ffff
fffe fcf8 f0e0 c080 fffe fcf8 f0e0 c080
ff7f 3f1f 0f07 0301 ff7f 3f1f 0f07 0301
0000 0000 0000 0000 0000 0000 0000 0000
80c0 e0f0 f8fc feff 80c0 e0f0 f8fc feff
0000 ffe7 c381 8100 0000 ffe7 c381 8100
00cf cf00 00f9 f900 00cf cf00 00f9 f900
00aa aa00 00ff ff00 00aa aa00 00ff ff00
0103 070f 1f3f 7fff 0103 070f 1f3f 7fff
c8a1 2452 14b9 5238 c8a1 2452 14b9 5238
ff00 99a7 e599 00ff ff00 99a7 e599 00ff
bd89 99e5 a799 91bd bd89 99e5 a799 91bd
ffff bf29 5205 4000 ffff bf29 5205 4000
2b05 0805 0000 0000 2b05 0805 0000 0000
d4a0 10a0 0000 0000 d4a0 10a0 0000 0000
3c76 fddf ffff ffff 3c7e ffff ffff ffff
ffbf fffe fbff ffff ffbf ffff ffff ffff
3c3c 3c3c 7800 0000 3c3c 3c3c fcfc 3800
00ff ffff ff00 0000 00ff ffff ffff 0000
00ff ffff ff80 0000 00ff ffff ffff 8000
0078 3c3c 3c3c 3c3c 0078 3c3c 3c3c 3c3c
3c3c 3c3c 3c1e 0000 3c3c 3c3c 3c3f 1f0c
0000 c0f0 f8f8 7c3c 0000 c0f0 f8f8 fc7c
3e3f 1f1f 0700 0000 3e3f 1f1f 0f07 0000
c0e0 f078 3c1e 0f07 c0e0 f078 3c1e 0f07
0078 3b3f 3f3f 3e3c 0078 3b3f 3f3f 3f3e
0000 030f 1f1f 3e3c 0000 030f 1f1f 3f3e
3c3c 3c3c 3c3c 3c3c 3c3c 3c3c 3c3c 3c3c
7cfc f8f8 e000 0000 7cfc f8f8 f8e0 0000
f8fd faf5 ea15 eaf5 fffa fdfa d5ea 150a
1f5f bf5f ab54 ab57 ffbf 5faf 57ab 54a8
f5fa fcff ffff 0000 0a05 0300 0000 ffff
af5f 3fff ffff 0000 50a0 c000 0000 ffff
f8ff fff7 df3f ffff fff8 f8f8 e0c0 0000
1fbf bfaf bbdc eff7 ff5f 5f5f 4723 1008
ffff f8f8 f8ff ffff beef ffff fff8 f8f8
ffff 1f1f 1fff ffff 7df7 ffff ff1f 1f1f
ffff ffff ffff 0000 0000 0000 0000 ffff
f7f7 f7f7 f7f7 0000 2808 0828 0808 ffff
f8ff ffff df3f ffff fff8 f8f0 e0c0 0000
1fff ffff fbfc ffff ff1f 1f0f 0703 0000
0000 0000 0000 0000 5000 0000 0000 ffff
1f1f 1f0f 0700 0000 5f5f 5f4f 4722 1008
ffff f8f8 f8f8 f8ff beef f8f8 f8f8 f8fb
ffff 1f1f 1f1f 1fff 7df7 1f1f 1f1f 1fdf
0000 0000 0000 0000 0000 0000 0000 ffff
2000 0020 0000 0000 2808 0828 0808 ffff
f8f8 f8f0 e000 0000 f8f8 f8f0 e060 0000
1f1f 1f0f 0700 0000 1f1f 1f0f 0706 0000
fefc f8f0 e0c0 8020 fefc f8f0 e0c0 8020
0001 0100 0000 0103 0000 0201 0000 0103
0080 8000 0000 80c0 0080 4080 0000 80c0
7f3f 1f0f 0703 0100 7f3f 1f0f 0703 0100
4000 0001 0181 c0f0 4000 0083 1183 c4f0
071d 7fbf cfff ffff 071f 3fc3 cffe ff7e
e0b8 fefd e7ff ffff e0f8 fcc3 e77f ff7e
0200 0080 8081 0307 0202 00c0 82d1 0307
f8e0 c080 8000 0000 f8e0 c080 8000 2000
ffff f8f8 f8ff f8f9 bdef f8f8 f8fb f8fd
ffff 1f1f 1fff 1f9f bdf7 1f1f 1fdf 1fbf
1f07 0301 0100 0000 1f07 0301 0100 0000
ffff ffff fff8 e0c0 ffff ffff fff8 f0c0
f8f9 f8f1 e001 0001 f8fd f8f5 e815 2815
1f9f 1f8f 0780 0080 1fbf 1faf 17a8 14a8
ffff ffff ff1f 0703 ffff ffff ff1f 0f03
fffe fdff fefe fdfb 0003 0301 0101 0307
ffff bfff 7f7f bfef 0040 c080 8080 c0d0
0000 0000 0000 0000 0a05 0300 0000 ffff
0000 0000 0000 0000 50a0 c000 0000 ffff
ffff ffeb fdfa ffff ffff ff17 0305 0000
ffff ffd7 af7f bfff ffff ffe8 d080 4000
c0c0 c0c0 c0c0 0000 c0c0 e2c0 ead2 ffff
0303 0303 0303 0000 0303 4703 574b ffff
ffff ffff ffff ffff ffff fffc f0e0 c080
ffff ffff ffff ffff ffff ff7f 1f0f 0703
57ef 1fff ffff 0000 a890 e000 0000 ffff
eaf7 f8ff ffff 0000 1509 0700 0000 ffff
ffff ffff ffff ffff 8000 0000 0000 0000
ffff ffff ffff ffff 0101 0000 0000 0000
ffff ddeb d5e9 0000 c0c0 e0d4 e8d4 ffff
ffff bbd7 ab97 0000 0303 072b 172b ffff
ffff ffff ffff ffff fefc f8f0 e0c0 8102
fdfa f7fd fefe fdfb 060d 1923 4181 0307
bf5f efbf 7f7f bfef 60b0 98c4 8281 c0d0
ffff ffff ffff ffff 7f3f 1f0f 0703 8140
ffbb d7eb f5fa fcfe 04cc f8f4 fafd ffff
ffff 7fff cfff ff7f 071d ff83 cffe fbfc
fffb feff e7ff fffe e0bc ffc1 e77f df3f
fadd eb57 af5f 3f7f 2533 1faf 5fbf ffff
ffff ffaf d5eb f0fc 0000 80d1 ebf5 ffff
ffff f8f8 f8ff f8f9 bfef ffff fffb ffff
ffff 1f1f 1fff 1f9f fdf7 ffff ffdf ffff
ffff ffeb d7af 0f3f 0000 0095 abd7 ffff
ffff ffff ffff efdf ffff ffff fff8 f0f0
faff faf7 ea57 aad7 fdf9 fdf9 d5a9 5529
5fff 5fef 57ea 55eb bf9f bf9f ab95 aa94
ffff ffff ffff f7fb ffff ffff ff1f 0f17
0000 0000 0000 0000 0000 0000 0000 0000""";
    
    // Color palette for 2-bit sprites
    private double[,] palette = {    // Black (1) - For outlines, spades, clubs
        { DonsolTheme.get_default().get_black_r(), DonsolTheme.get_default().get_black_g(), DonsolTheme.get_default().get_black_b() },
        { DonsolTheme.get_default().get_gray_r(), DonsolTheme.get_default().get_gray_g(), DonsolTheme.get_default().get_gray_b() },
        
        { DonsolTheme.get_default().get_red_r(), DonsolTheme.get_default().get_red_g(), DonsolTheme.get_default().get_red_b() },
        { DonsolTheme.get_default().get_white_r(), DonsolTheme.get_default().get_white_g(), DonsolTheme.get_default().get_white_b() },
    };
    
    /**
     * Create a new sprite renderer
     */
    public SpriteRenderer(Cairo.Context ctx) {
        cr = ctx;
        cr.set_antialias(Cairo.Antialias.NONE);
        cr.set_line_width(1.0);
        
        // Initialize spritesheet data if not already done
        load_spritesheet();
    }
    
    /**
     * Load spritesheet data from the hex values in spritesheet.tal
     */
    private static void load_spritesheet() {
        
        if (spritesheet_hex == null || spritesheet_hex.length == 0) {
            stdout.printf("ERROR: spritesheet_hex is null or empty!\n");
            spritesheet_data = new uint16[0];
            return;
        }
        
        // Split and filter in one step to avoid indexing issues
        string[] tokens = new string[0];
        foreach (string part in spritesheet_hex.split_set(" \t\n\r")) {
            if (part != "") tokens += part;
        }
        
        if (tokens.length == 0) {
            spritesheet_data = new uint16[0];
            return;
        }
        
        // Allocate array with exact size
        spritesheet_data = new uint16[tokens.length];
        
        // Parse each token
        for (int i = 0; i < tokens.length; i++) {
            try {
                spritesheet_data[i] = parse_hex_manually(tokens[i]);
            } catch (Error e) {
                stdout.printf("Error parsing token '%s': %s\n", tokens[i], e.message);
                spritesheet_data[i] = 0;
            }
        }
        
        // Count non-zero values
        int non_zero_count = 0;
        for (int i = 0; i < spritesheet_data.length; i++) {
            if (spritesheet_data[i] != 0) non_zero_count++;
        }
    }
    
    private static uint16 parse_hex_manually(string hex) {
        uint16 value = 0;
        
        foreach (char c in hex.to_utf8()) {
            // Shift existing value left by 4 bits
            value <<= 4;
            
            // Parse hex digit
            if (c >= '0' && c <= '9') {
                value |= (uint16)(c - '0');
            } else if (c >= 'a' && c <= 'f') {
                value |= (uint16)(c - 'a' + 10);
            } else {
                stdout.printf("Invalid hex character: '%c'\n", c);
                return 0;
            }
        }
        
        return value;
    }
    
    /**
     * Draw a sprite from the spritesheet using CHR format
     */
    public void draw_sprite(int x, int y, int sprite_index, int width, int height) {
        
        // In CHR format, each 8x8 sprite is represented by 8 uint16 values
        int offset = sprite_index * 8;
        
        // Check bounds
        if (offset + 8 > spritesheet_data.length) {
            return;
        }
        
        // Calculate pixel scale factors
        double pixel_scale_x = (double)width / 8.0;
        double pixel_scale_y = (double)height / 8.0;
        
        // Process each row in the 8x8 sprite
        for (int py = 0; py < 8; py++) {
            // Determine which of the 8 uint16 values we need
            int row_idx = py / 2;
            // First 4 uint16 values are for plane 1, next 4 for plane 2
            int plane1_index = offset + row_idx;
            int plane2_index = offset + 4 + row_idx;
            
            // Each uint16 contains two rows - determine which byte to use
            int shift = (py % 2 == 0) ? 8 : 0; // High byte for even rows, low byte for odd
            
            // Extract bytes from each plane
            uint8 plane1_byte = (uint8)((spritesheet_data[plane1_index] >> shift) & 0xFF);
            uint8 plane2_byte = (uint8)((spritesheet_data[plane2_index] >> shift) & 0xFF);
            
            // Process each bit in the row
            for (int px = 0; px < 8; px++) {
                // Extract bits according to CHR format spec (right to left)
                int bit1 = (plane2_byte >> px) & 0x1;
                int bit2 = (plane1_byte >> px) & 0x1;
                
                // Combine to get color index (0-3)
                int color_index = (bit2 << 1) | bit1;
                
                // Flip x-coordinate to match CHR spec
                int draw_x = x + (int)((7 - px) * pixel_scale_x);
                int draw_y = y + (int)(py * pixel_scale_y);
                
                // Calculate pixel size
                int pixel_width = (int)Math.floor(pixel_scale_x);
                if (pixel_width < 1) pixel_width = 1;
                
                int pixel_height = (int)Math.floor(pixel_scale_y);
                if (pixel_height < 1) pixel_height = 1;
                
                // Draw the pixel with debug output
                draw_rect(
                    draw_x,
                    draw_y,
                    pixel_width,
                    pixel_height,
                    palette[color_index, 0],
                    palette[color_index, 1],
                    palette[color_index, 2]
                );
            }
        }
    }
    
    // Helper drawing methods
    private void draw_rect(int x, int y, int width, int height, double r, double g, double b) {
        cr.set_source_rgb(r, g, b);
        cr.rectangle(x, y, width, height);
        cr.fill();
    }
    public void pixel(int x, int y, double r, double g, double b) {
        cr.set_source_rgb(r, g, b);
        cr.rectangle(x, y, 1, 1);
        cr.fill();
    }
}