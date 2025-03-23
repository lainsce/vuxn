/* window.vala
 *
 * Main window for the drawing application
 */
public class Window : Gtk.ApplicationWindow {
    private Gtk.DrawingArea drawing_area;
    private Gtk.ScrolledWindow scrolled_window;
    private Gtk.Box main_box;
    private Gtk.Box filename_box;
    private Gtk.Box paned;
    private Gtk.Box tool_bar;

    private Gtk.Button resize_handle;
    private Gtk.Label dimensions_label;
    private bool is_resizing = false;
    private int resize_start_x = 0;
    private int resize_start_y = 0;
    private int resize_start_width = 0;
    private int resize_start_height = 0;

    private DrawingManager drawing_manager;
    private double zoom_level = 1.0;
    private bool zoom_mode = false;
    private const int TILE_SIZE = 12;
    private const int DEFAULT_TILES_WIDTH = 30;
    private const int DEFAULT_TILES_HEIGHT = 24;

    // Track file state
    private string current_filename = "no_name.tga";
    private bool has_unsaved_changes = false;
    private Gtk.Label filename_label;

    private Theme.Manager theme;

    public Window(Gtk.Application app) {
        Object(application: app);

        title = "Voodle";
        set_size_request(800, 570);
        resizable = false;
        add_css_class("window");

        // Load CSS provider
        var provider = new Gtk.CssProvider();
        provider.load_from_resource("/com/example/voodle/style.css");

        // Apply the CSS to the default display
        Gtk.StyleContext.add_provider_for_display(
                                                  Gdk.Display.get_default(),
                                                  provider,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 10
        );

        // Initialize the drawing manager
        drawing_manager = new DrawingManager(
            DEFAULT_TILES_WIDTH * TILE_SIZE,
            DEFAULT_TILES_HEIGHT * TILE_SIZE
        );

        // Connect to drawing manager's changed signal
        drawing_manager.changed.connect(() => {
            if (drawing_area != null) {
                drawing_area.queue_draw();
            }
        });

        main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);

        main_box.prepend(create_titlebar());

        // Create header bar with menu
        setup_tool_bar();

        // Create main container
        set_child(main_box);

        // Create the layout
        paned = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        paned.vexpand = true;
        main_box.append(paned);

        // Create the tools box
        var tools_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        tools_box.add_css_class("tool-box");
        tools_box.valign = Gtk.Align.START;
        tools_box.margin_start = 8;
        tools_box.margin_end = 8;
        tools_box.margin_top = 8;
        tools_box.margin_bottom = 8;
        paned.append(tools_box);

        // Create the tools UI
        setup_tools_ui(tools_box);

        // Create the drawing area
        setup_drawing_area();
        drawing_area.queue_draw();

        // Create a scrolled window for the drawing area
        scrolled_window = new Gtk.ScrolledWindow();
        scrolled_window.set_child(filename_box);
        paned.append(scrolled_window);

        // Set up close confirmation
        close_request.connect(() => {
            if (has_unsaved_changes) {
                return show_save_confirmation("Quit without saving?");
            }
            return false;
        });

        theme = Theme.Manager.get_default();
        theme.apply_to_display();
        setup_theme_management();
        theme.theme_changed.connect(drawing_area.queue_draw);

