/*
 * Turquoise - A pattern drawing application
 * Utility functions
 */

namespace Turquoise {

    // VM state structure
    public class VmState {
        // Runtime
        public int x = 0;
        public int y = 0;
        public int scale = 1;

        // Registers (1 bit flags)
        public int drawing = 1;    // Start with drawing enabled
        public int coloring = 0;   // Start with coloring disabled
        public int mirror = 0;     // Start with mirror disabled
        public int flipx = 0;      // Start with flipx disabled
        public int flipy = 0;      // Start with flipy disabled
        public bool return_flag = false; // Return flag

        // Return position (for push/pop)
        public int return_x = 0;
        public int return_y = 0;
    }

    public enum Instruction {
        PUSH_POP = 0x0,        // Push/Pop
        MOVE_RIGHT = 0x1,      // Move(1,0)
        MOVE_LEFT = 0x2,       // Move(-1,0)
        FLIP_HORIZONTAL = 0x3, // Flip(1,0)
        MOVE_UP = 0x4,         // Move(0,1)
        MOVE_UP_RIGHT = 0x5,   // Move(1,1)
        MOVE_UP_LEFT = 0x6,    // Move(-1,1)
        MIRROR = 0x7,          // Mirror()
        MOVE_DOWN = 0x8,       // Move(0,-1)
        MOVE_DOWN_RIGHT = 0x9, // Move(1,-1)
        MOVE_DOWN_LEFT = 0xa,  // Move(-1,-1)
        FLIP_VERTICAL = 0xb,   // Flip(0,1)
        COLOR = 0xc,           // Color()
        DRAW = 0xd,            // Draw()
        SCALE_UP = 0xe,        // Scale(1)
        SCALE_DOWN = 0xf       // Scale(-1)
    }
    
    /*
	 * InstructionSet class to hold a complete set of instructions
	 */
	public class InstructionSet {
        public uint8 length;
        public uint8 cycles;
        public uint8[] instructions;
        public int cycles_completed = 0;
        public int frames_executed = 0;
        
        public InstructionSet(uint8 length, uint8 cycles, uint8[] instructions) {
            this.length = length;
            this.cycles = cycles;
            this.instructions = instructions;
        }
    }

    // Instruction decoder
    public class InstructionDecoder {
        // Execute a single instruction
        public static void execute(uint8 instruction, ref VmState state) {
            switch (instruction) {
                case Instruction.PUSH_POP: // 0
                    if (state.return_flag) {
                        // Pop (Return)
                        state.x = state.return_x;
                        state.y = state.return_y;
                        state.return_flag = false;
                    } else {
                        // Push (Call)
                        state.return_x = state.x;
                        state.return_y = state.y;
                        state.return_flag = true;
                    }
                    break;
                    
                case Instruction.MOVE_RIGHT: // 1
                    move_in_direction(ref state, 1, 0);
                    break;
                    
                case Instruction.MOVE_LEFT: // 2
                    move_in_direction(ref state, -1, 0);
                    break;
                    
                case Instruction.FLIP_HORIZONTAL: // 3
                    // Toggle flipx (0->1, 1->0)
                    state.flipx = (state.flipx == 0) ? 1 : 0;
                    break;
                    
                case Instruction.MOVE_UP: // 4
                    move_in_direction(ref state, 0, 1);
                    break;
                    
                case Instruction.MOVE_UP_RIGHT: // 5
                    move_in_direction(ref state, 1, 1);
                    break;
                    
                case Instruction.MOVE_UP_LEFT: // 6
                    move_in_direction(ref state, -1, 1);
                    break;
                    
                case Instruction.MIRROR: // 7
                    // Toggle mirror (0->1, 1->0)
                    state.mirror = (state.mirror == 0) ? 1 : 0;
                    break;
                    
                case Instruction.MOVE_DOWN: // 8
                    move_in_direction(ref state, 0, -1);
                    break;
                    
                case Instruction.MOVE_DOWN_RIGHT: // 9
                    move_in_direction(ref state, 1, -1);
                    break;
                    
                case Instruction.MOVE_DOWN_LEFT: // a
                    move_in_direction(ref state, -1, -1);
                    break;
                    
                case Instruction.FLIP_VERTICAL: // b
                    // Toggle flipy (0->1, 1->0)
                    state.flipy = (state.flipy == 0) ? 1 : 0;
                    break;
                    
                case Instruction.COLOR: // c
                    // Toggle coloring (0->1, 1->0)
                    state.coloring = (state.coloring == 0) ? 1 : 0;
                    break;
                    
                case Instruction.DRAW: // d
                    // Toggle drawing (0->1, 1->0)
                    state.drawing = (state.drawing == 0) ? 1 : 0;
                    break;
                    
                case Instruction.SCALE_UP: // e
                    state.scale += 1;
                    break;
                    
                case Instruction.SCALE_DOWN: // f
                    state.scale -= 1;
                    if (state.scale < 1) state.scale = 1; // Prevent negative/zero scale
                    break;
            }
        }
        
