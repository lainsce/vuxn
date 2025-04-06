using Gtk;
using Cairo;

namespace ShavianKeyboard {
    // The main window class for the Shavian keyboard application
    public class ShavianWindow : Gtk.ApplicationWindow {
        // Constants
        private const int KEY_WIDTH = 32;
        private const int KEY_HEIGHT = 48;
        private const int KEY_SPACING = 4;
        private const int BORDER_RADIUS = 2;
        
        // UI Elements
        private Gtk.Entry entry;
        private Gtk.Box main_box;
        private Gtk.Grid keyboard_grid;
        
        private Theme.Manager theme;
        
        // Key widgets storage
        private Gtk.DrawingArea[,] key_widgets;
        
        // Key state tracking
        private bool[,] key_hover_states;
        private bool[,] key_pressed_states;
        
        // Currently hovered key tracking
        private int hovered_row = -1;
        private int hovered_col = -1;
        
        // Mode tracking
        private bool alternate_mode = false;
        private bool numeric_mode = false;
        
        public ShavianWindow(Gtk.Application app) {
            Object(application: app);
            
            this.title = "Shavian Keyboard";
            this.resizable = false;
            
            var _tmp = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            _tmp.visible = false;
            this.titlebar = _tmp;
            
            // Load CSS
            var provider = new Gtk.CssProvider();
            provider.load_from_resource("/com/example/shav/style.css");
            
            // Apply CSS to the app
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
            
            theme = Theme.Manager.get_default();
            theme.apply_to_display();
            setup_theme_management();
            
            setup_ui();
        }
        
        private void setup_theme_management() {
            string theme_file = GLib.Path.build_filename(Environment.get_home_dir(), ".theme");
            
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
            // Create main box
            main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8) {
                margin_start = 8,
                margin_end = 8,
                margin_top = 8,
                margin_bottom = 8
            };
            this.set_child(main_box);
            main_box.append(create_titlebar());
            
            // Create text entry
            entry = new Gtk.Entry();
            entry.add_css_class ("mac-entry");
            main_box.append(entry);
            
            // Create keyboard grid
            keyboard_grid = new Gtk.Grid() {
                row_spacing = KEY_SPACING,
                column_spacing = KEY_SPACING,
                hexpand = true,
                vexpand = true
            };
            main_box.append(keyboard_grid);
            
            // Set up keyboard
            setup_keyboard();
            
            // Set up keyboard shortcuts
            var controller = new Gtk.EventControllerKey();
            controller.key_pressed.connect(on_key_pressed);
            main_box.add_controller(controller);
        }
        
        private Gtk.Widget create_titlebar() {
            var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);

            // Create close button
            var close_button = new Gtk.Button();
            close_button.add_css_class("close-button");
            close_button.tooltip_text = "Close";
            close_button.valign = Gtk.Align.CENTER;
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
        
        private void setup_keyboard() {
            int rows = 4;
            int cols = 9;
            
            key_widgets = new Gtk.DrawingArea[rows, cols];
            key_hover_states = new bool[rows, cols];
            key_pressed_states = new bool[rows, cols];
            
            // Row 1 - 9 keys
            for (int col = 0; col < 9; col++) {
                add_key(0, col, 0, col);
            }
            
            // Row 2 - 9 keys
            for (int col = 0; col < 9; col++) {
                add_key(1, col, 1, col);
            }
            
            // Row 3 - 9 keys
            for (int col = 0; col < 9; col++) {
                add_key(2, col, 2, col);
            }
            
            // Row 4 - special keys with different widths
            add_key(3, 0, 3, 0, 1); // Mode
            add_key(3, 1, 3, 1, 1); // Comma
            add_key(3, 2, 3, 2, 5); // Space (spanning 5 columns)
            add_key(3, 3, 3, 7, 1); // Period
            add_key(3, 4, 3, 8, 1); // Enter
        }
        
