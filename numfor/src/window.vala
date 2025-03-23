using Gtk;

public class Window : He.ApplicationWindow {
    // UI components
    private Grid grid;
    private Label formula_display; // Display label for formula on status bar
    private Label coordinates_label;
    private Label result_label;
    private Label title_label;
    private Grid spreadsheet_grid;
    private ScrolledWindow scrolled_window;

    // Cell data storage
    private string[,] cell_data;
    private Widget[,] cell_buttons;
    private Label[,] cell_labels;
    private Entry[,] cell_entries;
    private Label[] row_headers;
    private Label[] col_headers;

    // Grid dimensions
    private int rows = 26;
    private int cols = 8;
    private int visible_rows_start = 0;
    private int visible_rows_count = 20; // Number of visible rows

    // Header highlighting state
    private int current_hover_row = -1;
    private int current_hover_col = -1;

    // Currently selected cell (single cell focus)
    private int active_row = -1;
    private int active_col = -1;

    // Selection state
    private bool has_selection = false;
    private int selection_start_row = -1;
    private int selection_start_col = -1;
    private int selection_end_row = -1;
    private int selection_end_col = -1;

    // Drag selection state
    private bool is_dragging = false;
    private int drag_start_row = -1;
    private int drag_start_col = -1;

    // Referenced cells tracking
    private Gee.ArrayList<Utils.CellPosition> temp_highlighted_cells;
    private Gee.HashSet<string> processed_cells = new Gee.HashSet<string>();

    private bool is_editing_formula = false;

    // Add a property to track the current file path
    private string file_path = "";

    private Gee.MultiMap<string, string> cell_dependencies = new Gee.HashMultiMap<string, string>();

    public Window(He.Application app) {
        Object(
            application: app,
            default_width: 565,
            default_height: 391,
            width_request: 591,
            height_request: 391
        );

        // Initialize cell data
        cell_data = new string[rows, cols];
        temp_highlighted_cells = new Gee.ArrayList<Utils.CellPosition>();

        // Create the main vertical layout
        grid = new Grid();
        grid.orientation = Orientation.VERTICAL;
        grid.hexpand = true;
        grid.vexpand = true;

        // Create UI components
        create_spreadsheet_grid();
        create_formula_bar();

        // Set up main layout
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        box.hexpand = true;
        box.vexpand = true;
        box.append(create_titlebar());
        box.append(grid);

        set_child(box);

        // Set up keyboard handling for the whole window
        var key_controller = new Gtk.EventControllerKey();
        key_controller.key_released.connect((keyval, keycode, state) => {
            on_key_released(keyval, keycode, state);
        });
        key_controller.key_pressed.connect((keyval, keycode, state) => {
            if (active_row >= 0 && active_col >= 0) {
                switch (keyval) {
                    case Gdk.Key.Up:
                        if (active_row > 0) {
                            start_cell_edit(active_row - 1, active_col);
                        }
                        return true;

                    case Gdk.Key.Down:
                        if (active_row < rows - 1) {
                            start_cell_edit(active_row + 1, active_col);
                        }
                        return true;

                    case Gdk.Key.Left:
                        if (active_col > 0) {
                            start_cell_edit(active_row, active_col - 1);
                        }
                        return true;

                    case Gdk.Key.Right:
                        if (active_col < cols - 1) {
                            start_cell_edit(active_row, active_col + 1);
                        }
                        return true;
                        
                    case Gdk.Key.Return:
                    case Gdk.Key.KP_Enter:
                        // First process the current formula if there's an active edit
                        if (is_editing_formula && active_row >= 0 && active_col >= 0) {
                            finish_cell_edit(active_row, active_col);
                        }
                        
                        // Then move to the cell below if possible
                        if (active_row < rows - 1) {
                            start_cell_edit(active_row + 1, active_col);
                        }
                        return true;
                }
            }
            return false;
        });
        box.add_controller(key_controller);
        
        var shortcut_controller = new Gtk.ShortcutController();
        shortcut_controller.add_shortcut(new Gtk.Shortcut(
            Gtk.ShortcutTrigger.parse_string("Escape"),
            new Gtk.CallbackAction((widget) => {
                clear_selection();
                return true;
            })
        ));
        this.add_controller(shortcut_controller);
    }

	private void update_all_cells_in_selection_range() {
	    // Normalize selection coordinates
	    int min_row = int.min(selection_start_row, selection_end_row);
	    int max_row = int.max(selection_start_row, selection_end_row);
	    int min_col = int.min(selection_start_col, selection_end_col);
	    int max_col = int.max(selection_start_col, selection_end_col);
	    
	    // Clear selection from all cells first
	    for (int r = 0; r < rows; r++) {
	        for (int c = 0; c < cols; c++) {
	            // Only clear cells outside the selection
	            if (r < min_row || r > max_row || c < min_col || c > max_col) {
	                cell_buttons[r, c].remove_css_class("cell-selected");
	            }
	        }
	    }
	    
	    // Now add selection to all cells in range
	    for (int r = min_row; r <= max_row; r++) {
	        for (int c = min_col; c <= max_col; c++) {
	            cell_buttons[r, c].add_css_class("cell-selected");
	        }
	    }
	}

