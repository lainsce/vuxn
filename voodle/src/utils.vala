/* utils.vala
 *
 * Utility classes for the drawing application
 */
// TGA file utilities
public class TgaUtils {
    public static void save_tga(string filename, Cairo.ImageSurface surface) {
        try {
            // Get image data from the surface
            int width = surface.get_width();
            int height = surface.get_height();
            unowned uint8[] data = surface.get_data();

            // Create TGA header
            uint8[] header = new uint8[18];
            header[2] = 2; // Uncompressed RGB
            header[12] = (uint8)(width & 0xFF);
            header[13] = (uint8)(width >> 8);
            header[14] = (uint8)(height & 0xFF);
            header[15] = (uint8)(height >> 8);
            header[16] = 32; // 32 bits per pixel
            header[17] = 0x28; // Flip vertically

            // Open file
            var file = GLib.File.new_for_path(filename);
            var stream = file.replace(null, false, GLib.FileCreateFlags.REPLACE_DESTINATION);

            // Write header
            size_t bytes_written;
            stream.write_all(header, out bytes_written);

            // Write pixel data (Cairo uses ARGB32, TGA wants BGRA)
            uint8[] buffer = new uint8[width * height * 4];
            int buffer_pos = 0;

            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    int index = y * surface.get_stride() + x * 4;
                    buffer[buffer_pos++] = data[index + 2]; // B
                    buffer[buffer_pos++] = data[index + 1]; // G
                    buffer[buffer_pos++] = data[index + 0]; // R
                    buffer[buffer_pos++] = data[index + 3]; // A
                }
            }

            stream.write_all(buffer, out bytes_written);
            stream.close();
        } catch (Error e) {
            print("Error saving TGA: %s\n", e.message);
        }
    }

    public static Cairo.ImageSurface? load_tga(string filename, Cairo.ImageSurface? existing_surface = null) {
        try {
            // Open file
            var file = GLib.File.new_for_path(filename);
            var stream = file.read();

            // Read header
            uint8[] header = new uint8[18];
            size_t bytes_read;
            stream.read_all(header, out bytes_read);

            if (bytes_read < 18) {
                print("Invalid TGA file\n");
                return null;
            }

            // Get dimensions
            int width = header[12] + (header[13] << 8);
            int height = header[14] + (header[15] << 8);

            // Check image type
            if (header[2] != 2) {
                print("Unsupported TGA format\n");
                return null;
            }

            // Create or reuse surface
            Cairo.ImageSurface surface;
            if (existing_surface != null &&
                width == existing_surface.get_width() &&
                height == existing_surface.get_height()) {

                surface = existing_surface;
                // Clear surface
                var cr = new Cairo.Context(surface);
                cr.set_source_rgb(1, 1, 1);
                cr.paint();
            } else {
                surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, width, height);
            }

            // Read pixel data
            unowned uint8[] data = surface.get_data();
            int stride = surface.get_stride();

            uint8[] buffer = new uint8[width * height * 4];
            stream.read_all(buffer, out bytes_read);

            if (bytes_read < width * height * 4) {
                print("Invalid TGA data\n");
                return null;
            }

            int buffer_pos = 0;
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    int index = y * stride + x * 4;
                    data[index + 0] = buffer[buffer_pos + 2]; // R
                    data[index + 1] = buffer[buffer_pos + 1]; // G
                    data[index + 2] = buffer[buffer_pos + 0]; // B
                    data[index + 3] = buffer[buffer_pos + 3]; // A
                    buffer_pos += 4;
                }
            }

            // Mark surface as dirty
            surface.mark_dirty();

            return surface;
        } catch (Error e) {
            print("Error loading TGA: %s\n", e.message);
            return null;
        }
    }
}
