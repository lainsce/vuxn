/*
 * Turquoise - A pattern drawing application
 * Main window implementation - Complete rewrite matching the original design
 */

namespace Turquoise {
    public class MainWindow : Gtk.ApplicationWindow {
        // UI Components
        private Gtk.Box main_box;
        private Gtk.TextView rule_text_view;
        private Gtk.DrawingArea drawing_area;
        private Gtk.DrawingArea run_button;
        private Gtk.DrawingArea skip_button;
        private Gtk.DrawingArea show_instructions_button;
        private Gtk.DrawingArea show_end_button;
        
        private Theme.Manager theme = Theme.Manager.get_default();
        
        // VM State
        private VmState vm_state;
        private List<InstructionSet?> instruction_sets = new List<InstructionSet?>();
        private int current_set_index = 0;
        
        // Execution state
        private bool show_instructions = false;
        private bool show_end_point = false;
        private uint32 runner_source_id = 0;
        private bool is_running = false;
        private int current_instruction_index = 0;
        
        // Drawing history for visualization
        private class DrawPoint {
            public int x;
            public int y;
            public bool draw_line;
            public bool color_mode;
            public int flipx_state;    // Changed to int
            public int flipy_state;    // Changed to int
            public int mirror_state;   // Changed to int
            public int scale_state;
            
            public DrawPoint(int x, int y, bool draw_line, bool color_mode, 
                            int flipx, int flipy, int mirror, int scale) {
                this.x = x;
                this.y = y;
                this.draw_line = draw_line;
                this.color_mode = color_mode;
                this.flipx_state = flipx;
                this.flipy_state = flipy;
                this.mirror_state = mirror;
                this.scale_state = scale;
            }
        }
        
        private List<DrawPoint> draw_history;

        public MainWindow(Gtk.Application app) {
            Object(
                application: app,
                title: "Turquoise",
                default_width: 272,
                default_height: 192,
                resizable: false
            );

            theme.apply_to_display();
            setup_theme_management();
            theme.theme_changed.connect(() => {
                drawing_area.queue_draw();
                run_button.queue_draw();
                skip_button.queue_draw();
                show_instructions_button.queue_draw();
                show_end_button.queue_draw();
            });
            
            // Hide default titlebar
            var _tmp = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            _tmp.visible = false;
            titlebar = _tmp;

            // Load CSS
            var provider = new Gtk.CssProvider();
            provider.load_from_resource("/com/example/turquoise/style.css");

            // Apply CSS to the app
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );

            draw_history = new List<DrawPoint>();
            
            setup_ui();
            setup_actions();
            setup_drag_and_drop();
            
            // Initialize VM state
            reset_vm_state();
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
            // Main container
            main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            set_child(main_box);
            
            main_box.append(create_titlebar());
            
            var content_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);

            // Left pane container (1/3 of the width)
            var left_pane = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            
            // Rule text view
            rule_text_view = new Gtk.TextView();
            rule_text_view.set_wrap_mode(Gtk.WrapMode.WORD);
            rule_text_view.set_monospace(true);
            rule_text_view.left_margin = 4;
            rule_text_view.right_margin = 4;
            
            var scroll = new Gtk.ScrolledWindow();
            scroll.set_hexpand(true);
            scroll.set_vexpand(true);
            scroll.set_child(rule_text_view);
            left_pane.append(scroll);
            
            // Button row
            var button_row = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
            button_row.set_margin_start(2);
            button_row.set_margin_end(2);
            button_row.set_margin_top(2);
            button_row.set_margin_bottom(2);
            
            // Create buttons with common function
            run_button = create_button(8, 8, draw_run_button, on_run_button_clicked);
            skip_button = create_button(8, 8, draw_skip_button, on_skip_button_clicked);
            show_instructions_button = create_button(8, 8, draw_show_instructions_button, on_show_instructions_clicked);
            show_end_button = create_button(8, 8, draw_show_end_button, on_show_end_clicked);
            
            // Left side buttons
            var left_buttons = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
            left_buttons.append(run_button);
            left_buttons.append(skip_button);
            
            // Add button containers to button row
            button_row.append(left_buttons);
            
            // Add spacer to push right buttons to the right side
            var spacer = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            spacer.set_hexpand(true);
            button_row.append(spacer);
            
