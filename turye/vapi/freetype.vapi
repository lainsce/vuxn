[CCode (cprefix = "FT_", lower_case_cprefix = "ft_", cheader_filename = "ft2build.h,freetype/freetype.h")]
namespace FT {
    [Compact]
    [CCode (free_function = "FT_Done_Library")]
    public class Library {
        [CCode (cname = "FT_Init_FreeType")]
        public static int init_freetype (out Library library);
    }
    
    [Compact]
    [CCode (free_function = "FT_Done_Face")]
    public class Face {
        [CCode (cname = "FT_New_Memory_Face")]
        public static int new_memory_face (Library library, [CCode (array_length = false)] uint8[] file_base, long file_size, long face_index, out Face face);
        
        [CCode (cname = "FT_Set_Pixel_Sizes")]
        public int set_pixel_sizes (uint pixel_width, uint pixel_height);
    }
}