    private bool on_key_released(uint keyval, uint keycode, Gdk.ModifierType state) {
        print("Key released: %u\n", keyval);
        
        // Debug the current selection
        if (has_selection) {
            print("Current selection: start=(%d,%d), end=(%d,%d)\n", 
                  selection_start_row, selection_start_col,
                  selection_end_row, selection_end_col);
        }
        
        // Handle keyboard shortcuts
        if (keyval == Gdk.Key.Escape) {
            // Escape key clears selection
            clear_selection();
            return true;
        }

        // If active cell is selected and user presses '='
        if (keyval == Gdk.Key.equal && active_row >= 0 && active_col >= 0) {
            // Start formula editing
            start_cell_edit(active_row, active_col);
            
            // Set text to "=" and place cursor at end
            if (cell_entries[active_row, active_col] != null) {
                cell_entries[active_row, active_col].text = "=";
                is_editing_formula = true;
                Timeout.add(10, () => {
                    cell_entries[active_row, active_col].set_position(1);
                    return false;
                });
            }
            
            return true;
        }

        return false;
    }

    private Gtk.Widget create_titlebar() {
        // Create Mac-style title bar
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        title_bar.hexpand = true;
        title_bar.add_css_class("title-bar");

        // Close button
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;
        close_button.clicked.connect(() => this.close());

        // Title
        var title_label = new Gtk.Label("Numfor");
        title_label.add_css_class("title-box");
        title_label.hexpand = true;
        title_label.valign = Gtk.Align.CENTER;
        title_label.halign = Gtk.Align.CENTER;

        // Store reference to title label as a class member for easier updates
        this.title_label = title_label;

        // Update the title if we already have a file path
        update_window_title();

        // Arrange titlebar components
        title_bar.append(close_button);
        title_bar.append(title_label);

        // Enable window dragging
        var winhandle = new Gtk.WindowHandle();
        winhandle.set_child(title_bar);

        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        vbox.append(winhandle);

        return vbox;
    }

    private void create_spreadsheet_grid() {
        spreadsheet_grid = new Grid();

        // Initialize arrays for headers and cells
        row_headers = new Label[rows];
        col_headers = new Label[cols];
        cell_buttons = new Widget[rows, cols];
        cell_labels = new Label[rows, cols];
        cell_entries = new Entry[rows, cols];

        // Create header row
        create_header_row();

        // Add row numbers and cells
        for (int row = 0; row < rows; row++) {
            // Add row number
            var row_label = new Label(row.to_string()) {
                width_request = 60,
                height_request = 16,
                valign = Align.CENTER,
                halign = Align.END,
                xalign = (float)0.90
            };
            row_label.add_css_class("row-header");
            row_headers[row] = row_label;
            spreadsheet_grid.attach(row_label, 0, row + 1, 1, 1);

            // Add cells for this row
            for (int col = 0; col < cols; col++) {
                var cell = create_cell(row, col);
                cell_buttons[row, col] = cell;
                spreadsheet_grid.attach(cell, col + 1, row + 1, 1, 1);
            }
        }

        // Make the spreadsheet scrollable
        scrolled_window = new ScrolledWindow();
        scrolled_window.set_child(spreadsheet_grid);
        scrolled_window.vexpand = true;
        scrolled_window.hexpand = true;

        scrolled_window.vadjustment.value_changed.connect(() => {
            update_visible_rows();
        });

        // Add a click handler to the grid to clear selection when clicking empty areas
        var grid_click = new Gtk.GestureClick();
        grid_click.button = 1;
        grid_click.pressed.connect((n_press, x, y) => {
            // Clear selection when clicking on the grid (but not on cells)
            hide_all_entry_fields();
            clear_selection();
        });

        spreadsheet_grid.add_controller(grid_click);
        
        // Setup global drag handlers
        setup_global_drag_handlers();

        grid.attach(scrolled_window, 0, 0, 1, 1);
    }

    private void update_visible_rows() {
        double scroll_pos = scrolled_window.vadjustment.value;
        int row_height = 16; // Match your row height

        // Calculate which rows should be visible
        int new_start = (int)(scroll_pos / row_height);
        if (new_start != visible_rows_start) {
            visible_rows_start = new_start;

            // Only update cells that are actually visible
            for (int r = visible_rows_start; r < visible_rows_start + visible_rows_count && r < rows; r++) {
                for (int c = 0; c < cols; c++) {
                    update_single_cell(r, c);
                }
            }
        }
    }

    private void create_header_row() {
        // Create corner cell for coordinates display
        var corner_cell = new Label("") {
            width_request = 60,
            height_request = 16,
            xalign = (float)0.10,
            valign = Align.CENTER
        };
	corner_cell.add_css_class("cell-header");
        corner_cell.add_css_class("cell-corner");
        this.coordinates_label = corner_cell;
        spreadsheet_grid.attach(corner_cell, 0, 0, 1, 1);

        // Add column headers (A-Z)
        for (int col = 0; col < cols; col++) {
            var col_label = new Label(((char)('A' + col)).to_string()) {
                width_request = 60,
                height_request = 16,
                valign = Align.CENTER,
                xalign = (float)0.90
            };
            col_label.add_css_class("cell-header");
            col_headers[col] = col_label;
            spreadsheet_grid.attach(col_label, col + 1, 0, 1, 1);
        }
    }

    private Widget create_cell(int row, int col) {
        var cell_container = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0) {
            width_request = 60,
            height_request = 16,
            valign = Align.CENTER
        };
        cell_container.add_css_class("cell");
        
        // Label for normal display
        var cell_label = new Label("") {
            valign = Align.CENTER,
	    xalign = (float)0.10,
            max_width_chars = 6,
            single_line_mode = true,
            ellipsize = Pango.EllipsizeMode.END,
            hexpand = true
        };
        
        // Entry for editing directly in the cell
        var cell_entry = new Entry() {
            valign = Align.CENTER,
	    halign = Align.START,
	    max_width_chars = 6,
            visible = false  // Initially hidden
        };
        
        cell_container.append(cell_label);
        cell_container.append(cell_entry);
        
