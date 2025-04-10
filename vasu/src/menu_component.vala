// MenuComponent - manages application menus
public class MenuComponent : Gtk.Box {
    private VasuData chr_data;
    private VasuEditorView editor_view;
    private VasuPreviewView preview_view;
    private TopBarComponent top_bar;
    private Gtk.PopoverMenuBar menubar;
    
    // Signals that will be connected to main window
    public signal void request_save();
    public signal void request_open();
    public signal void request_rename();
    public signal void request_exit();
    public signal void tool_or_color_changed();
    
    // Action group for window actions
    private GLib.SimpleActionGroup action_group;
    
    public MenuComponent(VasuData data, VasuEditorView editor, VasuPreviewView preview, TopBarComponent top_bar) {
        Object(orientation: Gtk.Orientation.VERTICAL, spacing: 0);
        
        chr_data = data;
        editor_view = editor;
        preview_view = preview;

        margin_start = 4;
        margin_end = 8;
        margin_top = 9;
        margin_bottom = 0;
        
        // Create the action group first
        action_group = new GLib.SimpleActionGroup();
        
        // Setup the menu
        setup_menu();
    }
    
    private void setup_menu() {
        // Create a menu model
        var menu_model = create_menu_model();
        
        // Create the menu bar
        menubar = new Gtk.PopoverMenuBar.from_model(menu_model);
        menubar.add_css_class("menubar");
        
        // Set up the appearance
        menubar.halign = Gtk.Align.START;
        menubar.valign = Gtk.Align.START;
        
        // Add menubar to this component
        append(menubar);
        
        // Set up action handlers
        add_actions();
    }
    
    private GLib.MenuModel create_menu_model() {
        var menu_bar = new GLib.Menu();
        
        // File menu
        var file_menu = new GLib.Menu();
        file_menu.append("About…", "app.about");
        file_menu.append("New (Ctrl-N)", "app.new");
        file_menu.append("Rename (Ctrl-R)", "app.rename");
        file_menu.append("Open (Ctrl-O)", "app.open");
        file_menu.append("Save (Ctrl-S)", "app.save");
        file_menu.append("Exit (Ctrl-Q)", "app.exit");
        menu_bar.append_submenu("File", file_menu);
        
        // Edit menu
        var edit_menu = new GLib.Menu();
        edit_menu.append("Copy (Ctrl-C)", "app.copy");
        edit_menu.append("Paste (Ctrl-V)", "app.paste");
        edit_menu.append("Cut (Ctrl-X)", "app.cut");
        edit_menu.append("Erase", "app.erase");
        edit_menu.append("Invert (Ctrl-I)", "app.invert");
        edit_menu.append("Colorize (Ctrl-K)", "app.colorize");
        edit_menu.append("Mirror Horizontal", "app.mirror-h");
        edit_menu.append("Mirror Vertical", "app.mirror-v");
        menu_bar.append_submenu("Edit", edit_menu);
        
        // View menu
        var view_menu = new GLib.Menu();
        view_menu.append("Zoom", "app.zoom");
        view_menu.append("Shift Horizontal", "app.shift-h");
        view_menu.append("Shift Vertical", "app.shift-v");
        view_menu.append("Shift Reset", "app.shift-reset");
        view_menu.append("Select All (Ctrl-A)", "app.select-all");
        menu_bar.append_submenu("View", view_menu);
        
        // Tool menu
        var tool_menu = new GLib.Menu();
        tool_menu.append("Brush (Ctrl-B)", "app.tool-brush");
        tool_menu.append("Cursor (Ctrl-T)", "app.tool-cursor");
        tool_menu.append("Zoom (Ctrl-E)", "app.tool-zoom");
        tool_menu.append("Background (Ctrl-0)", "app.color-0");
        tool_menu.append("Color 1 (Ctrl-1)", "app.color-1");
        tool_menu.append("Color 2 (Ctrl-2)", "app.color-2");
        tool_menu.append("Color 3 (Ctrl-3)", "app.color-3");
        menu_bar.append_submenu("Tool", tool_menu);
        
        return menu_bar;
    }
    
