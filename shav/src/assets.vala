using Gtk;
using Cairo;

namespace ShavianKeyboard {
    // Keyboard layout and character definitions
    public class Assets {
        // Key layout data: [name, primary_char, alternate_char, num_char]
        private static string[,] _keys;
        
        public static string[,] keys {
            get {
                if (_keys == null) {
                    initialize_keys();
                }
                return _keys;
            }
        }
        
        private static void initialize_keys() {
            _keys = new string[36, 4] {
                // Row 1
                {"yew/ooze/7", "𐑿", "𐑳", "7"},
                {"age/egg/8", "𐑱", "𐑧", "8"},
                {"ice/ash/9", "𐑲", "𐑨", "9"},
                {"are/ah/@", "𐑸", "𐑭", "@"},
                {"oil/out/:", "𐑶", "𐑬", ":"},
                {"fee/vow/·", "𐑓", "𐑝", "·"},
                {"yeah/woe/.", "𐑘", "𐑢", "."},
                {"thigh/they/_", "𐑔", "𐑞", "_"},
                {"hung/haha/*", "𐑙", "𐑣", "*"},
                
                // Row 2
                {"roar/loll/4", "𐑮", "𐑤", "4"},
                {"eat/if/5", "𐑰", "𐑦", "5"},
                {"ado/ian/6", "𐑩", "𐑪", "6"},
                {"mime/nun/'", "𐑥", "𐑯", "'"},
                {"or/awe/;", "𐑹", "𐑷", ";"},
                {"tot/dead/—", "𐑑", "𐑛", "—"},
                {"so/zoo/-", "𐑕", "𐑟", "-"},
                {"kick/gag/?", "𐑒", "𐑜", "?"},
                {"peep/bib/!", "𐑐", "𐑚", "!"},
                
                // Row 3
                {"air/on/1", "𐑺", "𐑪", "1"},
                {"err/up/2", "𐑻", "𐑵", "2"},
                {"ear/array/3", "𐑽", "𐑼", "3"},
                {"wool/oak/0", "𐑫", "𐑴", "0"},
                {"church/judge/(", "𐑗", "𐑡", "("},
                {"sure/measure/)", "𐑖", "𐑠", ")"},
                {"//<", "<", "<", "<"},
                {"//>", ">", ">", ">"},
                {"//⌫", "⌫", "⌫", "⌫"},
                
                // Row 4
                {"//⋄", "⋄", "⋄", "⋄"},
                {"//,",",",",",","},
                {"// ", " ", " ", " "},
                {"//.", ".", ".", "."},
                {"//←", "←", "←", "←"},

                 // Extra empty rows to ensure array has enough space
                {"", "", "", ""},
                {"", "", "", ""}
            };
        }
        
        // Pixel patterns for Shavian characters using hex strings
        // Each character is represented by a single hex string (16 hex digits = 8 bytes = 64 bits = 8×8 grid)
        private static HashTable<unichar, string> _pixel_patterns;
        
        public static unowned HashTable<unichar, string> pixel_patterns {
            get {
                if (_pixel_patterns == null) {
                    initialize_pixel_patterns();
                }
                return _pixel_patterns;
            }
        }
        
