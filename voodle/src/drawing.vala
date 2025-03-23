/* drawing.vala
 *
 * Drawing functionality for the Voodle application
 */

// Expanded Tool enum to include MAGIC_WAND
public enum Tool {
    PENCIL,
    ERASER,
    HALFTONER,
    LINE,
    MAGIC_WAND
}

public enum Halftone {
    FULL,
    CHECKERBOARD,
    CROSS_5X5,
    CROSS_3X3,
    DIAGONAL_RIGHT,
    DIAGONAL_LEFT,
    VERTICAL_LINES,
    HORIZONTAL_LINES
}

public enum Thickness {
    PX_1,
    PX_3,
    PX_5,
    PX_7
}

public enum Shape {
    SQUARE,
    CIRCLE,
    DIAMOND
}

public class DrawingManager {
    // The surface we're drawing on
    public Cairo.ImageSurface surface { get; set; }

    // Current drawing state
    public Tool current_tool { get; set; default = Tool.PENCIL; }
    public Halftone current_halftone { get; set; default = Halftone.FULL; }
    public Thickness current_thickness { get; set; default = Thickness.PX_1; }
    public Shape current_shape { get; set; default = Shape.CIRCLE; }

    // Drawing state variables
    private double start_x;
    private double start_y;
    private double last_x;
    private double last_y;
    private const int TILE_SIZE = 12;
    public bool drawing_line { get; set; default = false; }

    // Magic wand state
    public bool has_selection { get; private set; default = false; }
    private bool[] selection_mask;

    // Theme manager reference
    private Theme.Manager theme;

    // Signals
    public signal void changed();

    // Constructor
    public DrawingManager(int width = 600, int height = 400) {
        // Create the surface
        surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, width, height);

        // Initialize selection mask
        selection_mask = new bool[width * height];

        // Get theme manager
        theme = Theme.Manager.get_default();