    private void add_actions() {
        // Get the application
        var app = GLib.Application.get_default() as Gtk.Application;
        if (app == null) return;
        
        // File menu actions
        var about_action = new SimpleAction("about", null);
        about_action.activate.connect(() => {
            show_about_dialog();
        });
        action_group.add_action(about_action);
        
        var new_action = new SimpleAction("new", null);
        new_action.activate.connect(() => {
            editor_view.clear_editor();
            preview_view.clear_canvas();
            chr_data.filename = "untitled10x10.chr";
        });
        action_group.add_action(new_action);
        
        var rename_action = new SimpleAction("rename", null);
        rename_action.activate.connect(() => {
            request_rename();
        });
        action_group.add_action(rename_action);
        
        var open_action = new SimpleAction("open", null);
        open_action.activate.connect(() => {
            request_open();
        });
        action_group.add_action(open_action);
        
        var save_action = new SimpleAction("save", null);
        save_action.activate.connect(() => {
            request_save();
        });
        action_group.add_action(save_action);
        
        var exit_action = new SimpleAction("exit", null);
        exit_action.activate.connect(() => {
            request_exit();
        });
        action_group.add_action(exit_action);
        
        // Edit menu actions
        var copy_action = new SimpleAction("copy", null);
        copy_action.activate.connect(() => {
            copy_selected_tile();
        });
        action_group.add_action(copy_action);
        
        var paste_action = new SimpleAction("paste", null);
        paste_action.activate.connect(() => {
            paste_to_selected_tile();
        });
        action_group.add_action(paste_action);
        
        var cut_action = new SimpleAction("cut", null);
        cut_action.activate.connect(() => {
            cut_selected_tile();
        });
        action_group.add_action(cut_action);
        
        var erase_action = new SimpleAction("erase", null);
        erase_action.activate.connect(() => {
            erase_selected_tile();
        });
        action_group.add_action(erase_action);
        
        var invert_action = new SimpleAction("invert", null);
        invert_action.activate.connect(() => {
            invert_selected_tile();
        });
        action_group.add_action(invert_action);
        
        var colorize_action = new SimpleAction("colorize", null);
        colorize_action.activate.connect(() => {
            colorize_selected_tile();
        });
        action_group.add_action(colorize_action);
        
        var mirror_h_action = new SimpleAction("mirror-h", null);
        mirror_h_action.activate.connect(() => {
            chr_data.mirror_horizontal = !chr_data.mirror_horizontal;
        });
        action_group.add_action(mirror_h_action);
        
        var mirror_v_action = new SimpleAction("mirror-v", null);
        mirror_v_action.activate.connect(() => {
            chr_data.mirror_vertical = !chr_data.mirror_vertical;
        });
        action_group.add_action(mirror_v_action);
        
        // View menu actions
        var zoom_action = new SimpleAction("zoom", null);
        zoom_action.activate.connect(() => {
            toggle_zoom();
        });
        action_group.add_action(zoom_action);
        
        var shift_h_action = new SimpleAction("shift-h", null);
        shift_h_action.activate.connect(() => {
            chr_data.shift_horizontal();
            editor_view.update_from_current_tile();
        });
        action_group.add_action(shift_h_action);
        
        var shift_v_action = new SimpleAction("shift-v", null);
        shift_v_action.activate.connect(() => {
            chr_data.shift_vertical();
            editor_view.update_from_current_tile();
        });
        action_group.add_action(shift_v_action);
        
        var shift_reset_action = new SimpleAction("shift-reset", null);
        shift_reset_action.activate.connect(() => {
            chr_data.reset_shift();
            editor_view.update_from_current_tile();
            
            // Visual shifts in the top bar component (if any)
            if (top_bar != null) {
                top_bar.shift_x = 0;
                top_bar.shift_y = 0;
                
                if (top_bar.sprite_view_area != null) {
                    top_bar.sprite_view_area.queue_draw();
                }
            }
        });
        action_group.add_action(shift_reset_action);
        
        var select_all_action = new SimpleAction("select-all", null);
        select_all_action.activate.connect(() => {
            select_all_tiles();
        });
        action_group.add_action(select_all_action);
        
        // Tool menu actions
        var tool_brush_action = new SimpleAction("tool-brush", null);
        tool_brush_action.activate.connect(() => {
            chr_data.selected_tool = 0; // Pen tool
            tool_or_color_changed();
        });
        action_group.add_action(tool_brush_action);
        
        var tool_cursor_action = new SimpleAction("tool-cursor", null);
        tool_cursor_action.activate.connect(() => {
            chr_data.selected_tool = 1; // Cursor tool
            tool_or_color_changed();
        });
        action_group.add_action(tool_cursor_action);
        
        var tool_zoom_action = new SimpleAction("tool-zoom", null);
        tool_zoom_action.activate.connect(() => {
            chr_data.selected_tool = 2; // Zoom tool
            tool_or_color_changed();
        });
        action_group.add_action(tool_zoom_action);
        
        // Color selection actions
        var color_0_action = new SimpleAction("color-0", null);
        color_0_action.activate.connect(() => {
            chr_data.selected_color = 0; // Background color
            tool_or_color_changed();
        });
        action_group.add_action(color_0_action);
        
        var color_1_action = new SimpleAction("color-1", null);
        color_1_action.activate.connect(() => {
            chr_data.selected_color = 1; // Color 1
            tool_or_color_changed();
        });
        action_group.add_action(color_1_action);
        
        var color_2_action = new SimpleAction("color-2", null);
        color_2_action.activate.connect(() => {
            chr_data.selected_color = 2; // Color 2
            tool_or_color_changed();
        });
        action_group.add_action(color_2_action);
        
        var color_3_action = new SimpleAction("color-3", null);
        color_3_action.activate.connect(() => {
            chr_data.selected_color = 3; // Color 3
            tool_or_color_changed();
        });
        action_group.add_action(color_3_action);
        
        // Add the action group to the application
        app.set_action_group(action_group);
        
        // When the widget is attached to a window, insert the action group
        realize.connect(() => {
            var window = get_root() as Gtk.Window;
            if (window != null) {
                window.insert_action_group("app", action_group);
            }
        });
    }
    
