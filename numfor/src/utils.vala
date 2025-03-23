using Gtk;

public class Utils {
    private static Gee.HashSet<string> calculating_cells = new Gee.HashSet<string>();

    // Helper class for tracking cell positions
    public class CellPosition {
        public int row;
        public int col;
        
        public CellPosition(int row, int col) {
            this.row = row;
            this.col = col;
        }
        
        public bool equals(CellPosition other) {
            return this.row == other.row && this.col == other.col;
        }
    }

    // Extract a range reference from a formula
    public static string extract_range_reference(string formula) {
        // Simple implementation: find a pattern like "X#:Y#" where X,Y are letters and # are numbers
        string[] tokens = formula.split(" ");
        foreach (string token in tokens) {
            if (token.contains(":")) {
                // Make sure it matches a cell range pattern
                if (is_valid_range_reference(token)) {
                    return token;
                }
            }
        }
        return "";
    }

    // Check if a string is a valid range reference
    public static bool is_valid_range_reference(string ref_str) {
        if (!ref_str.contains(":")) return false;

        string[] parts = ref_str.split(":");
        if (parts.length != 2) return false;

        // Each part should be a valid cell reference
        return is_valid_cell_reference(parts[0]) && is_valid_cell_reference(parts[1]);
    }

    // Check if a string is a valid cell reference (like A0, B5, etc)
    public static bool is_valid_cell_reference(string ref_str) {
        if (ref_str.length < 2) return false;

        // First character should be a letter
        if (ref_str[0] < 'A' || ref_str[0] > 'Z') return false;

        // Rest should be a number
        for (int i = 1; i < ref_str.length; i++) {
            if (ref_str[i] < '0' || ref_str[i] > '9') return false;
        }

        return true;
    }

    public static string[] parse_cell_range(string range_ref, string[,] cell_data, int max_rows, int max_cols) {
        // Split on the colon
        string[] parts = range_ref.split(":");
        if (parts.length != 2) {
            return new string[0]; // Invalid range
        }

        // Parse start and end cell references
        int start_col = parts[0][0] - 'A';
        int start_row = int.parse(parts[0].substring(1));

        int end_col = parts[1][0] - 'A';
        int end_row = int.parse(parts[1].substring(1));

        // Validate coordinates
        if (start_row < 0 || start_row >= max_rows ||
            end_row < 0 || end_row >= max_rows ||
            start_col < 0 || start_col >= max_cols ||
            end_col < 0 || end_col >= max_cols) {
            return new string[0]; // Invalid range
        }

        // Normalize range (ensure start <= end)
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

        // Collect all cell values in the range
        string[] values = new string[(end_row - start_row + 1) * (end_col - start_col + 1)];
        int index = 0;

        for (int row = start_row; row <= end_row; row++) {
            for (int col = start_col; col <= end_col; col++) {
                // Get cell value, handle formulas if needed
                string cell_value = cell_data[row, col] ?? "0";
                if (cell_value.has_prefix("=")) {
                    // Recursively calculate the formula value (avoid circular references!)
                    cell_value = calculate_rpn(cell_value.substring(1), cell_data, max_rows, max_cols);
                }
                values[index++] = cell_value;
            }
        }

        return values;
    }