        // Clear the surface
        clear_surface();
    }

    // Helper methods
    public int get_thickness_size() {
        switch (current_thickness) {
            case Thickness.PX_1:
                return 1;
            case Thickness.PX_3:
                return 3;
            case Thickness.PX_5:
                return 5;
            case Thickness.PX_7:
                return 7;
            default:
                return 1;
        }
    }

    public void clear_surface() {
        // Create a new context for the surface
        var cr = new Cairo.Context(surface);

        // Set background color from theme
        Gdk.RGBA bg_color = theme.get_color("theme_bg");
        cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue);

        // Fill the entire surface
        cr.paint();

        // Clear selection
        clear_selection();

        // Emit changed signal
        changed();
    }

    public void clear_selection() {
        has_selection = false;
        for (int i = 0; i < selection_mask.length; i++) {
            selection_mask[i] = false;
        }

        // Notify that the display needs to be updated
        changed();
    }

    // Drawing methods
    private void apply_tool_settings(Cairo.Context cr) {
        Gdk.RGBA fg_color = theme.get_color("theme_fg");
        Gdk.RGBA bg_color = theme.get_color("theme_bg");

        // Set color based on tool
        if (current_tool == Tool.ERASER) {
            cr.set_source_rgb(bg_color.red, bg_color.green, bg_color.blue); // Background color
        } else {
            cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue); // Foreground color
        }

        // Set line width based on current thickness setting
        cr.set_line_width(get_thickness_size());
    }

    private void draw_shape(Cairo.Context cr, double x, double y) {
        int size = get_thickness_size();
        double offset = size / 2.0;

        switch (current_shape) {
            case Shape.SQUARE:
                // Draw square centered on the point
                cr.rectangle(x - offset, y - offset, size, size);
                cr.fill();
                break;

            case Shape.CIRCLE:
                // For small sizes, use squares for 1px and 3px per the requirements
                if (size <= 3) {
                    cr.rectangle(x - offset, y - offset, size, size);
                    cr.fill();
                } else {
                    // Draw circle centered on the point
                    cr.arc(x, y, offset, 0, 2 * Math.PI);
                    cr.fill();
                }
                break;

            case Shape.DIAMOND:
                if (size == 7) {
                    // Special case for 7px diamond: circle with corner pixels off
                    cr.arc(x, y, 3, 0, 2 * Math.PI);
                    cr.fill();
                } else {
                    // Draw diamond shape
                    cr.move_to(x, y - offset); // Top
                    cr.line_to(x + offset, y); // Right
                    cr.line_to(x, y + offset); // Bottom
                    cr.line_to(x - offset, y); // Left
                    cr.close_path();
                    cr.fill();
                }
                break;
        }
    }

    private void draw_shape_line(Cairo.Context cr, double x1, double y1, double x2, double y2) {
        // Calculate how many steps to take
        double dx = x2 - x1;
        double dy = y2 - y1;
        double distance = Math.sqrt(dx * dx + dy * dy);

        int steps = (int)(distance);
        if (steps < 1) steps = 1;

        for (int i = 0; i <= steps; i++) {
            double t = (double)i / steps;
            double x = x1 + t * dx;
            double y = y1 + t * dy;

            // Only draw if we don't have a selection or this point is in the selection
            if (!has_selection || is_point_in_selection((int)x, (int)y)) {
                // Draw the shape at this point
                draw_shape(cr, x, y);
            }
        }
    }

    public void draw_at_point(double x, double y) {
        var cr = new Cairo.Context(surface);
        cr.set_antialias(Cairo.Antialias.NONE); // No antialiasing

        // Check if we have an active selection
        if (has_selection && current_tool != Tool.MAGIC_WAND) {
            // Only draw if the point is within the selection
            if (is_point_in_selection((int)x, (int)y)) {
                if (current_tool == Tool.HALFTONER) {
                    apply_halftone_pattern(cr, x, y);
                } else {
                    // Apply tool settings
                    apply_tool_settings(cr);

                    // Draw the shape based on current settings
                    draw_shape(cr, x, y);
                }
            }
        } else {
            // No selection, draw normally
            if (current_tool == Tool.HALFTONER) {
                apply_halftone_pattern(cr, x, y);
            } else {
                // Apply tool settings
                apply_tool_settings(cr);

                // Draw the shape based on current settings
                draw_shape(cr, x, y);
            }
        }

        // Emit changed signal
        changed();
    }

    private bool is_point_in_selection(int x, int y) {
        int width = surface.get_width();
        int height = surface.get_height();

        // Bounds check
        if (x < 0 || x >= width || y < 0 || y >= height) {
            return false;
        }

        // Check if this point is in the selection mask
        return selection_mask[y * width + x];
    }

    private void apply_halftone_pattern(Cairo.Context cr, double x, double y) {
        // Round to the nearest multiple of 4 to align with pattern grid
        int grid_x = (int)(x / 4) * 4;
        int grid_y = (int)(y / 4) * 4;
        cr.set_line_width(1);
        cr.set_antialias(Cairo.Antialias.NONE); // No antialiasing

        // Set foreground color
        Gdk.RGBA fg_color = theme.get_color("theme_fg");
        cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);

        switch (current_halftone) {
            case Halftone.FULL:
                // Full drawing - fill the entire cell
                cr.rectangle(grid_x, grid_y, 4, 4);
                cr.fill();
                break;

            case Halftone.CHECKERBOARD:
                // Checkerboard pattern - fill alternating cells
                bool should_fill = ((int)(grid_x / 4) + (int)(grid_y / 4)) % 2 == 0;
                if (should_fill) {
                    cr.rectangle(grid_x, grid_y, 4, 4);
                    cr.fill();
                }
                break;

            case Halftone.CROSS_5X5:
                // 5x5 cross with edge dots and center
                // Center dot
                cr.rectangle(grid_x + 2, grid_y + 2, 1, 1);
                cr.fill();

                // Edge dots (forming a cross pattern)
                cr.rectangle(grid_x, grid_y + 2, 1, 1);     // Left
                cr.rectangle(grid_x + 2, grid_y, 1, 1);     // Top
                cr.rectangle(grid_x + 4, grid_y + 2, 1, 1); // Right
                cr.rectangle(grid_x + 2, grid_y + 4, 1, 1); // Bottom
                cr.fill();
                break;

            case Halftone.CROSS_3X3:
                // 3x3 cross with edge dots and center
                // Center dot
                cr.rectangle(grid_x + 2, grid_y + 2, 1, 1);
                cr.fill();

                // Edge dots (forming a smaller cross pattern)
                cr.rectangle(grid_x + 1, grid_y + 2, 1, 1); // Left
                cr.rectangle(grid_x + 2, grid_y + 1, 1, 1); // Top
                cr.rectangle(grid_x + 3, grid_y + 2, 1, 1); // Right
                cr.rectangle(grid_x + 2, grid_y + 3, 1, 1); // Bottom
                cr.fill();
                break;

            case Halftone.DIAGONAL_RIGHT:
                // Diagonal lines from top-left to bottom-right
                cr.move_to(grid_x, grid_y);
                cr.line_to(grid_x + 4, grid_y + 4);
                cr.stroke();
                break;

            case Halftone.DIAGONAL_LEFT:
                // Diagonal lines from top-right to bottom-left
                cr.move_to(grid_x + 4, grid_y);
                cr.line_to(grid_x, grid_y + 4);
                cr.stroke();
                break;

            case Halftone.VERTICAL_LINES:
                // Vertical lines
                cr.move_to(grid_x + 2, grid_y);
                cr.line_to(grid_x + 2, grid_y + 4);
                cr.stroke();
                break;

            case Halftone.HORIZONTAL_LINES:
                // Horizontal lines
                cr.move_to(grid_x, grid_y + 2);
                cr.line_to(grid_x + 4, grid_y + 2);
                cr.stroke();
                break;
        }
    }

    // Method to draw halftone pattern along a line
    private void draw_halftone_line(double x1, double y1, double x2, double y2) {
        // Convert to grid coordinates (4px grid)
        int start_grid_x = (int)(x1 / 4);
        int start_grid_y = (int)(y1 / 4);
        int end_grid_x = (int)(x2 / 4);
        int end_grid_y = (int)(y2 / 4);

        // Use Bresenham's line algorithm to determine which grid cells to fill
        // This ensures we don't get overlapping patterns
        int dx_grid = (end_grid_x - start_grid_x).abs();
        int dy_grid = (end_grid_y - start_grid_y).abs();
        int sx = start_grid_x < end_grid_x ? 1 : -1;
        int sy = start_grid_y < end_grid_y ? 1 : -1;
        int err = dx_grid - dy_grid;

        int curr_x = start_grid_x;
        int curr_y = start_grid_y;

        var cr = new Cairo.Context(surface);

        while (true) {
            // Only draw if we don't have a selection or this point is in the selection
            if (!has_selection || is_point_in_selection(curr_x * 4, curr_y * 4)) {
                // Draw pattern at current grid position
                apply_halftone_pattern(cr, curr_x * 4, curr_y * 4);
            }

            // Exit condition
            if (curr_x == end_grid_x && curr_y == end_grid_y) break;

            // Calculate next position
            int e2 = 2 * err;
            if (e2 > -dy_grid) {
                err -= dy_grid;
                curr_x += sx;
            }
            if (e2 < dx_grid) {
                err += dx_grid;
                curr_y += sy;
            }
        }
    }

    // Magic Wand functionality
    public void magic_wand_select(double x, double y) {
        // Clear previous selection
        clear_selection();

        // Get the pixel color at the selected point
        int width = surface.get_width();
        int height = surface.get_height();
        int target_x = (int)x;
        int target_y = (int)y;

        // Bounds check
        if (target_x < 0 || target_x >= width || target_y < 0 || target_y >= height) {
            return;
        }

        // Get the target color
        unowned uint8[] data = surface.get_data();
        int stride = surface.get_stride();

        int target_index = target_y * stride + target_x * 4;
        uint8 target_b = data[target_index];
        uint8 target_g = data[target_index + 1];
        uint8 target_r = data[target_index + 2];
        uint8 target_a = data[target_index + 3];

        // Use flood fill algorithm to find matching pixels
        var queue = new Queue<int>();
        queue.push_tail(target_y * width + target_x);
        selection_mask[target_y * width + target_x] = true;

        while (queue.get_length() > 0) {
            int pos = queue.pop_head();
            int y_pos = pos / width;
            int x_pos = pos % width;

            // Check neighboring pixels (4-directional)
            check_pixel(queue, x_pos + 1, y_pos, width, height, stride, data, target_r, target_g, target_b, target_a);
            check_pixel(queue, x_pos - 1, y_pos, width, height, stride, data, target_r, target_g, target_b, target_a);
            check_pixel(queue, x_pos, y_pos + 1, width, height, stride, data, target_r, target_g, target_b, target_a);
            check_pixel(queue, x_pos, y_pos - 1, width, height, stride, data, target_r, target_g, target_b, target_a);
        }

        has_selection = true;
        changed(); // Request redraw to show selection
    }

    private void check_pixel(Queue<int> queue, int x, int y, int width, int height, int stride,
                            uint8[] data, uint8 target_r, uint8 target_g, uint8 target_b, uint8 target_a) {
        // Check bounds
        if (x < 0 || x >= width || y < 0 || y >= height) {
            return;
        }

        // Check if already processed
        int pos = y * width + x;
        if (selection_mask[pos]) {
            return;
        }

        // Check color match
        int index = y * stride + x * 4;
        uint8 b = data[index];
        uint8 g = data[index + 1];
        uint8 r = data[index + 2];
        uint8 a = data[index + 3];

        // If color matches exactly, select this pixel
        if (r == target_r && g == target_g && b == target_b && a == target_a) {
            selection_mask[pos] = true;
            queue.push_tail(pos);
        }
    }

    // Apply the current drawing tool to the selection
    public void apply_to_selection() {
        if (!has_selection) {
            return;
        }

        int width = surface.get_width();
        int height = surface.get_height();
        var cr = new Cairo.Context(surface);
        cr.set_antialias(Cairo.Antialias.NONE);

        // Store current tool and halftone
        Tool original_tool = current_tool;

        // Temporarily set to drawing tool if currently on magic wand
        if (current_tool == Tool.MAGIC_WAND) {
            current_tool = Tool.PENCIL;
        }

        apply_tool_settings(cr);

        // Apply the current tool to each selected pixel
        for (int y = 0; y < height; y++) {
            for (int x = 0; x < width; x++) {
                if (selection_mask[y * width + x]) {
                    // Apply current tool to this pixel
                    if (current_tool == Tool.HALFTONER) {
                        apply_halftone_pattern(cr, x, y);
                    } else {
                        draw_shape(cr, x, y);
                    }
                }
            }
        }

        // Restore original tool
        current_tool = original_tool;

        // Clear selection after applying
        clear_selection();
        changed();
    }

    public void handle_draw_begin(double x, double y) {
        // Store positions
        last_x = x;
        last_y = y;
        start_x = last_x; // Store initial position for line tool
        start_y = last_y;

        if (current_tool == Tool.LINE) {
            drawing_line = true;
        } else if (current_tool == Tool.MAGIC_WAND) {
            // Magic wand selection is handled separately in magic_wand_select()
            return;
        } else {
            draw_at_point(last_x, last_y);
        }
    }

    public void handle_draw_update(double x, double y) {
        // Calculate absolute surface coordinates for current position
        double abs_x = start_x + x;
        double abs_y = start_y + y;

        if (current_tool == Tool.LINE) {
            // Update last position for preview line
            last_x = abs_x;
            last_y = abs_y;
            // Signal that we need a redraw
            changed();
        } else if (current_tool == Tool.MAGIC_WAND) {
            // Magic wand doesn't need drag updates
            return;
        } else if (current_tool == Tool.HALFTONER) {
            // Draw halftone pattern along the path
            draw_halftone_line(last_x, last_y, abs_x, abs_y);

            // Update last position for next segment
            last_x = abs_x;
            last_y = abs_y;

            // Signal that we need a redraw
            changed();
        } else {
            // Draw a line from the last point to the current point
            var cr = new Cairo.Context(surface);
            cr.set_antialias(Cairo.Antialias.NONE); // No antialiasing

            apply_tool_settings(cr);

            // Draw a line between points based on current shape/thickness
            if (current_shape == Shape.SQUARE ||
                (current_shape == Shape.CIRCLE && get_thickness_size() <= 3)) {

                if (!has_selection) {
                    // For square and small circles, draw a simple line
                    cr.move_to(last_x, last_y);
                    cr.line_to(abs_x, abs_y);
                    cr.stroke();
                } else {
                    // Draw a line with selection mask check
                    draw_shape_line(cr, last_x, last_y, abs_x, abs_y);
                }
            } else {
                // For other shapes, draw points at each step along the line
                draw_shape_line(cr, last_x, last_y, abs_x, abs_y);
            }

            // Update last position for next segment
            last_x = abs_x;
            last_y = abs_y;

            // Signal that we need a redraw
            changed();
        }
    }

    public void handle_draw_end(double x, double y) {
        // Calculate absolute position for end point
        double end_x = start_x + x;
        double end_y = start_y + y;

        if (current_tool == Tool.LINE && drawing_line) {
            var cr = new Cairo.Context(surface);
            cr.set_antialias(Cairo.Antialias.NONE); // No antialiasing

            // Apply tool settings
            apply_tool_settings(cr);

            // Draw the final line
            if (current_shape == Shape.SQUARE ||
                (current_shape == Shape.CIRCLE && get_thickness_size() <= 3)) {

                if (!has_selection) {
                    // Draw a straight line for square and small circles
                    cr.move_to(start_x, start_y);
                    cr.line_to(end_x, end_y);
                    cr.stroke();
                } else {
                    // Draw a line with selection mask check
                    draw_shape_line(cr, start_x, start_y, end_x, end_y);
                }
            } else {
                // For more complex shapes, draw points along the line
                draw_shape_line(cr, start_x, start_y, end_x, end_y);
            }

            drawing_line = false;

            // Signal that we need a redraw
            changed();
        }
    }

    public void draw_preview(Cairo.Context cr) {
        // Draw the surface
        cr.set_source_surface(surface, 0, 0);
        cr.paint();

        // Draw preview for line tool if active
        if (current_tool == Tool.LINE && drawing_line) {
            cr.set_antialias(Cairo.Antialias.NONE);

            // Use current theme's foreground color
            Gdk.RGBA fg_color = theme.get_color("theme_fg");
            cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);

            // Set line width based on current thickness
            cr.set_line_width(get_thickness_size());

            // If we have a selection, we need to clip the line preview to it
            if (has_selection) {
                // Create a temporary path for clipping
                int width = surface.get_width();
                int height = surface.get_height();

                // We'll use a temporary surface for drawing the selection mask
                var mask_surface = new Cairo.ImageSurface(Cairo.Format.A8, width, height);
                var mask_cr = new Cairo.Context(mask_surface);

                // Fill the selection area in the mask
                for (int y = 0; y < height; y++) {
                    for (int x = 0; x < width; x++) {
                        if (selection_mask[y * width + x]) {
                            mask_cr.rectangle(x, y, 1, 1);
                        }
                    }
                }
                mask_cr.fill();

                // Use the mask to clip our drawing
                cr.save();
                cr.set_source_surface(mask_surface, 0, 0);
                cr.clip();

                // Draw the preview line (it will be clipped to the selection)
                cr.set_source_rgb(fg_color.red, fg_color.green, fg_color.blue);
                cr.move_to(start_x, start_y);
                cr.line_to(last_x, last_y);
                cr.stroke();

                cr.restore();
            } else {
                // No selection, draw normal preview
                cr.move_to(start_x, start_y);
                cr.line_to(last_x, last_y);
                cr.stroke();
            }
        }

        // Draw selection outline if magic wand is active and we have a selection
        if (has_selection) {
            // Use a dashed line for selection outline
            cr.set_antialias(Cairo.Antialias.NONE);
            Gdk.RGBA sel_color = theme.get_color("theme_selection");
            cr.set_source_rgb(sel_color.red, sel_color.green, sel_color.blue); // selection
            cr.set_line_width(1);

            double[] dashes = {1.0, 1.0};
            cr.set_dash(dashes, 0);

            int width = surface.get_width();
            int height = surface.get_height();

            // Draw outline of the selection
            for (int y = 0; y < height; y++) {
                for (int x = 0; x < width; x++) {
                    if (selection_mask[y * width + x]) {
                        // Check if this is a border pixel (at least one neighbor is not selected)
                        bool is_border = false;

                        // Check four neighbors
                        if (x > 0 && !selection_mask[y * width + (x-1)]) is_border = true;
                        if (x < width-1 && !selection_mask[y * width + (x+1)]) is_border = true;
                        if (y > 0 && !selection_mask[(y-1) * width + x]) is_border = true;
                        if (y < height-1 && !selection_mask[(y+1) * width + x]) is_border = true;

                        if (is_border) {
                            cr.rectangle(x, y, 1, 1);
                        }
                    }
                }
            }

            cr.stroke();
            cr.set_dash(null, 0); // Reset dash pattern
        }
    }

    // Surface handling methods
    public void resize_surface(int tiles_width, int tiles_height) {
        int width = tiles_width * TILE_SIZE;
        int height = tiles_height * TILE_SIZE;

        // Surface is already set by resize_canvas
        // We just need to update the selection mask
        selection_mask = new bool[width * height];
        clear_selection();

        // Signal that we need a redraw
        changed();
    }
}
