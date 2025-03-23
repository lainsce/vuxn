/* donsol-theme.vala */
public class DonsolTheme {
    private static DonsolTheme? instance;
    public Theme.Manager theme_manager;
    
    private DonsolTheme() {
        theme_manager = Theme.Manager.get_default();
    }
    
    public static DonsolTheme get_default() {
        if (instance == null) {
            instance = new DonsolTheme();
        }
        return instance;
    }
    
    public void init() {
        theme_manager.load_color_mode();
        theme_manager.apply_to_display();
    }
    
    // Theme color getters for BLACK (maps to theme_fg)
    public float get_black_r() { 
        var color = theme_manager.get_color("theme_fg");
        return color.red;
    }
    
    public float get_black_g() { 
        var color = theme_manager.get_color("theme_fg");
        return color.green;
    }
    
    public float get_black_b() { 
        var color = theme_manager.get_color("theme_fg");
        return color.blue;
    }
    
    // Theme color getters for WHITE (maps to theme_bg)
    public float get_white_r() { 
        var color = theme_manager.get_color("theme_bg");
        return color.red;
    }
    
    public float get_white_g() { 
        var color = theme_manager.get_color("theme_bg");
        return color.green;
    }
    
    public float get_white_b() { 
        var color = theme_manager.get_color("theme_bg");
        return color.blue;
    }
    
    // Theme color getters for RED (maps to theme_accent)
    public float get_red_r() { 
        var color = theme_manager.get_color("theme_accent");
        return color.red;
    }
    
    public float get_red_g() { 
        var color = theme_manager.get_color("theme_accent");
        return color.green;
    }
    
    public float get_red_b() { 
        var color = theme_manager.get_color("theme_accent");
        return color.blue;
    }
    
    // Theme color getters for GRAY (mix of fg and bg)
    public float get_gray_r() { 
        var fg = theme_manager.get_color("theme_selection");
        return fg.red;
    }
    
    public float get_gray_g() { 
        var fg = theme_manager.get_color("theme_selection");
        return fg.green;
    }
    
    public float get_gray_b() { 
        var fg = theme_manager.get_color("theme_selection");
        return fg.blue;
    }
    
    // Toggle between 1-bit and 2-bit modes
    public void toggle_1bit_mode() {
        if (theme_manager.color_mode == Theme.ColorMode.ONE_BIT) {
            theme_manager.color_mode = Theme.ColorMode.TWO_BIT;
        } else {
            theme_manager.color_mode = Theme.ColorMode.ONE_BIT;
        }
        theme_manager.save_color_mode();
    }
}