    // Implementation of menu actions
    
    private void show_about_dialog() {
        var about_dialog = new Gtk.AboutDialog();
        about_dialog.set_transient_for(get_root() as Gtk.Window);
        about_dialog.set_modal(true);
        
        about_dialog.program_name = "Vasu";
        about_dialog.version = "1.0";
        about_dialog.copyright = "© 2025";
        about_dialog.comments = "A tiny character/sprite editor";
        
        about_dialog.present();
    }
    
    // Clipboard for copy/paste operations
    private int[,] clipboard_tile = null;
    
    private void copy_selected_tile() {
        // Get the selected tile
        int tile_x = editor_view.selected_tile_x;
        int tile_y = editor_view.selected_tile_y;
        
        // Create a new tile for the clipboard
        clipboard_tile = new int[8, 8];
        
        // Copy the selected tile data to the clipboard
        for (int y = 0; y < 8; y++) {
            for (int x = 0; x < 8; x++) {
                int editor_x = tile_x * 8 + x;
                int editor_y = tile_y * 8 + y;
                int color = editor_view.get_pixel(editor_x, editor_y);
                clipboard_tile[x, y] = color;
            }
        }
    }
    
    private void paste_to_selected_tile() {
        if (clipboard_tile == null) return;
        
        // Get the selected tile
        int tile_x = editor_view.selected_tile_x;
        int tile_y = editor_view.selected_tile_y;
        
        // Paste the clipboard data to the selected tile
        for (int y = 0; y < 8; y++) {
            for (int x = 0; x < 8; x++) {
                int editor_x = tile_x * 8 + x;
                int editor_y = tile_y * 8 + y;
                int color = clipboard_tile[x, y];
                editor_view.set_pixel(editor_x, editor_y, color);
            }
        }
        
        // If this is the currently active tile, update the CHR data as well
        if (tile_x == 0 && tile_y == 0) {
            for (int y = 0; y < 8; y++) {
                for (int x = 0; x < 8; x++) {
                    chr_data.set_pixel(x, y, clipboard_tile[x, y]);
                }
            }
        }
    }
    