        // Also handle motion within the cell for better drag tracking
        var motion_controller = new Gtk.EventControllerMotion();
	motion_controller.enter.connect(() => {
	    // Track that the mouse entered this cell
	    update_hover_headers(row, col);
	    
	    // If we're dragging, directly modify this cell's appearance
	    if (is_dragging) {
	        // Update the end point of the selection
	        selection_end_row = row;
	        selection_end_col = col;
	        
	        // Add selection styling directly to this cell
	        cell_container.add_css_class("cell-selected");
	        
	        // Mark this cell as processed to avoid duplicate processing
	        string cell_key = "%d-%d".printf(row, col);
	        processed_cells.add(cell_key);
	        
	        // Update coordinates display for real-time feedback
	        coordinates_label.label = get_selection_reference();
	        
	        print("Cell entered during drag: row=%d, col=%d\n", row, col);
	    }
	});

	motion_controller.motion.connect((x, y) => {
	    if (is_dragging) {
	        // Still need to update even within the cell for smoother behavior
	        selection_end_row = row;
	        selection_end_col = col;
	        
	        // Use the more efficient styling update
	        update_drag_selection_styling(selection_start_row, selection_start_col, 
	                                     selection_end_row, selection_end_col);
	    }
	});
        
        motion_controller.leave.connect(() => {
            clear_hover_headers();
        });
        cell_container.add_controller(motion_controller);

        // Connect left-click events for selection with improved drag handling
        var left_click = new Gtk.GestureClick();
        left_click.button = 1;  // Left mouse button

        left_click.pressed.connect((n_press, x, y) => {
            // Skip multiple clicks for now
            if (n_press > 1) {
                return;
            }

	    // Clear the processed cells tracking for a new drag operation
            processed_cells.clear();

            // First, save any existing edits in other cells
            if (active_row >= 0 && active_col >= 0 &&
                (active_row != row || active_col != col)) {
                // Save changes from the previously edited cell
                if (cell_entries != null && 
                    cell_entries[active_row, active_col] != null &&
                    cell_entries[active_row, active_col].visible) {
                    finish_cell_edit(active_row, active_col);
                }
            }

            // Store the starting cell for dragging
            drag_start_row = row;
            drag_start_col = col;
            is_dragging = true;
            
            print("Starting drag from row=%d, col=%d\n", row, col);

            // Check if we're editing a formula
            bool editing_formula = is_editing_formula;

            if (editing_formula) {
                // When editing a formula, handle selection for reference insertion
                // Start a new selection
                selection_start_row = row;
                selection_start_col = col;
                selection_end_row = row;
                selection_end_col = col;
                has_selection = true;

                // Update the display
                update_selection_display();

                // Insert the reference
                insert_cell_reference_to_formula();
            } else {
                // Regular cell selection (not in formula mode)
                // Start a new selection
                clear_selection();
                
                selection_start_row = row;
                selection_start_col = col;
                selection_end_row = row;
                selection_end_col = col;
                has_selection = true;

                // Set active cell
                active_row = row;
                active_col = col;

                // Update formula display with cell content
                if (cell_data[row, col] != null) {
                    formula_display.label = cell_data[row, col];
                    
                    // Update result label if it's a formula
                    if (cell_data[row, col].has_prefix("=")) {
                        string formula = cell_data[row, col].substring(1);
                        result_label.label = Utils.calculate_rpn(formula, cell_data, rows, cols);
                    } else {
                        result_label.label = cell_data[row, col];
                    }
                } else {
                    formula_display.label = "";
                    result_label.label = "";
                }

                update_cell_indicator();

                // Update selection display
                update_selection_display();
            }

            // Stop event propagation
            left_click.set_state(Gtk.EventSequenceState.CLAIMED);
        });

        // Add release handler to end dragging
	left_click.released.connect((n_press, x, y) => {
	    if (is_dragging) {
	        is_dragging = false;
	        
	        // Calculate if we actually did a drag (different start and end cells)
	        bool did_drag = (selection_start_row != selection_end_row) || 
	                       (selection_start_col != selection_end_col);
	        
	        print("Ending drag. Did drag? %s\n", did_drag.to_string());
	        
	        // Do a full selection update to ensure consistency
	        update_selection_display();
	        
	        // If it was a single cell selection (no drag), start editing
	        if (!did_drag && !is_editing_formula) {
	            // Begin editing this cell directly
	            start_cell_edit(row, col);
	        }
	    }
	});

        cell_container.add_controller(left_click);
        
        // Add right-click handler for formula creation
        var right_click = new Gtk.GestureClick();
        right_click.button = 3;  // Right mouse button
        
        right_click.pressed.connect((n_press, x, y) => {
            // Create formula from selection when right-clicking
            if (has_selection) {
                // Don't use the selection if we're right-clicking within it
                bool is_in_selection = false;
                
                // Normalize selection coordinates
                int start_row = int.min(selection_start_row, selection_end_row);
                int end_row = int.max(selection_start_row, selection_end_row);
                int start_col = int.min(selection_start_col, selection_end_col);
                int end_col = int.max(selection_start_col, selection_end_col);
                
                // Check if the right-clicked cell is within the selection
                if (row >= start_row && row <= end_row && col >= start_col && col <= end_col) {
                    is_in_selection = true;
                }
                
                if (!is_in_selection) {
                    // Create formula in the right-clicked cell using the current selection
                    create_formula_from_selection(row, col);
                }
            }
            
            // Stop event propagation
            right_click.set_state(Gtk.EventSequenceState.CLAIMED);
        });
        
        cell_container.add_controller(right_click);
        
        // Setup entry for cell editing
        cell_entry.activate.connect(() => {
	    // First save the current cell's content
	    finish_cell_edit(row, col);
	    
	    // Then move to the cell below if possible
	    if (row < rows - 1) {
	        start_cell_edit(row + 1, col);
	    }
	});
        
