/*
 * Varvara Theme Configurator
 */

using App.Utils;

namespace App {

    public class Window : He.ApplicationWindow {
        // Color controls
        private ColorPickerWidget accent_picker;
        private ColorPickerWidget selection_picker;
        private ColorPickerWidget fg_picker;
        private ColorPickerWidget bg_picker;

        // Theme file path
        private string theme_file_path;

        // Current colors
        private string accent_color = "#77ddcc";
        private string selection_color = "#ffbb33";
        private string fg_color = "#000000";
        private string bg_color = "#ffffff";

        // UI elements
        private Gtk.Label format_label;
        private Gtk.Label hex_values_label;
        private Gtk.Box main_box;

        /**
         * Constructor
         */
        public Window(Gtk.Application app) {
            Object(
                   application: app,
                   title: "Varvara Theme",
                   default_width: GRID_UNIT * 64, // 512px - wider to accommodate the pickers
                   default_height: GRID_UNIT * 48, // 384px
                   resizable: false
            );

            // Get the home directory and construct the theme file path
            theme_file_path = Path.build_filename(Environment.get_home_dir(), ".theme");

            // Load theme and setup UI
            load_theme();
            setup_ui();
        }

        /**
         * Loads the theme file and updates colors
         */
        private void load_theme() {
            if (!load_theme_file(theme_file_path,
                                 out accent_color,
                                 out selection_color,
                                 out fg_color,
                                 out bg_color)) {
                // If loading failed, use default colors
                accent_color = "#77ddcc";
                selection_color = "#ffbb33";
                fg_color = "#000000";
                bg_color = "#ffffff";
            }
        }

        /**
         * Creates and sets up the user interface
         */
        private void setup_ui() {
            // Main container box
            main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, GRID_UNIT) {
                margin_start = GRID_UNIT * 2,
                margin_end = GRID_UNIT * 2,
                margin_top = GRID_UNIT * 2,
                margin_bottom = GRID_UNIT * 2
            };

            // Add keyboard shortcut controller to main_box
            var key_controller = new Gtk.EventControllerKey();
            key_controller.key_pressed.connect((keyval, keycode, state) => {
                if (keyval == Gdk.Key.Escape) {
                    close();
                    return true;
                }
                return false;
            });
            main_box.add_controller(key_controller);

            // Create a grid for our color controls
            var grid = create_color_controls_grid();
            main_box.append(grid);

            // Create theme format preview
            var format_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, GRID_UNIT) {
                halign = Gtk.Align.CENTER,
                margin_top = GRID_UNIT
            };

            var format_title = new Gtk.Label("Theme Format:") {
                halign = Gtk.Align.START
            };
            format_box.append(format_title);

            format_label = new Gtk.Label("") {
                halign = Gtk.Align.CENTER,
                selectable = true
            };
            format_box.append(format_label);

            main_box.append(format_box);

