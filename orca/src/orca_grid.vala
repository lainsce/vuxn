// Update the OrcaGrid class to handle locking correctly
public class OrcaGrid {
    public const int WIDTH = 91;
    public const int HEIGHT = 37;
    
    private char[,] grid;
    private bool[,] locked_cells; // Track which cells are locked for reading
    private bool[,] data_cells; // Track cells that should be treated as data, not operators
    private bool[,] commented_cells; // Track cells within comment blocks
    private char[,] protected_content; // Store the original content of cells that must be preserved
    
    public OrcaGrid() {
        grid = new char[WIDTH, HEIGHT];
        locked_cells = new bool[WIDTH, HEIGHT];
        data_cells = new bool[WIDTH, HEIGHT];
        commented_cells = new bool[WIDTH, HEIGHT];
        protected_content = new char[WIDTH, HEIGHT];
        clear();
    }
    
    public void clear() {
        for (int x = 0; x < WIDTH; x++) {
            for (int y = 0; y < HEIGHT; y++) {
                grid[x, y] = '.';
                locked_cells[x, y] = false;
                data_cells[x, y] = false;
                commented_cells[x, y] = false;
            }
        }
    }
    
    public char get_char(int x, int y) {
        if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) {
            return grid[x, y];
        }
        return '.';
    }
    
    // In ORCA, all cells can be modified for the next frame,
    // regardless of locks. Locks only affect reading, not writing.
    public void set_char(int x, int y, char c) {
        if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) {
            grid[x, y] = c;
        }
    }
    
    // Lock a cell to mark it as "read" for this frame
    public void lock_cell(int x, int y) {
        if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) {
            locked_cells[x, y] = true;
        }
    }
    
    // Check if a cell is locked (has been read)
    public bool is_cell_locked(int x, int y) {
        if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) {
            return locked_cells[x, y];
        }
        return false;
    }
    
    // Reset all locks at the beginning of a frame
    public void reset_locks() {
        for (int x = 0; x < WIDTH; x++) {
            for (int y = 0; y < HEIGHT; y++) {
                locked_cells[x, y] = false;
            }
        }
    }
    
    public void mark_as_data(int x, int y) {
        if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) {
            data_cells[x, y] = true;
        }
    }
    
    public bool is_data_cell(int x, int y) {
        if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) {
            return data_cells[x, y];
        }
        return false;
    }

    public void reset_data_flags() {
        for (int x = 0; x < WIDTH; x++) {
            for (int y = 0; y < HEIGHT; y++) {
                data_cells[x, y] = false;
            }
        }
    }

    public void mark_as_comment(int x, int y) {
        if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) {
            commented_cells[x, y] = true;
        }
    }
    
    public bool is_commented_cell(int x, int y) {
        if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) {
            return commented_cells[x, y];
        }
        return false;
    }
    
    public void reset_comment_flags() {
        for (int x = 0; x < WIDTH; x++) {
            for (int y = 0; y < HEIGHT; y++) {
                commented_cells[x, y] = false;
            }
        }
    }
    
    public void protect_cell_content(int x, int y, char content) {
        if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) {
            protected_content[x, y] = content;
        }
    }

    public bool is_protected_cell(int x, int y) {
        return is_commented_cell(x, y); // For now, all commented cells are protected
    }

    public char get_protected_content(int x, int y) {
        if (x >= 0 && x < WIDTH && y >= 0 && y < HEIGHT) {
            return protected_content[x, y];
        }
        return '.';
    }

    public void reset_protected_content() {
        for (int x = 0; x < WIDTH; x++) {
            for (int y = 0; y < HEIGHT; y++) {
                protected_content[x, y] = '.';
            }
        }
    }
}