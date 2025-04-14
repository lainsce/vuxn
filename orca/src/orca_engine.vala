public class OrcaEngine {
    private OrcaGrid grid;
    private OrcaSynth synth;
    private int frame_count = 0;
    private bool running = false;

    private const string SPECIAL_OPERATORS = "=:!?%;$~";
    private const string OPERATORS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    // Add variable storage system
    private Gee.HashMap<char, char> variables;

    public signal void bpm_change_requested(int new_bpm);

    // Track active bangs in the current frame
    private bool[,] banged_this_frame;
    private bool[,] operator_processed_this_frame;
    private bool[,] bangs_used_as_inputs;

    public OrcaEngine(OrcaGrid grid, OrcaSynth synth) {
        this.grid = grid;
        this.synth = synth;
        banged_this_frame = new bool[OrcaGrid.WIDTH, OrcaGrid.HEIGHT];
        operator_processed_this_frame = new bool[OrcaGrid.WIDTH, OrcaGrid.HEIGHT];
        bangs_used_as_inputs = new bool[OrcaGrid.WIDTH, OrcaGrid.HEIGHT];
        variables = new Gee.HashMap<char, char> ();
    }

    public void start() {
        running = true;
    }

    public void stop() {
        running = false;
    }

    public bool is_running() {
        return running;
    }

    public int get_frame_count() {
        return frame_count;
    }

    public void tick() {
        if (!running) {
            return;
        }

        // Reset state
        grid.reset_locks();
        grid.reset_data_flags();
        grid.reset_comment_flags();

        // Reset bang tracking for this frame
        for (int x = 0; x < OrcaGrid.WIDTH; x++) {
            for (int y = 0; y < OrcaGrid.HEIGHT; y++) {
                banged_this_frame[x, y] = false;
                operator_processed_this_frame[x, y] = false;
                bangs_used_as_inputs[x, y] = false;
            }
        }

        // Create next grid state
        char[,] next_grid = new char[OrcaGrid.WIDTH, OrcaGrid.HEIGHT];
        for (int x = 0; x < OrcaGrid.WIDTH; x++) {
            for (int y = 0; y < OrcaGrid.HEIGHT; y++) {
                next_grid[x, y] = grid.get_char(x, y);
            }
        }

        // FIRST PASS: Process all bang (*) operators to establish bang effects ONLY
        for (int y = 0; y < OrcaGrid.HEIGHT; y++) {
            for (int x = 0; x < OrcaGrid.WIDTH; x++) {
                if (grid.get_char(x, y) == '*') {
                    process_bang_char(x, y);
                }
            }
        }

        // PRE-SCAN: Mark parameters for special operators
        for (int y = 0; y < OrcaGrid.HEIGHT; y++) {
            for (int x = 0; x < OrcaGrid.WIDTH; x++) {
                char c = grid.get_char(x, y);
                if (c == '=' || c == ':' || c == '!' || c == ';') {
                    // Fixed parameter count for these operators
                    for (int i = 1; i <= 4; i++) {
                        if (x + i < OrcaGrid.WIDTH) {
                            grid.mark_as_data(x + i, y);
                        }
                    }
                } else if (c == 'T') {
                    // For T, read the length parameter properly
                    int len = (x > 0) ? read_parameter(x - 1, y) : 1;
                    if (len <= 0) len = 1;
                    
                    // Mark T's parameters
                    for (int i = 1; i <= len; i++) {
                        if (x + i < OrcaGrid.WIDTH) {
                            grid.mark_as_data(x + i, y);
                        }
                    }
                }
            }
        }

        // MAIN SCAN: Process operators in grid order
        for (int y = 0; y < OrcaGrid.HEIGHT; y++) {
            for (int x = 0; x < OrcaGrid.WIDTH; x++) {
                char c = grid.get_char(x, y);

                // Skip processed, locked, or data cells
                if (grid.is_cell_locked(x, y) || grid.is_data_cell(x, y)) {
                    continue;
                }

                // Comments
                if (c == '#') {
                    process_comment(x, y, next_grid);
                    continue;
                }

                // Process uppercase operators and special operators always
                if ((c >= 'A' && c <= 'Z') || SPECIAL_OPERATORS.contains(c.to_string())) {
                    bool is_uppercase = c >= 'A' && c <= 'Z';
                    bool is_banged = banged_this_frame[x, y];
                    process_operator(c, x, y, next_grid, is_uppercase, is_banged);
                }
            }
        }

        // FINAL PASS: Now handle bang removal AFTER operators have had a chance to protect them
        for (int y = 0; y < OrcaGrid.HEIGHT; y++) {
            for (int x = 0; x < OrcaGrid.WIDTH; x++) {
                if (grid.get_char(x, y) == '*') {
                    // Bang disappears unless protected or used as input
                    if (!grid.is_protected_cell(x, y) && !bangs_used_as_inputs[x, y]) {
                        next_grid[x, y] = '.';
                    }
                }
            }
        }

        // Update the grid with the new state
        for (int x = 0; x < OrcaGrid.WIDTH; x++) {
            for (int y = 0; y < OrcaGrid.HEIGHT; y++) {
                grid.set_char(x, y, next_grid[x, y]);
            }
        }

        // Increment frame counter at the end (like JavaScript)
        frame_count++;
    }

    // Helper to directly check if a cell has a bang neighbor
    private bool has_bang_neighbor(int x, int y) {
        // Check the eight surrounding cells
        for (int dx = -1; dx <= 1; dx++) {
            for (int dy = -1; dy <= 1; dy++) {
                if (dx == 0 && dy == 0)continue;

                int nx = x + dx;
                int ny = y + dy;

                if (nx >= 0 && nx < OrcaGrid.WIDTH && ny >= 0 && ny < OrcaGrid.HEIGHT) {
                    if (grid.get_char(nx, ny) == '*') {
                        grid.protect_cell_content(nx, ny, '*');
                        return true;
                    }
                }
            }
        }
        return false;
    }

    public void mark_bang_as_input_parameter(int x, int y) {
        if (x >= 0 && x < OrcaGrid.WIDTH && y >= 0 && y < OrcaGrid.HEIGHT &&
            grid.get_char(x, y) == '*') {
            bangs_used_as_inputs[x, y] = true;
            grid.protect_cell_content(x, y, '*');
        }
    }

    // Process explicit * character - mark all adjacent cells as banged
    private void process_bang_char(int x, int y) {
        for (int dx = -1; dx <= 1; dx++) {
            for (int dy = -1; dy <= 1; dy++) {
                if (dx == 0 && dy == 0) {
                    continue;
                }

                if (grid.is_cell_locked(x, y)) {
                    continue;
                }

                int nx = x + dx;
                int ny = y + dy;

                if (nx >= 0 && nx < OrcaGrid.WIDTH && ny >= 0 && ny < OrcaGrid.HEIGHT) {
                    banged_this_frame[nx, ny] = true;
                }
            }
        }
    }

    public bool is_cell_banged(int x, int y) {
        if (x >= 0 && x < OrcaGrid.WIDTH && y >= 0 && y < OrcaGrid.HEIGHT) {
            return banged_this_frame[x, y];
        }
        return false;
    }

    // Helper method to get variable value
    private char get_variable_value(char var_name) {
        if (variables.has_key(var_name)) {
            return variables[var_name];
        }
        // Default to '.' if variable not found
        return '.';
    }

    // Helper method to mark an output cell as data in the next frame
    private void mark_output_as_data(int x, int y) {
        if (x >= 0 && x < OrcaGrid.WIDTH && y >= 0 && y < OrcaGrid.HEIGHT) {
            grid.mark_as_data(x, y);
        }
    }

    // Process regular alphabetic operators
    private void process_operator(char op, int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        char lower_op = op.tolower();

        switch (lower_op) {
        case 'a': // Add
            process_add(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'b': // Subtract
            process_subtract(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'c': // Clock
            process_clock(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'd': // Delay
            process_delay(x, y, next_grid, is_banged);
            break;
        case 'e': // East
            process_east(x, y, next_grid, is_banged);
            break;
        case 'f': // If
            process_if(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'g': // Generator
            process_generator(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'h': // Hold
            process_hold(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'i': // Increment
            process_increment(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'j': // Jumper
            process_jumper(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'k': // Konkat
            process_konkat(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'l': // Lesser
            process_lesser(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'm': // Multiply
            process_multiply(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'n': // North
            process_north(x, y, next_grid, is_banged);
            break;
        case 'o': // Read
            process_read(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'p': // Push
            process_push(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'q': // Query
            process_query(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'r': // Random
            process_random(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 's': // South
            process_south(x, y, next_grid, is_banged);
            break;
        case 't': // Track
            process_track(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'u': // Uclid
            process_uclid(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'v': // Variable
            process_variable(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'w': // West
            process_west(x, y, next_grid, is_banged);
            break;
        case 'x': // Write
            process_write(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'y': // Yumper
            process_yumper(x, y, next_grid, is_uppercase, is_banged);
            break;
        case 'z': // Lerp
            process_lerp(x, y, next_grid, is_uppercase, is_banged);
            break;

        // Special operators
        case '=': // OSC message
            process_osc(x, y);
            break;
        case '!': // MIDI CC
            process_cc(x, y);
            break;
        case '?': // MIDI Pitch Bend
            process_pb(x, y);
            break;
        case '%': // MIDI Mono
            process_mono(x, y);
            break;
        case ';': // UDP
            process_udp(x, y);
            break;
        case '$': // Self command
            process_self(x, y);
            break;
        case '~': // Our custom play operator
            process_play(x, y);
            break;
        case '*': // Bang
            process_bang_char(x, y);
            break;
        }
    }

    // Helper method to read a parameter, mark it as data, and return its value
    private int read_parameter(int x, int y) {
        if (x >= 0 && x < OrcaGrid.WIDTH && y >= 0 && y < OrcaGrid.HEIGHT) {
            // Mark as data and lock
            grid.mark_as_data(x, y);
            grid.lock_cell(x, y);

            // Return the value
            return get_value(x, y);
        }
        return 0; // Default value if out of bounds
    }

    // Helper for reading a character parameter
    private char read_char_parameter(int x, int y) {
        if (x >= 0 && x < OrcaGrid.WIDTH && y >= 0 && y < OrcaGrid.HEIGHT) {
            // Mark as data and lock
            grid.mark_as_data(x, y);
            grid.lock_cell(x, y);

            // Return the character
            return grid.get_char(x, y);
        }
        return '.'; // Default value if out of bounds
    }

    // A - add(a b): Outputs sum of inputs.
    private void process_add(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read parameters with data marking
        int a = (x > 0) ? read_parameter(x - 1, y) : 0;
        int b = (x + 1 < OrcaGrid.WIDTH) ? read_parameter(x + 1, y) : 0;

        // Calculate result
        int result = (a + b) % 36; // Base-36

        // Convert to output character
        char output = value_to_char(result);

        // Output below
        if (y + 1 < OrcaGrid.HEIGHT) {
            next_grid[x, y + 1] = output;
            mark_output_as_data(x, y + 1);
        }
    }

    // B - subtract(a b): Outputs difference of inputs.
    private void process_subtract(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read parameters with data marking
        int a = (x > 0) ? read_parameter(x - 1, y) : 0;
        int b = (x + 1 < OrcaGrid.WIDTH) ? read_parameter(x + 1, y) : 0;

        // Calculate absolute difference more directly
        int diff = (b >= a) ? (b - a) : (a - b);
        int result = diff % 36; // Base-36

        // Convert to output character
        char output = value_to_char(result);

        // Output below
        if (y + 1 < OrcaGrid.HEIGHT) {
            next_grid[x, y + 1] = output;
            mark_output_as_data(x, y + 1);
        }
    }

    // C - clock(rate mod): Outputs modulo of frame.
    private void process_clock(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read parameters with data marking
        int rate = (x > 0) ? read_parameter(x - 1, y) : 1;
        int mod = (x + 1 < OrcaGrid.WIDTH) ? read_parameter(x + 1, y) : 8;

        // Ensure valid values
        if (rate <= 0)rate = 1;
        if (mod <= 0)mod = 8;

        // Calculate result using the exact formula from JS
        int val = (int) Math.floor((double) frame_count / rate) % mod;

        // Convert to output character
        char output = value_to_char(val);

        // Output SOUTHWARD
        if (y + 1 < OrcaGrid.HEIGHT) {
            next_grid[x, y + 1] = output;
            mark_output_as_data(x, y + 1);
        }
    }

    // D - delay(rate mod): Bangs on modulo of frame.
    private void process_delay(int x, int y, char[,] next_grid, bool is_banged) {
        // Read parameters with data marking
        int rate = (x > 0) ? read_parameter(x - 1, y) : 1;
        int mod = (x + 1 < OrcaGrid.WIDTH) ? read_parameter(x + 1, y) : 8;

        // Ensure valid values
        if (rate <= 0) rate = 1;
        if (mod <= 0) mod = 8;

        // Use EXACTLY the same formula as in JS
        int res = frame_count % (mod * rate);
        bool should_bang = (res == 0) || (mod == 1);

        // Output position (cell below D)
        int output_x = x;
        int output_y = y + 1;

        if (should_bang && output_y < OrcaGrid.HEIGHT) {
            // Place a visual bang (*) character in the output cell
            next_grid[output_x, output_y] = '*';
            
            // IMPORTANT: Unlike regular data, bangs should NOT be marked as data
            // They need to be able to affect neighbors in the next frame
            // However, we may want to protect the bang content
            grid.protect_cell_content(output_x, output_y, '*');
        }
    }

    // E - east: Moves eastward, or bangs.
    private void process_east(int x, int y, char[,] next_grid, bool is_banged) {
        char operator_char = grid.get_char(x, y);

        // Calculate new position
        int new_x = x + 1;

        // Check if we can move
        if (new_x < OrcaGrid.WIDTH && grid.get_char(new_x, y) == '.') {
            // Move - erase current, place operator in new position
            next_grid[x, y] = '.';
            next_grid[new_x, y] = operator_char;
        } else {
            // Can't move - turn into bang
            next_grid[x, y] = '*';
        }
    }

    // F - if(a b): Bangs if inputs are equal.
    private void process_if(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read values from left and right
        char a = (x > 0) ? read_char_parameter(x - 1, y) : '.';
        char b = (x + 1 < OrcaGrid.WIDTH) ? read_char_parameter(x + 1, y) : '.';

        // Bang below if a and b are equal OR if this operator is banged
        if (a == b) {
            if (y + 1 < OrcaGrid.HEIGHT) {
                // Place a visual bang (*) character in the output cell
                next_grid[x, y + 1] = '*';
            }
        }
    }

    // G - generator(x y len): Writes operands with offset.
    private void process_generator(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read parameters with data marking
        int x_offset = (x > 2) ? read_parameter(x - 3, y) : 0;
        int y_offset = (x > 1) ? read_parameter(x - 2, y) : 0;
        int len = (x > 0) ? read_parameter(x - 1, y) : 1;

        if (len <= 0)len = 1;

        // Output y is y_offset + 1 in the JS implementation
        y_offset += 1;

        // Process each input value
        for (int offset = 0; offset < len; offset++) {
            // Input position - mark as data
            int in_x = x + offset + 1;
            char val = '.';

            if (in_x >= 0 && in_x < OrcaGrid.WIDTH) {
                val = read_char_parameter(in_x, y);
            }

            // Output position
            int out_x = x_offset + offset;
            int out_y = y_offset;

            // Write value to output
            if (out_x >= 0 && out_x < OrcaGrid.WIDTH &&
                out_y >= 0 && out_y < OrcaGrid.HEIGHT) {
                next_grid[out_x, out_y] = val;
                mark_output_as_data(out_x, out_y);
            }
        }
    }

    // H - Hold operator
    private void process_hold(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // H - hold: Holds southward operand.

        // Lock the cell below H
        int target_x = x;
        int target_y = y + 1;

        if (target_y < OrcaGrid.HEIGHT) {
            // Lock the cell for this frame
            grid.lock_cell(target_x, target_y);

            // Read the value from the locked cell
            char value = grid.get_char(target_x, target_y);

            // The value remains in the target cell
            next_grid[target_x, target_y] = value;

            if (value == '*') {
                mark_bang_as_input_parameter(target_x, target_y);
            }
        }
    }

    // I - increment(step mod): Increments southward operand.
    private void process_increment(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read parameters with proper data marking
        int step = (x > 0) ? read_parameter(x - 1, y) : 1;
        int mod = (x + 1 < OrcaGrid.WIDTH) ? read_parameter(x + 1, y) : 36;

        if (mod <= 0) mod = 36;
        
        // Read the value to increment
        int val = 0;
        if (y + 1 < OrcaGrid.HEIGHT) {
            val = get_value(x, y + 1);
        }

        // Calculate the incremented value
        int result = (val + step) % mod;

        // Convert to output character
        char output = value_to_char(result);

        // Output below (overwrite the existing value)
        if (y + 1 < OrcaGrid.HEIGHT) {
            next_grid[x, y + 1] = output;
            mark_output_as_data(x, y + 1);
        }
    }

    // J - jumper: Outputs northward operand.
    private void process_jumper(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Check the cell above
        char val = '.';
        if (y > 0) {
            val = grid.get_char(x, y - 1);
        }

        char operator_glyph = is_uppercase ? 'J' : 'j';

        // Skip if input is the same as this operator
        if (val == operator_glyph) {
            return;
        }

        // Count consecutive same-case Js below
        int jump_distance = 0;
        while (y + jump_distance + 1 < OrcaGrid.HEIGHT) {
            char next_char = grid.get_char(x, y + jump_distance + 1);
            if (next_char != operator_glyph) {
                break;
            }
            jump_distance++;
        }

        // Output value after the last J
        int output_y = y + jump_distance + 1;
        if (output_y < OrcaGrid.HEIGHT) {
            next_grid[x, output_y] = val;
            mark_output_as_data(x, output_y);
        }
    }

    // K - Konkat operator
    private void process_konkat(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read length parameter with data marking
        int len = (x > 0) ? read_parameter(x - 1, y) : 1;
        if (len <= 0)len = 1;

        // Process each position
        for (int offset = 0; offset < len; offset++) {
            int pos_x = x + offset + 1;

            if (pos_x >= OrcaGrid.WIDTH) {
                continue;
            }

            // Read the variable name and mark as data
            char var_name = read_char_parameter(pos_x, y);

            if (var_name == '.') {
                continue;
            }

            // Look up the variable value
            char var_value = get_variable_value(var_name);

            // Output the value below and mark as data
            if (y + 1 < OrcaGrid.HEIGHT) {
                next_grid[pos_x, y + 1] = var_value;
                mark_output_as_data(pos_x, y + 1);
            }
        }
    }

    // L - lesser(a b): Outputs smallest input.
    private void process_lesser(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read parameters with proper data marking
        int a = (x > 0) ? read_parameter(x - 1, y) : 0;
        int b = (x + 1 < OrcaGrid.WIDTH) ? read_parameter(x + 1, y) : 0;

        // Find the minimum value
        int result = (int) Math.fmin(a, b);

        // Convert to output character
        char output = value_to_char(result);

        // Output below
        if (y + 1 < OrcaGrid.HEIGHT) {
            next_grid[x, y + 1] = output;
            mark_output_as_data(x, y + 1);
        }
    }

    // M - multiply(a b): Outputs product of inputs.
    private void process_multiply(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read parameters with proper data marking
        int a = (x > 0) ? read_parameter(x - 1, y) : 0;
        int b = (x + 1 < OrcaGrid.WIDTH) ? read_parameter(x + 1, y) : 0;

        // Calculate product
        int result = (a * b) % 36; // Base-36

        // Convert to output character
        char output = value_to_char(result);

        // Output below
        if (y + 1 < OrcaGrid.HEIGHT) {
            next_grid[x, y + 1] = output;
            mark_output_as_data(x, y + 1);
        }
    }

    // Helper function to convert numeric values to ORCA base-36 characters
    private char value_to_char(int value) {
        if (value < 0)value = 0;
        if (value >= 36)value = value % 36;

        if (value < 10) {
            return (char) ('0' + value);
        } else {
            return (char) ('a' + (value - 10));
        }
    }

    // N - north: Moves northward, or bangs.
    private void process_north(int x, int y, char[,] next_grid, bool is_banged) {
        char operator_char = grid.get_char(x, y);

        // Calculate new position
        int new_y = y - 1;

        // Check if we can move
        if (new_y >= 0 && grid.get_char(x, new_y) == '.') {
            // Move - erase current, place operator in new position
            next_grid[x, y] = '.';
            next_grid[x, new_y] = operator_char;
        } else {
            // Can't move - turn into bang (explode)
            next_grid[x, y] = '*';
        }
    }

    // O - read(x y): Reads operand with offset.
    private void process_read(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read x,y offset parameters with proper data marking
        int x_offset = (x > 1) ? read_parameter(x - 2, y) : 0;
        int y_offset = (x > 0) ? read_parameter(x - 1, y) : 0;

        // Calculate read position with offset
        int read_x = x + x_offset + 1;
        int read_y = y + y_offset;

        // Read the character at the calculated position
        char val = '.';
        if (read_x >= 0 && read_x < OrcaGrid.WIDTH && read_y >= 0 && read_y < OrcaGrid.HEIGHT) {
            val = grid.get_char(read_x, read_y);
        }

        // Output below
        if (y + 1 < OrcaGrid.HEIGHT) {
            next_grid[x, y + 1] = val;
            mark_output_as_data(x, y + 1);
        }
    }

    // P - push(key len val): Writes eastward operand.
    private void process_push(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read parameters with data marking
        int key = (x > 1) ? read_parameter(x - 2, y) : 0;
        int len = (x > 0) ? read_parameter(x - 1, y) : 1;
        char val = (x + 1 < OrcaGrid.WIDTH) ? read_char_parameter(x + 1, y) : '.';

        // Ensure valid length
        if (len <= 0)len = 1;

        // Lock cells in the output region
        for (int offset = 0; offset < len; offset++) {
            if (x + offset < OrcaGrid.WIDTH && y + 1 < OrcaGrid.HEIGHT) {
                grid.lock_cell(x + offset, y + 1);
            }
        }

        // Calculate output position
        int output_x = x + (key % len);

        // Write the value to the calculated position
        if (output_x >= 0 && output_x < OrcaGrid.WIDTH && y + 1 < OrcaGrid.HEIGHT) {
            next_grid[output_x, y + 1] = val;
            mark_output_as_data(output_x, y + 1);
        }
    }

    // Q - query(x y len): Reads operands with offset.
    private void process_query(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read parameters with proper data marking
        int x_param = (x > 2) ? read_parameter(x - 3, y) : 0;
        int y_param = (x > 1) ? read_parameter(x - 2, y) : 0;
        int len = (x > 0) ? read_parameter(x - 1, y) : 1;
        
        if (len <= 0) len = 1;

        // Process each position to read from and output to
        for (int offset = 0; offset < len; offset++) {
            // Calculate input position with the +1 offset required by the algorithm
            int in_x = x + x_param + offset + 1;
            int in_y = y + y_param;

            // Calculate output position (matches JavaScript implementation)
            int out_x = x + (offset - len + 1);
            int out_y = y + 1;

            // Read input value if within bounds
            char value = '.';
            if (in_x >= 0 && in_x < OrcaGrid.WIDTH &&
                in_y >= 0 && in_y < OrcaGrid.HEIGHT) {
                value = grid.get_char(in_x, in_y);
                // CORRECTED: Don't mark input as output data
            }

            // Write to output position if within bounds
            if (out_x >= 0 && out_x < OrcaGrid.WIDTH &&
                out_y >= 0 && out_y < OrcaGrid.HEIGHT) {
                next_grid[out_x, out_y] = value;
                mark_output_as_data(out_x, out_y);
            }
        }
    }

    // R - random(min max): Outputs random value.
    private void process_random(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        int min = 0;
        int max = 35;
        
        // First, check for the special inline parameter case (like RG)
        char inline_param = grid.get_char(x + 1, y);
        if (inline_param >= 'A' && inline_param <= 'Z') {
            min = inline_param - 'A' + 10;
            max = min;
            read_parameter(x + 1, y); // Mark as data
        } else if (inline_param >= 'a' && inline_param <= 'z') {
            min = inline_param - 'a' + 10;
            max = min;
            read_parameter(x + 1, y); // Mark as data
        } else {
            // Regular case: read min from left, max from right
            if (x > 0) min = read_parameter(x - 1, y);
            if (x + 1 < OrcaGrid.WIDTH) max = read_parameter(x + 1, y);
        }
        
        // Ensure min <= max
        if (min > max) {
            int temp = min;
            min = max;
            max = temp;
        }
        
        int range = max - min + 1;
        int result = min + Random.int_range(0, range);
        
        // Convert to output character
        char output = value_to_char(result);
        
        // Modify case if needed
        if (is_uppercase || (inline_param >= 'A' && inline_param <= 'Z')) {
            output = output.toupper();
        }
        
        // Output below
        if (y + 1 < OrcaGrid.HEIGHT) {
            next_grid[x, y + 1] = output;
            mark_output_as_data(x, y + 1);
        }
    }

    // S - south: Moves southward, or bangs.
    private void process_south(int x, int y, char[,] next_grid, bool is_banged) {
        char operator_char = grid.get_char(x, y);

        // Calculate new position
        int new_y = y + 1;

        // Check if we can move
        if (new_y < OrcaGrid.HEIGHT && grid.get_char(x, new_y) == '.') {
            // Move - erase current, place operator in new position
            next_grid[x, y] = '.';
            next_grid[x, new_y] = operator_char;
        } else {
            // Can't move - turn into bang
            next_grid[x, y] = '*';
        }
    }

    // T - track(key len): Makes a track of notes.
    private void process_track(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read parameters with data marking
        int key = (x > 1) ? read_parameter(x - 2, y) : 0;
        int len = (x > 0) ? read_parameter(x - 1, y) : 1;

        if (len <= 0)len = 1;

        // Lock cells in the read region AND mark them as data
        for (int offset = 0; offset < len; offset++) {
            int data_x = x + offset + 1;
            if (data_x < OrcaGrid.WIDTH) {
                grid.lock_cell(data_x, y);
                grid.mark_as_data(data_x, y);

                // Also protect cell content to ensure it's not modified
                char cell_content = grid.get_char(data_x, y);
                grid.protect_cell_content(data_x, y, cell_content);

                if (cell_content == '*') {
                    mark_bang_as_input_parameter(data_x, y);
                }
            }
        }

        // Calculate offset exactly like JS
        int offset = (key % len) + 1;

        // Read the value, already marked as data above
        char val = '.';
        int read_x = x + offset;
        if (read_x >= 0 && read_x < OrcaGrid.WIDTH) {
            val = grid.get_char(read_x, y);
        }

        // Output to the cell BELOW
        if (y + 1 < OrcaGrid.HEIGHT) {
            next_grid[x, y + 1] = val;
            mark_output_as_data(x, y + 1);
        }
    }

    // U - uclid(step max): Bangs on Euclidean rhythm.
    private void process_uclid(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read parameters with data marking
        int step = (x > 0) ? read_parameter(x - 1, y) : 1;
        int max = (x + 1 < OrcaGrid.WIDTH) ? read_parameter(x + 1, y) : 8;

        // Ensure valid values
        if (step < 0)step = 0;
        if (max < 1)max = 1;

        // Calculate the current beat position
        int beat_position = frame_count % max;

        // Proper Euclidean rhythm algorithm
        bool should_bang = (beat_position * step) % max < step;

        // Bang below if condition is met or if operator is banged
        if ((should_bang) && y + 1 < OrcaGrid.HEIGHT) {
            next_grid[x, y + 1] = '*';
        }
    }

    // V - Variable operator: Reads and writes variable.
    private void process_variable(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read parameters with data marking
        char write = (x > 0) ? read_char_parameter(x - 1, y) : '.';
        char read = (x + 1 < OrcaGrid.WIDTH) ? read_char_parameter(x + 1, y) : '.';

        // If write is not empty, store the variable
        if (write != '.') {
            variables[write] = read;
            return;
        }

        // If write is empty but read is not, look up the variable
        if (read != '.') {
            char value = get_variable_value(read);

            // Output the value below V
            if (y + 1 < OrcaGrid.HEIGHT) {
                next_grid[x, y + 1] = value;
                mark_output_as_data(x, y + 1);
            }
        }
    }

    // W - west: Moves westward, or bangs.
    private void process_west(int x, int y, char[,] next_grid, bool is_banged) {
        char operator_char = grid.get_char(x, y);

        // Calculate new position
        int new_x = x - 1;

        // Check if we can move
        if (new_x >= 0 && grid.get_char(new_x, y) == '.') {
            // Move - erase current, place operator in new position
            next_grid[x, y] = '.';
            next_grid[new_x, y] = operator_char;
        } else {
            // Can't move - turn into bang
            next_grid[x, y] = '*';
        }
    }

    // X - write(x y val): Writes operand with offset.
    private void process_write(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read parameters with data marking
        int x_offset = (x > 1) ? read_parameter(x - 2, y) : 0;
        int y_offset = (x > 0) ? read_parameter(x - 1, y) : 0;

        // Special handling for bang input
        char val;
        if (x + 1 < OrcaGrid.WIDTH && grid.get_char(x + 1, y) == '*') {
            mark_bang_as_input_parameter(x + 1, y);
            val = '*';
        } else {
            val = read_char_parameter(x + 1, y);
        }

        // Calculate write position
        int write_x = x + x_offset;
        int write_y = y + y_offset + 1;

        // Write the value
        if (write_x >= 0 && write_x < OrcaGrid.WIDTH && write_y >= 0 && write_y < OrcaGrid.HEIGHT) {
            next_grid[write_x, write_y] = val;

            if (val != '*') {
                bool is_operator = (val >= 'A' && val <= 'Z') ||
                    SPECIAL_OPERATORS.contains(val.to_string());

                if (!is_operator || !is_banged) {
                    mark_output_as_data(write_x, write_y);
                }
            }
        }
    }

    // Y - Yumper implementation
    private void process_yumper(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read value from west (left)
        char val = '.';
        if (x > 0) {
            val = grid.get_char(x - 1, y);
        }

        // Skip if input is the same as operator
        char operator_glyph = is_uppercase ? 'Y' : 'y';
        if (val == operator_glyph) {
            return;
        }

        // Count jumper distance
        int i = 0;
        while (true) {
            i++; // Pre-increment

            if (x + i >= OrcaGrid.WIDTH) {
                break;
            }

            if (grid.get_char(x + i, y) != operator_glyph) {
                break;
            }
        }

        // Output position
        int output_x = x + i;

        if (output_x < OrcaGrid.WIDTH) {
            // Preserve the operator at the destination if it exists
            char dest_char = grid.get_char(output_x, y);

            // If destination is a special operator like =, preserve it
            // Otherwise write the value directly
            if (dest_char == '=' || dest_char == ':') {
                // We'll handle this in the Play operator by checking variables
                // Store the passed value
                variables[dest_char] = val;
            } else {
                // Normal behavior - write the value
                next_grid[output_x, y] = val;

                // Mark this cell as data if it's a lowercase letter
                mark_output_as_data(output_x, y);
            }
        }
    }

    // Z - lerp(rate target): Transitions operand to target.
    private void process_lerp(int x, int y, char[,] next_grid, bool is_uppercase, bool is_banged) {
        // Read parameters with data marking
        int rate = (x > 0) ? read_parameter(x - 1, y) : 1;
        int target = (x + 1 < OrcaGrid.WIDTH) ? read_parameter(x + 1, y) : 0;

        // Read current value (but don't mark it as data - it will be overwritten)
        int val = 0;
        if (y + 1 < OrcaGrid.HEIGHT) {
            val = get_value(x, y + 1);
        }

        // Calculate transition (LERP) using exact JavaScript algorithm
        int mod = 0;

        if (val <= target - rate) {
            mod = rate;
        } else if (val >= target + rate) {
            mod = -rate;
        } else {
            mod = target - val;
        }

        int result = val + mod;

        // Convert to output character
        char output = value_to_char(result);

        // Output below (overwrite the existing value)
        if (y + 1 < OrcaGrid.HEIGHT) {
            next_grid[x, y + 1] = output;
            mark_output_as_data(x, y + 1);
        }
    }

    private void process_comment(int x, int y, char[,] next_grid) {
        // Preserve the comment character
        grid.lock_cell(x, y);
        grid.mark_as_comment(x, y);
        grid.protect_cell_content(x, y, '#');
        next_grid[x, y] = '#';

        // Process all characters until the next comment
        for (int pos_x = x + 1; pos_x < OrcaGrid.WIDTH; pos_x++) {
            char c = grid.get_char(pos_x, y);

            // Protect, lock, and mark this character
            grid.protect_cell_content(pos_x, y, c);
            grid.mark_as_comment(pos_x, y);
            grid.lock_cell(pos_x, y);

            // Store in next grid
            next_grid[pos_x, y] = c;

            // Stop at closing comment
            if (c == '#') {
                break;
            }
        }
    }

    // ~ - play(ch oct note velocity): Play note with built-in synth
    private void process_play(int x, int y) {
        // Mark parameters as data
        for (int i = 1; i <= 4; i++) {
            int param_x = x + i;
            if (param_x < OrcaGrid.WIDTH) {
                grid.mark_as_data(param_x, y);
                grid.lock_cell(param_x, y);
            }
        }

        // Only trigger when banged - direct check like JavaScript
        if (!has_bang_neighbor(x, y)) {
            print("Play at %d,%d: Not banged, skipping\n", x, y);
            return;
        }

        print("Play at %d,%d: Banged, generating sound\n", x, y);

        // Read parameters
        int channel = 0;
        int octave = 4;
        char note = '.';
        int velocity = 127;

        if (x + 1 < OrcaGrid.WIDTH) {
            channel = get_value(x + 1, y);
        }

        if (x + 2 < OrcaGrid.WIDTH) {
            octave = get_value(x + 2, y);
            if (octave > 8)octave = 8;
        }

        if (x + 3 < OrcaGrid.WIDTH) {
            note = grid.get_char(x + 3, y);
        }

        if (x + 4 < OrcaGrid.WIDTH) {
            velocity = get_value(x + 4, y);
            velocity = (velocity * 127) / 35;
        }

        // Calculate note duration based on context
        int duration_frames = calculate_duration_for_operator(x, y);

        print("Play: ch=%d, oct=%d, note=%c, velocity=%d, duration=%d frames\n",
              channel, octave, note, velocity, duration_frames);

        // Play the note
        if (note != '.') {
            synth.play_note(channel, octave, note, velocity, duration_frames);
        } else {
            print("Play: Skipping play - no valid note found\n");
        }
    }

    // = - osc(path): Sends OSC message
    private void process_osc(int x, int y) {
        // Read the path parameter and mark as data
        char path = '.';
        if (x + 1 < OrcaGrid.WIDTH) {
            path = read_char_parameter(x + 1, y);
        }

        // Only trigger when banged
        if (!has_bang_neighbor(x, y)) {
            return;
        }

        // Build the message
        StringBuilder msg = new StringBuilder();
        for (int i = 2; i <= 36; i++) {
            int param_x = x + i;
            if (param_x >= OrcaGrid.WIDTH)break;

            char g = grid.get_char(param_x, y);
            grid.mark_as_data(param_x, y);
            grid.lock_cell(param_x, y);
            grid.protect_cell_content(param_x, y, g);

            if (g == '.')break;
            msg.append_c(g);
        }

        print("OSC message: /%c %s\n", path, msg.str);

        // We could map this to MIDI like:
        // int channel = path - 'a'; // Map a-p to channels 0-15
        // synth.send_osc_as_midi(channel, msg.str);
    }

    // ! - cc(channel, knob, value): Sends MIDI control change
    private void process_cc(int x, int y) {
        // Only trigger when banged
        if (!has_bang_neighbor(x, y)) {
            return;
        }

        // Read parameters with proper data marking
        int channel = (x + 1 < OrcaGrid.WIDTH) ? read_parameter(x + 1, y) : 0;
        int knob = (x + 2 < OrcaGrid.WIDTH) ? read_parameter(x + 2, y) : 0;
        int value = (x + 3 < OrcaGrid.WIDTH) ? read_parameter(x + 3, y) : 0;

        // Additional protection for parameters if needed
        for (int i = 1; i <= 3; i++) {
            int param_x = x + i;
            if (param_x < OrcaGrid.WIDTH) {
                char g = grid.get_char(param_x, y);
                grid.protect_cell_content(param_x, y, g);
            }
        }

        // Normalize value from 0-35 to 0-127 for MIDI
        int midi_value = (value * 127) / 35;

        print("MIDI CC: ch=%d, knob=%d, value=%d\n", channel, knob, midi_value);

        // Send MIDI CC
        synth.send_midi_cc(channel, knob, midi_value);
    }

    // ? - pb(channel, lsb, msb): Sends MIDI pitch bend
    private void process_pb(int x, int y) {
        // Mark parameters as data
        for (int i = 1; i <= 3; i++) {
            int param_x = x + i;
            if (param_x < OrcaGrid.WIDTH) {
                char g = grid.get_char(param_x, y);
                grid.mark_as_data(param_x, y);
                grid.lock_cell(param_x, y);
                grid.protect_cell_content(param_x, y, g);
            }
        }

        // Only trigger when banged
        if (!has_bang_neighbor(x, y)) {
            return;
        }

        // Read parameters
        int channel = (x + 1 < OrcaGrid.WIDTH) ? read_parameter(x + 1, y) : 0;
        int lsb = (x + 2 < OrcaGrid.WIDTH) ? read_parameter(x + 2, y) : 0;
        int msb = (x + 3 < OrcaGrid.WIDTH) ? read_parameter(x + 3, y) : 0;

        // Normalize values from 0-35 to 0-127 for MIDI
        int midi_lsb = (lsb * 127) / 35;
        int midi_msb = (msb * 127) / 35;

        print("MIDI Pitch Bend: ch=%d, lsb=%d, msb=%d\n", channel, midi_lsb, midi_msb);

        // Send MIDI pitch bend
        synth.send_midi_pitch_bend(channel, midi_lsb, midi_msb);
    }

    // % - mono(channel octave note velocity length): Sends MIDI monophonic note
    private void process_mono(int x, int y) {
        // Mark parameters as data
        for (int i = 1; i <= 4; i++) {
            int param_x = x + i;
            if (param_x < OrcaGrid.WIDTH) {
                char g = grid.get_char(param_x, y);
                grid.mark_as_data(param_x, y);
                grid.lock_cell(param_x, y);
                grid.protect_cell_content(param_x, y, g);
            }
        }

        // Only trigger when banged
        if (!has_bang_neighbor(x, y)) {
            return;
        }

        // Read parameters (same as regular MIDI)
        int channel = (x + 1 < OrcaGrid.WIDTH) ? read_parameter(x + 1, y) : 0;
        int octave = (x + 2 < OrcaGrid.WIDTH) ? read_parameter(x + 2, y) : 4;
        char note = (x + 3 < OrcaGrid.WIDTH) ? read_char_parameter(x + 3, y) : '.';
        int velocity = (x + 4 < OrcaGrid.WIDTH) ? read_parameter(x + 4, y) : 127;

        // Ensure valid values
        if (octave > 8)octave = 8;
        velocity = (velocity * 127) / 35; // Normalize to MIDI range

        int duration_frames = calculate_duration_for_operator(x, y);

        print("MIDI Mono: ch=%d, oct=%d, note=%c, vel=%d, dur=%d\n",
              channel, octave, note, velocity, duration_frames);

        // Only play if note is valid
        if (note != '.' && note != '*') {
            synth.play_note_mono(channel, octave, note, velocity, duration_frames);
        }
    }

    // ; - udp: Sends UDP message
    private void process_udp(int x, int y) {
        // Only trigger when banged
        if (!has_bang_neighbor(x, y)) {
            return;
        }

        // Build message from characters after the operator
        StringBuilder msg = new StringBuilder();
        for (int i = 1; i <= 36; i++) {
            int param_x = x + i;
            if (param_x >= OrcaGrid.WIDTH)break;

            char g = grid.get_char(param_x, y);
            grid.mark_as_data(param_x, y);
            grid.lock_cell(param_x, y);
            grid.protect_cell_content(param_x, y, g);

            if (g == '.')break;
            msg.append_c(g);
        }

        print("UDP message: %s\n", msg.str);

        // Send UDP message through port 49161
        synth.send_udp(msg.str);
    }

    // $ - self: Sends ORCA command
    private void process_self(int x, int y) {
        // Only trigger when banged
        if (!has_bang_neighbor(x, y)) {
            return;
        }

        // Build command from characters after the operator
        StringBuilder cmd = new StringBuilder();
        for (int i = 1; i <= 36; i++) {
            int param_x = x + i;
            if (param_x >= OrcaGrid.WIDTH)break;

            char g = grid.get_char(param_x, y);
            grid.mark_as_data(param_x, y);
            grid.lock_cell(param_x, y);
            grid.protect_cell_content(param_x, y, g);

            if (g == '.')break;
            cmd.append_c(g);
        }

        string command = cmd.str;
        print("Self command: %s\n", command);

        // Process the command
        if (command.has_prefix("bpm")) {
            // Handle both formats: bpm=120 and bpm120
            string bpm_str;
            if (command.contains("=")) {
                // Format: bpm=120
                string[] parts = command.split("=", 2);
                if (parts.length < 2)return;
                bpm_str = parts[1];
            } else {
                // Legacy format: bpm120
                bpm_str = command.substring(3);
            }

            // Parse BPM value
            int new_bpm = 0;
            new_bpm = int.parse(bpm_str);

            if (new_bpm > 0) {
                print("  Changing BPM to %d\n", new_bpm);
                bpm_change_requested(new_bpm);
            }
        } else if (command.has_prefix("render")) {
            print("  Render frame requested\n");
            // Force rendering of the current frame
        }
    }

    // Calculate appropriate duration based on nearby D operators
    private int calculate_duration_for_operator(int x, int y) {
        // Default duration if no D operator found
        int duration = 8;

        // Look for D operators nearby that might be triggering this
        for (int dx = -1; dx <= 1; dx++) {
            for (int dy = -1; dy <= 1; dy++) {
                int nx = x + dx;
                int ny = y + dy;

                if (nx < 0 || nx >= OrcaGrid.WIDTH || ny < 0 || ny >= OrcaGrid.HEIGHT) {
                    continue;
                }

                if (grid.get_char(nx, ny) == 'D') {
                    // Found a D operator, read its parameters
                    int rate = 1;
                    int mod = 8;

                    if (nx > 0) {
                        char rate_char = grid.get_char(nx - 1, ny);
                        if (rate_char >= '0' && rate_char <= '9') {
                            rate = rate_char - '0';
                        }
                    }

                    if (nx + 1 < OrcaGrid.WIDTH) {
                        char mod_char = grid.get_char(nx + 1, ny);
                        if (mod_char >= '0' && mod_char <= '9') {
                            mod = mod_char - '0';
                        }
                    }

                    // Calculate duration based on D's timing
                    duration = rate * mod;
                    return duration;
                }
            }
        }

        return duration;
    }

    private int get_value(int x, int y) {
        if (x < 0 || x >= OrcaGrid.WIDTH || y < 0 || y >= OrcaGrid.HEIGHT) {
            return 0;
        }

        char c = grid.get_char(x, y);

        if (c >= '0' && c <= '9') {
            return c - '0';
        } else if (c >= 'a' && c <= 'z') {
            return (c - 'a') + 10;
        } else if (c >= 'A' && c <= 'Z') {
            return (c - 'A') + 10;
        }

        return 0;
    }
}
