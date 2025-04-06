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
        private string selection_color = "#ffbb66";
        private string fg_color = "#000000";
        private string bg_color = "#ffffff";

        // UI elements
        private Gtk.Box main_box;

        /**
         * Constructor
         */
        public Window(Gtk.Application app) {
            Object(
                   application: app,
                   title: "Confvara",
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
                selection_color = "#ffbb66";
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

            // Add a spacer
            main_box.append(new Gtk.Box(Gtk.Orientation.VERTICAL, 0) {
                vexpand = true
            });

            // Create action buttons
            var button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, GRID_UNIT) {
                halign = Gtk.Align.END
            };

            var apply_button = new Gtk.Button.with_label("Apply Theme") {
                width_request = GRID_UNIT * 14,
                height_request = GRID_UNIT * 4
            };
            apply_button.add_css_class("action");
            apply_button.clicked.connect(on_apply_clicked);

            button_box.append(apply_button);
            main_box.append(button_box);

            var box2 = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            box2.append(create_titlebar());
            box2.append(main_box);

            // Add the main box to the window
            this.set_child(box2);
        }

        /**
         * Creates the titlebar for the window
         */
        private Gtk.Widget create_titlebar() {
            // Create classic Mac-style title bar
            var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            title_bar.width_request = 352;

            // Close button on the left
            var close_button = new Gtk.Button();
            close_button.add_css_class("close-button");
            close_button.tooltip_text = "Close";
            close_button.valign = Gtk.Align.CENTER;
            close_button.margin_start = 8;
            close_button.margin_top = 8;
            close_button.margin_bottom = 8;
            close_button.clicked.connect(() => {
                this.close();
            });

            title_bar.append(close_button);

            var winhandle = new Gtk.WindowHandle();
            winhandle.set_child(title_bar);

            // Main layout
            var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            vbox.append(winhandle);

            return vbox;
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

            bg_picker = new ColorPickerWidget() {
                halign = Gtk.Align.START
            };
            set_color_picker(bg_picker, bg_color);
            grid.attach(bg_picker, 0, 0, 1, 1);

            fg_picker = new ColorPickerWidget() {
                halign = Gtk.Align.START
            };
            set_color_picker(fg_picker, fg_color);
            grid.attach(fg_picker, 1, 0, 1, 1);

            accent_picker = new ColorPickerWidget() {
                halign = Gtk.Align.START
            };
            set_color_picker(accent_picker, accent_color);
            grid.attach(accent_picker, 2, 0, 1, 1);

            selection_picker = new ColorPickerWidget() {
                halign = Gtk.Align.START
            };
            set_color_picker(selection_picker, selection_color);
            grid.attach(selection_picker, 3, 0, 1, 1);
            
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