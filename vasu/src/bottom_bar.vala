// BottomToolbarComponent - manages the bottom toolbar with tools, filename, etc.
public class BottomToolbarComponent : Gtk.Box {
    private VasuData chr_data;
    private VasuEditorView editor_view;
    private VasuPreviewView preview_view;
    private FilenameComponent filename_component;
    private List<Gtk.Button> color_buttons;
    private List<Gtk.ToggleButton> tool_buttons;
    private List<ulong> color_button_handlers = new List<ulong>();
    private List<ulong> tool_button_handlers = new List<ulong>();
    
    // Delegate for drawing toolbar items
    private delegate void DrawFunc(Cairo.Context cr, int width, int height);
    
    // Signal to request file operations
    public signal void request_save();
    public signal void request_open();
    public signal void selected_color_changed();
    
    public BottomToolbarComponent(VasuData data, VasuEditorView editor, VasuPreviewView preview) {
        Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);
        
        chr_data = data;
        editor_view = editor;
        preview_view = preview;
        
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
        
        // 1. Color buttons (the 3 usable colors, excluding background)
        color_buttons = new List<Gtk.Button>();

        for (int i = 0; i < VasuData.COLORS_COUNT; i++) {
            int color_idx = i; // Capture for use in lambda
            if (color_idx == 0) continue;
            
            var color_item = create_toolbar_item(8, 8, (cr, width, height) => {
                cr.set_antialias(Cairo.Antialias.NONE);
                
                // Draw the color
                Gdk.RGBA color = chr_data.get_color(color_idx);
                cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
                
                if (chr_data.selected_color != color_idx) {
                    // Not selected - draw outlined shape
                    // Row 1
                    cr.rectangle(2, 1, 3, 1);
                    
                    // Row 2
                    cr.rectangle(1, 2, 1, 1);
                    cr.rectangle(5, 2, 1, 1);
                    
                    // Row 3
                    cr.rectangle(0, 3, 1, 3);
                    cr.rectangle(6, 3, 1, 3);
                    
                    // Row 6
                    cr.rectangle(1, 6, 1, 1);
                    cr.rectangle(5, 6, 1, 1);
                    
                    // Row 7
                    cr.rectangle(2, 7, 3, 1);
                    
                    cr.fill();
                } else {
                    // Selected - draw filled circle
                    // Row 1
                    cr.rectangle(2, 1, 3, 1);
                    
                    // Row 2
                    cr.rectangle(1, 2, 5, 1);
                    
                    // Row 3
                    cr.rectangle(0, 3, 7, 3);
                    
                    // Row 6
                    cr.rectangle(1, 6, 5, 1);
                    
                    // Row 7
                    cr.rectangle(2, 7, 3, 1);
                    cr.fill();
                }
            });
            
            if (color_idx == 3) {
                color_item.margin_end = 8;
            }
            
            // Set color selection behavior
            ulong color_handler_id = color_item.clicked.connect(() => {
                chr_data.selected_color = color_idx;
                selected_color_changed();
                
                // Force redraw of all color buttons to update their appearance
                foreach (var button in color_buttons) {
                    var drawing_area = button.get_data<Gtk.DrawingArea>("drawing-area");
                    if (drawing_area != null) {
                        drawing_area.queue_draw();
                    }
                }
            });
            color_button_handlers.append(color_handler_id);
            color_buttons.append(color_item);
            append(color_item);
        }
        
        // Create a list to track tool buttons for mutual exclusion
        tool_buttons = new List<Gtk.ToggleButton>();
        