    // Simple RPN calculator for formulas
    public static string calculate_rpn(string formula, string[,] cell_data, int max_rows, int max_cols) {
        // First check if we have a range operation
        if (formula.contains(":")) {
            // Extract the range reference
            string range_ref = extract_range_reference(formula);
            if (range_ref != "") {
                // Get the operator that follows the range
                string[] tokens = formula.split(" ");
                string operator = "";

                // Find the range and the operator
                bool range_found = false;
                foreach (string token in tokens) {
                    if (token == range_ref) {
                        range_found = true;
                        continue;
                    }

                    if (range_found && token.length == 1 &&
                        (token == "+" || token == "-" || token == "*" || token == "/" || 
                         token == "=" || token == "!" || token == ">" || token == "<" ||
                         token == "#" || token == "\"")) {
                        operator = token;
                        break;
                    }
                }

                // Process the range values
                string[] range_values = parse_cell_range(range_ref, cell_data, max_rows, max_cols);
                if (range_values.length == 0) return "ERR_RANGE";

                // Apply the operator to the range
                switch (operator) {
                case "+": // Sum - default behavior
                    double sum = 0;
                    foreach (string value in range_values) {
                        double val = 0;
                        if (double.try_parse(value, out val)) {
                            sum += val;
                        }
                    }
                    return "%.3f".printf(sum);

                case "-": // Subtract all values from the first one
                    if (range_values.length == 0) return "0.00";

                    double result;
                    if (!double.try_parse(range_values[0], out result)) result = 0;

                    for (int i = 1; i < range_values.length; i++) {
                        double val = 0;
                        if (double.try_parse(range_values[i], out val)) {
                            result -= val;
                        }
                    }
                    return "%.3f".printf(result);

                case "*": // Multiply all values together
                    double product = 1.0;
                    foreach (string value in range_values) {
                        double val = 0;
                        if (double.try_parse(value, out val)) {
                            product *= val;
                        }
                    }
                    return "%.3f".printf(product);

                case "/": // Divide first value by all others
                    if (range_values.length == 0) return "0.00";

                    double div_result;
                    if (!double.try_parse(range_values[0], out div_result)) div_result = 0;

                    for (int i = 1; i < range_values.length; i++) {
                        double val = 0;
                        if (double.try_parse(range_values[i], out val) && val != 0) {
                            div_result /= val;
                        } else {
                            return "ERR_DIV0";
                        }
                    }
                    return "%.3f".printf(div_result);
                    
                case "=": // Are all values equal?
                    if (range_values.length <= 1) return "1"; // Single value is equal to itself
                    
                    string first_val = range_values[0];
                    foreach (string value in range_values) {
                        if (value != first_val) return "0";
                    }
                    return "1";
                    
                case "!": // Are any values not equal to the first?
                    if (range_values.length <= 1) return "0"; // Single value is equal to itself
                    
                    string first = range_values[0];
                    foreach (string value in range_values) {
                        if (value != first) return "1";
                    }
                    return "0";
                    
                case ">": // Is first value greater than all others?
                    if (range_values.length <= 1) return "1"; // Single value comparison is true
                    
                    double first_num;
                    if (!double.try_parse(range_values[0], out first_num)) return "0";
                    
                    for (int i = 1; i < range_values.length; i++) {
                        double val = 0;
                        if (double.try_parse(range_values[i], out val)) {
                            if (first_num <= val) return "0";
                        }
                    }
                    return "1";
                    
                case "<": // Is first value less than all others?
                    if (range_values.length <= 1) return "1"; // Single value comparison is true
                    
                    double first_n;
                    if (!double.try_parse(range_values[0], out first_n)) return "0";
                    
                    for (int i = 1; i < range_values.length; i++) {
                        double val = 0;
                        if (double.try_parse(range_values[i], out val)) {
                            if (first_n >= val) return "0";
                        }
                    }
                    return "1";

                case "#": // Count non-empty cells
                    int cell_count = 0;
                    foreach (string value in range_values) {
                        if (value != null && value != "") {
                            cell_count++;
                        }
                    }
                    return cell_count.to_string();

                case "\"": // Concatenate all values as strings
                    StringBuilder concat_result = new StringBuilder();
                    foreach (string value in range_values) {
                        concat_result.append(value);
                    }
                    return concat_result.str;

                default: // If no operator is specified, default to SUM
                    double default_sum = 0;
                    foreach (string value in range_values) {
                        double val = 0;
                        if (double.try_parse(value, out val)) {
                            default_sum += val;
                        }
                    }
                    return "%.3f".printf(default_sum);
                }
            }
        }

        // If not a range operation, process as regular RPN
        var tokens = formula.split(" ");
        var stack = new Gee.ArrayList<double?>();

        foreach (string token in tokens) {
            // Skip empty tokens
            if (token.strip() == "") continue;

            switch (token) {
            case "+":
                if (stack.size >= 2) {
                    double b = stack.remove_at(stack.size - 1);
                    double a = stack.remove_at(stack.size - 1);
                    stack.add(a + b);
                }
                break;
            case "-":
                if (stack.size >= 2) {
                    double b = stack.remove_at(stack.size - 1);
                    double a = stack.remove_at(stack.size - 1);
                    stack.add(a - b);
                }
                break;
            case "*":
                if (stack.size >= 2) {
                    double b = stack.remove_at(stack.size - 1);
                    double a = stack.remove_at(stack.size - 1);
                    stack.add(a * b);
                }
                break;
            case "/":
                if (stack.size >= 2) {
                    double b = stack.remove_at(stack.size - 1);
                    double a = stack.remove_at(stack.size - 1);
                    if (b != 0) {
                        stack.add(a / b);
                    } else {
                        return "ERR_DIV0";
                    }
                }
                break;
            case "=":
                if (stack.size >= 2) {
                    double b = stack.remove_at(stack.size - 1);
                    double a = stack.remove_at(stack.size - 1);
                    stack.add(a == b ? 1 : 0);
                }
                break;
            case "!":
                if (stack.size >= 2) {
                    double b = stack.remove_at(stack.size - 1);
                    double a = stack.remove_at(stack.size - 1);
                    stack.add(a != b ? 1 : 0);
                }
                break;
            case ">":
                if (stack.size >= 2) {
                    double b = stack.remove_at(stack.size - 1);
                    double a = stack.remove_at(stack.size - 1);
                    stack.add(a > b ? 1 : 0);
                }
                break;
            case "<":
                if (stack.size >= 2) {
                    double b = stack.remove_at(stack.size - 1);
                    double a = stack.remove_at(stack.size - 1);
                    stack.add(a < b ? 1 : 0);
                }
                break;
            case "#":
                if (stack.size >= 1) {
                    // Get count of non-zero values
                    int count = 0;
                    int num_items = (int)stack.size;
                    for (int i = 0; i < num_items; i++) {
                        if (stack.get(i) != 0) count++;
                    }
                    stack.clear();
                    stack.add(count);
                }
                break;
            case "\"":
                if (stack.size >= 2) {
                    string b = stack.remove_at(stack.size - 1).to_string();
                    string a = stack.remove_at(stack.size - 1).to_string();
                    // Store as string
                    double result;
                    if (double.try_parse(a + b, out result)) {
                        stack.add(result);
                    } else {
                        // If not a valid number, just add it as 0
                        stack.add(0);
                    }
                }
                break;
            default:
                // Check for cell range
                if (token.contains(":") && is_valid_range_reference(token)) {
                    string[] range_values = parse_cell_range(token, cell_data, max_rows, max_cols);
                    // Push each value from the range onto the stack
                    foreach (string value in range_values) {
                        double val = 0;
                        if (double.try_parse(value, out val)) {
                            stack.add(val);
                        } else {
                            stack.add(0); // Default for non-numeric
                        }
                    }
                    continue;
                }

                // Try to parse as a number
                double num;
                if (double.try_parse(token, out num)) {
                    stack.add(num);
                } else {
                    // Check for cell reference
                    if (is_valid_cell_reference(token)) {
                        int c = token[0] - 'A';
                        int r = int.parse(token.substring(1));

                        if (r >= 0 && r < max_rows && c >= 0 && c < max_cols &&
                            cell_data[r, c] != null) {

                            // Check for circular reference
                            string cell_id = token;
                            if (calculating_cells.contains(cell_id)) {
                                return "ERR_CIRCULAR";
                            }

                            // Mark this cell as being calculated to detect circular references
                            calculating_cells.add(cell_id);

                            string cell_value = cell_data[r, c];
                            if (cell_value.has_prefix("=")) {
                                // Recursively calculate formula
                                cell_value = calculate_rpn(cell_value.substring(1), cell_data, max_rows, max_cols);
                            }

                            // Remove cell from calculating set now that we're done with it
                            calculating_cells.remove(cell_id);

                            double val;
                            if (double.try_parse(cell_value, out val)) {
                                stack.add(val);
                            } else {
                                stack.add(0); // Default for non-numeric
                            }
                        } else {
                            stack.add(0); // Default for empty or out-of-bounds
                        }
                    }
                }
                break;
            }
        }

        if (stack.size > 0) {
            return "%.3f".printf(stack.get(stack.size - 1));
        }

        return "ERR";
    }