        var entry_key_controller = new Gtk.EventControllerKey();
        entry_key_controller.key_pressed.connect((keyval, keycode, state) => {
	    if (keyval == Gdk.Key.Escape) {
	        cancel_cell_edit(row, col);
	        return true;
	    } else if (keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) {
	        // Let the activate signal handle this
	        // (the activate signal will be triggered after this handler)
	        return false;
	    } else if (keyval == Gdk.Key.Tab) {
	        // Handle Tab key to move to the next cell (right)
	        finish_cell_edit(row, col);
	        if (col < cols - 1) {
	            start_cell_edit(row, col + 1);
	        } else if (row < rows - 1) {
	            // Move to the first column of the next row
	            start_cell_edit(row + 1, 0);
	        }
	        return true;
	    } else if (keyval == Gdk.Key.ISO_Left_Tab) {
	        // Handle Shift+Tab to move to the previous cell (left)
	        finish_cell_edit(row, col);
	        if (col > 0) {
	            start_cell_edit(row, col - 1);
	        } else if (row > 0) {
	            // Move to the last column of the previous row
	            start_cell_edit(row - 1, cols - 1);
	        }
	        return true;
	    }
    	    return false;
        });
        cell_entry.add_controller(entry_key_controller);
        
        // Store the label and entry in maps for later access
        cell_labels[row, col] = cell_label;
        cell_entries[row, col] = cell_entry;