        private void add_key(int layout_row, int layout_col, int grid_row, int grid_col, int width = 1) {
            int idx = layout_row * 9 + layout_col;
            string key_label = Assets.keys[idx, 0];
            string char_primary = Assets.keys[idx, 1];
            string char_alternate = Assets.keys[idx, 2];
            string char_numeric = Assets.keys[idx, 3];
            
            var drawing_area = new Gtk.DrawingArea() {
                content_width = KEY_WIDTH + 4,
                content_height = KEY_HEIGHT + 4
            };
            
            theme.theme_changed.connect(() => {
                drawing_area.queue_draw();
            });
            
            // Add motion controller for hover state
            var motion_controller = new Gtk.EventControllerMotion();
            motion_controller.enter.connect(() => {
                key_hover_states[layout_row, layout_col] = true;
                
                // Update currently hovered key
                hovered_row = layout_row;
                hovered_col = layout_col;
                
                // Redraw the space bar as well (layout coordinates 3,2)
                if (key_widgets[3, 2] != null) {
                    key_widgets[3, 2].queue_draw();
                }
                
                drawing_area.queue_draw();
            });
            motion_controller.leave.connect(() => {
                key_hover_states[layout_row, layout_col] = false;
                
                // Clear currently hovered key if this is the one being hovered
                if (hovered_row == layout_row && hovered_col == layout_col) {
                    hovered_row = -1;
                    hovered_col = -1;
                    
                    // Redraw the space bar
                    if (key_widgets[3, 2] != null) {
                        key_widgets[3, 2].queue_draw();
                    }
                }
                
                drawing_area.queue_draw();
            });
            drawing_area.add_controller(motion_controller);
            
            drawing_area.set_draw_func((area, cr, width, height) => {
                // Get key state
                bool is_hovered = key_hover_states[layout_row, layout_col];
                bool is_pressed = key_pressed_states[layout_row, layout_col];
                
                // Determine shadow height based on state
                double shadow_height = 3; // Default
                if (is_pressed) {
                    shadow_height = 1; // 1px shadow when pressed
                } else if (is_hovered) {
                    shadow_height = 2; // 2px shadow when hovered
                }
                
                // Determine vertical adjustment based on state
                double y_offset = 0;
                if (is_pressed) {
                    y_offset = 2; // Move down 2px when pressed
                } else if (is_hovered) {
                    y_offset = 1; // Move down 1px when hovered
                }
                
                // Determine key colors based on theme
                Gdk.RGBA ac_color = theme.get_color("theme_accent");
                Gdk.RGBA sel_color = theme.get_color("theme_selection");
                Gdk.RGBA bg_color = theme.get_color("theme_bg");
                Gdk.RGBA fg_color = theme.get_color("theme_fg");
                
                // Set background color based on state
                Gdk.RGBA bg_fill_color;
                if (is_pressed) {
                    bg_fill_color = sel_color; // Use accent color when pressed
                } else {
                    bg_fill_color = ac_color; // Use bg color otherwise
                }
                
                // Draw key background with slight border radius
                cr.set_antialias(Cairo.Antialias.NONE);
                cr.set_line_width(1);
                
                // Background fill
                cr.set_source_rgb(bg_fill_color.red, bg_fill_color.green, bg_fill_color.blue);
                double key_height = height - y_offset;
                Utils.draw_rounded_rectangle(cr, 0, y_offset, width, key_height, BORDER_RADIUS);
                cr.fill();
                
                // Shadow (if any)
                if (shadow_height > 0) {
                    double x = 0.5;
                    double y = y_offset + 0.5;
                    double shadow_y = y + key_height - shadow_height;
                    cr.set_source_rgb(sel_color.red, sel_color.green, sel_color.blue);
                    cr.move_to(x + BORDER_RADIUS, shadow_y);
                    cr.line_to(x + width - BORDER_RADIUS, shadow_y);
                    cr.line_to(x + width, y + key_height - BORDER_RADIUS); // Right bottom corner
                    cr.line_to(x + width - BORDER_RADIUS, y + key_height); // Bottom right corner
                    cr.line_to(x + BORDER_RADIUS, y + key_height); // Bottom left corner
                    cr.line_to(x, y + key_height - BORDER_RADIUS); // Left bottom corner
                    cr.line_to(x + BORDER_RADIUS, shadow_y); // Back to start
                    cr.fill();
                }
                
                // Draw key border
                cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
                Utils.draw_rounded_rectangle(cr, 0, y_offset, width, key_height, BORDER_RADIUS);
                cr.stroke();

                // Calculate adjustments for character positioning based on key state
                double char_y_offset = y_offset;

                // Draw key label
                string special_display_text;
                string display_text1;
                string display_text2;
                string display_text3;
                if (key_label.has_prefix("//")) {
                    // Special key
                    cr.set_source_rgb(sel_color.red, sel_color.green, sel_color.blue);
                    special_display_text = key_label.substring(2);
                    
                    // If this is the space bar and there's a hovered key, show its name
                    if (special_display_text == " " && hovered_row >= 0 && hovered_col >= 0) {
                        // Draw the space character on the right
                        Utils.draw_pixelated_text(cr, special_display_text, width - 11, height - 11 + char_y_offset);
                        
                        // Get the hovered key's name and display it on the left
                        int hovered_idx = hovered_row * 9 + hovered_col;
                        string hovered_key_label = Assets.keys[hovered_idx, 0];
                        
                        // Parse the name from format like "peep/bib/!"
                        string display_name = "";
                        if (hovered_key_label.has_prefix("//")) {
                            // Special key, don't show name
                        } else if (numeric_mode) {
                            // In numeric mode, don't display a name
                        } else {
                            // Extract the parts of the name
                            string[] name_parts = hovered_key_label.split("/");
                            
                            if (alternate_mode && name_parts.length > 1) {
                                // In alternate mode, show the second name
                                display_name = name_parts[1];
                            } else if (name_parts.length > 0) {
                                // In primary mode, show the first name
                                display_name = name_parts[0];
                            }
                            
                            // Draw the key name on the left side
                            cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
                            
                            // Create a simple text layout to display the name
                            var layout = Pango.cairo_create_layout(cr);
                            layout.set_text(display_name, -1);
                            
                            // Use a small font
                            var font_desc = Pango.FontDescription.from_string("Monaco 9");
                            layout.set_font_description(font_desc);
                            
                            double text_x = 11;
                            double text_y = (height - 20);
                            
                            cr.move_to(text_x, text_y);
                            Pango.cairo_show_layout(cr, layout);
                        }
                    } else {
                        // Just draw the special key character
                        Utils.draw_pixelated_text(cr, special_display_text, width - 11, height - 11 + char_y_offset);
                    }
                } else {
                    // Character key - display the appropriate character based on mode
                    if (numeric_mode && char_numeric != null && char_numeric.length > 0) {
                        cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
                        display_text1 = char_numeric;
                        Utils.draw_pixelated_text(cr, display_text1, width - 11, height - 11 + char_y_offset);
                        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
                        display_text2 = char_alternate;
                        Utils.draw_pixelated_text(cr, display_text2, 11, 11 + char_y_offset);
                        cr.set_source_rgb(sel_color.red, sel_color.green, sel_color.blue);
                        display_text3 = char_primary;
                        Utils.draw_pixelated_text(cr, display_text3, width / 2, height / 2 + char_y_offset);
                    } else if (alternate_mode && char_alternate != null && char_alternate.length > 0) {
                        cr.set_source_rgb(sel_color.red, sel_color.green, sel_color.blue);
                        display_text1 = char_numeric;
                        Utils.draw_pixelated_text(cr, display_text1, width - 11, height - 11 + char_y_offset);
                        cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
                        display_text2 = char_alternate;
                        Utils.draw_pixelated_text(cr, display_text2, 11, 11 + char_y_offset);
                        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
                        display_text3 = char_primary;
                        Utils.draw_pixelated_text(cr, display_text3, width / 2, height / 2 + char_y_offset);
                    } else if (char_primary != null && char_primary.length > 0) {
                        cr.set_source_rgb(sel_color.red, sel_color.green, sel_color.blue);
                        display_text1 = char_numeric;
                        Utils.draw_pixelated_text(cr, display_text1, width - 11, height - 11 + char_y_offset);
                        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
                        display_text2 = char_alternate;
                        Utils.draw_pixelated_text(cr, display_text2, 11, 11 + char_y_offset);
                        cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
                        display_text3 = char_primary;
                        Utils.draw_pixelated_text(cr, display_text3, width / 2, height / 2 + char_y_offset);
                    } else {
                        display_text1 = " "; // Fallback
                        display_text2 = " "; // Fallback
                        display_text3 = " "; // Fallback
                    }
                }
            });
            
            var gesture = new Gtk.GestureClick();
            gesture.set_button(1); // Left mouse button
            gesture.pressed.connect((n_press, x, y) => {
                // Set pressed state
                key_pressed_states[layout_row, layout_col] = true;
                drawing_area.queue_draw();
                
                // Handle key press
                string char_to_insert = "";
                if (key_label.has_prefix("//")) {
                    // Special key
                    string key_type = key_label.substring(2);
                    switch (key_type) {
                        case "⋄":
                            // Cycle through modes: Primary -> Alternate -> Numeric -> Primary
                            if (numeric_mode) {
                                numeric_mode = false;
                                alternate_mode = false;
                            } else if (alternate_mode) {
                                alternate_mode = false;
                                numeric_mode = true;
                            } else {
                                alternate_mode = true;
                                numeric_mode = false;
                            }
                            redraw_keyboard();
                            return;
                        case "⌫":
                            int cursor_pos = entry.cursor_position;
                            if (cursor_pos > 0) {
                                // Delete the character before the cursor
                                // For Unicode characters, we need to delete a whole character
                                entry.delete_text(cursor_pos - 1, cursor_pos);
                                entry.set_position(cursor_pos - 1);
                            }
                            return;
                        case "<":
                            int cursor_pos = entry.cursor_position;
                            if (cursor_pos > 0) {
                                entry.set_position(cursor_pos - 1);
                            }
                            return;
                        case ">":
                            int cursor_pos = entry.cursor_position;
                            if (cursor_pos < entry.text.length) {
                                entry.set_position(cursor_pos + 1);
                            }
                            return;
                        case " ":
                            char_to_insert = " ";
                            break;
                        case "←":
                            var clipboard = Gdk.Display.get_default().get_clipboard();
                            clipboard.set_text(entry.text);
                            return;
                        case ",":
                            char_to_insert = ",";
                            break;
                        case ".":
                            char_to_insert = ".";
                            break;
                        default:
                            return;
                    }
                } else {
                    // Character key - determine which character to insert based on mode
                    string char_str = "";
                    if (numeric_mode) {
                        char_str = char_numeric; // Use numeric character
                    } else if (alternate_mode) {
                        char_str = char_alternate;
                    } else {
                        char_str = char_primary;
                    }
                    
                    if (char_str != null && char_str.length > 0) {
                        char_to_insert = char_str;
                    }
                }
                
                // Only proceed if we have something to insert
                if (char_to_insert.length > 0) {
                    try {
                        // Each Shavian character is 4 bytes in UTF-8, so we need to handle them carefully
                        // Delete any selected text
                        int start_pos, end_pos;
                        if (entry.get_selection_bounds(out start_pos, out end_pos)) {
                            // There is a selection - replace it
                            entry.delete_text(start_pos, end_pos);
                            entry.set_position(start_pos);
                        }
                        
                        // Insert the character at the current position
                        int cursor_pos = entry.cursor_position;
                        entry.insert_text(char_to_insert, -1, ref cursor_pos);
                        
                        // Set the cursor position after the inserted text
                        entry.set_position(cursor_pos);
                    } catch (Error e) {
                        stderr.printf("Error inserting text: %s\n", e.message);
                    }
                }
            });
            
            // Add release event to reset pressed state
            gesture.released.connect((n_press, x, y) => {
                key_pressed_states[layout_row, layout_col] = false;
                drawing_area.queue_draw();
            });
            
            drawing_area.add_controller(gesture);
            
            // Store the widget for later access
            key_widgets[layout_row, layout_col] = drawing_area;
            
            // Add to grid
            keyboard_grid.attach(drawing_area, grid_col, grid_row, width, 1);
        }
        
        private bool on_key_pressed(uint keyval, uint keycode, Gdk.ModifierType state) {
            if (keyval == Gdk.Key.Alt_L || keyval == Gdk.Key.Alt_R) {
                alternate_mode = !alternate_mode;
                numeric_mode = false;
                redraw_keyboard();
                return true;
            } else if (keyval == Gdk.Key.Shift_L || keyval == Gdk.Key.Shift_R) {
                numeric_mode = !numeric_mode;
                alternate_mode = false;
                redraw_keyboard();
                return true;
            }
            return false;
        }
        
        private void redraw_keyboard() {
            // Redraw all keys to reflect the mode change
            for (int r = 0; r < 4; r++) {
                for (int c = 0; c < 9; c++) {
                    if (key_widgets[r, c] != null) {
                        key_widgets[r, c].queue_draw();
                    }
                }
            }
        }
    }
}