        private static void initialize_pixel_patterns() {
            _pixel_patterns = new HashTable<unichar, string>(direct_hash, direct_equal);
            
            // Common Shavian characters - 8x16 pixel patterns as hex strings
            // 𐑐 (PEEP)
            _pixel_patterns.insert('𐑐', "00000060100808080808080800000000");
            // 𐑑 (TOT)
            _pixel_patterns.insert('𐑑', "00000008186808080808080800000000");
            // 𐑒 (KICK)
            _pixel_patterns.insert('𐑒', "0000000404043c404040403c00000000");
            // 𐑓 (FEE)
            _pixel_patterns.insert('𐑓', "00000008080808080808106000000000");
            // 𐑔 (THIGH)
            _pixel_patterns.insert('𐑔', "00000060100838448484887000000000");
            // 𐑕 (SO)
            _pixel_patterns.insert('𐑕', "00000038444020100804443800000000");
            // 𐑖 (SURE)
            _pixel_patterns.insert('𐑖', "00000008102020404040443800000000");
            // 𐑗 (CHURCH)
            _pixel_patterns.insert('𐑗', "0000000810e020404040443800000000");
            // 𐑘 (YEA)
            _pixel_patterns.insert('𐑘', "00000040402020101008080400000000");
            // 𐑙 (HUNG)
            _pixel_patterns.insert('𐑙', "0000003048484848484830cc00000000");
            // 𐑚 (BIB)
            _pixel_patterns.insert('𐑚', "00000000000020202020202020100c00");
            // 𐑛 (DEAD)
            _pixel_patterns.insert('𐑛', "00000000000040404040404058604000");
            // 𐑜 (GAG)
            _pixel_patterns.insert('𐑜', "00000000000078040404047840404000");
            // 𐑝 (VOW)
            _pixel_patterns.insert('𐑝', "00000000000018204040404040404000");
            // 𐑞 (THEY)
            _pixel_patterns.insert('𐑞', "00000000000038448484887040201800");
            // 𐑟 (ZOO)
            _pixel_patterns.insert('𐑟', "00000000000038440408102040443800");
            // 𐑠 (MEASURE)
            _pixel_patterns.insert('𐑠', "00000000000038440404040808102000");
            // 𐑡 (JUDGE)
            _pixel_patterns.insert('𐑡', "0000000000003844040404080e102000");
            // 𐑢 (WOE)
            _pixel_patterns.insert('𐑢', "00000000000004080810102020404000");
            // 𐑣 (HAHA)
            _pixel_patterns.insert('𐑣', "000000000000cc304848484848483000");
            // 𐑤 (LOLL)
            _pixel_patterns.insert('𐑤', "00000000000038404040403800000000");
            // 𐑥 (MIME)
            _pixel_patterns.insert('𐑥', "0000000000000c101010106000000000");
            // 𐑦 (IF)
            _pixel_patterns.insert('𐑦', "00000000000010101010101000000000");
            // 𐑧 (EGG)
            _pixel_patterns.insert('𐑧', "00000000000040404040201c00000000");
            // 𐑨 (ASH)
            _pixel_patterns.insert('𐑨', "00000000000004040404087000000000");
            // 𐑩 (ADO)
            _pixel_patterns.insert('𐑩', "0000000000001c204040404000000000");
            // 𐑪 (ON)
            _pixel_patterns.insert('𐑪', "00000000000070080404040400000000");
            // 𐑫 (WOOL)
            _pixel_patterns.insert('𐑫', "00000000000044442828101000000000");
            // 𐑬 (OUT)
            _pixel_patterns.insert('𐑬', "0000000000007c081010202000000000");
            // 𐑭 (AH)
            _pixel_patterns.insert('𐑭', "0000000000001c202018087000000000");
            // 𐑹 (ROAR)
            _pixel_patterns.insert('𐑹', "000000000000cc2222c2847800000000");
            // 𐑯 (NUN)
            _pixel_patterns.insert('𐑯', "00000000000060101010100c00000000");
            // 𐑰 (EAT)
            _pixel_patterns.insert('𐑰', "000000000000404c5464040400000000");
            // 𐑱 (AGE)
            _pixel_patterns.insert('𐑱', "0000000000007c404040201c00000000");
            // 𐑲 (ICE)
            _pixel_patterns.insert('𐑲', "0000000000007c040404087000000000");
            // 𐑵 (UP)
            _pixel_patterns.insert('𐑵', "00000000000010102828444400000000");
            // 𐑴 (OAK)
            _pixel_patterns.insert('𐑴', "00000000000038444444443800000000");
            // 𐑳 (OOZE)
            _pixel_patterns.insert('𐑳', "00000000000008106010100800000000");
            // 𐑶 (OIL)
            _pixel_patterns.insert('𐑶', "00000000000020100c10102000000000");
            // 𐑷 (AWE)
            _pixel_patterns.insert('𐑷', "00000000000070080830201c00000000");
            // 𐑮 (ARE)
            _pixel_patterns.insert('𐑮', "00000000000038040404043800000000");
            // 𐑸 (OR)
            _pixel_patterns.insert('𐑸', "0000000000003c42423212e400000000");
            // 𐑺 (AIR)
            _pixel_patterns.insert('𐑺', "0000000000001c222272826400000000");
            // 𐑻 (ERR)
            _pixel_patterns.insert('𐑻', "00000000000064827222221c00000000");
            // 𐑼 (ARRAY)
            _pixel_patterns.insert('𐑼', "0000000000003c428282828c00000000");
            // 𐑽 (EAR)
            _pixel_patterns.insert('𐑽', "000000000000bcc28282829c00000000");
            // 𐑾 (IAN)
            _pixel_patterns.insert('𐑾', "0000000000004e506040404000000000");
            // 𐑿 (YEW)
            _pixel_patterns.insert('𐑿', "00000080808048485454222200000000");

            // Numbers (0-9)
            // 0
            _pixel_patterns.insert('0', "00000078848484848484847800000000");
            // 1
            _pixel_patterns.insert('1', "00000010301010101010101000000000");
            // 2
            _pixel_patterns.insert('2', "0000007884040418608080fc00000000");
            // 3
            _pixel_patterns.insert('3', "000000fc040818040404847800000000");
            // 4
            _pixel_patterns.insert('4', "000000182828484888fc080800000000");
            // 5
            _pixel_patterns.insert('5', "000000fc8080f8040404847800000000");
            // 6
            _pixel_patterns.insert('6', "000000384080f8848484847800000000");
            // 7
            _pixel_patterns.insert('7', "000000fc040408081010202000000000");
            // 8
            _pixel_patterns.insert('8', "00000078848478848484847800000000");
            // 9
            _pixel_patterns.insert('9', "00000078848484847c04087000000000");
            
            // Symbols (like @)
            // @
            _pixel_patterns.insert('@', "000000003c4299a5a5a5ad9640300000");
            // :
            _pixel_patterns.insert(':', "00000000001000000010000000000000");
            // ·
            _pixel_patterns.insert('·', "00000000000010381000000000000000");
            // _
            _pixel_patterns.insert('_', "0000000000000000000000fe00000000");
            // *
            _pixel_patterns.insert('*', "00000000105438ee3854100000000000");
            // '
            _pixel_patterns.insert('\'', "00000030301000000000000000000000");
            // ;
            _pixel_patterns.insert(';', "00000000001000000010102000000000");
            // —
            _pixel_patterns.insert('—', "00000000000000fe0000000000000000");
            // -
            _pixel_patterns.insert('-', "000000000000007c0000000000000000");
            // ?
            _pixel_patterns.insert('?', "00000078848404081020002000000000");
            // !
            _pixel_patterns.insert('!', "00000020202020202020002000000000");
            // (
            _pixel_patterns.insert('(', "00001020204040404040402020100000");
            // )
            _pixel_patterns.insert(')', "00004020201010101010102020400000");
            // < (Left)
            _pixel_patterns.insert('<', "00000000102040fe4020100000000000");
            // > (Right)
            _pixel_patterns.insert('>', "00000000100804fe0408100000000000");
            // Backspace
            _pixel_patterns.insert('⌫', "000000001f21558955211f0000000000");
            // Mode
            _pixel_patterns.insert('⋄', "0000000010387cfe7c38100000000000");
            // Comma
            _pixel_patterns.insert(',', "00000000000000000010102000000000");
            // Space
            _pixel_patterns.insert(' ', "00000000000000000084fc0000000000");
            // Period
            _pixel_patterns.insert('.', "00000000000000000000001000000000");
            // Enter
            _pixel_patterns.insert('←', "000000001232528c5030100000000000");
        
        }
    }
}