    // Update when processing formulas to track which cells depend on others
    public static void track_dependencies(int row, int col, string formula, Gee.MultiMap<string, string> cell_dependencies) {
        string cell_id = "%c%d".printf('A' + col, row);

        // Clear existing dependencies for this cell
        remove_cell_from_dependencies(cell_id, cell_dependencies);

        // Extract cell references from the formula
        string[] tokens = formula.split(" ");
        foreach (string token in tokens) {
            // Check for cell references
            if (is_valid_cell_reference(token)) {
                // Add dependency: token -> cell_id (token affects cell_id)
                cell_dependencies.set(token, cell_id);
            }
            // Check for range references
            else if (token.contains(":") && is_valid_range_reference(token)) {
                // Extract all cells in the range and add dependencies
                string[] parts = token.split(":");
                if (parts.length == 2) {
                    // Get range bounds
                    int start_col = parts[0][0] - 'A';
                    int start_row = int.parse(parts[0].substring(1));
                    int end_col = parts[1][0] - 'A';
                    int end_row = int.parse(parts[1].substring(1));

                    // Normalize range
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

                    // Add dependency for each cell in the range
                    for (int r = start_row; r <= end_row; r++) {
                        for (int c = start_col; c <= end_col; c++) {
                            string ref_cell = "%c%d".printf('A' + c, r);
                            cell_dependencies.set(ref_cell, cell_id);
                        }
                    }
                }
            }
        }
    }

