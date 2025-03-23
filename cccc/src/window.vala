namespace App {
    public class Window : Gtk.ApplicationWindow {
        private Gtk.Label display_stack1;
        private Gtk.Label display_stack2;
        private Gtk.Label display_stack3;
        private Gtk.Label display_stack4;
        private Gtk.Label display_stack5;
        private Gtk.Label display_input;
        private Gtk.Label title_label;
        private Theme.Manager theme;
        private PipDrawingArea pip_area;

        // Dynamic pipeline for the beep sound
        private UxnAudio uxn_audio;

        // Input and mode state
        private string current_input = "";
        private int current_base = 16; // Hexadecimal by default
        private const int MAX_INPUT_LENGTH = 4; // Limit to 4 hex digits (0000-FFFF)

        // Stack for RPN calculator operations with fractions
        private Gee.ArrayList<Fraction> stack;

        // Collection of hex buttons for easy reference
        private Gee.ArrayList<Gtk.Button> hex_buttons;

        /**
         * Create a new calculator window
         */
        public Window (Gtk.Application app) {
            Object (application : app, title : "CCCC");

            // Initialize GStreamer for sound
            try {
                uxn_audio = new UxnAudio();
            } catch (Error e) {
                warning ("Failed to initialize GStreamer: %s", e.message);
            }

            // Load CSS provider
            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("/com/example/cccc/style.css");

            // Apply the CSS to the default display
            Gtk.StyleContext.add_provider_for_display (
                                                       Gdk.Display.get_default (),
                                                       provider,
                                                       Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 10
            );

            theme = Theme.Manager.get_default ();
            theme.apply_to_display ();
            setup_theme_management ();

            set_titlebar (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) { visible = false });

            // Initialize collections
            stack = new Gee.ArrayList<Fraction> ();
            hex_buttons = new Gee.ArrayList<Gtk.Button> ();

            // Set window properties
            default_height = 200;
            resizable = false;

            // Create UI
            setup_ui ();
            title_label.set_label (current_base == 16 ? "Hexadecimal" : "Decimal");

            // Set initial button sensitivity
            update_button_sensitivity ();
        }

        /**
         * Play calculator beep sound with 8-bit PC style
         *
         * @param value The value or digit that determines the beep note
         */
        private void play_beep (string value) {
            if (uxn_audio != null) uxn_audio.play_note(value);
        }

        private void setup_theme_management () {
            // Force initial theme load
            var theme_file = Path.build_filename (Environment.get_home_dir (), ".theme");

            // Set up the check
            GLib.Timeout.add (10, () => {
                if (FileUtils.test (theme_file, FileTest.EXISTS)) {
                    try {
                        theme.load_theme_from_file (theme_file);
                    } catch (Error e) {
                        warning ("Theme load failed: %s", e.message);
                    }
                }
                return true; // Continue the timeout
            });
        }

        /**
         * Setup the main UI components
         */
        private void setup_ui () {
            // Main vertical layout box
            var main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true,
                vexpand = true
            };
            set_child (main_box);

            main_box.append (create_titlebar ());

            // Display area
            setup_display_area (main_box);

            // Keypad
            setup_keypad (main_box);
        }

        // Title bar
        private Gtk.Widget create_titlebar () {
            // Create classic Mac-style title bar
            var title_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            title_bar.add_css_class ("title-bar");

            // Close button on the left
            var close_button = new Gtk.Button ();
            close_button.add_css_class ("close-button");
            close_button.tooltip_text = "Close";
            close_button.valign = Gtk.Align.CENTER;
            close_button.margin_start = 8;
            close_button.clicked.connect (() => {
                this.close ();
            });

            title_label = new Gtk.Label ("");
            title_label.add_css_class ("title-box");
            title_label.hexpand = true;
            title_label.valign = Gtk.Align.CENTER;
            title_label.halign = Gtk.Align.CENTER;

            var fixed = new Gtk.Fixed ();
            fixed.valign = Gtk.Align.CENTER;
            fixed.halign = Gtk.Align.CENTER;
            fixed.margin_end = 8;
            fixed.set_size_request (20, 0);

            title_bar.append (close_button);
            title_bar.append (title_label);
            title_bar.append (fixed);

            var winhandle = new Gtk.WindowHandle ();
            winhandle.set_child (title_bar);

            // Main layout
            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            vbox.append (winhandle);

            return vbox;
        }

        /**
         * Setup the calculator display area
         */
        private void setup_display_area (Gtk.Box main_box) {
            var display_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            display_area.add_css_class ("display-area");

            // Display section with numbers
            var display_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            display_box.add_css_class ("calculator-display");

            // Add the four vertical stack display labels
            display_stack1 = new Gtk.Label ("") {
                halign = Gtk.Align.START
            };
            display_stack1.add_css_class ("display-label");

            display_stack2 = new Gtk.Label ("") {
                halign = Gtk.Align.START
            };
            display_stack2.add_css_class ("display-label");

            display_stack3 = new Gtk.Label ("") {
                halign = Gtk.Align.START
            };
            display_stack3.add_css_class ("display-label");

            display_stack4 = new Gtk.Label ("") {
                halign = Gtk.Align.START
            };
            display_stack4.add_css_class ("display-label");

            display_stack5 = new Gtk.Label ("") {
                halign = Gtk.Align.START
            };
            display_stack5.add_css_class ("display-label");

            var indicator = new Indicator () {
                halign = Gtk.Align.START,
                valign = Gtk.Align.CENTER
            };
            indicator.add_css_class ("result-indicator");
            indicator.playing = true;

            // Create a horizontal box for the input area with pip drawing and text display
            var input_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            // Create a horizontal box for the pip area and text label
            var result_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
                valign = Gtk.Align.CENTER
            };
            result_box.add_css_class ("result-sep");

            result_box.append (indicator);

            // Create input label
            display_input = new Gtk.Label ("0") {
                halign = Gtk.Align.START,
                xalign = 0,
                hexpand = true,
                width_request = 88
            };
            display_input.add_css_class ("result-label");
            result_box.append (display_input);

            // Initialize pip drawing area
            pip_area = new PipDrawingArea () {
                valign = Gtk.Align.CENTER,
                halign = Gtk.Align.START,
                hexpand = true
            };
            pip_area.value_changed.connect (on_pip_value_changed);
            result_box.append (pip_area);

            input_box.append (result_box);

            var display_stack_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                hexpand = true,
                margin_start = 15
            };
            display_stack_box.add_css_class ("display-stack");
            display_stack_box.append (display_stack1);
            display_stack_box.append (display_stack2);
            display_stack_box.append (display_stack3);
            display_stack_box.append (display_stack4);
            display_stack_box.append (display_stack5);

            display_box.append (display_stack_box);
            display_box.append (input_box);

            display_area.append (display_box);
            main_box.append (display_area);
        }

        private void on_pip_value_changed (string new_value) {
            current_input = new_value;
            update_display ();
        }

        /**
         * Setup the calculator keypad
         */
        private void setup_keypad (Gtk.Box main_box) {
            var keypad = new Gtk.Grid () {
                column_spacing = 2,
                row_spacing = 2,
                hexpand = true,
                valign = Gtk.Align.START,
                vexpand_set = true,
                margin_start = 16,
                height_request = 94,
                width_request = 191
            };
            keypad.add_css_class ("calculator-keypad");

            // Calc operation buttons
            var main_calc_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 2) {
                valign = Gtk.Align.START,
                halign = Gtk.Align.CENTER,
                vexpand_set = true
            };
            var calc_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);

            // Left column function buttons
            var ac_button = new Gtk.Button ();
            ac_button.set_icon_name ("ac-symbolic");
            ac_button.valign = Gtk.Align.CENTER;
            ac_button.clicked.connect (() => on_clear_clicked (ac_button));
            calc_box.append (ac_button);
            ac_button.add_css_class ("half-keypad-button");

            // Base toggle button
            var base_toggle = new Gtk.ToggleButton ();
            base_toggle.set_icon_name ("hd-symbolic");
            base_toggle.valign = Gtk.Align.CENTER;
            base_toggle.clicked.connect (() => on_base_toggle (base_toggle));
            base_toggle.add_css_class ("base-toggle");
            calc_box.append (base_toggle);
            base_toggle.add_css_class ("half-keypad-button");

            main_calc_box.append (calc_box);

            var calc_box2 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
            main_calc_box.append (calc_box2);

            // Duplicate button
            var button_dup = new Gtk.Button ();
            button_dup.tooltip_text = "Duplicate top value";
            button_dup.valign = Gtk.Align.CENTER;
            button_dup.icon_name = "dup-symbolic";
            button_dup.add_css_class ("half-keypad-button");
            button_dup.clicked.connect (() => on_stack_duplicate (button_dup));
            calc_box2.append (button_dup);

            // Swap button
            var button_swp = new Gtk.Button ();
            button_swp.tooltip_text = "Swap top two values";
            button_swp.valign = Gtk.Align.CENTER;
            button_swp.icon_name = "swp-symbolic";
            button_swp.clicked.connect (() => on_stack_swap (button_swp));
            button_swp.add_css_class ("half-keypad-button");
            calc_box2.append (button_swp);

            var calc_box3 = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
            main_calc_box.append (calc_box3);

            // Vid (division mirror) button
            var button_vid = new Gtk.Button () {
                child = new Gtk.Label ("") {
                    halign = Gtk.Align.CENTER
                }
            };
            button_vid.tooltip_text = "Convert to unit fractions";
            button_vid.valign = Gtk.Align.CENTER;
            button_vid.icon_name = "vid-symbolic";
            button_vid.clicked.connect (() => on_vid_operation (button_vid));
            button_vid.add_css_class ("half-keypad-button");
            calc_box3.append (button_vid);

            // Invert button
            var button_inv = new Gtk.Button ();
            button_inv.valign = Gtk.Align.CENTER;
            button_inv.tooltip_text = "Invert fraction (flip numerator/denominator)";
            button_inv.icon_name = "inv-symbolic";
            button_inv.clicked.connect (() => on_stack_invert (button_inv));
            button_inv.add_css_class ("half-keypad-button");
            calc_box3.append (button_inv);

            keypad.attach (main_calc_box, 0, 0, 1, 3);

            // Stack operation buttons - Horizontal arrows
            var arrow_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);

            var button_push = new Gtk.Button () {
                child = new Gtk.Label ("") {
                    label = "^",
                    halign = Gtk.Align.CENTER,
                    valign = Gtk.Align.END,
                    margin_bottom = 5
                }
            };
            button_push.clicked.connect (() => on_stack_push (button_push));
            button_push.add_css_class ("keypad-button");

            var button_pop = new Gtk.Button () {
                child = new Gtk.Label ("") {
                    label = "_",
                    halign = Gtk.Align.CENTER,
                    valign = Gtk.Align.END,
                    margin_bottom = 5
                }
            };
            button_pop.clicked.connect (() => on_stack_pop (button_pop));
            button_pop.add_css_class ("keypad-button");

            arrow_box.append (button_pop);
            arrow_box.append (button_push);
            keypad.attach (arrow_box, 0, 2, 1, 2);

            // Setup digits and operators
            setup_keypad_buttons (keypad);

            main_box.append (keypad);
        }

        /**
         * Setup the digit and operator buttons on the keypad
         */
        private void setup_keypad_buttons (Gtk.Grid keypad) {
            // Row 0
            var button_7 = new Gtk.Button.with_label ("7");
            button_7.clicked.connect (() => on_number_clicked (button_7));
            keypad.attach (button_7, 1, 0, 1, 1);
            button_7.add_css_class ("keypad-button");

            var button_8 = new Gtk.Button.with_label ("8");
            button_8.clicked.connect (() => on_number_clicked (button_8));
            keypad.attach (button_8, 2, 0, 1, 1);
            button_8.add_css_class ("keypad-button");

            var button_9 = new Gtk.Button.with_label ("9");
            button_9.clicked.connect (() => on_number_clicked (button_9));
            keypad.attach (button_9, 3, 0, 1, 1);
            button_9.add_css_class ("keypad-button");

            var button_F = new Gtk.Button.with_label ("F");
            button_F.clicked.connect (() => on_number_clicked (button_F));
            button_F.add_css_class ("hex-button");
            hex_buttons.add (button_F);
            keypad.attach (button_F, 4, 0, 1, 1);
            button_F.add_css_class ("keypad-button");

            var button_mult = new Gtk.Button.with_label ("*");
            button_mult.clicked.connect (() => on_operator_clicked (button_mult));
            keypad.attach (button_mult, 5, 0, 1, 1);
            button_mult.add_css_class ("keypad-button");
            button_mult.add_css_class ("keypad-op-button");

            // Bitwise AND
            var button_and = new Gtk.Button.with_label ("&");
            button_and.clicked.connect (() => on_operator_clicked (button_and));
            keypad.attach (button_and, 6, 0, 1, 1);
            button_and.add_css_class ("keypad-button");
            button_and.add_css_class ("keypad-op-button");

            // Row 1
            var button_4 = new Gtk.Button.with_label ("4");
            button_4.clicked.connect (() => on_number_clicked (button_4));
            keypad.attach (button_4, 1, 1, 1, 1);
            button_4.add_css_class ("keypad-button");

            var button_5 = new Gtk.Button.with_label ("5");
            button_5.clicked.connect (() => on_number_clicked (button_5));
            keypad.attach (button_5, 2, 1, 1, 1);
            button_5.add_css_class ("keypad-button");

            var button_6 = new Gtk.Button.with_label ("6");
            button_6.clicked.connect (() => on_number_clicked (button_6));
            keypad.attach (button_6, 3, 1, 1, 1);
            button_6.add_css_class ("keypad-button");

            var button_E = new Gtk.Button.with_label ("E");
            button_E.clicked.connect (() => on_number_clicked (button_E));
            button_E.add_css_class ("hex-button");
            hex_buttons.add (button_E);
            keypad.attach (button_E, 4, 1, 1, 1);
            button_E.add_css_class ("keypad-button");

            var button_div = new Gtk.Button.with_label ("÷");
            button_div.clicked.connect (() => on_operator_clicked (button_div));
            keypad.attach (button_div, 5, 1, 1, 1);
            button_div.add_css_class ("keypad-button");
            button_div.add_css_class ("keypad-op-button");

            // Bitwise OR
            var button_or = new Gtk.Button.with_label ("|");
            button_or.clicked.connect (() => on_operator_clicked (button_or));
            keypad.attach (button_or, 6, 1, 1, 1);
            button_or.add_css_class ("keypad-button");
            button_or.add_css_class ("keypad-op-button");

            // Row 2
            var button_1 = new Gtk.Button.with_label ("1");
            button_1.clicked.connect (() => on_number_clicked (button_1));
            keypad.attach (button_1, 1, 2, 1, 1);
            button_1.add_css_class ("keypad-button");


            var button_2 = new Gtk.Button.with_label ("2");
            button_2.clicked.connect (() => on_number_clicked (button_2));
            keypad.attach (button_2, 2, 2, 1, 1);
            button_2.add_css_class ("keypad-button");

            var button_3 = new Gtk.Button.with_label ("3");
            button_3.clicked.connect (() => on_number_clicked (button_3));
            keypad.attach (button_3, 3, 2, 1, 1);
            button_3.add_css_class ("keypad-button");

            var button_D = new Gtk.Button.with_label ("D");
            button_D.clicked.connect (() => on_number_clicked (button_D));
            button_D.add_css_class ("hex-button");
            hex_buttons.add (button_D);
            keypad.attach (button_D, 4, 2, 1, 1);
            button_D.add_css_class ("keypad-button");


            var button_add = new Gtk.Button.with_label ("+");
            button_add.clicked.connect (() => on_operator_clicked (button_add));
            keypad.attach (button_add, 5, 2, 1, 1);
            button_add.add_css_class ("keypad-button");
            button_add.add_css_class ("keypad-op-button");

            // Bitwise Shift Left
            var button_shift_left = new Gtk.Button.with_label ("«");
            button_shift_left.clicked.connect (() => on_operator_clicked (button_shift_left));
            keypad.attach (button_shift_left, 6, 2, 1, 1);
            button_shift_left.add_css_class ("keypad-button");
            button_shift_left.add_css_class ("keypad-op-button");


            // Row 3
            var button_0 = new Gtk.Button.with_label ("0");
            button_0.clicked.connect (() => on_number_clicked (button_0));
            keypad.attach (button_0, 1, 3, 1, 1);
            button_0.add_css_class ("keypad-button");


            var button_A = new Gtk.Button.with_label ("A");
            button_A.clicked.connect (() => on_number_clicked (button_A));
            button_A.add_css_class ("hex-button");
            hex_buttons.add (button_A);
            keypad.attach (button_A, 2, 3, 1, 1);
            button_A.add_css_class ("keypad-button");


            var button_B = new Gtk.Button.with_label ("B");
            button_B.clicked.connect (() => on_number_clicked (button_B));
            button_B.add_css_class ("hex-button");
            button_B.add_css_class ("keypad-button");
            hex_buttons.add (button_B);
            keypad.attach (button_B, 3, 3, 1, 1);

            var button_C = new Gtk.Button.with_label ("C");
            button_C.clicked.connect (() => on_number_clicked (button_C));
            button_C.add_css_class ("hex-button");
            hex_buttons.add (button_C);
            keypad.attach (button_C, 4, 3, 1, 1);
            button_C.add_css_class ("keypad-button");


            var button_sub = new Gtk.Button.with_label ("-");
            button_sub.clicked.connect (() => on_operator_clicked (button_sub));
            keypad.attach (button_sub, 5, 3, 1, 1);
            button_sub.add_css_class ("keypad-button");
            button_sub.add_css_class ("keypad-op-button");

            // Bitwise Shift Right
            var button_shift_right = new Gtk.Button.with_label ("»");
            button_shift_right.clicked.connect (() => on_operator_clicked (button_shift_right));
            keypad.attach (button_shift_right, 6, 3, 1, 1);
            button_shift_right.add_css_class ("keypad-button");
            button_shift_right.add_css_class ("keypad-op-button");
        }

        /**
         * Toggle between hexadecimal and decimal modes
         */
        private void on_base_toggle (Gtk.ToggleButton toggle_button) {
            // Toggle between hexadecimal and decimal modes
            current_base = current_base == 16 ? 10 : 16;

            // Update the toggle button label
            toggle_button.active = current_base == 10 ? true : false;
            title_label.set_label (current_base == 16 ? "Hexadecimal" : "Decimal");

            // Update button sensitivity
            update_button_sensitivity ();

            // Clear current input when changing modes to avoid confusion
            current_input = "";
            update_display ();

            // Update all display labels to reflect the current base
            update_all_displays ();
        }

        /**
         * Handles duplicating the top value on the stack
         */
        private void on_stack_duplicate (Gtk.Button button) {
            if (stack.size > 0) {
                // Get the top value without removing it
                var fraction = stack[stack.size - 1];

                // Add a duplicate to the stack
                stack.add (new Fraction (fraction.numerator, fraction.denominator));

                // Update display
                update_all_displays ();
            }
        }

        /**
         * Handles swapping the top two values on the stack
         */
        private void on_stack_swap (Gtk.Button button) {
            if (stack.size >= 2) {
                // Get indices of the two top elements
                int top_idx = stack.size - 1;
                int second_idx = stack.size - 2;

                // Swap the elements
                var temp = stack[top_idx];
                stack[top_idx] = stack[second_idx];
                stack[second_idx] = temp;

                // Update display
                update_all_displays ();
            }
        }

        /**
         * Handles the vid operation (division mirror)
         * Converts numbers to unit fractions (1/n)
         */
        private void on_vid_operation (Gtk.Button button) {
            if (stack.size > 0 && stack[stack.size - 1].denominator == 1) {
                // Remove the top value
                var top = stack.remove_at (stack.size - 1);

                // If we have at least one value left, swap the components
                if (stack.size > 0) {
                    var second = stack.remove_at (stack.size - 1);

                    // Create unit fraction from the top value
                    int64 top_value = top.numerator;
                    var unit_fraction1 = new Fraction (1, top_value);

                    // Create unit fraction from the second value
                    int64 second_value = second.numerator;
                    var unit_fraction2 = new Fraction (1, second_value);

                    // Add the unit fractions back to the stack
                    stack.add (unit_fraction1);
                    stack.add (unit_fraction2);
                } else {
                    // Just create and add unit fractions if only one value
                    int64 top_value = top.numerator;
                    var unit_fraction = new Fraction (1, top_value);
                    stack.add (unit_fraction);
                    stack.add (new Fraction (1, 1)); // Add 1/1 to match original behavior
                }

                // Update display
                update_all_displays ();
            }
        }

        /**
         * Handles inverting a fraction (swaps numerator and denominator)
         */
        private void on_stack_invert (Gtk.Button button) {
            if (stack.size > 0) {
                // Get the top value
                var top_idx = stack.size - 1;
                var fraction = stack[top_idx];

                // Create new inverted fraction by swapping numerator and denominator
                var inverted = new Fraction (fraction.denominator, fraction.numerator);

                // Replace the top value
                stack[top_idx] = inverted;

                // Update display
                update_all_displays ();
            }
        }

        /**
         * Update sensitivity of hex buttons based on current mode
         */
        private void update_button_sensitivity () {
            // Enable/disable hex buttons based on current mode
            foreach (var button in hex_buttons) {
                button.set_sensitive (current_base == 16);
            }
        }

        /**
         * Update all display labels to show values in the current base
         */
        private void update_all_displays () {
            // Update all stack displays based on current stack size
            display_stack1.set_text ("");
            display_stack2.set_text ("");
            display_stack3.set_text ("");
            display_stack4.set_text ("");
            display_stack5.set_text ("");

            // Fill stack displays from bottom to top
            for (int i = 0; i < stack.size && i < 5; i++) {
                string stack_value = stack[stack.size - 1 - i].to_string_for_base (current_base);

                switch (i) {
                case 0:
                    display_stack5.set_text (stack_value);
                    break;
                case 1:
                    display_stack4.set_text (stack_value);
                    break;
                case 2:
                    display_stack3.set_text (stack_value);
                    break;
                case 3:
                    display_stack2.set_text (stack_value);
                    break;
                case 4:
                    display_stack1.set_text (stack_value);
                    break;
                }
            }
        }

        /**
         * Handle number button clicks
         */
        private void on_number_clicked (Gtk.Button button) {
            // Get the button label safely
            string? label_text = button.get_label ();
            if (label_text == null)return;

            string digit = label_text;

            // Play a beep sound with brightness based on the button value
            play_beep (digit);

            // Check if the digit is valid for the current base
            if (current_base == 10 && !is_valid_decimal_digit (digit)) {
                return;
            }

            // Simple approach: just add the digit if we're under the limit
            if (current_input.length < MAX_INPUT_LENGTH) { // Allow for digits + '/' + more digits
                current_input += digit;
                update_display ();
            }
        }

        /**
         * Check if a digit is valid for decimal mode
         */
        private bool is_valid_decimal_digit (string digit) {
            // Check if the digit is valid for decimal mode (0-9)
            return digit.get_char (0) >= '0' && digit.get_char (0) <= '9';
        }

        /**
         * Handle operator button clicks
         */
        private void on_operator_clicked (Gtk.Button button) {
            // Get the button label safely
            string? label_text = button.get_label ();
            if (label_text == null)return;

            string op = label_text;

            // Special case for division symbol used for entering fractions
            if (op == "÷" && !current_input.contains ("/") && current_input.length > 0) {
                current_input += "/";
                update_display ();
                return;
            }

            // In an RPN calculator, operators act immediately on the top two stack items
            if (stack.size >= 2) {
                try {
                    // Get the top two values from the stack
                    Fraction val2 = stack.remove_at (stack.size - 1);
                    Fraction val1 = stack.remove_at (stack.size - 1);

                    Fraction result = new Fraction (0);

                    // Perform the operation
                    switch (op) {
                    case "+":
                        result = val1.add (val2);
                        break;
                    case "-":
                        result = val1.subtract (val2);
                        break;
                    case "*":
                        result = val1.multiply (val2);
                        break;
                    case "÷":
                        result = val1.divide (val2);
                        break;
                    case "&":
                        // Bitwise AND operation
                        int num1 = (int) val1.to_decimal ();
                        int num2 = (int) val2.to_decimal ();
                        result = new Fraction (num1 & num2);
                        break;
                    case "|":
                        // Bitwise OR operation
                        int num1 = (int) val1.to_decimal ();
                        int num2 = (int) val2.to_decimal ();
                        result = new Fraction (num1 | num2);
                        break;
                    case "«":
                        // Bitwise shift left (first operand shifted by second operand)
                        int num1 = (int) val1.to_decimal ();
                        int shift = (int) val2.to_decimal ();
                        result = new Fraction (num1 << shift);
                        break;
                    case "»":
                        // Bitwise shift right (first operand shifted by second operand)
                        int num1 = (int) val1.to_decimal ();
                        int shift = (int) val2.to_decimal ();
                        result = new Fraction (num1 >> shift);
                        break;
                    default:
                        // Push the values back if operation not recognized
                        stack.add (val1);
                        stack.add (val2);
                        return;
                    }

                    // Push result back to stack
                    stack.add (result);

                    // Update display based on current stack
                    update_all_displays ();

                    // Clear the input display when an operation is performed
                    current_input = "";
                    update_display ();
                } catch (Error e) {
                    warning ("Error in operation: %s", e.message);
                }
            }
        }

        /**
         * Handle clear button clicks
         */
        private void on_clear_clicked (Gtk.Button button) {
            // Clear the current input and stack displays
            current_input = "";

            // Clear the stack completely
            stack.clear ();

            // Update all displays
            update_all_displays ();
            update_display ();
        }

        /**
         * Handle stack push button clicks
         */
        private void on_stack_push (Gtk.Button button) {
            // Push current input to stack (RPN calculator style)
            if (current_input.length > 0) {
                try {
                    // Parse the input as a fraction using the current base
                    Fraction value = new Fraction.from_value (current_input, current_base);

                    stack.add (value);

                    // Update display to show stack operation
                    update_all_displays ();

                    // Clear current input after pushing to stack
                    current_input = "";
                    update_display ();
                } catch (Error e) {
                    warning ("Error parsing input: %s", e.message);
                    current_input = "";
                    update_display ();
                }
            }
        }

        /**
         * Handle stack pop button clicks
         */
        private void on_stack_pop (Gtk.Button button) {
            // Pop value from stack (RPN calculator style)
            if (stack != null && stack.size > 0) {
                try {
                    Fraction value = stack.remove_at (stack.size - 1);

                    // Set current input based on the current base
                    current_input = value.to_string_for_base (current_base);

                    // Update stack display
                    update_all_displays ();
                    update_display ();
                } catch (Error e) {
                    warning ("Error in stack pop: %s", e.message);
                }
            }
        }

        /**
         * Update the display with current input
         */
        private void update_display () {
            // Display the current input in the result area
            // If there's no input, show the default value
            if (current_input.length > 0) {
                display_input.set_text (current_input);

                // Only update pip area if input is a valid hex value (doesn't contain fraction)
                if (!current_input.contains ("/")) {
                    pip_area.set_from_hex (current_input);
                }
            } else {
                display_input.set_text ("0");
                pip_area.set_from_hex ("0");
            }
        }

        protected override void dispose () {
            // Cleanup GStreamer resources
            if (uxn_audio != null) {
                uxn_audio.cleanup();
            }

            base.dispose ();
        }
    }
}
