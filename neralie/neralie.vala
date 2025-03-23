public class NeralieApp : Gtk.Application {
    // Font character widths (for fixed-width characters we use 8)
    private const int CHARACTER_WIDTH = 8;
    private const int PADDING = 24;
    private uint timeout_id;
    private int fps_counter = 0;
    private int last_second = -1;
    
    // Font data from original code - 4 uint16 values per character in ICN format
    private const uint16[] font_numbers = {
        0x7cc6, 0xced6, 0xe6c6, 0x7c00, // 0
        0x1838, 0x1818, 0x1818, 0x7e00, // 1
        0x3c66, 0x063c, 0x6066, 0x7e00, // 2
        0x3c66, 0x061c, 0x0666, 0x3c00, // 3
        0x1c3c, 0x6ccc, 0xfe0c, 0x1e00, // 4
        0x7e62, 0x607c, 0x0666, 0x3c00, // 5
        0x3c66, 0x607c, 0x6666, 0x3c00, // 6
        0x7e66, 0x060c, 0x1818, 0x1800, // 7
        0x3c66, 0x663c, 0x6666, 0x3c00, // 8
        0x3c66, 0x663e, 0x0666, 0x3c00, // 9
        0x7cc6, 0xced6, 0xe6c6, 0x7c00, // 10 (unused)
        0x0018, 0x1800, 0x1818, 0x0000  // 11 (colon)
    };
    
    private const uint16[] font_letters = {
        0x183c, 0x6666, 0x7e66, 0x6600, // A
        0xfc66, 0x667c, 0x6666, 0xfc00, // B
        0x3c66, 0xc0c0, 0xc066, 0x3c00, // C
        0xf86c, 0x6666, 0x666c, 0xf800, // D
        0xfe62, 0x6878, 0x6862, 0xfe00, // E
        0xfe62, 0x6878, 0x6860, 0xf000, // F
        0x3c66, 0xc0c0, 0xce66, 0x3e00, // G
        0x6666, 0x667e, 0x6666, 0x6600, // H
        0x7e18, 0x1818, 0x1818, 0x7e00, // I
        0x1e0c, 0x0c0c, 0xcccc, 0x7800, // J
        0xe666, 0x6c78, 0x6c66, 0xe600, // K
        0xf060, 0x6060, 0x6266, 0xfe00, // L
        0xc6ee, 0xfefe, 0xd6c6, 0xc600, // M
        0xc6e6, 0xf6de, 0xcec6, 0xc600, // N
        0x386c, 0xc6c6, 0xc66c, 0x3800, // O
        0xfc66, 0x667c, 0x6060, 0xf000, // P
        0x386c, 0xc6c6, 0xdacc, 0x7600, // Q
        0xfc66, 0x667c, 0x6c66, 0xe600, // R
        0x3c66, 0x603c, 0x0666, 0x3c00, // S
        0x7e5a, 0x1818, 0x1818, 0x3c00, // T
        0x6666, 0x6666, 0x6666, 0x3c00, // U
        0x6666, 0x6666, 0x663c, 0x1800, // V
        0xc6c6, 0xc6d6, 0xfeee, 0xc600, // W
        0xc66c, 0x3838, 0x6cc6, 0xc600, // X
        0x6666, 0x663c, 0x1818, 0x3c00, // Y
        0xfec6, 0x8c18, 0x3266, 0xfe00, // Z
        0x0018, 0x187e, 0x1818, 0x0000  // Special character
    };
    
    // Colors from original UXNtal code
    private const Gdk.RGBA COLOR_BG = { 0.0f, 0.0f, 0.0f, 1.0f };
    private const Gdk.RGBA COLOR_FG = { 1.0f, 1.0f, 1.0f, 1.0f };
    private const Gdk.RGBA COLOR_ACCENT = { 51.0f/255.0f, 238.0f/255.0f, 187.0f/255.0f, 1.0f };  // #3eb
    
    public NeralieApp() {
        Object(application_id: "org.example.neralie", flags: ApplicationFlags.DEFAULT_FLAGS);
    }
    
    protected override void activate() {
        var window = new Gtk.ApplicationWindow(this) {
            title = "Neralie",
            default_width = 220,
            default_height = 304,
            resizable = false
        };
        
        window.set_titlebar (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { 
        	visible = false
        });
        
        var drawing_area = new Gtk.DrawingArea();
        drawing_area.set_draw_func(draw_func);
        
        var winhandle = new Gtk.WindowHandle ();
        winhandle.set_child (drawing_area);
        
        window.set_child(winhandle);
        window.present();
        
        // Setup a timer to redraw the clock
        timeout_id = GLib.Timeout.add(16, () => {
            // Update FPS counter
            fps_counter++;
            var now = new DateTime.now_local();
            if (now.get_second() != last_second) {
                fps_counter = 0;
                last_second = now.get_second();
            }
            
            drawing_area.queue_draw();
            return Source.CONTINUE;
        });
        
        window.close_request.connect(() => {
            Source.remove(timeout_id);
            return false;
        });
        
        apply_css();
    }
    
    private string load_css_style() {
	    string css = """
window {
    background: black;
    color: white;
    border-radius: 0;
    padding: 1px;
}
window.csd {
    box-shadow:
        inset 0 0 0 1px white,
        0 0 0 1px black,
        2px 2px 0 0 black;
}
	    """;
	    
	    return css;
	}
	
	// To apply this CSS to your application, add this function to your NeralieApp class
	// and call it from the activate method:
	private void apply_css() {
	    string css = load_css_style();
	    var provider = new Gtk.CssProvider();
	    provider.load_from_data(css.data);
	    
	    Gtk.StyleContext.add_provider_for_display(
	        Gdk.Display.get_default(),
	        provider,
	        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
	    );
	}
    
    private void draw_func(Gtk.DrawingArea drawing_area, Cairo.Context cr, int width, int height) {
        // Clear the canvas with the original background color
        cr.set_source_rgb(COLOR_BG.red, COLOR_BG.green, COLOR_BG.blue);
        cr.paint();
        
        // Calculate frame bounds
        int frame_x1 = PADDING;
        int frame_y1 = PADDING;
        int frame_x2 = width - PADDING - 1;
        int frame_y2 = height - PADDING;
        
        // Set up Cairo for drawing
        cr.set_line_width(1);
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Draw frame (accent color)
        cr.set_source_rgb(COLOR_ACCENT.red, COLOR_ACCENT.green, COLOR_ACCENT.blue);
        draw_horizontal_line(cr, frame_x1, frame_x2, frame_y1);
        draw_horizontal_line(cr, frame_x1, frame_x2, frame_y2);
        draw_vertical_line(cr, frame_y1, frame_y2, frame_x1);
        draw_vertical_line(cr, frame_y1, frame_y2, frame_x2);
        
        // Calculate Neralie time
        var neralie = calculate_neralie();
        
        // Draw date and clock (foreground color)
        cr.set_source_rgb(COLOR_FG.red, COLOR_FG.green, COLOR_FG.blue);
        draw_date(cr, width, height, neralie);
        draw_clock(cr, frame_x1, frame_y1, frame_x2, frame_y2, neralie);
    }
    
    private NeralieTime calculate_neralie() {
        var now = new DateTime.now_local();
        var time = new NeralieTime();
        
        // Calculate fraction of day (0.0 to 1.0)
        double seconds_in_day = now.get_hour() * 3600 + now.get_minute() * 60 + 
                               now.get_second() + now.get_microsecond() / 1000000.0;
        double day_fraction = seconds_in_day / 86400.0;
        
        // Convert to Neralie (100 pulses per day)
        double pulses = day_fraction * 100.0;
        
        // Extract components
        time.pulse = (int)pulses; // 0-99
        
        // Calculate decimals
        double fraction = pulses - time.pulse;
        time.decimal1 = (int)(fraction * 10);
        time.decimal2 = (int)(fraction * 100) % 10;
        time.decimal3 = (int)(fraction * 1000) % 10;
        
        return time;
    }
    
    private void draw_horizontal_line(Cairo.Context cr, int x1, int x2, int y) {
        cr.move_to(x1, y + 0.5);
        cr.line_to(x2, y + 0.5);
        cr.stroke();
    }
    
    private void draw_vertical_line(Cairo.Context cr, int y1, int y2, int x) {
        cr.move_to(x + 0.5, y1);
        cr.line_to(x + 0.5, y2);
        cr.stroke();
    }
    
    private void draw_vertical_dotted_line(Cairo.Context cr, int y1, int y2, int x) {
    	double[] dashes = {1.0, 1.0};
        cr.set_dash(dashes, 0);
        cr.move_to(x + 0.5, y1);
        cr.line_to(x + 0.5, y2);
        cr.stroke();
        cr.set_dash(null, 0);
    }
    
    private void draw_bitmap_digit(Cairo.Context cr, int x, int y, int digit) {
        if (digit < 0 || digit > 9) return;
        
        // Each character is 4 uint16 values (8 rows total)
        int idx = digit * 4;
        
        // Draw the digit using its bitmap representation
        draw_bitmap_char(cr, x, y, font_numbers, idx);
    }
    
    private void draw_bitmap_letter(Cairo.Context cr, int x, int y, char letter) {
        int letter_idx = letter - 'A';
        if (letter_idx < 0 || letter_idx >= 26) return;
        
        int idx = letter_idx * 4;
        if (idx >= font_letters.length - 3) return;
        
        draw_bitmap_char(cr, x, y, font_letters, idx);
    }
    
    private void draw_bitmap_char(Cairo.Context cr, int x, int y, uint16[] font, int idx) {
        // Each character is 4 uint16 values (8 rows total)
        // First uint16: rows 0-1
        // Second uint16: rows 2-3
        // Third uint16: rows 4-5
        // Fourth uint16: rows 6-7
        
        // First uint16 (rows 0-1)
        draw_icn_rows(cr, x, y, font[idx]);
        
        // Second uint16 (rows 2-3)
        draw_icn_rows(cr, x, y + 2, font[idx + 1]);
        
        // Third uint16 (rows 4-5)
        draw_icn_rows(cr, x, y + 4, font[idx + 2]);
        
        // Fourth uint16 (rows 6-7)
        draw_icn_rows(cr, x, y + 6, font[idx + 3]);
        
        cr.fill();
    }
    
    private void draw_icn_rows(Cairo.Context cr, int x, int y, uint16 data) {
        // Extract the high byte (first row)
        uint8 row1 = (uint8)((data >> 8) & 0xFF);
        
        // Extract the low byte (second row)
        uint8 row2 = (uint8)(data & 0xFF);
        
        // Draw first row
        for (int col = 0; col < 8; col++) {
            if ((row1 & (1 << (7 - col))) != 0) {
                cr.rectangle(x + col, y, 1, 1);
            }
        }
        
        // Draw second row
        for (int col = 0; col < 8; col++) {
            if ((row2 & (1 << (7 - col))) != 0) {
                cr.rectangle(x + col, y + 1, 1, 1);
            }
        }
    }
    
    private void draw_date(Cairo.Context cr, int width, int height, NeralieTime neralie) {
        // Position for text at bottom of screen
        int x = (width / 2) - 52;
        int y = height - 16;
        
        var now = new DateTime.now_local();
        
        // Draw Arvelie date
        int year = now.get_year() - 2006;
        draw_bitmap_digit(cr, x, y, year / 10);
        draw_bitmap_digit(cr, x + CHARACTER_WIDTH, y, year % 10);
        x += CHARACTER_WIDTH * 2;
        
        // Month letter (A-Z representing months)
        int doty = now.get_day_of_year();
        int month = doty / 14; // Divide year into 26 "months" of 14 days
        char month_char = (char)('A' + month);
        draw_bitmap_letter(cr, x, y, month_char);
        x += CHARACTER_WIDTH;
        
        // Day (00-13)
        int day = doty % 14;
        draw_bitmap_digit(cr, x, y, day / 10);
        draw_bitmap_digit(cr, x + CHARACTER_WIDTH, y, day % 10);
        x += CHARACTER_WIDTH * 2 + 4; // Add space
        
        // Draw Neralie time in XXX:YYY format
        // Convert standard time to Neralie time
        int hours = now.get_hour();
        int minutes = now.get_minute();
        int seconds = now.get_second();
        
        // First digit (hundreds of pulse)
        int hundreds = (hours * 10) / 24; // Map 0-23 hours to 0-9
        draw_bitmap_digit(cr, x, y, hundreds);
        x += CHARACTER_WIDTH;
        
        // Second and third digits (pulse 00-99)
        int pulse = neralie.pulse;
        draw_bitmap_digit(cr, x, y, pulse / 10);
        draw_bitmap_digit(cr, x + CHARACTER_WIDTH, y, pulse % 10);
        x += CHARACTER_WIDTH * 2;
        
        // Decimals (as is)
        draw_bitmap_digit(cr, x, y, neralie.decimal1);
        draw_bitmap_digit(cr, x + CHARACTER_WIDTH, y, neralie.decimal2);
        x += CHARACTER_WIDTH * 2;
        draw_bitmap_digit(cr, x, y, neralie.decimal3);
    }
    
    private void draw_clock(Cairo.Context cr, int x1, int y1, int x2, int y2, NeralieTime neralie) {
        int width = x2 - x1;
        int height = y2 - y1;
        
        // Calculate the hundreds digit based on hour
        var now = new DateTime.now_local();
        int hours = now.get_hour();
        int hundreds = (hours * 10) / 24; // Map 0-23 hours to 0-9
        int full_pulse = hundreds * 100 + neralie.pulse;
        
        // Draw visual representation of Neralie time
        
        // Horizontal line for pulse (moves vertically)
        int y_pos = y1 + (int)(neralie.pulse * height / 100.0);
        draw_horizontal_line(cr, x1, x2, y_pos);
        
        // Digital display for pulse - positioned above the frame
        // Now showing all three digits
        draw_bitmap_digit(cr, x1 - 20, y1 - 18, hundreds);
        draw_bitmap_digit(cr, x1 - 12, y1 - 18, neralie.pulse / 10);
        draw_bitmap_digit(cr, x1 - 4, y1 - 18, neralie.pulse % 10);
        
        // Vertical line for first decimal (moves horizontally)
        int x_pos_1 = x1 + (int)(neralie.decimal1 * width / 10.0);
        draw_vertical_dotted_line(cr, y1, y2, x_pos_1);
        
        // Digital display for first decimal - positioned to the left of the frame
        draw_bitmap_digit(cr, x1 - 12, y_pos - 4, neralie.decimal1);
        
        // Second horizontal line for second decimal (moves vertically)
        y_pos = y1 + (int)(neralie.decimal2 * height / 10.0);
        draw_horizontal_line(cr, x1, x2, y_pos);
        
        // Digital display for second decimal - positioned to the right of the frame
        draw_bitmap_digit(cr, x2 + 2, y_pos - 4, neralie.decimal2);
        
        // Second vertical line for third decimal (moves horizontally)
        int x_pos_3 = x1 + (int)(neralie.decimal3 * width / 10.0);
        draw_vertical_line(cr, y1, y2, x_pos_3);
        
        // Digital display for third decimal - positioned above the frame
        draw_bitmap_digit(cr, x_pos_3 - 4, y1 - 9, neralie.decimal3);
    }
    
    public static int main(string[] args) {
        return new NeralieApp().run(args);
    }
}

// Class to hold Neralie time values
public class NeralieTime {
    public int pulse;     // 0-99 (main pulse)
    public int decimal1;  // 0-9 (first decimal)
    public int decimal2;  // 0-9 (second decimal)
    public int decimal3;  // 0-9 (third decimal)
    
    public string to_string() {
        return "%02d:%d%d%d".printf(pulse, decimal1, decimal2, decimal3);
    }
}