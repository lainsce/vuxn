// BottomToolbarComponent - manages the bottom toolbar with basic tools and filename
public class BottomToolbarComponent : Gtk.Box {
    private IconcharData char_data;
    private IconcharView viewer;
    private FilenameComponent filename_component;
    
    // Delegate for drawing toolbar items
    private delegate void DrawFunc(Cairo.Context cr, int width, int height);
    
    // Signal to request file operations
    public signal void request_open();
    
    public BottomToolbarComponent(IconcharData data, IconcharView view) {
        Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);
        
        char_data = data;
        viewer = view;
        
        add_css_class("status-bar");
        margin_start = 15;
        margin_end = 15;
        margin_top = 2;
        margin_bottom = 7;
        valign = Gtk.Align.CENTER;
        
        setup_ui();
    }
    
    private void setup_ui() {
        // Create toolbar items using Cairo drawing areas
        
        // 1. Filename component (centered)
        filename_component = new FilenameComponent(char_data);
        filename_component.hexpand = true;
        filename_component.halign = Gtk.Align.START;
        append(filename_component);
        
        // 2. Clear button
        var clear_tool = create_toolbar_button(8, 8, (cr, width, height) => {
            cr.set_antialias(Cairo.Antialias.NONE);
            
            // Draw selection tool icon
            Gdk.RGBA color = char_data.get_color(1);
            cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
            
            // Row 1
            cr.rectangle(1, 1, 7, 1);
            
            // Row 2
            cr.rectangle(1, 2, 1, 1);
            cr.rectangle(7, 2, 1, 1);
            
            // Row 3
            cr.rectangle(1, 3, 1, 1);
            cr.rectangle(7, 3, 1, 1);
            
            // Row 4
            cr.rectangle(1, 4, 1, 1);
            cr.rectangle(7, 4, 1, 1);
            
            // Row 5
            cr.rectangle(1, 5, 1, 1);
            cr.rectangle(6, 5, 1, 1);
            
            // Row 6
            cr.rectangle(1, 6, 1, 1);
            cr.rectangle(5, 6, 1, 1);
            cr.rectangle(7, 6, 1, 1);

            // Row 7
            cr.rectangle(1, 7, 4, 1);
            cr.rectangle(6, 7, 1, 1);
            cr.fill();
        });
        
        clear_tool.clicked.connect(() => {
            viewer.clear_view();
            char_data.filename = "untitled10x10.chr";
            queue_draw();
        });
        append(clear_tool);
        
        // 3. File open tool
        var file_open_tool = create_toolbar_button(8, 8, (cr, width, height) => {
            cr.set_antialias(Cairo.Antialias.NONE);
            
            // Draw open icon
            Gdk.RGBA color = char_data.get_color(1);
            cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
            
            // Row 1
            cr.rectangle(1, 1, 7, 1);
            
            // Row 2
            cr.rectangle(1, 2, 1, 1);
            cr.rectangle(3, 2, 1, 1);
            cr.rectangle(5, 2, 1, 1);
            cr.rectangle(7, 2, 1, 1);
            
            // Row 3
            cr.rectangle(1, 3, 1, 1);
            cr.rectangle(2, 3, 1, 1);
            cr.rectangle(4, 3, 1, 1);
            cr.rectangle(6, 3, 1, 1);
            cr.rectangle(7, 3, 1, 1);
            
            // Row 4
            cr.rectangle(1, 4, 1, 1);
            cr.rectangle(3, 4, 1, 1);
            cr.rectangle(5, 4, 1, 1);
            cr.rectangle(7, 4, 1, 1);
            
            // Row 5
            cr.rectangle(1, 5, 1, 1);
            cr.rectangle(2, 5, 1, 1);
            cr.rectangle(4, 5, 1, 1);
            cr.rectangle(6, 5, 1, 1);
            
            // Row 6
            cr.rectangle(1, 6, 1, 1);
            cr.rectangle(3, 6, 1, 1);
            cr.rectangle(5, 6, 1, 1);
            cr.rectangle(7, 6, 1, 1);

            // Row 7
            cr.rectangle(1, 7, 4, 1);
            cr.rectangle(6, 7, 1, 1);
            cr.fill();
        });
        
        file_open_tool.margin_end = 8;
        
        file_open_tool.clicked.connect(() => {
            request_open();
            queue_draw();
        });
        append(file_open_tool);

        // Connect palette changes to update toolbar buttons
        char_data.palette_changed.connect(() => {
            clear_tool.get_data<Gtk.DrawingArea>("drawing-area").queue_draw();
            file_open_tool.get_data<Gtk.DrawingArea>("drawing-area").queue_draw();
        });
    }
    
    // Helper method to create regular toolbar buttons
    private Gtk.Button create_toolbar_button(int width, int height, owned DrawFunc draw_func) {
        var drawing_area = new Gtk.DrawingArea();
        drawing_area.set_size_request(width, height);
        drawing_area.set_draw_func((area, cr, w, h) => {
            draw_func(cr, w, h);
        });
        
        var click_gesture = new Gtk.GestureClick();
        drawing_area.add_controller(click_gesture);
        
        // Add the drawing area to a container
        var event_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        event_box.append(drawing_area);
        
        // Store the drawing area for redrawing
        click_gesture.set_data("drawing-area", drawing_area);
        click_gesture.set_data("container", event_box);
        
        var button = new Gtk.Button();
        button.set_child(event_box);
        
        // Store drawing area in button data for later access
        button.set_data("drawing-area", drawing_area);
        
        return button;
    }
    
    // Public method to focus the filename component
    public void focus_filename() {
        filename_component.start_editing();
    }
}