            // Right side buttons
            var right_buttons = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 2);
            right_buttons.append(show_instructions_button);
            right_buttons.append(show_end_button);
            button_row.append(right_buttons);
            
            left_pane.append(button_row);
            content_box.append(left_pane);
            
            // Drawing area (2/3 of the width)
            drawing_area = new Gtk.DrawingArea();
            drawing_area.set_hexpand(true);
            drawing_area.set_vexpand(true);
            drawing_area.content_width = 181;
            drawing_area.content_height = 181;
            drawing_area.set_draw_func(draw_canvas);
            content_box.append(drawing_area);
            
            main_box.append(content_box);
            
            // Set up widget sizes - use size constraints
            int total_width = 272;
            left_pane.hexpand = false;
            left_pane.width_request = total_width / 3;
            drawing_area.width_request = (total_width * 2) / 3;
        }
        
        // Title bar
        private Gtk.Widget create_titlebar() {
            // Create classic Mac-style title bar
            var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            title_bar.width_request = 272;

            // Close button on the left
            var close_button = new Gtk.Button();
            close_button.add_css_class("close-button");
            close_button.tooltip_text = "Close";
            close_button.valign = Gtk.Align.CENTER;
            close_button.halign = Gtk.Align.START;
            close_button.margin_start = 4;
            close_button.margin_top = 4;
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
        
        // Define delegate for button click callback
        private delegate void ButtonClickedFunc(Gtk.GestureClick gesture, int n_press, double x, double y);
        
        private Gtk.DrawingArea create_button(int width, int height, 
                                           Gtk.DrawingAreaDrawFunc draw_func, 
                                           owned ButtonClickedFunc clicked_func) {
            var button = new Gtk.DrawingArea();
            button.set_content_width(width);
            button.set_content_height(height);
            button.set_draw_func(draw_func);
            
            var click = new Gtk.GestureClick();
            button.add_controller(click);
            click.released.connect(clicked_func);
            
            return button;
        }
        
        private void setup_actions() {
            // Add keyboard shortcuts
            var key_controller = new Gtk.EventControllerKey();
            main_box.add_controller(key_controller);
            key_controller.key_pressed.connect(on_key_pressed);
        }
        
        private void setup_drag_and_drop() {
            var drop_target = new Gtk.DropTarget(typeof(Gdk.FileList), Gdk.DragAction.COPY);
            drop_target.drop.connect(on_drop);
            main_box.add_controller(drop_target);
        }
        
        private bool on_drop(Gtk.DropTarget target, Value value, double x, double y) {
            if (value.type() == typeof(Gdk.FileList)) {
                var file_list = (Gdk.FileList)value.get_boxed();
                foreach (var file in file_list.get_files()) {
                    if (file.get_path().has_suffix(".turquoise")) {
                        load_file(file);
                        return true;
                    }
                }
            }
            return false;
        }
        
        private void load_file(File file) {
            try {
                uint8[] contents;
                string etag_out;
                file.load_contents(null, out contents, out etag_out);
                
                var buffer = rule_text_view.get_buffer();
                buffer.set_text((string)contents, contents.length);
            } catch (Error e) {
            }
        }
        
        private bool on_key_pressed(Gtk.EventControllerKey controller, uint keyval, uint keycode, Gdk.ModifierType modifiers) {
            if (keyval == Gdk.Key.r && (modifiers & Gdk.ModifierType.CONTROL_MASK) != 0) {
                on_run_button_clicked();
                return true;
            }
            return false;
        }
        
        /* Button click handlers */
        private void on_run_button_clicked(Gtk.GestureClick? gesture = null, int n_press = 0, double x = 0, double y = 0) {
            if (is_running) {
                // Stop the current execution
                if (runner_source_id > 0) {
                    Source.remove(runner_source_id);
                    runner_source_id = 0;
                }
                is_running = false;
                drawing_area.queue_draw();
                run_button.queue_draw();
                return;
            }
            
            // Get text from the buffer
            var buffer = rule_text_view.get_buffer();
            Gtk.TextIter start, end;
            buffer.get_bounds(out start, out end);
            string text = buffer.get_text(start, end, false);
            
            // Parse instructions from hex string
            reset_vm_state();
            reset_instruction_set_counters();
            clear_drawing_history();
            parse_string_instructions(text);
            start_execution();
            run_button.queue_draw();
        }
        
        private void on_skip_button_clicked(Gtk.GestureClick? gesture = null, int n_press = 0, double x = 0, double y = 0) {
            // Skip 80 instructions
            int skip_count = 80;
            for (int i = 0; i < skip_count; i++) {
                execute_frame();
            }
            
            drawing_area.queue_draw();
        }
        
        private void on_show_instructions_clicked(Gtk.GestureClick? gesture = null, int n_press = 0, double x = 0, double y = 0) {
            show_instructions = !show_instructions;
            drawing_area.queue_draw();
            show_instructions_button.queue_draw();
        }
        
        private void on_show_end_clicked(Gtk.GestureClick? gesture = null, int n_press = 0, double x = 0, double y = 0) {
            show_end_point = !show_end_point;
            drawing_area.queue_draw();
            show_end_button.queue_draw();
        }
        
        /* Drawing functions for buttons */
        
        private void draw_run_button(Gtk.DrawingArea drawing_area, Cairo.Context cr, int width, int height) {
            // Set line properties
            cr.set_antialias(Cairo.Antialias.NONE);
            cr.set_line_width(1);
            
            // Draw play/stop icon
            if (is_running) {
                // Draw stop icon (square) in white when active
                Utils.set_color_bg(cr); // White for active icon
                cr.rectangle(2, 2, width - 2, height - 2);
                cr.fill();
            } else {
                // Draw play icon (triangle) in black when inactive
                Utils.set_color_fg(cr); // Black for inactive icon
                cr.move_to(1, 1);
                cr.line_to(1, height - 1);
                cr.line_to(width - 1, height / 2);
                cr.close_path();
                cr.fill();
            }
        }
        
        private void draw_skip_button(Gtk.DrawingArea drawing_area, Cairo.Context cr, int width, int height) {
            // Set line properties
            cr.set_antialias(Cairo.Antialias.NONE);
            cr.set_line_width(1);
            
            // Draw skip icon (simplified for 8x8)
            Utils.set_color_fg(cr); // Black for skip icon
            
            // First triangle
            cr.move_to(1, 1);
            cr.line_to(1, height - 1);
            cr.line_to(4, height / 2);
            cr.close_path();
            cr.fill();
            
            // Second triangle
            cr.move_to(4, 1);
            cr.line_to(4, height - 1);
            cr.line_to(7, height / 2);
            cr.close_path();
            cr.fill();
        }
        
        private void draw_show_instructions_button(Gtk.DrawingArea drawing_area, Cairo.Context cr, int width, int height) {
            // Set line properties
            cr.set_antialias(Cairo.Antialias.NONE);
            cr.set_line_width(1);
            int x = 0;
            int y = 0;
            
            if (show_instructions) {
                Utils.set_color_bg(cr); // White for active icon
            } else {
                Utils.set_color_fg(cr); // Black for inactive icon
            }

            cr.rectangle(x + 0, y + 1, 1, 1); // Bullet/number
            cr.rectangle(x + 2, y + 1, 6, 1); // Rule text
            cr.rectangle(x + 0, y + 3, 1, 1); // Bullet/number
            cr.rectangle(x + 2, y + 3, 6, 1); // Rule text
            cr.rectangle(x + 0, y + 5, 1, 1); // Bullet/number
            cr.rectangle(x + 2, y + 5, 6, 1); // Rule text
            cr.fill();
        }
        
        private void draw_show_end_button(Gtk.DrawingArea drawing_area, Cairo.Context cr, int width, int height) {
            // Set line properties
            cr.set_antialias(Cairo.Antialias.NONE);
            cr.set_line_width(1);
            int x = 0;
            int y = 0;

            if (show_end_point) {
                Utils.set_color_bg(cr); // White for active icon
            } else {
                Utils.set_color_fg(cr); // Black for inactive icon
            }
            
            cr.rectangle(x + 1, y + 0, 5, 1);
            cr.rectangle(x + 1, y + 6, 5, 1);
            cr.rectangle(x + 0, y + 1, 1, 5);
            cr.rectangle(x + 6, y + 1, 1, 5);
            cr.rectangle(x + 2, y + 2, 3, 1);
            cr.rectangle(x + 2, y + 4, 3, 1);
            cr.rectangle(x + 2, y + 3, 1, 1);
            cr.rectangle(x + 4, y + 3, 1, 1);
            cr.rectangle(x + 3, y + 3, 1, 1);
            cr.fill();
        }
        
        /* VM State and Instructions */
        private void reset_vm_state() {
            // Initialize the VM state
            vm_state = new VmState();
            vm_state.x = drawing_area.get_width() / 2;
            vm_state.y = drawing_area.get_height() / 2;
            vm_state.scale = 1;
            
            // Registers - use integers, not booleans
            vm_state.drawing = 1;     // Drawing starts enabled (1)
            vm_state.coloring = 0;    // Color mode starts disabled (0)
            vm_state.mirror = 0;      // Mirror starts disabled (0)
            vm_state.flipx = 0;       // Flip X starts disabled (0)
            vm_state.flipy = 0;       // Flip Y starts disabled (0)
            vm_state.return_flag = false; // Return flag starts disabled
            
            // Return position (unused until PUSH)
            vm_state.return_x = 0;
            vm_state.return_y = 0;
        }
        
        private void clear_drawing_history() {
            draw_history = new List<DrawPoint>();
        }
        
        private void add_to_drawing_history(
                                            int x,
                                            int y,
                                            int flipx,
                                            int flipy,
                                            int mirror,
                                            int scale,
                                            bool draw_line,
                                            bool color_mode
        ) {
            // Create a point with the current VM state
            var point = new DrawPoint(
                x, y, draw_line, color_mode, flipx, flipy, mirror, scale
            );
            
            // Add the point to history
            draw_history.append(point);
        }
        
        // Parse instructions from hex string
        private void parse_string_instructions(string text) {
            // Clear existing instruction sets
            instruction_sets = new List<InstructionSet?>();
            
            // Split the input by lines to process each instruction set separately
            string[] lines = text.split("\n");
            
            foreach (string line in lines) {
                // Skip empty lines
                if (line.strip() == "") continue;
                
                // Remove all whitespace for consistent processing
                string clean_line = line.replace(" ", "").strip();
                
                // Need at least 4 characters for a valid header (length + cycles)
                if (clean_line.length < 4) continue;
                
                // First byte (2 chars) as length
                string length_str = clean_line.substring(0, 2);
                uint8 length = Utils.hex_char_to_value(length_str[0]) * 16 + Utils.hex_char_to_value(length_str[1]);
                
                // Second byte (next 2 chars) as cycles
                string cycles_str = clean_line.substring(2, 2);
                uint8 cycles = Utils.hex_char_to_value(cycles_str[0]) * 16 + Utils.hex_char_to_value(cycles_str[1]);
                
                // Ensure we have enough characters for all commands
                if (clean_line.length < 4 + length) continue;
                
                // Extract and parse the commands (each command is one hex character)
                uint8[] instructions = new uint8[length];
                for (int i = 0; i < length; i++) {
                    char c = clean_line[4 + i];
                    if ((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
                        instructions[i] = Utils.hex_char_to_value(c);
                    } else {
                        // Invalid character, use 0 as default
                        instructions[i] = 0;
                    }
                }
                
                // Create and append the instruction set
                var set = new InstructionSet(length, cycles, instructions);
                instruction_sets.append(set);
            }
            
            // Reset to the first instruction set
            current_set_index = 0;
        }

        private void reset_instruction_set_counters() {
            foreach (InstructionSet set in instruction_sets) {
                set.cycles_completed = 0;
                set.frames_executed = 0;
            }
        }
        
        uint8 hex_to_int (string hex) {
			uint8 result = 0;

			for (int i = 0; i < hex.length; i++) {
				  char c = hex[i];
				  result *= 16;

				  if (c >= '0' && c <= '9') {
				      result += (uint8) (c - '0');
				  } else if (c >= 'a' && c <= 'f') {
				      result += (uint8) (c - 'a' + 10);
				  } else {
				      warning ("Invalid hex character: %c", c);
				      return 0;
				  }
			}

			return result;
	    }
        
        private void start_execution() {
            is_running = true;
            
            // Execute a frame every 1s
            runner_source_id = Timeout.add(100, () => {
                execute_frame();
                drawing_area.queue_draw();
                
                // Return true to keep the source active
                return is_running;
            });
        }

        // Execute a single frame of instructions
        private void execute_frame() {
            if (instruction_sets.length() == 0 || current_set_index >= instruction_sets.length()) {
                is_running = false;
                run_button.queue_draw();
                return;
            }
            
            // Get the current instruction set
            InstructionSet set = instruction_sets.nth_data(current_set_index);
            
            // Get the current instruction index within this set
            current_instruction_index = set.frames_executed % set.length;
            
            // Get the instruction to execute
            uint8 instruction = set.instructions[current_instruction_index];
            
            // Save the current state before executing (for history tracking)
            int prev_x = vm_state.x;
            int prev_y = vm_state.y;
            int prev_draw = vm_state.drawing;
            int prev_color = vm_state.coloring;
            
            // Execute the instruction
            InstructionDecoder.execute(instruction, ref vm_state);
            
            // Track position changes for drawing history
            if (vm_state.drawing != 0) {
                // Only add to history if we're in drawing mode
                bool color_mode = vm_state.coloring != 0;
                
                // Add previous point if it moved
                if (prev_x != vm_state.x || prev_y != vm_state.y) {
                    add_to_drawing_history(
                            prev_x,
                            prev_y,
                            vm_state.flipx,
                            vm_state.flipy,
                            vm_state.mirror,
                            vm_state.scale,
                            true,
                            color_mode
                    );
                }
                
                // Add current point
                add_to_drawing_history(
                        vm_state.x,
                        vm_state.y,
                        vm_state.flipx,
                        vm_state.flipy,
                        vm_state.mirror,
                        vm_state.scale,
                        true,
                        color_mode
                );
            }
            
            // Increment the frame counter
            set.frames_executed++;
            
            // Track cycles completion
            if (set.frames_executed % set.length == 0) {
                set.cycles_completed++;
                
                // Only move to the next set when all cycles are completed
                if (set.cycles_completed >= set.cycles) {
                    current_set_index++;
                    // Ensure we don't go out of bounds
                    if (current_set_index >= instruction_sets.length()) {
                        is_running = false;
                        run_button.queue_draw();
                    }
                }
            }
            
            drawing_area.queue_draw();
        }
        
        /* Drawing functions */
        private void draw_canvas(Gtk.DrawingArea drawing_area, Cairo.Context cr, int width, int height) {
            // Set drawing properties
            cr.set_line_width(1);
            cr.set_antialias(Cairo.Antialias.NONE);
            
            // Draw all recorded operations
            draw_history_path(cr);
            
            // Draw current position
            Utils.set_color_bg(cr);
            cr.rectangle(vm_state.x, vm_state.y, 1, 1);
            cr.fill();
            
            // Draw direction indicators if enabled
            if (show_instructions) {
                // Current instruction being executed
                draw_instructions_visualization(cr, 4, 0);
            }
            
            // Draw endpoint symbol if enabled
            if (show_end_point) {
                draw_endpoint_symbol(cr);
            }
        }
        
        private void draw_instructions_visualization(Cairo.Context cr, int x_start, int y_start) {
            // Set drawing properties
            cr.set_antialias(Cairo.Antialias.NONE);
            cr.set_line_width(1);
            
            if (instruction_sets.length() == 0 || current_set_index >= instruction_sets.length()) {
                return;
            }
            
            InstructionSet set = instruction_sets.nth_data(current_set_index);
            
            // Set up layout parameters
            int grid_spacing = 9; // Space between cells
            int items_per_row = 16; // Number of instructions per row
            
            // Draw instruction grid
            for (int i = 0; i < set.instructions.length; i++) {
                uint8 instruction = set.instructions[i];
                
                // Calculate grid position
                int row = i / items_per_row;
                int col = i % items_per_row;
                
                int x = x_start + col * grid_spacing;
                int y = y_start + row * grid_spacing;
                
                // Highlight current instruction being executed
                bool is_active = (i % set.length == current_instruction_index);
                
                if (is_active) {
                    // Draw the symbol in white
                    Utils.set_color_bg(cr);
                } else {
                    Utils.set_color_fg(cr);
                }
                
                switch (instruction) {
                    case Instruction.PUSH_POP:
                        // Draw stack icon (four dots)
                        cr.rectangle(x + 3, y + 1, 1, 1);
                        cr.rectangle(x + 3, y + 5, 1, 1);
                        cr.rectangle(x + 1, y + 3, 1, 1);
                        cr.rectangle(x + 5, y + 3, 1, 1);
                        cr.fill();
                        break;
                        
                    case Instruction.MOVE_RIGHT:
                        draw_right_arrow(cr, x, y);
                        break;
                        
                    case Instruction.MOVE_LEFT:
                        draw_left_arrow(cr, x, y);
                        break;
                        
                    case Instruction.MOVE_DOWN:
                        draw_down_arrow(cr, x, y);
                        break;
                        
                    case Instruction.MOVE_UP:
                        draw_up_arrow(cr, x, y);
                        break;
                        
                    case Instruction.MOVE_DOWN_RIGHT:
                        draw_down_right_arrow(cr, x, y);
                        break;
                        
                    case Instruction.MOVE_DOWN_LEFT:
                        draw_down_left_arrow(cr, x, y);
                        break;
                        
                    case Instruction.MOVE_UP_RIGHT:
                        draw_up_right_arrow(cr, x, y);
                        break;
                        
                    case Instruction.MOVE_UP_LEFT:
                        draw_up_left_arrow(cr, x, y);
                        break;
                        
                    case Instruction.FLIP_HORIZONTAL:
                        draw_flip_horizontal(cr, x, y);
                        break;
                        
                    case Instruction.FLIP_VERTICAL:
                        draw_flip_vertical(cr, x, y);
                        break;
                        
                    case Instruction.MIRROR:
                        draw_mirror(cr, x, y);
                        break;
                        
                    case Instruction.COLOR:
                        // Draw alternating pixels to create a checkerboard pattern
                        for (int crow = 0; crow < 7; crow++) {
                            for (int ccol = 0; ccol < 7; ccol++) {
                                if ((crow + ccol) % 2 == 0) {
                                    cr.rectangle(x + ccol, y + crow, 1, 1);
                                }
                            }
                        }
                        
                        // Fill all rectangles
                        cr.fill();
                        break;
                        
                    case Instruction.DRAW:
                        // Outer square
                        cr.rectangle(x + 0, y + 0, 7, 1);
                        cr.rectangle(x + 0, y + 6, 7, 1);
                        cr.rectangle(x + 0, y + 1, 1, 5);
                        cr.rectangle(x + 6, y + 1, 1, 5);
                        
                        // Draw inner square
                        cr.rectangle(x + 2, y + 2, 3, 1);
                        cr.rectangle(x + 2, y + 4, 3, 1);
                        cr.rectangle(x + 2, y + 3, 1, 1);
                        cr.rectangle(x + 4, y + 3, 1, 1);

                        cr.fill();
                        break;
                        
                    case Instruction.SCALE_UP:
                        // Draw scale up
                        cr.rectangle(x + 3, y + 0, 1, 1);
                        cr.rectangle(x + 2, y + 1, 3, 1);
                        cr.rectangle(x + 1, y + 2, 5, 1);
                        for (int crow = 3; crow < 7; crow++) {
                            cr.rectangle(x + 0, y + crow, 7, 1);
                        }
                        cr.fill();
                        break;
                        
                    case Instruction.SCALE_DOWN:
                        // Draw scale down
                        for (int crow = 0; crow < 4; crow++) {
                            cr.rectangle(x + 0, y + crow, 7, 1);
                        }
                        cr.rectangle(x + 1, y + 4, 5, 1);
                        cr.rectangle(x + 2, y + 5, 3, 1);
                        cr.rectangle(x + 3, y + 6, 1, 1);
                        cr.fill();
                        break;
                }
            }
        }
        
        private void draw_history_path(Cairo.Context cr) {
            DrawPoint? previous = null;
            
            foreach (var point in draw_history) {
                // Choose color based on point state
                if (point.color_mode) {
                    Utils.set_color_accent(cr);
                } else {
                    Utils.set_color_fg(cr);
                }
                
                // Draw the point
                cr.rectangle(point.x, point.y, 1, 1);
                cr.fill();
                
                previous = point;
            }
        }
        
        private void draw_right_arrow(Cairo.Context cr, int x, int y) {
            // Arrow body
            // Row 0
            cr.rectangle(x + 0, y + 3, 1, 1);
            
            // Row 1
            cr.rectangle(x + 1, y + 3, 1, 1);
            
            // Row 2
            cr.rectangle(x + 2, y + 3, 1, 1);
            
            // Row 3
            cr.rectangle(x + 3, y + 0, 1, 1);
            cr.rectangle(x + 3, y + 1, 1, 1);
            cr.rectangle(x + 3, y + 2, 1, 1);
            cr.rectangle(x + 3, y + 3, 1, 1);
            cr.rectangle(x + 3, y + 4, 1, 1);
            cr.rectangle(x + 3, y + 5, 1, 1);
            cr.rectangle(x + 3, y + 6, 1, 1);
            
            // Row 4
            cr.rectangle(x + 4, y + 1, 1, 1);
            cr.rectangle(x + 4, y + 2, 1, 1);
            cr.rectangle(x + 4, y + 3, 1, 1);
            cr.rectangle(x + 4, y + 4, 1, 1);
            cr.rectangle(x + 4, y + 5, 1, 1);
            
            // Row 5
            cr.rectangle(x + 5, y + 2, 1, 1);
            cr.rectangle(x + 5, y + 3, 1, 1);
            cr.rectangle(x + 5, y + 4, 1, 1);
            
            // Row 6
            cr.rectangle(x + 6, y + 3, 1, 1);
            cr.fill();
        }

        // Draw left arrow (mirror of right arrow)
        private void draw_left_arrow(Cairo.Context cr, int x, int y) {
            // Mirror the right arrow
            cr.rectangle(x + 6, y + 3, 1, 1);
            cr.rectangle(x + 5, y + 3, 1, 1);
            cr.rectangle(x + 4, y + 3, 1, 1);
            
            cr.rectangle(x + 3, y + 0, 1, 1);
            cr.rectangle(x + 3, y + 1, 1, 1);
            cr.rectangle(x + 3, y + 2, 1, 1);
            cr.rectangle(x + 3, y + 3, 1, 1);
            cr.rectangle(x + 3, y + 4, 1, 1);
            cr.rectangle(x + 3, y + 5, 1, 1);
            cr.rectangle(x + 3, y + 6, 1, 1);
            
            cr.rectangle(x + 2, y + 1, 1, 1);
            cr.rectangle(x + 2, y + 2, 1, 1);
            cr.rectangle(x + 2, y + 3, 1, 1);
            cr.rectangle(x + 2, y + 4, 1, 1);
            cr.rectangle(x + 2, y + 5, 1, 1);
            
            cr.rectangle(x + 1, y + 2, 1, 1);
            cr.rectangle(x + 1, y + 3, 1, 1);
            cr.rectangle(x + 1, y + 4, 1, 1);
            
            cr.rectangle(x + 0, y + 3, 1, 1);
            cr.fill();
        }

        // Draw down arrow (rotate right arrow 90 degrees clockwise)
        private void draw_down_arrow(Cairo.Context cr, int x, int y) {
            // Center column
            cr.rectangle(x + 3, y + 0, 1, 1);
            cr.rectangle(x + 3, y + 1, 1, 1);
            cr.rectangle(x + 3, y + 2, 1, 1);
            
            // Horizontal part
            cr.rectangle(x + 0, y + 3, 1, 1);
            cr.rectangle(x + 1, y + 3, 1, 1);
            cr.rectangle(x + 2, y + 3, 1, 1);
            cr.rectangle(x + 3, y + 3, 1, 1);
            cr.rectangle(x + 4, y + 3, 1, 1);
            cr.rectangle(x + 5, y + 3, 1, 1);
            cr.rectangle(x + 6, y + 3, 1, 1);
            
            // Arrow head
            cr.rectangle(x + 1, y + 4, 1, 1);
            cr.rectangle(x + 2, y + 4, 1, 1);
            cr.rectangle(x + 3, y + 4, 1, 1);
            cr.rectangle(x + 4, y + 4, 1, 1);
            cr.rectangle(x + 5, y + 4, 1, 1);
            
            cr.rectangle(x + 2, y + 5, 1, 1);
            cr.rectangle(x + 3, y + 5, 1, 1);
            cr.rectangle(x + 4, y + 5, 1, 1);
            
            cr.rectangle(x + 3, y + 6, 1, 1);
            cr.fill();
        }

        // Draw up arrow (rotate right arrow 90 degrees counter-clockwise)
        private void draw_up_arrow(Cairo.Context cr, int x, int y) {
            // Center column
            cr.rectangle(x + 3, y + 4, 1, 1);
            cr.rectangle(x + 3, y + 5, 1, 1);
            cr.rectangle(x + 3, y + 6, 1, 1);
            
            // Horizontal part
            cr.rectangle(x + 0, y + 3, 1, 1);
            cr.rectangle(x + 1, y + 3, 1, 1);
            cr.rectangle(x + 2, y + 3, 1, 1);
            cr.rectangle(x + 3, y + 3, 1, 1);
            cr.rectangle(x + 4, y + 3, 1, 1);
            cr.rectangle(x + 5, y + 3, 1, 1);
            cr.rectangle(x + 6, y + 3, 1, 1);
            
            // Arrow head
            cr.rectangle(x + 1, y + 2, 1, 1);
            cr.rectangle(x + 2, y + 2, 1, 1);
            cr.rectangle(x + 3, y + 2, 1, 1);
            cr.rectangle(x + 4, y + 2, 1, 1);
            cr.rectangle(x + 5, y + 2, 1, 1);
            
            cr.rectangle(x + 2, y + 1, 1, 1);
            cr.rectangle(x + 3, y + 1, 1, 1);
            cr.rectangle(x + 4, y + 1, 1, 1);
            
            cr.rectangle(x + 3, y + 0, 1, 1);
            cr.fill();
        }

        // Draw diagonal arrows
        private void draw_down_right_arrow(Cairo.Context cr, int x, int y) {
            cr.rectangle(x + 0, y + 1, 1, 1);
            cr.rectangle(x + 5, y + 1, 1, 1);
            cr.rectangle(x + 0, y + 2, 2, 1);
            cr.rectangle(x + 4, y + 2, 1, 1);
            cr.rectangle(x + 0, y + 3, 4, 1);
            cr.rectangle(x + 0, y + 4, 4, 1);
            cr.rectangle(x + 0, y + 5, 5, 1);
            cr.rectangle(x + 0, y + 6, 6, 1);
            cr.fill();
        }

        private void draw_down_left_arrow(Cairo.Context cr, int x, int y) {
            cr.rectangle(x + 1, y + 1, 1, 1);
            cr.rectangle(x + 6, y + 1, 1, 1);
            cr.rectangle(x + 2, y + 2, 1, 1);
            cr.rectangle(x + 5, y + 2, 2, 1);
            cr.rectangle(x + 3, y + 3, 4, 1);
            cr.rectangle(x + 3, y + 4, 4, 1);
            cr.rectangle(x + 2, y + 5, 5, 1);
            cr.rectangle(x + 1, y + 6, 6, 1);
            cr.fill();
        }

        private void draw_up_right_arrow(Cairo.Context cr, int x, int y) {
            cr.rectangle(x + 1, y + 0, 6, 1);
            cr.rectangle(x + 2, y + 1, 5, 1);
            cr.rectangle(x + 3, y + 2, 4, 1);
            cr.rectangle(x + 3, y + 3, 4, 1);
            cr.rectangle(x + 2, y + 4, 1, 1);
            cr.rectangle(x + 5, y + 4, 2, 1);
            cr.rectangle(x + 1, y + 5, 1, 1);
            cr.rectangle(x + 6, y + 5, 1, 1);
            cr.fill();
        }

        private void draw_up_left_arrow(Cairo.Context cr, int x, int y) {
            cr.rectangle(x + 0, y + 0, 6, 1);
            cr.rectangle(x + 0, y + 1, 5, 1);
            cr.rectangle(x + 0, y + 2, 4, 1);
            cr.rectangle(x + 0, y + 3, 4, 1);
            cr.rectangle(x + 0, y + 4, 2, 1);
            cr.rectangle(x + 4, y + 4, 1, 1);
            cr.rectangle(x + 0, y + 5, 1, 1);
            cr.rectangle(x + 5, y + 5, 1, 1);
            cr.fill();
        }

        // Draw flip horizontal symbol
        private void draw_flip_horizontal(Cairo.Context cr, int x, int y) {
            // Middle vertical line
            cr.rectangle(x + 3, y + 0, 1, 7);
            
            // Vertical lines at ends
            cr.rectangle(x + 1, y + 0, 1, 7);
            cr.rectangle(x + 5, y + 0, 1, 7);
            
            // Dots in the sides
            cr.rectangle(x + 0, y + 3, 1, 1);
            cr.rectangle(x + 6, y + 3, 1, 1);
            cr.fill();
        }

        // Draw flip vertical symbol
        private void draw_flip_vertical(Cairo.Context cr, int x, int y) {
            // Middle horizontal line
            cr.rectangle(x + 0, y + 3, 7, 1);
            
            // Horizontal lines at ends
            cr.rectangle(x + 0, y + 1, 7, 1);
            cr.rectangle(x + 0, y + 5, 7, 1);
            
            // Dots in the sides
            cr.rectangle(x + 3, y + 0, 1, 1);
            cr.rectangle(x + 3, y + 6, 1, 1);
            cr.fill();
        }

        // Draw mirror symbol
        private void draw_mirror(Cairo.Context cr, int x, int y) {
            cr.rectangle(x + 2, y + 0, 3, 1);
            cr.rectangle(x + 6, y + 0, 1, 1);
            cr.rectangle(x + 1, y + 1, 1, 1);
            cr.rectangle(x + 5, y + 1, 1, 1);
            cr.rectangle(x + 0, y + 2, 1, 1);
            cr.rectangle(x + 4, y + 2, 1, 1);
            cr.rectangle(x + 6, y + 2, 1, 1);
            cr.rectangle(x + 0, y + 3, 1, 1);
            cr.rectangle(x + 3, y + 3, 1, 1);
            cr.rectangle(x + 6, y + 3, 1, 1);
            cr.rectangle(x + 0, y + 4, 1, 1);
            cr.rectangle(x + 2, y + 4, 1, 1);
            cr.rectangle(x + 6, y + 4, 1, 1);
            cr.rectangle(x + 1, y + 5, 1, 1);
            cr.rectangle(x + 5, y + 5, 1, 1);
            cr.rectangle(x + 0, y + 6, 1, 1);
            cr.rectangle(x + 2, y + 6, 3, 1);
            cr.fill();
        }
        
        private void draw_endpoint_symbol(Cairo.Context cr) {
            // Draw Ø symbol at endpoint
            Utils.set_color_bg(cr);
            
            // Draw a square instead of a circle for precise pixel alignment
            int size = (int)Math.floor(Math.fmax(2.0f, Math.fmin(8.0f, vm_state.scale * 2.0f)));
            cr.rectangle(vm_state.x - size, vm_state.y - size, size * 2, size * 2);
            cr.stroke();
            
            // Smaller square
            cr.rectangle(vm_state.x - size / 2, vm_state.y - size / 2, 1, 1);
            cr.stroke();
        }
    }
}