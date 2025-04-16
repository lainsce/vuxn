public class ScreenColorPicker {
    private ColorPickerWindow window;
    private bool is_picking = false;
    
    // X11 helper functions
    [CCode (cname = "x11_init_display", cheader_filename = "x11_helper.h")]
    private extern static void* init_display();
    
    [CCode (cname = "x11_close_display", cheader_filename = "x11_helper.h")]
    private extern static void close_display(void* display);
    
    [CCode (cname = "x11_get_root_window", cheader_filename = "x11_helper.h")]
    private extern static ulong get_root_window(void* display);
    
    [CCode (cname = "X111RGBColor", cheader_filename = "x11_helper.h")]
    private struct X11RGBColor {
        public uint8 r;
        public uint8 g;
        public uint8 b;
    }
    
    [CCode (cname = "x11_get_pixel_color", cheader_filename = "x11_helper.h")]
    private extern static int get_pixel_color(void* display, ulong root_window, int x, int y, out X11RGBColor color);
    
    [CCode (cname = "x11_grab_pointer", cheader_filename = "x11_helper.h")]
    private extern static int grab_pointer(void* display, ulong root_window);
    
    [CCode (cname = "x11_ungrab_pointer", cheader_filename = "x11_helper.h")]
    private extern static void ungrab_pointer(void* display);
    
    [CCode (cname = "x11_wait_for_click", cheader_filename = "x11_helper.h")]
    private extern static int wait_for_click(void* display, ulong root_window, int timeout_ms, out int x, out int y);
    
    // X11 display and root window
    private void* x_display = null;
    private ulong x_root_window = 0;
    
    // Constructor
    public ScreenColorPicker(ColorPickerWindow win) {
        this.window = win;
        
        // Initialize X11 display
        x_display = init_display();
        if (x_display != null) {
            x_root_window = get_root_window(x_display);
        }
    }
    
    // Destructor
    ~ScreenColorPicker() {
        if (x_display != null) {
            close_display(x_display);
        }
    }
    
    // Start color picking mode
    public void start_picking() {
        if (is_picking || x_display == null) {
            return;
        }
        
        is_picking = true;
        
        // We need to run this in a separate thread to not block the UI
        new Thread<void*>("color-picker", () => {
            // Grab the pointer
            int grab_result = grab_pointer(x_display, x_root_window);
            if (grab_result != 1) {
                warning("Failed to grab pointer");
                return null;
            }
            
            // Wait for click
            int x, y;
            int click_result = wait_for_click(x_display, x_root_window, 10000, out x, out y);
            
            // Always ungrab pointer when done
            ungrab_pointer(x_display);
            
            if (click_result == 1) {
                // Got a click, get color
                X11RGBColor x11_color;
                int color_result = get_pixel_color(x_display, x_root_window, x, y, out x11_color);
                
                if (color_result == 1) {
                    // Update color on main thread
                    Idle.add(() => {
                        RgbColor color = { x11_color.r, x11_color.g, x11_color.b };
                        window.set_color_from_rgb(color);
                        stop_picking();
                        return false;
                    });
                }
            }
            
            return null;
        });
    }
    
    // Stop picking
    public void stop_picking() {
        if (is_picking && x_display != null) {
            ungrab_pointer(x_display);
        }
        is_picking = false;
    }
}