        // Move in a direction with transformations applied
        private static void move_in_direction(ref VmState state, int dx, int dy) { 
            // Create copies of direction vectors for transformation
            int transformed_dx = dx;
            int transformed_dy = dy;

            // 1. flip X
            if (state.flipx   != 0) transformed_dx = -transformed_dx;

            // 2. mirror across y=x
            if (state.mirror  != 0) {
                int tmp       = transformed_dx;
                transformed_dx = transformed_dy;
                transformed_dy = tmp;
            }

            // 3. flip Y
            if (state.flipy   != 0) transformed_dy = -transformed_dy;

            // 4. scale & step
            for (int i = 0; i < state.scale; i++) {
                state.x      += transformed_dx;
                state.y      -= transformed_dy;
                
                if (state.x < 0) state.x = 0;
                if (state.y < 0) state.y = 0;
                if (state.x > 181) state.x = 180;
                if (state.y > 181) state.y = 180;
            }
        }
    }

    // Utility functions
    public class Utils {
        // Set color functions for Cairo context
        public static void set_color_bg(Cairo.Context cr) {
            Theme.Manager theme = Theme.Manager.get_default();
            var bg_color = theme.get_color("theme_bg");
            cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);
        }
        
        public static void set_color_fg(Cairo.Context cr) {
            Theme.Manager theme = Theme.Manager.get_default();
            var fg_color = theme.get_color("theme_fg");
            cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
        }
        
        public static void set_color_accent(Cairo.Context cr) {
            Theme.Manager theme = Theme.Manager.get_default();
            var accent_color = theme.get_color("theme_accent");
            cr.set_source_rgb(accent_color.red, accent_color.green, accent_color.blue);
        }
        
        public static void set_color_selection(Cairo.Context cr) {
            Theme.Manager theme = Theme.Manager.get_default();
            var sel_color = theme.get_color("theme_selection");
            cr.set_source_rgb(sel_color.red, sel_color.green, sel_color.blue);
        }
        
        // Validate that a string contains only hexadecimal characters
        public static bool is_valid_hex(string text) {
            for (int i = 0; i < text.length; i++) {
                char c = text[i];
                if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) {
                    return false;
                }
            }
            return text.length > 0;
        }
        
        // Convert hex string to bytes
        public static uint8[] hex_to_bytes(string hex) {
            int len = hex.down().length / 2;
            uint8[] result = new uint8[len];
            
            for (int i = 0; i < len; i++) {
                string byte_str = hex.down().substring(i * 2, 2);
                result[i] = (uint8)int.parse("0x" + byte_str);
            }
            
            return result;
        }
        
        // Convert a single hex character to a value
        public static uint8 hex_char_to_value(char c) {
            if (c >= '0' && c <= '9') return (uint8)(c - '0');
            if (c >= 'a' && c <= 'f') return (uint8)(c - 'a' + 10);
            if (c >= 'A' && c <= 'F') return (uint8)(c - 'A' + 10);
            return 0;
        }
        
        // Convert bytes to hex string
        public static string bytes_to_hex(uint8[] bytes) {
            var builder = new StringBuilder();
            foreach (uint8 b in bytes) {
                builder.append_printf("%02x", b);
            }
            return builder.str;
        }
    }
}