    private void cut_selected_tile() {
        // First copy the tile
        copy_selected_tile();
        
        // Then clear it
        erase_selected_tile();
    }
    
    private void erase_selected_tile() {
        // Get the selected tile
        int tile_x = editor_view.selected_tile_x;
        int tile_y = editor_view.selected_tile_y;
        
        // Clear the selected tile
        for (int y = 0; y < 8; y++) {
            for (int x = 0; x < 8; x++) {
                int editor_x = tile_x * 8 + x;
                int editor_y = tile_y * 8 + y;
                editor_view.set_pixel(editor_x, editor_y, 0); // Set to background color
            }
        }
        
        // If this is the currently active tile, update the CHR data as well
        if (tile_x == 0 && tile_y == 0) {
            chr_data.clear_tile();
        }
    }
    
    private void invert_selected_tile() {
        // Get the selected tile
        int tile_x = editor_view.selected_tile_x;
        int tile_y = editor_view.selected_tile_y;
        
        // Invert the selected tile
        for (int y = 0; y < 8; y++) {
            for (int x = 0; x < 8; x++) {
                int editor_x = tile_x * 8 + x;
                int editor_y = tile_y * 8 + y;
                int color = editor_view.get_pixel(editor_x, editor_y);
                
                // Invert the color (0->3, 1->2, 2->1, 3->0)
                int inverted_color = 3 - color;
                
                editor_view.set_pixel(editor_x, editor_y, inverted_color);
            }
        }
        
        // If this is the currently active tile, update the CHR data as well
        if (tile_x == 0 && tile_y == 0) {
            for (int y = 0; y < 8; y++) {
                for (int x = 0; x < 8; x++) {
                    int color = chr_data.get_pixel(x, y);
                    int inverted_color = 3 - color;
                    chr_data.set_pixel(x, y, inverted_color);
                }
            }
        }
    }
    
    private void colorize_selected_tile() {
        // Get the selected tile
        int tile_x = editor_view.selected_tile_x;
        int tile_y = editor_view.selected_tile_y;
        
        // Get the current selected color
        int new_color = chr_data.selected_color;
        
        // Colorize the selected tile
        for (int y = 0; y < 8; y++) {
            for (int x = 0; x < 8; x++) {
                int editor_x = tile_x * 8 + x;
                int editor_y = tile_y * 8 + y;
                int color = editor_view.get_pixel(editor_x, editor_y);
                
                // Only change non-transparent pixels
                if (color != 0) {
                    editor_view.set_pixel(editor_x, editor_y, new_color);
                }
            }
        }
        
        // If this is the currently active tile, update the CHR data as well
        if (tile_x == 0 && tile_y == 0) {
            for (int y = 0; y < 8; y++) {
                for (int x = 0; x < 8; x++) {
                    int color = chr_data.get_pixel(x, y);
                    if (color != 0) {
                        chr_data.set_pixel(x, y, new_color);
                    }
                }
            }
        }
    }
    
    private void toggle_zoom() {
        // Toggle zoom mode
        if (chr_data.zoom_level == 8) {
            chr_data.zoom_level = 16;
        } else {
            chr_data.zoom_level = 8;
        }
        
        // Force redraw
        editor_view.queue_draw();
    }
    
    private void select_all_tiles() {
        // This function would typically select all tiles for a multi-tile operation
        // For now, we'll just select the first tile
        editor_view.select_tile(0, 0);
    }
}