            // Add a real-time hex color preview labels
            var hex_preview_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, GRID_UNIT) {
                halign = Gtk.Align.CENTER,
                margin_top = GRID_UNIT / 2
            };

            var hex_preview_label = new Gtk.Label("Full Colors:") {
                halign = Gtk.Align.START
            };
            hex_preview_box.append(hex_preview_label);

            hex_values_label = new Gtk.Label("") {
                halign = Gtk.Align.START,
                selectable = true
            };
            hex_preview_box.append(hex_values_label);

            main_box.append(hex_preview_box);

            // Add a spacer
            main_box.append(new Gtk.Box(Gtk.Orientation.VERTICAL, 0) {
                vexpand = true
            });

            // Create action buttons
            var button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, GRID_UNIT) {
                halign = Gtk.Align.END
            };

            var apply_button = new Gtk.Button.with_label("Apply Theme") {
                width_request = GRID_UNIT * 12,
                height_request = GRID_UNIT * 4
            };
            apply_button.add_css_class("suggested-action");
            apply_button.clicked.connect(on_apply_clicked);

            button_box.append(apply_button);
            main_box.append(button_box);

            var box2 = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            box2.append(create_titlebar());
            box2.append(main_box);

            // Add the main box to the window
            this.set_child(box2);

            // Update hex values display
            update_hex_values_display();

            // Update theme format display
            update_theme_format();

            // Connect signals to update when colors change
            accent_picker.color_set.connect(() => {
                update_hex_values_display();
                update_theme_format();
            });
            selection_picker.color_set.connect(() => {
                update_hex_values_display();
                update_theme_format();
            });
            fg_picker.color_set.connect(() => {
                update_hex_values_display();
                update_theme_format();
            });
            bg_picker.color_set.connect(() => {
                update_hex_values_display();
                update_theme_format();
            });
        }

        /**
         * Creates the titlebar for the window
         */
        private Gtk.Widget create_titlebar() {
            // Create classic Mac-style title bar
            var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            title_bar.width_request = 223;
            title_bar.add_css_class("title-bar");

            // Add event controller for right-click to toggle main_box visibility
            var click_controller = new Gtk.GestureClick();
            click_controller.set_button(1); // 1 = right mouse button
            click_controller.released.connect(() => {
                if (main_box.visible) {
                    main_box.visible = false;
                } else {
                    main_box.visible = true;
                }
            });
            title_bar.add_controller(click_controller);

            // Close button on the left
            var close_button = new Gtk.Button();
            close_button.add_css_class("close-button");
            close_button.tooltip_text = "Close";
            close_button.valign = Gtk.Align.CENTER;
            close_button.margin_start = 8;
            close_button.clicked.connect(() => {
                this.close();
            });

            var title_label = new Gtk.Label("Varvara Theme Config");
            title_label.add_css_class("title-box");
            title_label.hexpand = true;
            title_label.valign = Gtk.Align.CENTER;
            title_label.halign = Gtk.Align.CENTER;

            var fixed = new Gtk.Fixed();
            fixed.valign = Gtk.Align.CENTER;
            fixed.halign = Gtk.Align.CENTER;
            fixed.margin_end = 8;
            fixed.set_size_request(20, 0);

            title_bar.append(close_button);
            title_bar.append(title_label);
            title_bar.append(fixed);

            var winhandle = new Gtk.WindowHandle();
            winhandle.set_child(title_bar);

            // Main layout
            var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            vbox.append(winhandle);

            return vbox;
        }

        /**
         * Updates the hex values display
         */
        private void update_hex_values_display() {
            if (hex_values_label == null) return;

            string accent_hex = get_color_picker_hex(accent_picker);
            string selection_hex = get_color_picker_hex(selection_picker);
            string fg_hex = get_color_picker_hex(fg_picker);
            string bg_hex = get_color_picker_hex(bg_picker);

            hex_values_label.set_text("%s %s %s %s".printf(bg_hex, fg_hex, accent_hex, selection_hex));
        }

        /**
         * Updates the theme format display based on current colors
         */
        private void update_theme_format() {
            if (format_label == null) return;

            // Get current colors as specific position hex digits for the format display
            // First group: first digit (position 0)
            string a1 = get_color_hex_digit(bg_picker, 0);      // BG
            string b1 = get_color_hex_digit(fg_picker, 0);      // FG
            string c1 = get_color_hex_digit(accent_picker, 0);  // ACCENT
            string d1 = get_color_hex_digit(selection_picker, 0); // SELECTION

            // Second group: third digit (position 2)
            string a2 = get_color_hex_digit(bg_picker, 2);      // BG
            string b2 = get_color_hex_digit(fg_picker, 2);      // FG
            string c2 = get_color_hex_digit(accent_picker, 2);  // ACCENT
            string d2 = get_color_hex_digit(selection_picker, 2); // SELECTION

            // Third group: fifth digit (position 4)
            string a3 = get_color_hex_digit(bg_picker, 4);      // BG
            string b3 = get_color_hex_digit(fg_picker, 4);      // FG
            string c3 = get_color_hex_digit(accent_picker, 4);  // ACCENT
            string d3 = get_color_hex_digit(selection_picker, 4); // SELECTION

            // Format the content according to the pattern "ABCD ABCD ABCD"
            string format_text = a1 + b1 + c1 + d1 + " " + a2 + b2 + c2 + d2 + " " + a3 + b3 + c3 + d3;

            // Update format preview text
            format_label.set_text(format_text);
        }

        /**
         * Creates a grid for color controls
         */
        private Gtk.Grid create_color_controls_grid() {
            // Create a grid for the color controls
            var grid = new Gtk.Grid() {
                column_spacing = GRID_UNIT * 2,
                row_spacing = GRID_UNIT,
                halign = Gtk.Align.FILL,
                hexpand = true,
                margin_top = GRID_UNIT,
                margin_bottom = GRID_UNIT
            };
            
            // Create the background color row
            var bg_label = new Gtk.Label("Background (#A):") {
                halign = Gtk.Align.START,
                width_request = GRID_UNIT * 12
            };
            bg_picker = new ColorPickerWidget() {
                halign = Gtk.Align.START
            };
            set_color_picker(bg_picker, bg_color);
            grid.attach(bg_label, 0, 0, 1, 1);
            grid.attach(bg_picker, 1, 0, 1, 1);
            
            // Create the foreground color row
            var fg_label = new Gtk.Label("Foreground (#B):") {
                halign = Gtk.Align.START,
                width_request = GRID_UNIT * 12
            };
            fg_picker = new ColorPickerWidget() {
                halign = Gtk.Align.START
            };
            set_color_picker(fg_picker, fg_color);
            grid.attach(fg_label, 0, 1, 1, 1);
            grid.attach(fg_picker, 1, 1, 1, 1);

            // Create the accent color row
            var accent_label = new Gtk.Label("Accent (#C):") {
                halign = Gtk.Align.START,
                width_request = GRID_UNIT * 12
            };
            accent_picker = new ColorPickerWidget() {
                halign = Gtk.Align.START
            };
            set_color_picker(accent_picker, accent_color);
            grid.attach(accent_label, 0, 2, 1, 1);
            grid.attach(accent_picker, 1, 2, 1, 1);

            // Create the selection color row
            var selection_label = new Gtk.Label("Selection (#D):") {
                halign = Gtk.Align.START,
                width_request = GRID_UNIT * 12
            };
            selection_picker = new ColorPickerWidget() {
                halign = Gtk.Align.START
            };
            set_color_picker(selection_picker, selection_color);
            grid.attach(selection_label, 0, 3, 1, 1);
            grid.attach(selection_picker, 1, 3, 1, 1);
            
            return grid;
        }

        /**
         * Event handler for Apply button
         */
        private void on_apply_clicked() {
            // Save theme to file
            save_theme_file(
                                           theme_file_path,
                                           accent_picker,
                                           selection_picker,
                                           fg_picker,
                                           bg_picker,
                                           this
            );
        }
    }
}