    public static void remove_cell_from_dependencies(string cell_id, Gee.MultiMap<string, string> cell_dependencies) {
        // Find all places where this cell is a dependent
        var keys_to_update = new Gee.ArrayList<string>();

        // Get all keys in the MultiMap
        var all_keys = cell_dependencies.get_keys();
        foreach (string key in all_keys) {
            // Get all values for this key
            var values = cell_dependencies.get(key);
            if (cell_id in values) {
                keys_to_update.add(key);
            }
        }

        // Remove the cell from all dependency lists
        foreach (string key in keys_to_update) {
            cell_dependencies.remove(key, cell_id);
        }
    }

    // Update dependent cells recursively
    public static void update_dependent_cells(string cell_id, Gee.MultiMap<string, string> cell_dependencies, 
                                             string[,] cell_data, int rows, int cols, Window window) {
        var visited = new Gee.HashSet<string>();
        update_dependents_recursive(cell_id, visited, cell_dependencies, cell_data, rows, cols, window);
    }

    // Recursive helper to update dependent cells
    private static void update_dependents_recursive(string cell_id, Gee.HashSet<string> visited, 
                                                  Gee.MultiMap<string, string> cell_dependencies,
                                                  string[,] cell_data, int rows, int cols, Window window) {
        if (cell_id in visited) {
            // Avoid circular references
            return;
        }

        visited.add(cell_id);

        // Get cells that depend on this one
        var dependents = cell_dependencies.get(cell_id);
        if (dependents != null) {
            foreach (string dependent in dependents) {
                // Parse the cell reference
                int dep_col = dependent[0] - 'A';
                int dep_row = int.parse(dependent.substring(1));

                // Make sure the indices are valid
                if (dep_row >= 0 && dep_row < rows && dep_col >= 0 && dep_col < cols) {
                    // Update the cell's display through the window
                    window.update_single_cell(dep_row, dep_col);

                    // Recursively update cells that depend on this one
                    update_dependents_recursive(dependent, visited, cell_dependencies, cell_data, rows, cols, window);
                }
            }
        }
    }