        return cell_container;
    }

	private void update_drag_selection_styling(int start_row, int start_col, int end_row, int end_col) {
	    // Normalize selection coordinates
	    int min_row = int.min(start_row, end_row);
	    int max_row = int.max(start_row, end_row);
	    int min_col = int.min(start_col, end_col);
	    int max_col = int.max(start_col, end_col);
	    
	    // Update the coordinates display
	    coordinates_label.label = "%c%d:%c%d".printf(
	        'A' + min_col, min_row,
	        'A' + max_col, max_row
	    );
	    
	    // Efficient update: only check cells that could be affected
	    for (int r = 0; r < rows; r++) {
	        for (int c = 0; c < cols; c++) {
	            bool should_be_selected = (r >= min_row && r <= max_row && 
	                                     c >= min_col && c <= max_col);
	            
	            bool is_selected = cell_buttons[r, c].has_css_class("cell-selected");
	            
	            // Only update styling if needed
	            if (should_be_selected && !is_selected) {
	                cell_buttons[r, c].add_css_class("cell-selected");
	            } else if (!should_be_selected && is_selected) {
	                cell_buttons[r, c].remove_css_class("cell-selected");
	            }
	        }
	    }
	}

    private void update_cell_indicator() {
        if (active_row >= 0 && active_col >= 0) {
            string cell_ref = "%c%d".printf('A' + active_col, active_row);
            
            // If this is a formula, show the formula in the formula display
            if (cell_data[active_row, active_col] != null && 
                cell_data[active_row, active_col].has_prefix("=")) {
                formula_display.label = cell_data[active_row, active_col];
            } else {
                // Otherwise, show just the cell reference
                if (has_selection && (selection_start_row != selection_end_row || 
                    selection_start_col != selection_end_col)) {
                    // Show range if we have a multi-cell selection
                    formula_display.label = get_selection_reference();
                } else {
                    formula_display.label = cell_ref;
                }
            }
        }
    }

    private void create_formula_bar() {
        var formula_bar = new Grid();
        formula_bar.column_spacing = 5;
        formula_bar.add_css_class("mac-toolbar");
        formula_bar.orientation = Orientation.HORIZONTAL;
        formula_bar.hexpand = true;

        // Replace formula entry with a formula display label
        var formula_display = new Label("") {
            halign = Gtk.Align.START,
            valign = Align.CENTER,
            margin_start = 65,
            xalign = 0,
            max_width_chars = 40,
            ellipsize = Pango.EllipsizeMode.END
        };
        formula_display.add_css_class("formula-display");
        
        // Result indicator arrow
        var arrow_label = new Image() {
            width_request = 16,
            halign = Align.CENTER,
            valign = Align.CENTER,
            icon_name = "texture-symbolic"
        };
        arrow_label.add_css_class("arrow-indicator");

        // Result indicator
        result_label = new Label("") {
            width_request = 100,
            xalign = 0,
            halign = Align.START,
            valign = Align.CENTER
        };

        // Arrange formula bar components
        formula_bar.attach(formula_display, 0, 0, 1, 1);
        formula_bar.attach(arrow_label, 1, 0, 1, 1);
        formula_bar.attach(result_label, 2, 0, 1, 1);

        // Store reference to the formula display
        this.formula_display = formula_display;
        
        grid.attach(formula_bar, 0, 2, 1, 1);
    }

    private void insert_cell_reference_to_formula() {
        print("\n----- Inserting cell reference -----\n");

        if (!has_selection) {
            print("No selection, returning\n");
            return;
        }

        // Only proceed if we're editing a formula
        if (!is_editing_formula) {
            print("Not in formula editing mode\n");
            return;
        }

        // Get the reference using get_selection_reference
        string cell_ref = get_selection_reference();
        print("Reference: %s\n", cell_ref);

        // Get the active cell's entry
        var entry = cell_entries[active_row, active_col];
        
        if (entry.visible) {
            // Get current cursor position and text
            int cursor_pos = entry.cursor_position;
            string current_text = entry.text;

            print("Current text: '%s', cursor at: %d\n", current_text, cursor_pos);

            // Construct text parts
            string text_before = current_text.substring(0, cursor_pos);
            string text_after = current_text.substring(cursor_pos);

            // Create new text with the reference inserted
            string new_text = text_before + cell_ref + text_after;

            print("New text will be: '%s'\n", new_text);

            // Update entry
            entry.text = new_text;

            // Move cursor after the inserted reference
            Timeout.add(10, () => {
                entry.set_position(cursor_pos + cell_ref.length);
                entry.grab_focus();
                return false;
            });

            print("Reference inserted\n");
        }
    }

    private void start_cell_edit(int row, int col) {
        if (row < 0 || row >= rows || col < 0 || col >= cols) {
            return;
        }
        
        // Save changes in the previously active cell if different
        if (active_row >= 0 && active_col >= 0 && 
            (active_row != row || active_col != col) &&
            active_row < rows && active_col < cols) {
            
            // If the previous cell's entry is visible, we need to save its content
            if (cell_entries != null && cell_entries[active_row, active_col] != null &&
                cell_entries[active_row, active_col].visible) {
                
                // Save the content of the previous cell
                finish_cell_edit(active_row, active_col);
            }
        }

        // Set active cell
        active_row = row;
        active_col = col;

        // Update selection to match
        selection_start_row = row;
        selection_start_col = col;
        selection_end_row = row;
        selection_end_col = col;
        has_selection = true;
        
        // Make sure we see the cell we're editing
        ensure_cell_visible(row, col);

        // Update cell indicator
        update_cell_indicator();

        // Update selection display
        update_selection_display();
        
        // Get the entry and label for this cell
        var entry = cell_entries[row, col];
        var label = cell_labels[row, col];
        
        // Set entry text to current cell value
        entry.text = cell_data[row, col] ?? "";
        
        // Show the entry and hide the label
        entry.visible = true;
        label.visible = false;
        
        // Focus the entry and select all text
        entry.grab_focus();
        Timeout.add(10, () => {
            entry.select_region(0, -1);
            return false;
        });
        
        // Set flag to indicate we're in edit mode
        is_editing_formula = entry.text.has_prefix("=");
    }

    // New method to ensure a cell is visible during editing
    private void ensure_cell_visible(int row, int col) {
        // Calculate cell position in the grid
        double row_height = 16.0;
        double header_height = 16.0;
        
        // Calculate y position in the scrolled window
        double y_pos = header_height + (row * row_height);
        
        // Get current scroll position
        double scroll_pos = scrolled_window.vadjustment.value;
        double scroll_height = scrolled_window.vadjustment.page_size;
        
        // Check if cell is out of view and scroll if needed
        if (y_pos < scroll_pos) {
            // Cell is above visible area, scroll up
            scrolled_window.vadjustment.value = y_pos - header_height;
        } else if (y_pos + row_height > scroll_pos + scroll_height) {
            // Cell is below visible area, scroll down
            scrolled_window.vadjustment.value = y_pos + row_height - scroll_height;
        }
    }

    // Method to finish editing a cell
    private void finish_cell_edit(int row, int col) {
        if (row < 0 || row >= rows || col < 0 || col >= cols) {
            return;
        }
        
        var entry = cell_entries[row, col];
        var label = cell_labels[row, col];
        
        // Get the new value from the entry
        string new_value = entry.text;
        
        // Store in cell data
        cell_data[row, col] = new_value;
        
        // Hide entry and show label
        entry.visible = false;
        label.visible = true;
        
        // Update display
        if (new_value.has_prefix("=")) {
            // Update formula display
            formula_display.label = new_value;
            
            // Calculate and show result
            string formula = new_value.substring(1);
            string result = Utils.calculate_rpn(formula, cell_data, rows, cols);
            result_label.label = result;
            
            // Track dependencies for formulas
            Utils.track_dependencies(row, col, formula, cell_dependencies);
            
            // Update styling
            Widget cell_widget = cell_buttons[row, col];
            cell_widget.remove_css_class("cell-formula");
            cell_widget.add_css_class("cell-formula-main");
        } else {
            formula_display.label = new_value;
            result_label.label = new_value;
            
            // Remove formula styling
            Widget cell_widget = cell_buttons[row, col];
            cell_widget.remove_css_class("cell-formula");
            cell_widget.remove_css_class("cell-formula-main");
        }
        
        // Reset editing state
        is_editing_formula = false;
        
        // Update this cell's display
        update_single_cell(row, col);
        
        // Update dependent cells
        string cell_id = "%c%d".printf('A' + col, row);
        Utils.update_dependent_cells(cell_id, cell_dependencies, cell_data, rows, cols, this);
    }

    // Method to cancel editing without saving
    private void cancel_cell_edit(int row, int col) {
        if (row < 0 || row >= rows || col < 0 || col >= cols) {
            return;
        }
        
        var entry = cell_entries[row, col];
        var label = cell_labels[row, col];
        
        // Hide entry and show label
        entry.visible = false;
        label.visible = true;
        
        // Reset editing state
        is_editing_formula = false;
    }

    private void update_hover_headers(int row, int col) {
        // Clear previous highlight state
        clear_hover_headers();

        // Store current hover position
        current_hover_row = row;
        current_hover_col = col;

        // Highlight row and column headers
        if (row >= 0 && row < rows) {
            row_headers[row].add_css_class("header-highlighted");
        }

        if (col >= 0 && col < cols) {
            col_headers[col].add_css_class("header-highlighted");
        }
    }

    private void clear_hover_headers() {
        // Remove highlight from previous headers
        if (current_hover_row >= 0 && current_hover_row < rows) {
            row_headers[current_hover_row].remove_css_class("header-highlighted");
        }

        if (current_hover_col >= 0 && current_hover_col < cols) {
            col_headers[current_hover_col].remove_css_class("header-highlighted");
        }

        current_hover_row = -1;
        current_hover_col = -1;
    }

