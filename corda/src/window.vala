public class CordaWindow : Gtk.ApplicationWindow {
    private Gtk.DrawingArea drawing_area;
    private CordaState ruler_state;
    private Theme.Manager theme;
    
    public CordaWindow(Gtk.Application app) {
        Object(
            application: app,
            title: "Corda",
            default_width: CordaConstants.WINDOW_WIDTH,
            default_height: CordaConstants.WINDOW_HEIGHT,
            icon_name: "com.example.ruler",
            resizable: false
        );
                
        var _tmp = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        _tmp.visible = false;
        titlebar = _tmp;
        
        theme = Theme.Manager.get_default();
        theme.apply_to_display();
        setup_theme_management();
        theme.theme_changed.connect(() => {
            drawing_area.queue_draw();
        });
        
         // Load CSS
        var provider = new Gtk.CssProvider();
        provider.load_from_resource("/com/example/corda/style.css");
        
        // Apply CSS to the app
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        add_css_class("ruler-window");
        setup_ui();
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
    
    private void setup_ui() {
        // Initialize ruler state
        ruler_state = new CordaState();
        
        // Create main container with classic Mac-style 4px padding
        var main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        main_box.append(create_titlebar());
        this.set_child(main_box);

        // Create drawing area
        drawing_area = new Gtk.DrawingArea();
        drawing_area.set_draw_func(draw_rulers);
        drawing_area.set_content_width(CordaConstants.WINDOW_WIDTH);
        drawing_area.set_content_height(CordaConstants.WINDOW_HEIGHT);
        main_box.append(drawing_area);
        
        // Setup controllers
        setup_gesture_controllers();
    }
    
    private void setup_gesture_controllers() {
        // Setup gesture controller for horizontal dragging
        var drag_gesture = new Gtk.GestureDrag();
        drawing_area.add_controller(drag_gesture);
        
        drag_gesture.drag_begin.connect((x, y) => {
            // Check if click is on cm ruler (now at bottom)
            if (y >= CordaConstants.CM_RULER_Y && 
                y <= CordaConstants.CM_RULER_Y + CordaConstants.RULER_HEIGHT) {
                ruler_state.dragging_cm = true;
                ruler_state.drag_start_x = x;
                ruler_state.drag_start_cm_x = ruler_state.cm_x;
            }
            // Check if click is on inch ruler (now at top)
            else if (y >= CordaConstants.INCH_RULER_Y && 
                     y <= CordaConstants.INCH_RULER_Y + CordaConstants.RULER_HEIGHT) {
                ruler_state.dragging_inch = true;
                ruler_state.drag_start_x = x;
                ruler_state.drag_start_inch_x = ruler_state.inch_x;
            }
        });
        
        drag_gesture.drag_update.connect((x, y) => {
            if (ruler_state.dragging_cm) {
                // Round to integer values to ensure pixel-perfect rendering
                ruler_state.cm_x = Math.floor(ruler_state.drag_start_cm_x + x);
                ruler_state.inch_x = Math.floor(ruler_state.drag_start_cm_x + x);
                drawing_area.queue_draw();
            }
        });
        
        drag_gesture.drag_end.connect((x, y) => {
            ruler_state.dragging_cm = false;
            ruler_state.dragging_inch = false;
        });
    }
    
        
    private Gtk.Widget create_titlebar() {
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        
        // Create close button
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;
        close_button.margin_top = 8;
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
    
    private void draw_rulers(Gtk.DrawingArea da, Cairo.Context cr, int width, int height) {
        var sel_color = theme.get_color ("theme_bg");
        cr.set_source_rgb(sel_color.red, sel_color.green,  sel_color.blue);
        cr.paint();
        
        // Set line properties - pixel-perfect 1px lines for classic Mac look
        cr.set_line_width(1);
        cr.set_antialias(Cairo.Antialias.NONE);
        
        // Draw cm ruler with horizontal offset
        cr.save();
        // Ensure pixel-aligned positioning by rounding the translation
        cr.translate(Math.floor(ruler_state.cm_x) + 0.5, 0);
        CordaDrawHelper.draw_cm_ruler(cr, CordaConstants.CM_RULER_Y, width);
        cr.restore();
        
        // Draw inch ruler with horizontal offset
        cr.save();
        // Ensure pixel-aligned positioning by rounding the translation
        cr.translate(Math.floor(ruler_state.inch_x) + 0.5, 0);
        CordaDrawHelper.draw_inch_ruler(cr, CordaConstants.INCH_RULER_Y, width);
        cr.restore();
    }
}