        // 2. Pen tool
        var pen_tool = create_toolbar_item(8, 8, (cr, width, height) => {
            cr.set_antialias(Cairo.Antialias.NONE);

            // Draw pen icon
            Gdk.RGBA color = {};
            if (chr_data.selected_tool == 0) {
                // Selected color
                color = chr_data.get_color(2);
            } else {
                // Unselected color
                color = chr_data.get_color(1);
            }
            cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);

            // Pen body
            // Row 1
            cr.rectangle(1, 1, 1, 1);
            cr.rectangle(2, 1, 1, 1);
            cr.rectangle(3, 1, 1, 1);

            // Row 2
            cr.rectangle(1, 2, 1, 1);
            cr.rectangle(2, 2, 1, 1);
            cr.rectangle(4, 2, 1, 1);
            
            // Row 3
            cr.rectangle(1, 3, 1, 1);
            cr.rectangle(5, 3, 1, 1);

            // Row 4
            cr.rectangle(2, 4, 1, 1);
            cr.rectangle(6, 4, 1, 1);

            // Row 5
            cr.rectangle(3, 5, 1, 1);
            cr.rectangle(7, 5, 1, 1);

            // Row 6
            cr.rectangle(4, 6, 1, 1);
            cr.rectangle(7, 6, 1, 1);

            // Row 7
            cr.rectangle(5, 7, 1, 1);
            cr.rectangle(6, 7, 1, 1);
            cr.fill();
        });
        
        ulong pen_handler_id = pen_tool.clicked.connect(() => {
            // Uncheck all other tool buttons
            foreach (var button in tool_buttons) {
                if (button != pen_tool) {
                    button.set_active(false);
                }
            }
            
            // Only set if it's being activated
            if (pen_tool.get_active()) {
                chr_data.selected_tool = 0;
                queue_draw();
            } else {
                // If deactivated, reactivate it (can't have no tool selected)
                pen_tool.set_active(true);
            }
        });
        tool_button_handlers.append(pen_handler_id);
        
        pen_tool.set_active(true);
        tool_buttons.append(pen_tool);
        append(pen_tool);
        
        // 3. Cursor tool
        var cursor_tool = create_toolbar_item(8, 8, (cr, width, height) => {
            cr.set_antialias(Cairo.Antialias.NONE);

            // Draw cursor icon
            Gdk.RGBA color = {};
            if (chr_data.selected_tool == 1) {
                // Selected color
                color = chr_data.get_color(2);
            } else {
                // Unselected color
                color = chr_data.get_color(1);
            }
            cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
            
            // Arrow
            // Row 1
            cr.rectangle(1, 1, 1, 1);
            
            // Row 2
            cr.rectangle(1, 2, 1, 1);
            cr.rectangle(2, 2, 1, 1);
            
            // Row 3
            cr.rectangle(1, 3, 1, 1);
            cr.rectangle(2, 3, 1, 1);
            cr.rectangle(3, 3, 1, 1);
            
            // Row 4
            cr.rectangle(1, 4, 1, 1);
            cr.rectangle(2, 4, 1, 1);
            cr.rectangle(3, 4, 1, 1);
            cr.rectangle(4, 4, 1, 1);
            
            // Row 5
            cr.rectangle(1, 5, 1, 1);
            cr.rectangle(2, 5, 1, 1);
            cr.rectangle(3, 5, 1, 1);
            cr.rectangle(4, 5, 1, 1);
            cr.rectangle(5, 5, 1, 1);
            
            // Row 6
            cr.rectangle(1, 6, 1, 1);
            cr.rectangle(3, 6, 1, 1);

            // Row 7
            cr.rectangle(4, 7, 1, 1);

            cr.fill();
        });
        
        ulong cursor_handler_id = cursor_tool.clicked.connect(() => {
            // Uncheck all other tool buttons
            foreach (var button in tool_buttons) {
                if (button != cursor_tool) {
                    button.set_active(false);
                }
            }
            
            // Only set if it's being activated
            if (cursor_tool.get_active()) {
                chr_data.selected_tool = 1;
                queue_draw();
            } else {
                // If deactivated, reactivate it (can't have no tool selected)
                cursor_tool.set_active(true);
            }
        });
        tool_button_handlers.append(cursor_handler_id);
        tool_buttons.append(cursor_tool);
        append(cursor_tool);
        
        // 4. Zoom tool
        var zoom_tool = create_toolbar_item(8, 8, (cr, width, height) => {
            cr.set_antialias(Cairo.Antialias.NONE);
            
            // Draw zoom icon
            Gdk.RGBA color = {};
            if (chr_data.selected_tool == 2) {
                // Selected color
                color = chr_data.get_color(2);
            } else {
                // Unselected color
                color = chr_data.get_color(1);
            }
            cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
            
            // Row 1
            cr.rectangle(2, 1, 1, 1);
            cr.rectangle(3, 1, 1, 1);
            
            // Row 2
            cr.rectangle(1, 2, 1, 1);
            cr.rectangle(4, 2, 1, 1);
            
            // Row 3
            cr.rectangle(0, 3, 1, 1);
            cr.rectangle(5, 3, 1, 1);
            
            // Row 4
            cr.rectangle(0, 4, 1, 1);
            cr.rectangle(5, 4, 1, 1);
            
            // Row 5
            cr.rectangle(1, 5, 1, 1);
            cr.rectangle(4, 5, 1, 1);
            
            // Row 6
            cr.rectangle(2, 6, 1, 1);
            cr.rectangle(3, 6, 1, 1);
            cr.rectangle(5, 6, 1, 1);

            // Row 7
            cr.rectangle(6, 7, 1, 1);

            cr.fill();
        });
        
        zoom_tool.margin_end = 8;
        
        ulong zoom_handler_id = zoom_tool.clicked.connect(() => {
            // Uncheck all other tool buttons
            foreach (var button in tool_buttons) {
                if (button != zoom_tool) {
                    button.set_active(false);
                }
            }
            
            // Only set if it's being activated
            if (zoom_tool.get_active()) {
                chr_data.selected_tool = 2;
                queue_draw();
            } else {
                // If deactivated, reactivate it (can't have no tool selected)
                zoom_tool.set_active(true);
            }
        });
        tool_button_handlers.append(zoom_handler_id);
        tool_buttons.append(zoom_tool);
        append(zoom_tool);
        
        // 5. Filename component
        filename_component = new FilenameComponent(chr_data);
        filename_component.hexpand = true;
        filename_component.halign = Gtk.Align.START;
        append(filename_component);
        
        // 6. Selection tool (Clear button)
        var clear_tool = create_toolbar_button(8, 8, (cr, width, height) => {
            cr.set_antialias(Cairo.Antialias.NONE);
            
            // Draw selection tool icon
            Gdk.RGBA color = chr_data.get_color(1);
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
            editor_view.clear_editor();
            preview_view.clear_canvas();
            chr_data.filename = "untitled10x10.chr";
            queue_draw();
        });
        append(clear_tool);
        
        // 7. File open tool
        var file_open_tool = create_toolbar_button(8, 8, (cr, width, height) => {
            cr.set_antialias(Cairo.Antialias.NONE);
            
            // Draw open icon
            Gdk.RGBA color = chr_data.get_color(1);
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
        
        // 8. Save button
        var save_tool = create_toolbar_button(8, 8, (cr, width, height) => {
            cr.set_antialias(Cairo.Antialias.NONE);
            
            // Draw save icon
            Gdk.RGBA color = chr_data.get_color(1);
            cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
            
            // Row 1
            cr.rectangle(4, 1, 1, 1);
            
            // Row 2
            cr.rectangle(2, 2, 1, 1);
            cr.rectangle(4, 2, 1, 1);
            cr.rectangle(6, 2, 1, 1);
            
            // Row 3
            cr.rectangle(3, 3, 1, 1);
            cr.rectangle(5, 3, 1, 1);
            
            // Row 4
            cr.rectangle(1, 4, 2, 1);
            cr.rectangle(6, 4, 2, 1);
            
            // Row 5
            cr.rectangle(3, 5, 1, 1);
            cr.rectangle(5, 5, 1, 1);
            
            // Row 6
            cr.rectangle(2, 6, 1, 1);
            cr.rectangle(4, 6, 1, 1);
            cr.rectangle(6, 6, 1, 1);

            // Row 7
            cr.rectangle(4, 7, 1, 1);
            cr.fill();
        });
        
        save_tool.clicked.connect(() => {
            request_save();
            queue_draw();
        });
        append(save_tool);

        // Connect palette changes to update color buttons
        chr_data.palette_changed.connect(() => {
            foreach (var button in color_buttons) {
                var drawing_area = button.get_data<Gtk.DrawingArea>("drawing-area");
                if (drawing_area != null) {
                    drawing_area.queue_draw();
                }
            }
            
            foreach (var button in tool_buttons) {
                var drawing_area = button.get_data<Gtk.DrawingArea>("drawing-area");
                if (drawing_area != null) {
                    drawing_area.queue_draw();
                }
            }
            
            clear_tool.get_data<Gtk.DrawingArea>("drawing-area").queue_draw();
            file_open_tool.get_data<Gtk.DrawingArea>("drawing-area").queue_draw();
            save_tool.get_data<Gtk.DrawingArea>("drawing-area").queue_draw();
        });
        
        // Connect selected color changes
        chr_data.notify["selected_color"].connect(() => {
            foreach (var button in color_buttons) {
                var drawing_area = button.get_data<Gtk.DrawingArea>("drawing-area");
                if (drawing_area != null) {
                    drawing_area.queue_draw();
                }
            }
            
            foreach (var button in tool_buttons) {
                var drawing_area = button.get_data<Gtk.DrawingArea>("drawing-area");
                if (drawing_area != null) {
                    drawing_area.queue_draw();
                }
            }
            clear_tool.get_data<Gtk.DrawingArea>("drawing-area").queue_draw();
            file_open_tool.get_data<Gtk.DrawingArea>("drawing-area").queue_draw();
            save_tool.get_data<Gtk.DrawingArea>("drawing-area").queue_draw();
            selected_color_changed();
        });
        
        chr_data.notify["selected_tool"].connect(() => {
            // Update the active state of tool toggle buttons
            foreach (var button in tool_buttons) {
                // Get the tool index using button's position in list
                // This assumes buttons were added in order: pen (0), cursor (1), zoom (2)
                int button_index = tool_buttons.index(button);
                button.set_active(button_index == chr_data.selected_tool);
                
                // Force redraw
                var drawing_area = button.get_data<Gtk.DrawingArea>("drawing-area");
                if (drawing_area != null) {
                    drawing_area.queue_draw();
                }
            }
        });
    }
    
    public void update_tool_buttons() {
        // Update each tool button based on the selected tool
        int index = 0;
        foreach (var button in color_buttons) {
            // Force redraw of drawing area
            var drawing_area = button.get_data<Gtk.DrawingArea>("drawing-area");
            if (drawing_area != null) {
                if (index < color_button_handlers.length()) {
                    ulong handler_id = color_button_handlers.nth_data(index);
                    GLib.SignalHandler.block(button, handler_id);
                    
                    // Update the active state
                    drawing_area.queue_draw();
                    selected_color_changed();
                    
                    // Unblock the signal
                    GLib.SignalHandler.unblock(button, handler_id);
                }
            }
            
            index++;
        }
        
        foreach (var button in tool_buttons) {
            // Get the tool index for this button (based on position in list)
            int button_tool_index = index;
            bool should_be_active = button_tool_index == chr_data.selected_tool;
            
            // Only update if state differs to avoid triggering callbacks
            if (button.get_active() != should_be_active) {
                // Block the clicked signal to avoid triggering the event
                if (index < tool_button_handlers.length()) {
                    ulong handler_id = tool_button_handlers.nth_data(index);
                    GLib.SignalHandler.block(button, handler_id);
                    
                    // Update the active state
                    button.set_active(should_be_active);
                    
                    // Unblock the signal
                    GLib.SignalHandler.unblock(button, handler_id);
                }
            }
            
            // Force redraw of drawing area
            var drawing_area = button.get_data<Gtk.DrawingArea>("drawing-area");
            if (drawing_area != null) {
                drawing_area.queue_draw();
            }
            
            index++;
        }
    }
    
    public void refresh_ui() {
        // Force redraw of all tool buttons
        foreach (var button in tool_buttons) {
            var drawing_area = button.get_data<Gtk.DrawingArea>("drawing-area");
            if (drawing_area != null) {
                drawing_area.queue_draw();
            }
        }
        
        foreach (var button in color_buttons) {
            var drawing_area = button.get_data<Gtk.DrawingArea>("drawing-area");
            if (drawing_area != null) {
                drawing_area.queue_draw();
            }
        }
        
        queue_draw();
    }
    
    // Helper method to create toolbar toggle buttons
    private Gtk.ToggleButton create_toolbar_item(int width, int height, owned DrawFunc draw_func) {
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
        
        var button = new Gtk.ToggleButton();
        button.set_child(event_box);
        
        // Store drawing area in button data for later access
        button.set_data("drawing-area", drawing_area);
        
        return button;
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
    
    public void focus_filename() {
        filename_component.start_editing();
    }
}