    // Helper function to parse CSV lines with quoted values
    public static string[] parse_csv_line(string line, int cols) {
        var result = new string[cols + 1]; // +1 for row number
        bool in_quotes = false;
        StringBuilder current_field = new StringBuilder();
        int field_index = 0;

        foreach (char c in line.to_utf8()) {
            if (c == '"') {
                in_quotes = !in_quotes;
            } else if (c == ',' && !in_quotes) {
                result[field_index] = current_field.str;
                current_field = new StringBuilder();
                field_index++;

                // Safety check to avoid array bounds
                if (field_index >= result.length) break;
            } else {
                current_field.append_c(c);
            }
        }

        // Add the last field
        if (field_index < result.length) {
            result[field_index] = current_field.str;
        }

        return result;
    }

    public static void save_to_csv(File file, Window parent_window, string[,] cell_data, int rows, int cols) {
        try {
            // Create output stream
            var output_stream = file.replace(null, false, FileCreateFlags.NONE);
            var data_output_stream = new DataOutputStream(output_stream);

            // Write header row with column labels
            string header = ",";
            for (int col = 0; col < cols; col++) {
                header += ((char)('A' + col)).to_string();
                if (col < cols - 1) header += ",";
            }
            data_output_stream.put_string(header + "\n");

            // Write data rows
            for (int row = 0; row < rows; row++) {
                string row_data = row.to_string() + ",";
                for (int col = 0; col < cols; col++) {
                    if (cell_data[row, col] != null) {
                        // Escape commas in cells
                        string cell_value = cell_data[row, col];
                        if ("," in cell_value) {
                            cell_value = "\"" + cell_value + "\"";
                        }
                        row_data += cell_value;
                    }
                    if (col < cols - 1) row_data += ",";
                }
                data_output_stream.put_string(row_data + "\n");
            }

            // Show success message
            var dialog = new MessageDialog(
                parent_window,
                DialogFlags.MODAL,
                MessageType.INFO,
                ButtonsType.OK,
                "Spreadsheet saved successfully to %s", file.get_path()
            );
            dialog.present();
            dialog.response.connect((response_id) => {
                dialog.destroy();
            });
        } catch (Error e) {
            // Show error message
            var dialog = new MessageDialog(
                parent_window,
                DialogFlags.MODAL,
                MessageType.ERROR,
                ButtonsType.OK,
                "Error saving file: %s", e.message
            );
            dialog.present();
            dialog.response.connect((response_id) => {
                dialog.destroy();
            });
        }
    }

    public static string[,] load_from_csv(File file, Window parent_window, int rows, int cols) {
        try {
            // Create input stream
            var input_stream = file.read();
            var data_input_stream = new DataInputStream(input_stream);

            // Create new cell data array
            var new_cell_data = new string[rows, cols];

            // Read header row (ignore it for now)
            string line = data_input_stream.read_line();

            // Read data rows
            int row_index = 0;
            while ((line = data_input_stream.read_line()) != null && row_index < rows) {
                // Split by comma, handling quoted values
                string[] parts = parse_csv_line(line, cols);

                // First column is row number, skip it
                for (int col = 1; col < parts.length && col <= cols; col++) {
                    if (parts[col] != "") {
                        new_cell_data[row_index, col - 1] = parts[col];
                    }
                }

                row_index++;
            }

            // Show success message
            var dialog = new MessageDialog(
                parent_window,
                DialogFlags.MODAL,
                MessageType.INFO,
                ButtonsType.OK,
                "Spreadsheet loaded successfully from %s", file.get_path()
            );
            dialog.present();
            dialog.response.connect((response_id) => {
                dialog.destroy();
            });

            return new_cell_data;
        } catch (Error e) {
            // Show error message
            var dialog = new MessageDialog(
                parent_window,
                DialogFlags.MODAL,
                MessageType.ERROR,
                ButtonsType.OK,
                "Error loading file: %s", e.message
            );
            dialog.present();
            dialog.response.connect((response_id) => {
                dialog.destroy();
            });

            return null;
        }
    }
}