private void setup_global_drag_handlers() {
    var grid_motion = new Gtk.EventControllerMotion();
    
    grid_motion.motion.connect((x, y) => {
        if (!is_dragging) return;
        
        // Convert coordinates to row and column
        double cell_height = 16.0;
        double cell_width = 60.0;
        double header_width = 60.0;
        double header_height = 16.0;
        
        // Adjust for headers
        double adj_x = x - header_width;
        double adj_y = y - header_height;
        
        if (adj_x < 0 || adj_y < 0) return; // In header area
        
        int col = (int)(adj_x / cell_width);
        int row = (int)(adj_y / cell_height);
        
        // Make sure we're in valid range
        row = int.min(int.max(row, 0), rows - 1);
        col = int.min(int.max(col, 0), cols - 1);
        
        // Only update if the cell changed
        if (row != selection_end_row || col != selection_end_col) {
            // Update selection end point
            selection_end_row = row;
            selection_end_col = col;
            
            // Update coordinates display
            coordinates_label.label = get_selection_reference();
            
            // Directly update the selection styling for all cells in the range
            update_all_cells_in_selection_range();
            
            print("Grid motion: drag to row=%d, col=%d\n", row, col);
        }
    });
    
    var grid_click = new Gtk.GestureClick();
    grid_click.button = 1;
    
    grid_click.released.connect((n_press, x, y) => {
        if (is_dragging) {
            print("Grid released: ending drag\n");
            is_dragging = false;
            
            // Full update on release
            update_selection_display();
        }
    });
    
    spreadsheet_grid.add_controller(grid_motion);
    spreadsheet_grid.add_controller(grid_click);
}

    private void clear_selection() {
        // Save changes in the active cell if it's being edited
        if (active_row >= 0 && active_col >= 0 && 
            active_row < rows && active_col < cols) {
            
            // If the active cell's entry is visible, we need to save its content
            if (cell_entries != null && cell_entries[active_row, active_col] != null &&
                cell_entries[active_row, active_col].visible) {
                
                // Save the content of the active cell
                finish_cell_edit(active_row, active_col);
            } else {
                // Otherwise just hide the entry and show the label
                if (cell_entries != null && cell_entries[active_row, active_col] != null) {
                    cell_entries[active_row, active_col].visible = false;
                    cell_labels[active_row, active_col].visible = true;
                }
            }
        }

        // Clear selection state
        has_selection = false;
        selection_start_row = -1;
        selection_start_col = -1;
        selection_end_row = -1;
        selection_end_col = -1;

        // Clear active cell
        active_row = -1;
        active_col = -1;

        // Clear cell styling
        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                cell_buttons[r, c].remove_css_class("cell-selected");
                cell_buttons[r, c].remove_css_class("cell-active");
            }
        }

        // Clear reference highlights
        clear_reference_highlights();

        // Clear coordinates display
        coordinates_label.label = "";

        // Clear formula bar
        formula_display.label = "";
        result_label.label = "";
        
        // Reset editing state
        is_editing_formula = false;
    }

    private void update_selection_display() {
        // Clear previous selection styling
        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                // Store formula status before removing classes
                bool was_formula_main = cell_buttons[r, c].has_css_class("cell-formula-main");

                cell_buttons[r, c].remove_css_class("cell-selected");
                cell_buttons[r, c].remove_css_class("cell-active");
                cell_buttons[r, c].remove_css_class("cell-formula"); // Remove reference highlighting

                // Restore formula-main class if it was there
                if (was_formula_main) {
                    cell_buttons[r, c].add_css_class("cell-formula-main");
                }
            }
        }

        if (!has_selection) {
            return;
        }

        // Normalize selection coordinates
        int start_row = int.min(selection_start_row, selection_end_row);
        int end_row = int.max(selection_start_row, selection_end_row);
        int start_col = int.min(selection_start_col, selection_end_col);
        int end_col = int.max(selection_start_col, selection_end_col);

        // Update coordinates display using get_selection_reference()
        coordinates_label.label = get_selection_reference();
        
        // Debug the current selection
        print("Selection: (%d,%d) to (%d,%d)\n", start_row, start_col, end_row, end_col);

        // Apply selection styling
        for (int r = start_row; r <= end_row; r++) {
            for (int c = start_col; c <= end_col; c++) {
                if (r >= 0 && r < rows && c >= 0 && c < cols) {
                    cell_buttons[r, c].add_css_class("cell-selected");
                }
            }
        }

        // Highlight the active cell differently
        if (active_row >= 0 && active_col >= 0 &&
            active_row < rows && active_col < cols) {
            cell_buttons[active_row, active_col].add_css_class("cell-active");
            
            // If the active cell is a formula, highlight referenced cells
            if (cell_data[active_row, active_col] != null && 
                cell_data[active_row, active_col].has_prefix("=")) {
                highlight_referenced_cells(active_row, active_col);
            }
        }

        // Update header highlighting for the active cell
        if (active_row >= 0 && active_col >= 0) {
            update_hover_headers(active_row, active_col);
        }
    }

    public void update_single_cell(int row, int col) {
        if (row < 0 || row >= rows || col < 0 || col >= cols) return;

        var cell_label = cell_labels[row, col];
        Widget cell_widget = cell_buttons[row, col];

        // Remove the formula classes if they exist
        cell_widget.remove_css_class("cell-formula");
        cell_widget.remove_css_class("cell-formula-main");

        if (cell_data[row, col] != null) {
            if (cell_data[row, col].has_prefix("=")) {
                string formula = cell_data[row, col].substring(1);
                cell_label.label = Utils.calculate_rpn(formula, cell_data, rows, cols);
                cell_widget.add_css_class("cell-formula-main");
            } else {
                cell_label.label = cell_data[row, col];
            }
        } else {
            cell_label.label = "";
        }
    }

    public void update_cell_display() {
        for (int row = 0; row < rows; row++) {
            for (int col = 0; col < cols; col++) {
                var cell_label = cell_labels[row, col];
                Widget cell_widget = cell_buttons[row, col];

                // Remove the formula classes if they exist
                cell_widget.remove_css_class("cell-formula");
                cell_widget.remove_css_class("cell-formula-main");

                if (cell_data[row, col] != null) {
                    // If the cell contains a formula, calculate and display the result
                    if (cell_data[row, col].has_prefix("=")) {
                        string formula = cell_data[row, col].substring(1);
                        cell_label.label = Utils.calculate_rpn(formula, cell_data, rows, cols);

                        // Add the formula class to indicate this is a formula cell
                        cell_widget.add_css_class("cell-formula-main");
                    } else {
                        cell_label.label = cell_data[row, col];
                    }
                } else {
                    cell_label.label = "";
                }
            }
        }
    }

    // Methods for highlighting referenced cells
    private void highlight_referenced_cells(int formula_row, int formula_col) {
        // First, clear any previous reference highlights
        clear_reference_highlights();
        
        // Check if we have a valid formula cell
        if (formula_row < 0 || formula_col < 0 || 
            formula_row >= rows || formula_col >= cols) {
            return;
        }
        
        string formula_text = cell_data[formula_row, formula_col];
        if (formula_text == null || !formula_text.has_prefix("=")) {
            return; // Not a formula
        }
        
        // Extract the actual formula part
        string formula = formula_text.substring(1);
        
        // Split the formula into tokens
        string[] tokens = formula.split(" ");
        
        // Find and highlight all cell references
        foreach (string token in tokens) {
            // Check for single cell references (like "A1")
            if (Utils.is_valid_cell_reference(token)) {
                highlight_single_cell_reference(token);
            }
            // Check for range references (like "A1:B2")
            else if (token.contains(":") && Utils.is_valid_range_reference(token)) {
                highlight_range_reference(token);
            }
        }
    }

    // Helper to highlight a single cell reference using cell-formula class
    private void highlight_single_cell_reference(string cell_ref) {
        // Parse the reference (like "A1")
        if (cell_ref.length < 2) return;
        
        int col = cell_ref[0] - 'A';
        int row = int.parse(cell_ref.substring(1));
        
        // Make sure it's in range
        if (row >= 0 && row < rows && col >= 0 && col < cols) {
            // Store if it was already a formula cell
            bool was_formula = cell_buttons[row, col].has_css_class("cell-formula-main");
            
            // Add to our tracking of cells with temporary formula styling
            if (!was_formula) {
                temp_highlighted_cells.add(new Utils.CellPosition(row, col));
                cell_buttons[row, col].add_css_class("cell-formula");
            }
        }
    }

    // Helper to highlight a range of cells using cell-formula class
    private void highlight_range_reference(string range_ref) {
        // Parse the range reference (like "A1:B2")
        string[] parts = range_ref.split(":");
        if (parts.length != 2) return;
        
        // Get the start cell
        int start_col = parts[0][0] - 'A';
        int start_row = int.parse(parts[0].substring(1));
        
        // Get the end cell
        int end_col = parts[1][0] - 'A';
        int end_row = int.parse(parts[1].substring(1));
        
        // Normalize the range
        if (start_row > end_row) {
            int temp = start_row;
            start_row = end_row;
            end_row = temp;
        }
        
        if (start_col > end_col) {
            int temp = start_col;
            start_col = end_col;
            end_col = temp;
        }
        
        // Add highlighting to all cells in the range
        for (int row = start_row; row <= end_row; row++) {
            for (int col = start_col; col <= end_col; col++) {
                if (row >= 0 && row < rows && col >= 0 && col < cols) {
                    // Store if it was already a formula cell
                    bool was_formula = cell_buttons[row, col].has_css_class("cell-formula-main");
                    
                    // Add to our tracking of cells with temporary formula styling
                    if (!was_formula) {
                        temp_highlighted_cells.add(new Utils.CellPosition(row, col));
                        cell_buttons[row, col].add_css_class("cell-formula");
                    }
                }
            }
        }
    }

    // Clear temporary formula highlighting
    private void clear_reference_highlights() {
        // Remove formula class from all temporarily highlighted cells
        foreach (var cell_pos in temp_highlighted_cells) {
            int row = cell_pos.row;
            int col = cell_pos.col;
            
            // Only remove if the cell doesn't actually contain a formula
            if (row >= 0 && row < rows && col >= 0 && col < cols) {
                if (cell_data[row, col] == null || !cell_data[row, col].has_prefix("=")) {
                    cell_buttons[row, col].remove_css_class("cell-formula");
                }
            }
        }
        
        // Clear the list
        temp_highlighted_cells.clear();
    }

    // Also update the hide_all_entry_fields method to save changes
    private void hide_all_entry_fields() {
        if (cell_entries == null) return;
        
        // First save any active cell's content
        if (active_row >= 0 && active_col >= 0 && 
            active_row < rows && active_col < cols) {
            
            // If the entry is visible, save its content
            if (cell_entries[active_row, active_col] != null &&
                cell_entries[active_row, active_col].visible) {
                finish_cell_edit(active_row, active_col);
                return; // No need to loop through all cells
            }
        }
        
        // If we reach here, either there was no active cell or it wasn't being edited
        for (int r = 0; r < rows; r++) {
            for (int c = 0; c < cols; c++) {
                if (cell_entries[r, c] != null) {
                    // If this entry is visible, save its content
                    if (cell_entries[r, c].visible) {
                        finish_cell_edit(r, c);
                    } else {
                        // Otherwise just hide it
                        cell_entries[r, c].visible = false;
                        cell_labels[r, c].visible = true;
                    }
                }
            }
        }
        
        // Reset editing state
        is_editing_formula = false;
    }

    private string get_selection_reference() {
        if (!has_selection) {
            return "";
        }

        // Normalize selection coordinates
        int start_row = int.min(selection_start_row, selection_end_row);
        int end_row = int.max(selection_start_row, selection_end_row);
        int start_col = int.min(selection_start_col, selection_end_col);
        int end_col = int.max(selection_start_col, selection_end_col);

        if (start_row == end_row && start_col == end_col) {
            // Single cell reference
            return "%c%d".printf('A' + start_col, start_row);
        } else {
            // Range reference - this handles both 1D and 2D ranges
            string start_ref = "%c%d".printf('A' + start_col, start_row);
            string end_ref = "%c%d".printf('A' + end_col, end_row);
            return start_ref + ":" + end_ref;
        }
    }

    // Create a formula from the current selection when right-clicking a cell
    private void create_formula_from_selection(int target_row, int target_col) {
        // Make sure we have an active selection
        if (!has_selection) {
            return;
        }
        
        // Get the reference for the current selection
        string selection_ref = get_selection_reference();
        
        // Create a formula using the selection
        string formula = "=" + selection_ref;
        
        // Store the formula in the target cell
        cell_data[target_row, target_col] = formula;
        
        // Calculate and display result
        string result = Utils.calculate_rpn(selection_ref, cell_data, rows, cols);
        
        // Update the cell display
        var cell_widget = cell_buttons[target_row, target_col];
        cell_widget.remove_css_class("cell-formula");
        cell_widget.add_css_class("cell-formula-main");
        
        // Update the cell's appearance
        update_single_cell(target_row, target_col);
        
        // Track dependencies for this formula
        Utils.track_dependencies(target_row, target_col, selection_ref, cell_dependencies);
        
        // Update any cells that depend on this one
        string cell_id = "%c%d".printf('A' + target_col, target_row);
        Utils.update_dependent_cells(cell_id, cell_dependencies, cell_data, rows, cols, this);
        
        // Set the new cell as active
        active_row = target_row;
        active_col = target_col;
        
        // Update UI to reflect the new active cell
        update_cell_indicator();
        
        // Show the formula in the formula display
        formula_display.label = formula;
        result_label.label = result;
    }

    // Method to rebuild the entire dependency graph (for loading files, etc.)
    public void rebuild_dependency_graph() {
        // Clear all existing dependencies
        cell_dependencies.clear();

        // Scan all cells for formulas and rebuild dependencies
        for (int row = 0; row < rows; row++) {
            for (int col = 0; col < cols; col++) {
                if (cell_data[row, col] != null && cell_data[row, col].has_prefix("=")) {
                    Utils.track_dependencies(row, col, cell_data[row, col].substring(1), cell_dependencies);
                }
            }
        }
    }

    public void save_csv() {
        var file_chooser = new FileChooserDialog(
            "Save Spreadsheet", this, FileChooserAction.SAVE,
            "_Cancel", ResponseType.CANCEL,
            "_Save", ResponseType.ACCEPT
        );

        // Add file filter for CSV files
        var filter = new FileFilter();
        filter.add_pattern("*.csv");
        filter.set_filter_name("CSV Files");
        file_chooser.add_filter(filter);

        // Set default name
        file_chooser.set_current_name("spreadsheet.csv");

        file_chooser.present();

        file_chooser.response.connect((response) => {
            if (response == ResponseType.ACCEPT) {
                var file = file_chooser.get_file();
                Utils.save_to_csv(file, this, cell_data, rows, cols);

                // Update file path and window title
                file_path = file.get_path();
                print("File saved: %s\n", file_path);
                update_window_title();
            }
            file_chooser.destroy();
        });
    }

    public void open_csv() {
        var file_chooser = new FileChooserDialog(
            "Open Spreadsheet", this, FileChooserAction.OPEN,
            "_Cancel", ResponseType.CANCEL,
            "_Open", ResponseType.ACCEPT
        );

        // Add file filter for CSV files
        var filter = new FileFilter();
        filter.add_pattern("*.csv");
        filter.set_filter_name("CSV Files");
        file_chooser.add_filter(filter);

        file_chooser.present();

        file_chooser.response.connect((response) => {
            if (response == ResponseType.ACCEPT) {
                var file = file_chooser.get_file();
                string[,] loaded_data = Utils.load_from_csv(file, this, rows, cols);
                if (loaded_data != null) {
                    cell_data = loaded_data;

                    // Update file path and window title
                    file_path = file.get_path();
                    print("File opened: %s\n", file_path);
                    update_window_title();

                    update_cell_display();
                    rebuild_dependency_graph();
                }
            }
            file_chooser.destroy();
        });
    }

    private void update_window_title() {
        if (title_label == null)
            return;

        if (file_path != null && file_path.length > 0) {
            // Show just the filename part, not the full path
            string display_name = file_path;

            // Extract filename from path (handles both Unix and Windows paths)
            int last_slash = file_path.last_index_of_char('/');
            int last_backslash = file_path.last_index_of_char('\\');
            int last_sep = int.max(last_slash, last_backslash);

            if (last_sep >= 0 && last_sep < file_path.length - 1) {
                display_name = file_path.substring(last_sep + 1);
            }

            title_label.label = display_name;
            print("Updated window title to: %s\n", display_name);
        } else {
            title_label.label = "Numfor";
            print("Reset window title to: Numfor\n");
        }
    }
}