        // Set up keyboard shortcuts
        setup_keyboard_controls();
    }

    private void setup_keyboard_controls() {
        // Create a key event controller
        var key_controller = new Gtk.EventControllerKey();
        main_box.add_controller(key_controller);

        // Connect to key-pressed signal
        key_controller.key_pressed.connect((keyval, keycode, state) => {
            // Handle Enter key for applying magic wand selection
            if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
                if (drawing_manager.current_tool == Tool.MAGIC_WAND && drawing_manager.has_selection) {
                    drawing_manager.apply_to_selection();
                    mark_as_changed();
                    return true; // Event handled
                }
            }

            // Handle escape key to cancel selection
            if (keyval == Gdk.Key.Escape) {
                if (drawing_manager.current_tool == Tool.MAGIC_WAND && drawing_manager.has_selection) {
                    drawing_manager.clear_selection();
                    return true; // Event handled
                }
            }

            return false; // Event not handled
        });
    }

    // Title bar
    private Gtk.Widget create_titlebar() {
        // Create classic Mac-style title bar
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = 800;
        title_bar.add_css_class("title-bar");

        // Close button on the left
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;
        close_button.clicked.connect(() => {
            this.close();
        });

        var title_label = new Gtk.Label("Voodle");
        title_label.add_css_class("title-box");
        title_label.hexpand = true;
        title_label.valign = Gtk.Align.CENTER;
        title_label.halign = Gtk.Align.CENTER;

        title_bar.append(close_button);
        title_bar.append(title_label);

        var winhandle = new Gtk.WindowHandle();
        winhandle.set_child(title_bar);

        // Main layout
        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        vbox.append(winhandle);

        return vbox;
    }

    private void setup_theme_management() {
        // Force initial theme load
        var theme_file = GLib.Path.build_filename(Environment.get_home_dir(), ".theme");

        // Set up the check
        GLib.Timeout.add(10, () => {
            if (FileUtils.test(theme_file, FileTest.EXISTS)) {
                try {
                    theme.load_theme_from_file(theme_file);
                } catch (Error e) {
                    warning("Theme load failed: %s", e.message);
                }
            }
            return true; // Continue the timeout
        });
    }

    private void update_window_title() {
        string modified_indicator = has_unsaved_changes ? "*" : "";
        title = @"$(current_filename)$(modified_indicator)";
        filename_label.label = @"$(current_filename)$(modified_indicator)";
    }

    private void mark_as_changed() {
        has_unsaved_changes = true;
        update_window_title();
    }

    // Dialog methods
    private bool show_save_confirmation(string message, owned GLib.Callback? callback = null) {
        var dialog = new Gtk.MessageDialog(
                                           this,
                                           Gtk.DialogFlags.MODAL,
                                           Gtk.MessageType.WARNING,
                                           Gtk.ButtonsType.NONE,
                                           message
        );
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL);
        dialog.add_button("Discard", Gtk.ResponseType.REJECT);
        dialog.add_button("Save", Gtk.ResponseType.ACCEPT);

        dialog.response.connect((response_id) => {
            switch (response_id) {
                case Gtk.ResponseType.ACCEPT :
                    // Save and then continue with the callback
                    var save_dialog = new Gtk.FileChooserDialog(
                                                                "Save Image", this, Gtk.FileChooserAction.SAVE,
                                                                "_Cancel", Gtk.ResponseType.CANCEL,
                                                                "_Save", Gtk.ResponseType.ACCEPT
                    );

                    // Set up filters and defaults
                    var filter = new Gtk.FileFilter();
                    filter.set_filter_name("TGA files");
                    filter.add_pattern("*.tga");
                    save_dialog.add_filter(filter);

                    save_dialog.set_current_name(current_filename);

                    save_dialog.response.connect((save_response) => {
                    if (save_response == Gtk.ResponseType.ACCEPT) {
                        string filename = save_dialog.get_file().get_path();
                        if (!filename.has_suffix(".tga")) {
                            filename += ".tga";
                        }

                        TgaUtils.save_tga(filename, drawing_manager.surface);

                        // Update filename and window title
                        current_filename = GLib.Path.get_basename(filename);
                        filename_label.set_text(current_filename);
                        has_unsaved_changes = false;
                        update_window_title();

                        // Execute the callback after saving
                        if (callback != null) {
                            callback();
                        }
                    }
                    save_dialog.destroy();
                });

                    save_dialog.present();
                    break;

                case Gtk.ResponseType.REJECT:
                    // Discard changes and continue
                    has_unsaved_changes = false; // Clear the unsaved flag
                    if (callback != null) {
                        callback();
                    } else {
                        // If no callback, explicitly close the window
                        this.destroy();
                    }
                    break;

                case Gtk.ResponseType.CANCEL:
                    // Do nothing
                    break;
            }
            dialog.destroy();
        });

        dialog.present();
        return true; // Prevent the window from closing immediately
    }

    // File operations
    private void create_new_image() {
        drawing_manager.clear_surface();
        has_unsaved_changes = false;
        current_filename = "no_name.tga";
        update_window_title();
        filename_label.set_text(current_filename);
    }

    private void new_image() {
        if (has_unsaved_changes) {
            create_new_image();
        } else {
            create_new_image();
        }
    }

    private void save_image() {
        var dialog = new Gtk.FileChooserDialog(
                                               "Save Image", this, Gtk.FileChooserAction.SAVE,
                                               "_Cancel", Gtk.ResponseType.CANCEL,
                                               "_Save", Gtk.ResponseType.ACCEPT
        );

        var filter = new Gtk.FileFilter();
        filter.set_filter_name("TGA files");
        filter.add_pattern("*.tga");
        dialog.add_filter(filter);

        if (current_filename != "no_name.tga") {
            dialog.set_current_name(current_filename);
        } else {
            dialog.set_current_name(current_filename);
        }

        dialog.response.connect((response_id) => {
            if (response_id == Gtk.ResponseType.ACCEPT) {
                string filename = dialog.get_file().get_path();
                if (!filename.has_suffix(".tga")) {
                    filename += ".tga";
                }

                TgaUtils.save_tga(filename, drawing_manager.surface);

                // Update filename and window title
                current_filename = GLib.Path.get_basename(filename);
                filename_label.set_text(current_filename);
                has_unsaved_changes = false;
                update_window_title();
            }
            dialog.destroy();
        });

        dialog.present();
    }

    private void show_load_dialog() {
        var dialog = new Gtk.FileChooserDialog(
                                               "Open Image", this, Gtk.FileChooserAction.OPEN,
                                               "_Cancel", Gtk.ResponseType.CANCEL,
                                               "_Open", Gtk.ResponseType.ACCEPT
        );

        var filter = new Gtk.FileFilter();
        filter.set_filter_name("TGA files");
        filter.add_pattern("*.tga");
        dialog.add_filter(filter);

        dialog.response.connect((response_id) => {
            if (response_id == Gtk.ResponseType.ACCEPT) {
                string filename = dialog.get_file().get_path();

                // Load the TGA file
                Cairo.ImageSurface? new_surface = TgaUtils.load_tga(filename, drawing_manager.surface);

                if (new_surface != null) {
                    // If dimensions changed, update drawing manager
                    if (new_surface != drawing_manager.surface) {
                        drawing_manager.surface = new_surface;
                        drawing_area.set_content_width((int) (new_surface.get_width() * zoom_level));
                        drawing_area.set_content_height((int) (new_surface.get_height() * zoom_level));
                    }

                    // Update filename and window title
                    current_filename = GLib.Path.get_basename(filename);
                    filename_label.set_text(current_filename);
                    has_unsaved_changes = false;
                    update_window_title();

                    // Request redraw
                    drawing_area.queue_draw();
                }
            }
            dialog.destroy();
        });

        dialog.present();
    }

    private void load_image() {
        if (has_unsaved_changes) {
            show_load_dialog();
        } else {
            show_load_dialog();
        }
    }

    private void rename_file() {
        var dialog = new Gtk.Dialog.with_buttons(
                                                 "Rename File",
                                                 this,
                                                 Gtk.DialogFlags.MODAL,
                                                 "_Cancel",
                                                 Gtk.ResponseType.CANCEL,
                                                 "_Rename",
                                                 Gtk.ResponseType.ACCEPT
        );

        var content_area = dialog.get_content_area();
        content_area.set_spacing(4);
        content_area.margin_start = 8;
        content_area.margin_end = 8;
        content_area.margin_top = 8;
        content_area.margin_bottom = 8;

        var entry = new Gtk.Entry();
        entry.set_text(current_filename);
        entry.set_activates_default(true);
        content_area.append(entry);

        dialog.set_default_response(Gtk.ResponseType.ACCEPT);

        dialog.response.connect((response_id) => {
            if (response_id == Gtk.ResponseType.ACCEPT) {
                string new_name = entry.get_text();
                if (new_name != "") {
                    if (!new_name.has_suffix(".tga")) {
                        new_name += ".tga";
                    }
                    current_filename = new_name;
                    filename_label.set_text(current_filename);
                    update_window_title();
                }
            }
            dialog.destroy();
        });

        dialog.present();
    }

    private void setup_drawing_area() {
        // Add filename display
        filename_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        filename_box.hexpand = true;
        filename_box.vexpand = true;

        filename_label = new Gtk.Label(current_filename) {
            xalign = 0,
            margin_start = 4,
            margin_top = 8,
            halign = Gtk.Align.START,
            valign = Gtk.Align.START
        };
        filename_label.add_css_class("file-name");
        filename_box.append(filename_label);

        // Create a vertical box to stack the label and drawing area
        var drawing_stack = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        drawing_stack.hexpand = true;
        drawing_stack.vexpand = true;
        drawing_stack.valign = Gtk.Align.CENTER;
        drawing_stack.halign = Gtk.Align.CENTER;

        // Create and add the dimensions label at the top
        dimensions_label = new Gtk.Label(null);
        dimensions_label.add_css_class("dimensions-label");
        update_dimensions_label();
        dimensions_label.halign = Gtk.Align.START;
        dimensions_label.valign = Gtk.Align.START;

        // Add the label to the top of the vertical stack
        drawing_stack.append(dimensions_label);

        // Create an overlay just for the drawing area and resize handle
        var overlay = new Gtk.Overlay();

        // Create the drawing area
        drawing_area = new Gtk.DrawingArea();
        drawing_area.hexpand = true;
        drawing_area.vexpand = true;
        drawing_area.valign = Gtk.Align.CENTER;
        drawing_area.halign = Gtk.Align.CENTER;

        // Set content size based on tiles (width x height)
        drawing_area.set_content_width(DEFAULT_TILES_WIDTH * TILE_SIZE);
        drawing_area.set_content_height(DEFAULT_TILES_HEIGHT * TILE_SIZE);

        // Set the drawing area as the main content of the overlay
        overlay.set_child(drawing_area);

        // Create the resize handle
        resize_handle = new Gtk.Button();
        resize_handle.set_icon_name("circ-5-symbolic");
        resize_handle.add_css_class("resize-handle");
        resize_handle.set_size_request(8, 8);

        // Set positioning using Gtk.Overlay's built-in positioning
        resize_handle.halign = Gtk.Align.END;
        resize_handle.valign = Gtk.Align.END;
        resize_handle.margin_start = 8;
        resize_handle.margin_top = 8;
        resize_handle.margin_end = -8;
        resize_handle.margin_bottom = -8;

        // Add the resize handle as an overlay
        overlay.add_overlay(resize_handle);

        // Add the overlay to the vertical stack below the dimensions label
        drawing_stack.append(overlay);

        // Add the vertical stack to a frame with no shadow
        var frame = new Gtk.Frame(null);
        frame.margin_end = 14;
        frame.margin_bottom = 14;
        frame.set_child(drawing_stack);
        frame.add_css_class("drawing-area");

        filename_box.append(frame);

        // Set up drawing area callbacks
        drawing_area.set_draw_func(draw_function);

        // Set up gesture controllers for mouse movements
        setup_mouse_controllers();

        // Set up resize handle controller - needs to be initialized after adding to the UI
        Idle.add(() => {
            setup_resize_handle_controller();
            return false;
        });
    }

    private void update_dimensions_label() {
        int width_tiles = drawing_manager.surface.get_width() / TILE_SIZE;
        int height_tiles = drawing_manager.surface.get_height() / TILE_SIZE;
        dimensions_label.set_text(@"$(width_tiles) × $(height_tiles)");
    }

    private void setup_resize_handle_controller() {
        // Use a drag gesture for the resize handle
        var drag = new Gtk.GestureDrag();
        resize_handle.add_controller(drag);

        // Start drag operation
        drag.drag_begin.connect((start_x, start_y) => {
            is_resizing = true;

            // Store initial dimensions
            resize_start_width = drawing_manager.surface.get_width();
            resize_start_height = drawing_manager.surface.get_height();

            // Store initial drag coordinates
            resize_start_x = (int)start_x;
            resize_start_y = (int)start_y;

            // Ensure this gesture captures all future events in this sequence
            drag.set_state(Gtk.EventSequenceState.CLAIMED);
        });

        // Update during drag with better cursor tracking
        drag.drag_update.connect((offset_x, offset_y) => {
            if (!is_resizing) return;

            // Make sure we keep owning this event sequence
            drag.set_state(Gtk.EventSequenceState.CLAIMED);

            // Calculate new size based directly on the drag offset
            int new_width_pixels = resize_start_width + (int)offset_x;
            int new_height_pixels = resize_start_height + (int)offset_y;

            // Convert to tiles, rounding to nearest tile
            int width_tiles = (new_width_pixels + TILE_SIZE / 2) / TILE_SIZE;
            int height_tiles = (new_height_pixels + TILE_SIZE / 2) / TILE_SIZE;

            // Ensure minimum size of 1 tile
            width_tiles = int.max(width_tiles, 1);
            height_tiles = int.max(height_tiles, 1);

            // Only apply if dimensions actually changed
            int current_width_tiles = drawing_area.get_content_width() / TILE_SIZE;
            int current_height_tiles = drawing_area.get_content_height() / TILE_SIZE;

            if (width_tiles != current_width_tiles || height_tiles != current_height_tiles) {
                resize_canvas(width_tiles, height_tiles);
            }
        });

        // End drag operation
        drag.drag_end.connect((offset_x, offset_y) => {
            is_resizing = false;
            mark_as_changed();
        });
    }

    public void resize_canvas(int tiles_width, int tiles_height) {
        // Calculate new dimensions
        int new_width = tiles_width * TILE_SIZE;
        int new_height = tiles_height * TILE_SIZE;

        // Create a new surface with the desired size
        var new_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, new_width, new_height);

        // Create a context for the new surface
        var cr = new Cairo.Context(new_surface);

        // Fill the entire new surface with the background color first
        Gdk.RGBA bg_color = theme.get_color("theme_bg");
        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
        cr.paint();

        // Then copy the old surface content to the new one
        cr.set_source_surface(drawing_manager.surface, 0, 0);
        cr.paint();

        // Replace the old surface with the new one
        drawing_manager.surface = new_surface;

        // Update the drawing manager's selection mask
        drawing_manager.resize_surface(tiles_width, tiles_height);

        // Update the drawing area size
        drawing_area.set_content_width(new_width);
        drawing_area.set_content_height(new_height);

        // Update dimensions label
        update_dimensions_label();

        // Force redraw
        drawing_area.queue_draw();
    }

    private void show_resize_dialog() {
        var dialog = new Gtk.Dialog.with_buttons(
            "Resize Canvas",
            this,
            Gtk.DialogFlags.MODAL,
            "_Cancel",
            Gtk.ResponseType.CANCEL,
            "_Resize",
            Gtk.ResponseType.ACCEPT
        );

        var content_area = dialog.get_content_area();
        content_area.set_spacing(8);
        content_area.margin_start = 12;
        content_area.margin_end = 12;
        content_area.margin_top = 12;
        content_area.margin_bottom = 12;

        // Get current size in tiles
        int current_width_tiles = drawing_manager.surface.get_width() / TILE_SIZE;
        int current_height_tiles = drawing_manager.surface.get_height() / TILE_SIZE;

        // Create width entry
        var width_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var width_label = new Gtk.Label("Width (tiles):");
        width_label.halign = Gtk.Align.START;

        var width_adjustment = new Gtk.Adjustment(
            current_width_tiles,  // value
            1,                    // min
            100,                  // max
            1,                    // step increment
            5,                    // page increment
            0                     // page size
        );

        var width_spin = new Gtk.SpinButton(width_adjustment, 1, 0);
        width_spin.hexpand = true;

        width_box.append(width_label);
        width_box.append(width_spin);
        content_area.append(width_box);

        // Create height entry
        var height_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
        var height_label = new Gtk.Label("Height (tiles):");
        height_label.halign = Gtk.Align.START;

        var height_adjustment = new Gtk.Adjustment(
            current_height_tiles, // value
            1,                    // min
            100,                  // max
            1,                    // step increment
            5,                    // page increment
            0                     // page size
        );

        var height_spin = new Gtk.SpinButton(height_adjustment, 1, 0);
        height_spin.hexpand = true;

        height_box.append(height_label);
        height_box.append(height_spin);
        content_area.append(height_box);

        // Add note about pixels
        var pixels_label = new Gtk.Label(null);
        pixels_label.set_markup("<small>Each tile is " + TILE_SIZE.to_string() + "×" + TILE_SIZE.to_string() + " pixels</small>");
        pixels_label.margin_top = 8;
        content_area.append(pixels_label);

        // Update pixel size note when values change
        width_adjustment.value_changed.connect(() => {
            update_pixel_size_note(pixels_label, (int)width_adjustment.value, (int)height_adjustment.value);
        });

        height_adjustment.value_changed.connect(() => {
            update_pixel_size_note(pixels_label, (int)width_adjustment.value, (int)height_adjustment.value);
        });

        // Initial update
        update_pixel_size_note(pixels_label, current_width_tiles, current_height_tiles);

        dialog.set_default_response(Gtk.ResponseType.ACCEPT);

        dialog.response.connect((response_id) => {
            if (response_id == Gtk.ResponseType.ACCEPT) {
                int new_width_tiles = (int)width_adjustment.value;
                int new_height_tiles = (int)height_adjustment.value;

                // Resize the canvas
                resize_canvas(new_width_tiles, new_height_tiles);

                // Mark as changed
                mark_as_changed();
            }

            dialog.destroy();
        });

        dialog.present();
    }

    private void update_pixel_size_note(Gtk.Label label, int width_tiles, int height_tiles) {
        int width_pixels = width_tiles * TILE_SIZE;
        int height_pixels = height_tiles * TILE_SIZE;

        label.set_markup(
            "<small>Each tile is " + TILE_SIZE.to_string() + "×" + TILE_SIZE.to_string() +
            " pixels. Total: " + width_pixels.to_string() + "×" + height_pixels.to_string() +
            " pixels</small>"
        );
    }

    // Apply zoom directly from the button clicks
    private void apply_zoom(bool zoom_in, double x, double y) {
        // Calculate the maximum allowed zoom level based on frame size
        int frame_width = scrolled_window.get_width() - 20; // Account for padding
        int frame_height = scrolled_window.get_height() - 20;

        int surface_width = drawing_manager.surface.get_width();
        int surface_height = drawing_manager.surface.get_height();

        double max_zoom_width = (double)frame_width / surface_width;
        double max_zoom_height = (double)frame_height / surface_height;
        double max_zoom = double.min(max_zoom_width, max_zoom_height);

        // Determine if we can zoom in or out
        bool can_zoom_in = zoom_level < 10.0 && zoom_level < max_zoom;
        bool can_zoom_out = zoom_level > 0.1;

        if ((zoom_in && can_zoom_in) || (!zoom_in && can_zoom_out)) {
            // Get the position in surface coordinates before zoom
            double x_before = x / zoom_level;
            double y_before = y / zoom_level;

            // Adjust zoom level
            double old_zoom = zoom_level;
            double new_zoom = zoom_level * (zoom_in ? 1.2 : 0.8);

            // Make sure we don't exceed the calculated maximum zoom
            if (zoom_in) {
                new_zoom = double.min(new_zoom, max_zoom);
            }

            zoom_level = new_zoom;

            // Set drawing area size - constrained by frame dimensions
            int new_width = (int)(surface_width * zoom_level);
            int new_height = (int)(surface_height * zoom_level);

            // Ensure the drawing area size doesn't exceed frame dimensions
            new_width = int.min(new_width, frame_width);
            new_height = int.min(new_height, frame_height);

            drawing_area.set_content_width(new_width);
            drawing_area.set_content_height(new_height);

            // Calculate the new position of the point under the mouse after zoom
            double x_after = x_before * zoom_level;
            double y_after = y_before * zoom_level;

            // Calculate adjustment to keep the point under the mouse
            Gtk.Adjustment hadj = scrolled_window.get_hadjustment();
            Gtk.Adjustment vadj = scrolled_window.get_vadjustment();

            if (hadj != null && vadj != null) {
                double dx_scroll = x_after - x_before * old_zoom;
                double dy_scroll = y_after - y_before * old_zoom;

                // Adjust scroll position to keep the point under the mouse
                hadj.set_value(hadj.get_value() + dx_scroll);
                vadj.set_value(vadj.get_value() + dy_scroll);
            }

            // Request redraw
            drawing_area.queue_draw();
        }
    }

    private void setup_tool_bar() {
        // Create header bar
        tool_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
        main_box.append(tool_bar);
        set_titlebar(new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6) { visible = false });

        // Create file menu button
        var file_button = new Gtk.MenuButton();
        file_button.direction = Gtk.ArrowType.NONE;
        file_button.margin_start = 4;
        file_button.margin_top = 4;
        file_button.set_label("File");
        file_button.add_css_class("flat");
        file_button.add_css_class("flat-menu-button");
        tool_bar.append(file_button);

        // Create file menu model
        var file_menu = new GLib.Menu();
        file_menu.append("New", "win.new-file");
        file_menu.append("Save", "win.save-file");
        file_menu.append("Load", "win.load-file");
        file_menu.append("Rename", "win.rename-file");
        file_menu.append("Resize", "win.resize-canvas");

        var popover = new Gtk.PopoverMenu.from_model((GLib.MenuModel) file_menu);
        popover.set_has_arrow(false);
        file_button.set_popover(popover);

        // Add actions
        var new_action = new GLib.SimpleAction("new-file", null);
        new_action.activate.connect(new_image);
        add_action(new_action);

        var save_action = new GLib.SimpleAction("save-file", null);
        save_action.activate.connect(save_image);
        add_action(save_action);

        var load_action = new GLib.SimpleAction("load-file", null);
        load_action.activate.connect(load_image);
        add_action(load_action);

        var rename_action = new GLib.SimpleAction("rename-file", null);
        rename_action.activate.connect(rename_file);
        add_action(rename_action);

        var resize_action = new GLib.SimpleAction("resize-canvas", null);
        resize_action.activate.connect(show_resize_dialog);
        add_action(resize_action);
    }

    private void setup_mouse_controllers() {
        // Main gesture for drawing
        var drag = new Gtk.GestureDrag();
        drag.set_button(Gdk.BUTTON_PRIMARY);
        drawing_area.add_controller(drag);

        drag.drag_begin.connect((x, y) => {
            if (zoom_mode) {
                // If in zoom mode, zoom in with left mouse button
                apply_zoom(true, x, y);
                return;
            }

            // Convert coordinates based on zoom level
            double canvas_x = x / zoom_level;
            double canvas_y = y / zoom_level;

            drawing_manager.handle_draw_begin(canvas_x, canvas_y);
            mark_as_changed();
        });

        drag.drag_update.connect((x, y) => {
            if (zoom_mode) {
                return; // Don't draw while in zoom mode
            }

            // Convert coordinates based on zoom level
            double canvas_x = x / zoom_level;
            double canvas_y = y / zoom_level;

            drawing_manager.handle_draw_update(canvas_x, canvas_y);
        });

        drag.drag_end.connect((x, y) => {
            if (zoom_mode) {
                return; // Don't draw while in zoom mode
            }

            // Convert coordinates based on zoom level
            double canvas_x = x / zoom_level;
            double canvas_y = y / zoom_level;

            drawing_manager.handle_draw_end(canvas_x, canvas_y);
        });

        // Add right click handling for zoom out
        var right_click = new Gtk.GestureClick();
        right_click.set_button(Gdk.BUTTON_SECONDARY);
        drawing_area.add_controller(right_click);

        right_click.pressed.connect((n_press, x, y) => {
            if (zoom_mode && n_press == 1) {
                // If in zoom mode, zoom out with right mouse button
                apply_zoom(false, x, y);
            }
        });

        // Add click handling for single points
        var click = new Gtk.GestureClick();
        click.set_button(Gdk.BUTTON_PRIMARY);
        drawing_area.add_controller(click);

        click.pressed.connect((n_press, x, y) => {
            if (zoom_mode) {
                // If in zoom mode, zoom in with left mouse button
                apply_zoom(true, x, y);
                return;
            }

            // For single clicks (not part of a drag)
            if (n_press == 1) {
                double canvas_x = x / zoom_level;
                double canvas_y = y / zoom_level;

                if (drawing_manager.current_tool == Tool.MAGIC_WAND) {
                    drawing_manager.magic_wand_select(canvas_x, canvas_y);
                } else {
                    drawing_manager.draw_at_point(canvas_x, canvas_y);
                }
                mark_as_changed();
            }
        });
    }

    private void draw_function(Gtk.DrawingArea da, Cairo.Context cr, int width, int height) {
        // Scale based on zoom level
        cr.scale(zoom_level, zoom_level);

        // Let the drawing manager handle the drawing
        drawing_manager.draw_preview(cr);
    }

    private void setup_tools_ui(Gtk.Box tools_box) {
        // Create a grid for the tool buttons (first row)
        var tools_grid = new Gtk.Grid();
        tools_grid.halign = Gtk.Align.CENTER;
        tools_grid.set_row_spacing(4);
        tools_grid.set_column_spacing(4);
        tools_box.append(tools_grid);

        // Tool buttons
        Gtk.ToggleButton pencil_button = new Gtk.ToggleButton();
        pencil_button.icon_name = ("pen-symbolic");
        Gtk.ToggleButton halftoner_button = new Gtk.ToggleButton();
        halftoner_button.icon_name = ("halftone-symbolic");
        Gtk.ToggleButton line_button = new Gtk.ToggleButton();
        line_button.icon_name = ("selection-symbolic");
        Gtk.ToggleButton eraser_button = new Gtk.ToggleButton();
        eraser_button.icon_name = ("eraser-symbolic");
        Gtk.ToggleButton wand_button = new Gtk.ToggleButton();
        wand_button.icon_name = ("magic-symbolic");
        Gtk.ToggleButton zoom_button = new Gtk.ToggleButton();
        zoom_button.icon_name = ("zoom-symbolic");

        // Group tool buttons
        halftoner_button.group = pencil_button;
        line_button.group = pencil_button;
        eraser_button.group = pencil_button;
        wand_button.group = pencil_button;
        zoom_button.group = pencil_button;

        // Pencil tool - top left
        pencil_button.clicked.connect(() => {
            if (pencil_button.active) {
                drawing_manager.current_tool = Tool.PENCIL;
                zoom_mode = false;
            }
        });
        tools_grid.attach(pencil_button, 0, 0, 1, 1);

        // Eraser tool - top right
        eraser_button.clicked.connect(() => {
            if (eraser_button.active) {
                drawing_manager.current_tool = Tool.ERASER;
                zoom_mode = false;
            }
        });
        tools_grid.attach(eraser_button, 1, 0, 1, 1);

        // Halftone tool - middle left
        halftoner_button.clicked.connect(() => {
            if (halftoner_button.active) {
                drawing_manager.current_tool = Tool.HALFTONER;
                zoom_mode = false;
            }
        });
        tools_grid.attach(halftoner_button, 0, 1, 1, 1);

        // Line tool - middle right
        line_button.clicked.connect(() => {
            if (line_button.active) {
                drawing_manager.current_tool = Tool.LINE;
                zoom_mode = false;
            }
        });
        tools_grid.attach(line_button, 0, 2, 1, 1);

        // Magic Wand tool - bottom left
        wand_button.clicked.connect(() => {
            if (wand_button.active) {
                drawing_manager.current_tool = Tool.MAGIC_WAND;
                zoom_mode = false;
            }
        });
        tools_grid.attach(wand_button, 1, 1, 1, 1);

        // Zoom tool - bottom right
        zoom_button.clicked.connect(() => {
            if (zoom_button.active) {
                // Store previous tool to restore later
                zoom_mode = true;
            } else {
                zoom_mode = false;
            }
        });
        tools_grid.attach(zoom_button, 1, 2, 1, 1);

        // Add first separator
        var separator1 = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        tools_box.append(separator1);

        // Create grid for halftone patterns
        var halftone_grid = new Gtk.Grid();
        halftone_grid.halign = Gtk.Align.CENTER;
        halftone_grid.set_row_spacing(4);
        halftone_grid.set_column_spacing(4);
        tools_box.append(halftone_grid);

        // Create halftone pattern toggle buttons
        Gtk.ToggleButton full_button = new Gtk.ToggleButton();
        full_button.icon_name = ("ht-full-symbolic");
        Gtk.ToggleButton checkerboard_button = new Gtk.ToggleButton ();
        checkerboard_button.icon_name = ("ht-check-symbolic");
        Gtk.ToggleButton cross5_button = new Gtk.ToggleButton ();
        cross5_button.icon_name = ("ht-5-cross-symbolic");
        Gtk.ToggleButton cross3_button = new Gtk.ToggleButton ();
        cross3_button.icon_name = ("ht-3-cross-symbolic");
        Gtk.ToggleButton diag_right_button = new Gtk.ToggleButton ();
        diag_right_button.icon_name = ("ht-diag-right-symbolic");
        Gtk.ToggleButton diag_left_button = new Gtk.ToggleButton ();
        diag_left_button.icon_name = ("ht-diag-left-symbolic");
        Gtk.ToggleButton vert_lines_button = new Gtk.ToggleButton ();
        vert_lines_button.icon_name = ("ht-vert-symbolic");
        Gtk.ToggleButton horiz_lines_button = new Gtk.ToggleButton ();
        horiz_lines_button.icon_name = ("ht-hori-symbolic");

        // Group halftone buttons
        checkerboard_button.group = full_button;
        cross5_button.group = full_button;
        cross3_button.group = full_button;
        diag_right_button.group = full_button;
        diag_left_button.group = full_button;
        vert_lines_button.group = full_button;
        horiz_lines_button.group = full_button;

        // HT1 - Full drawing - top left
        full_button.clicked.connect(() => {
            if (full_button.active) {
                drawing_manager.current_halftone = Halftone.FULL;
            }
        });
        halftone_grid.attach(full_button, 0, 0, 1, 1);

        // HT2 - Checkerboard - top right
        checkerboard_button.clicked.connect(() => {
            if (checkerboard_button.active) {
                drawing_manager.current_halftone = Halftone.CHECKERBOARD;
            }
        });
        halftone_grid.attach(checkerboard_button, 1, 0, 1, 1);

        // HT3 - 5x5 Cross - middle left
        cross5_button.clicked.connect(() => {
            if (cross5_button.active) {
                drawing_manager.current_halftone = Halftone.CROSS_5X5;
            }
        });
        halftone_grid.attach(cross5_button, 0, 1, 1, 1);

        // HT4 - 3x3 Cross - middle right
        cross3_button.clicked.connect(() => {
            if (cross3_button.active) {
                drawing_manager.current_halftone = Halftone.CROSS_3X3;
            }
        });
        halftone_grid.attach(cross3_button, 1, 1, 1, 1);

        // HT5 - Diagonal Right - bottom left
        diag_right_button.clicked.connect(() => {
            if (diag_right_button.active) {
                drawing_manager.current_halftone = Halftone.DIAGONAL_RIGHT;
            }
        });
        halftone_grid.attach(diag_right_button, 0, 2, 1, 1);

        // HT6 - Diagonal Left - bottom right
        diag_left_button.clicked.connect(() => {
            if (diag_left_button.active) {
                drawing_manager.current_halftone = Halftone.DIAGONAL_LEFT;
            }
        });
        halftone_grid.attach(diag_left_button, 1, 2, 1, 1);

        // HT7 - Vertical Lines - bottom left
        vert_lines_button.clicked.connect(() => {
            if (vert_lines_button.active) {
                drawing_manager.current_halftone = Halftone.VERTICAL_LINES;
            }
        });
        halftone_grid.attach(vert_lines_button, 0, 3, 1, 1);

        // HT8 - Horizontal Lines - bottom right
        horiz_lines_button.clicked.connect(() => {
            if (horiz_lines_button.active) {
                drawing_manager.current_halftone = Halftone.HORIZONTAL_LINES;
            }
        });
        halftone_grid.attach(horiz_lines_button, 1, 3, 1, 1);

        // Add second separator
        var separator2 = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
        tools_box.append(separator2);

        // Create grid for the combined thickness and shape buttons
        var thickness_shape_grid = new Gtk.Grid();
        thickness_shape_grid.halign = Gtk.Align.CENTER;
        thickness_shape_grid.set_row_spacing(4);
        thickness_shape_grid.set_column_spacing(4);
        tools_box.append(thickness_shape_grid);

        // Create 8 toggle buttons for combined thickness and shape options
        Gtk.ToggleButton px1_circle_button = new Gtk.ToggleButton ();
        px1_circle_button.icon_name = ("circ-1-symbolic");
        Gtk.ToggleButton px1_diamond_button = new Gtk.ToggleButton ();
        px1_diamond_button.icon_name = ("diamond-3-symbolic");
        Gtk.ToggleButton px3_circle_button = new Gtk.ToggleButton ();
        px3_circle_button.icon_name = ("circ-3-symbolic");
        Gtk.ToggleButton px3_diamond_button = new Gtk.ToggleButton ();
        px3_diamond_button.icon_name = ("diamond-5-symbolic");
        Gtk.ToggleButton px5_circle_button = new Gtk.ToggleButton ();
        px5_circle_button.icon_name = ("circ-5-symbolic");
        Gtk.ToggleButton px5_diamond_button = new Gtk.ToggleButton ();
        px5_diamond_button.icon_name = ("diamond-7-symbolic");
        Gtk.ToggleButton px7_circle_button = new Gtk.ToggleButton ();
        px7_circle_button.icon_name = ("circ-7-symbolic");
        Gtk.ToggleButton px7_diamond_button = new Gtk.ToggleButton ();
        px7_diamond_button.icon_name = ("diamond-full-symbolic");

        // Group all thickness/shape buttons together
        px1_diamond_button.group = px1_circle_button;
        px3_circle_button.group = px1_circle_button;
        px3_diamond_button.group = px1_circle_button;
        px5_circle_button.group = px1_circle_button;
        px5_diamond_button.group = px1_circle_button;
        px7_circle_button.group = px1_circle_button;
        px7_diamond_button.group = px1_circle_button;

        // 1px Circle button
        px1_circle_button.clicked.connect(() => {
            if (px1_circle_button.active) {
                drawing_manager.current_thickness = Thickness.PX_1;
                drawing_manager.current_shape = Shape.CIRCLE;
            }
        });
        thickness_shape_grid.attach(px1_circle_button, 0, 0, 1, 1);

        // 1px Diamond button
        px1_diamond_button.clicked.connect(() => {
            if (px1_diamond_button.active) {
                drawing_manager.current_thickness = Thickness.PX_1;
                drawing_manager.current_shape = Shape.DIAMOND;
            }
        });
        thickness_shape_grid.attach(px1_diamond_button, 1, 0, 1, 1);

        // 3px Circle button
        px3_circle_button.clicked.connect(() => {
            if (px3_circle_button.active) {
                drawing_manager.current_thickness = Thickness.PX_3;
                drawing_manager.current_shape = Shape.CIRCLE;
            }
        });
        thickness_shape_grid.attach(px3_circle_button, 0, 1, 1, 1);

        // 3px Diamond button
        px3_diamond_button.clicked.connect(() => {
            if (px3_diamond_button.active) {
                drawing_manager.current_thickness = Thickness.PX_3;
                drawing_manager.current_shape = Shape.DIAMOND;
            }
        });
        thickness_shape_grid.attach(px3_diamond_button, 1, 1, 1, 1);

        // 5px Circle button
        px5_circle_button.clicked.connect(() => {
            if (px5_circle_button.active) {
                drawing_manager.current_thickness = Thickness.PX_5;
                drawing_manager.current_shape = Shape.CIRCLE;
            }
        });
        thickness_shape_grid.attach(px5_circle_button, 0, 2, 1, 1);

        // 5px Diamond button
        px5_diamond_button.clicked.connect(() => {
            if (px5_diamond_button.active) {
                drawing_manager.current_thickness = Thickness.PX_5;
                drawing_manager.current_shape = Shape.DIAMOND;
            }
        });
        thickness_shape_grid.attach(px5_diamond_button, 1, 2, 1, 1);

        // 7px Circle button
        px7_circle_button.clicked.connect(() => {
            if (px7_circle_button.active) {
                drawing_manager.current_thickness = Thickness.PX_7;
                drawing_manager.current_shape = Shape.CIRCLE;
            }
        });
        thickness_shape_grid.attach(px7_circle_button, 0, 3, 1, 1);

        // 7px Diamond button - special case with circle core
        px7_diamond_button.clicked.connect(() => {
            if (px7_diamond_button.active) {
                drawing_manager.current_thickness = Thickness.PX_7;
                drawing_manager.current_shape = Shape.DIAMOND;
            }
        });
        thickness_shape_grid.attach(px7_diamond_button, 1, 3, 1, 1);

        // Set default selections
        pencil_button.set_active(true);
        full_button.set_active(true);
        px1_circle_button.set_active(true);
    }
}
