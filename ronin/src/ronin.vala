/**
 * Ronin LISP functions and graphics implementation
 * A procedural graphics tool using Lain LISP interpreter
 */
using GLib;
using Gee;

// --- Shape Representation ---
public abstract class RoninShape : Object {
    public abstract void draw(Cairo.Context cr);
    public abstract RoninShape clone();

    public virtual string to_lisp_string() { return "(shape)"; }
}

public class RoninPos : RoninShape {
    public double x { get; set; }
    public double y { get; set; }

    public RoninPos(double x, double y) {
        this.x = x;
        this.y = y;
    }

    public override void draw(Cairo.Context cr) {
        // Nothing to draw for a position
    }

    public override RoninShape clone() {
        return new RoninPos(x, y);
    }

    public override string to_lisp_string() {
        return @"(pos $x $y)";
    }
}

public class RoninLine : RoninShape {
    public double x1 { get; set; }
    public double y1 { get; set; }
    public double x2 { get; set; }
    public double y2 { get; set; }

    public RoninLine(double x1, double y1, double x2, double y2) {
        this.x1 = x1;
        this.y1 = y1;
        this.x2 = x2;
        this.y2 = y2;
    }

    public override void draw(Cairo.Context cr) {
        cr.move_to(x1, y1);
        cr.line_to(x2, y2);
    }

    public override RoninShape clone() {
        return new RoninLine(x1, y1, x2, y2);
    }

    public override string to_lisp_string() {
        return @"(line $x1 $y1 $x2 $y2)";
    }
}

public class RoninRect : RoninShape {
    public double x { get; set; }
    public double y { get; set; }
    public double width { get; set; }
    public double height { get; set; }

    public RoninRect(double x, double y, double width, double height) {
        this.x = x;
        this.y = y;
        this.width = width;
        this.height = height;
    }

    public override void draw(Cairo.Context cr) {
        cr.rectangle(x, y, width, height);
    }

    public override RoninShape clone() {
        return new RoninRect(x, y, width, height);
    }

    public override string to_lisp_string() {
        return @"(rect $x $y $width $height)";
    }
}

public class RoninCircle : RoninShape {
    public double x { get; set; }
    public double y { get; set; }
    public double radius { get; set; }

    public RoninCircle(double x, double y, double radius) {
        this.x = x;
        this.y = y;
        this.radius = radius;
    }

    public override void draw(Cairo.Context cr) {
        cr.arc(x, y, radius, 0, 2 * Math.PI);
    }

    public override RoninShape clone() {
        return new RoninCircle(x, y, radius);
    }

    public override string to_lisp_string() {
        return @"(circle $x $y $radius)";
    }
}

public class RoninEllipse : RoninShape {
    public double x { get; set; }
    public double y { get; set; }
    public double rx { get; set; }
    public double ry { get; set; }

    public RoninEllipse(double x, double y, double rx, double ry) {
        this.x = x;
        this.y = y;
        this.rx = rx;
        this.ry = ry;
    }

    public override void draw(Cairo.Context cr) {
        // Cairo doesn't have a direct ellipse method, so we'll use a matrix transform
        cr.save();
        cr.translate(x, y);
        cr.scale(1, ry / rx);
        cr.arc(0, 0, rx, 0, 2 * Math.PI);
        cr.restore();
    }

    public override RoninShape clone() {
        return new RoninEllipse(x, y, rx, ry);
    }

    public override string to_lisp_string() {
        return @"(ellipse $x $y $rx $ry)";
    }
}

public class RoninArc : RoninShape {
    public double x { get; set; }
    public double y { get; set; }
    public double radius { get; set; }
    public double start_angle { get; set; }
    public double end_angle { get; set; }

    public RoninArc(double x, double y, double radius, double start_angle, double end_angle) {
        this.x = x;
        this.y = y;
        this.radius = radius;
        this.start_angle = start_angle;
        this.end_angle = end_angle;
    }

    public override void draw(Cairo.Context cr) {
        cr.arc(x, y, radius, start_angle, end_angle);
    }

    public override RoninShape clone() {
        return new RoninArc(x, y, radius, start_angle, end_angle);
    }

    public override string to_lisp_string() {
        return @"(arc $x $y $radius $start_angle $end_angle)";
    }
}

public class RoninPoly : RoninShape {
    public Gee.List<RoninPos> points { get; private set; }

    public RoninPoly() {
        points = new ArrayList<RoninPos> ();
    }

    public void add_point(double x, double y) {
        points.add(new RoninPos(x, y));
    }

    public override void draw(Cairo.Context cr) {
        if (points.size == 0)return;

        var first_point = points[0];
        cr.move_to(first_point.x, first_point.y);

        for (int i = 1; i < points.size; i++) {
            var point = points[i];
            cr.line_to(point.x, point.y);
        }
    }

    public override RoninShape clone() {
        var poly = new RoninPoly();
        foreach (var point in points) {
            poly.add_point(point.x, point.y);
        }
        return poly;
    }

    public override string to_lisp_string() {
        var builder = new StringBuilder("(poly");
        foreach (var point in points) {
            builder.append_printf(" %g %g", point.x, point.y);
        }
        builder.append(")");
        return builder.str;
    }
}

public class RoninSize : RoninShape {
    public double width { get; set; }
    public double height { get; set; }

    public RoninSize(double width, double height) {
        this.width = width;
        this.height = height;
    }

    public override void draw(Cairo.Context cr) {
    }

    public override RoninShape clone() {
        return new RoninSize(width, height);
    }

    public override string to_lisp_string() {
        return @"(size $width $height)";
    }
}

public class RoninText : RoninShape {
    public double x { get; set; }
    public double y { get; set; }
    public string text { get; set; }
    public string font { get; set; default = "Log"; }
    public double font_size { get; set; default = 16.0; }
    public string align { get; set; default = "left"; }

    public RoninText(double x, double y, string text, string? font = null, double font_size = 16.0, string align = "left") {
        this.x = x;
        this.y = y;
        this.text = text;
        if (font != null)this.font = font;
        this.font_size = font_size;
        this.align = align;
    }

    public override void draw(Cairo.Context cr) {
        cr.select_font_face(font, Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        cr.set_font_size(font_size);

        Cairo.TextExtents extents;
        cr.text_extents(text, out extents);

        double text_x = x;
        if (align == "center") {
            text_x = x - extents.width / 2;
        } else if (align == "right") {
            text_x = x - extents.width;
        }

        cr.move_to(text_x, y);
        cr.show_text(text);
    }

    public override RoninShape clone() {
        return new RoninText(x, y, text, font, font_size, align);
    }

    public override string to_lisp_string() {
        return @"(text $x $y \"$text\" \"$font\" $font_size \"$align\")";
    }
}

public class RoninSvgPath : RoninShape {
    public double x { get; set; }
    public double y { get; set; }
    public string path_string { get; set; }

    public RoninSvgPath(double x, double y, string path_string) {
        this.x = x;
        this.y = y;
        this.path_string = path_string;
    }

    private void svg_arc_to(Cairo.Context cr,
                            double rx, double ry,
                            double x_axis_rotation,
                            bool large_arc, bool sweep,
                            double x, double y) {
        // Get the current point
        double x1, y1;
        cr.get_current_point(out x1, out y1);

        // Handle degenerate cases
        rx = Math.fabs(rx);
        ry = Math.fabs(ry);

        if (rx < 0.001 || ry < 0.001) {
            // If the radii are too small, just draw a line
            cr.line_to(x, y);
            return;
        }

        // If the endpoints are the same, do nothing
        if (Math.fabs(x1 - x) < 0.001 && Math.fabs(y1 - y) < 0.001) {
            return;
        }

        // Convert rotation from degrees to radians
        double angle_rad = x_axis_rotation * Math.PI / 180.0;

        // Step 1: Transform to origin
        double dx = (x1 - x) / 2.0;
        double dy = (y1 - y) / 2.0;

        // Rotate to align with ellipse axes
        double cos_phi = Math.cos(angle_rad);
        double sin_phi = Math.sin(angle_rad);
        double x1_prime = cos_phi * dx + sin_phi * dy;
        double y1_prime = -sin_phi * dx + cos_phi * dy;

        // Ensure radii are large enough
        double rx_sq = rx * rx;
        double ry_sq = ry * ry;
        double x1_prime_sq = x1_prime * x1_prime;
        double y1_prime_sq = y1_prime * y1_prime;

        double radii_check = x1_prime_sq / rx_sq + y1_prime_sq / ry_sq;
        if (radii_check > 1) {
            rx *= Math.sqrt(radii_check);
            ry *= Math.sqrt(radii_check);
            rx_sq = rx * rx;
            ry_sq = ry * ry;
        }

        // Step 2: Compute center parameters
        double sign = (large_arc == sweep) ? -1.0 : 1.0;
        double sq = ((rx_sq * ry_sq) - (rx_sq * y1_prime_sq) - (ry_sq * x1_prime_sq))
            / ((rx_sq * y1_prime_sq) + (ry_sq * x1_prime_sq));

        sq = (sq < 0) ? 0 : sq;
        double coef = sign * Math.sqrt(sq);
        double cx_prime = coef * ((rx * y1_prime) / ry);
        double cy_prime = coef * -((ry * x1_prime) / rx);

        // Step 3: Transform back to user space
        double cx = cos_phi * cx_prime - sin_phi * cy_prime + (x1 + x) / 2.0;
        double cy = sin_phi * cx_prime + cos_phi * cy_prime + (y1 + y) / 2.0;

        // Step 4: Compute the start and end angles
        double ux = (x1_prime - cx_prime) / rx;
        double uy = (y1_prime - cy_prime) / ry;
        double vx = (-x1_prime - cx_prime) / rx;
        double vy = (-y1_prime - cy_prime) / ry;

        // Initial angle
        double n = Math.sqrt(ux * ux + uy * uy);
        double p = ux; // cos theta
        double theta = Math.acos(p / n);
        if (uy < 0) {
            theta = 2.0 * Math.PI - theta;
        }

        // Delta angle
        double delta = Math.acos((ux * vx + uy * vy) / (n * Math.sqrt(vx * vx + vy * vy)));
        if (ux * vy - uy * vx < 0) {
            delta = 2.0 * Math.PI - delta;
        }

        if (sweep && delta < 0) {
            delta += 2.0 * Math.PI;
        } else if (!sweep && delta > 0) {
            delta -= 2.0 * Math.PI;
        }

        // Draw the arc using Cairo's transformation matrix
        cr.save();
        cr.translate(cx, cy);
        cr.rotate(angle_rad);
        cr.scale(rx, ry);

        if (sweep) {
            cr.arc(0, 0, 1.0, theta, theta + delta);
        } else {
            cr.arc_negative(0, 0, 1.0, theta, theta + delta);
        }

        cr.restore();
    }

    public override void draw(Cairo.Context cr) {
        cr.save();
        cr.translate(x, y);

        // Normalize the path string by adding spaces around commands
        StringBuilder normalized = new StringBuilder();
        foreach (char c in path_string.to_utf8()) {
            if ("MLHVCSQTAZmlhvcsqtaz".contains(c.to_string())) {
                normalized.append(" " + c.to_string() + " ");
            } else if (c == ',') {
                normalized.append(" ");
            } else {
                normalized.append(c.to_string());
            }
        }

        string[] tokens = normalized.str.strip().split_set(" \t\n\r");

        // Parse the tokens
        char current_cmd = ' ';
        double current_x = 0;
        double current_y = 0;

        for (int i = 0; i < tokens.length; i++) {
            string token = tokens[i].strip();
            if (token == "")continue;

            if ("MLHVCSQTAZmlhvcsqtaz".contains(token)) {
                current_cmd = token[0];
            } else {
                try {
                    // Parse numeric arguments based on the current command
                    switch (current_cmd) {
                    case 'M': // Move to
                        current_x = double.parse(token);
                        current_y = double.parse(tokens[++i]);
                        cr.move_to(current_x, current_y);
                        break;

                    case 'L': // Line to
                        current_x = double.parse(token);
                        current_y = double.parse(tokens[++i]);
                        cr.line_to(current_x, current_y);
                        break;

                    case 'A': // Arc
                        double rx = double.parse(token);
                        double ry = double.parse(tokens[++i]);
                        double x_axis_rotation = double.parse(tokens[++i]);
                        bool large_arc = (int.parse(tokens[++i]) != 0);
                        bool sweep = (int.parse(tokens[++i]) != 0);
                        double x = double.parse(tokens[++i]);
                        double y = double.parse(tokens[++i]);

                        // Use our improved arc function
                        svg_arc_to(cr, rx, ry, x_axis_rotation, large_arc, sweep, x, y);

                        current_x = x;
                        current_y = y;
                        break;
                    }
                } catch (Error e) {
                    print("Error parsing path token: %s\n", e.message);
                }
            }
        }

        cr.restore();
    }

    public override RoninShape clone() {
        return new RoninSvgPath(x, y, path_string);
    }

    public override string to_lisp_string() {
        return @"(svg $x $y \"$path_string\")";
    }
}

// --- Drawing Operations ---
public abstract class RoninOperation : Object {
    public abstract void execute(Cairo.Context cr);

    public virtual string to_string() { return "(operation)"; }
}

public class RoninStrokeOperation : RoninOperation {
    private RoninShape shape;
    private Gdk.RGBA color;
    private double width;

    public RoninStrokeOperation(RoninShape shape, Gdk.RGBA color, double width = 1.0) {
        this.shape = shape;
        this.color = color;
        this.width = width;
    }

    public override void execute(Cairo.Context cr) {
        cr.save();
        cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
        cr.set_line_width(width);
        cr.set_antialias(Cairo.Antialias.NONE); // Per user preference
        shape.draw(cr);
        cr.stroke();
        cr.restore();
    }

    public override string to_string() {
        return @"Stroke: $(shape.to_lisp_string())";
    }
}

public class RoninFillOperation : RoninOperation {
    private RoninShape shape;
    private Gdk.RGBA color;

    public RoninFillOperation(RoninShape shape, Gdk.RGBA color) {
        this.shape = shape;
        this.color = color;
    }

    public override void execute(Cairo.Context cr) {
        cr.save();
        cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
        shape.draw(cr);
        cr.fill();
        cr.restore();
    }

    public override string to_string() {
        return @"Fill: $(shape.to_lisp_string())";
    }
}

public class RoninClearOperation : RoninOperation {
    private RoninRect? rect;

    public RoninClearOperation(RoninRect? rect = null) {
        this.rect = rect;
    }

    public override void execute(Cairo.Context cr) {
        cr.save();
        if (rect != null) {
            cr.rectangle(rect.x, rect.y, rect.width, rect.height);
            cr.clip();
        }
        cr.set_source_rgba(1.0, 1.0, 1.0, 1.0);
        cr.set_operator(Cairo.Operator.SOURCE);
        cr.paint();
        cr.restore();
    }

    public override string to_string() {
        if (rect != null) {
            return @"Clear: $(rect.to_lisp_string())";
        }
        return "Clear: (all)";
    }
}

public class RoninGuideOperation : RoninOperation {
    private RoninShape shape;
    private Gdk.RGBA color;

    public RoninGuideOperation(RoninShape shape, Gdk.RGBA color) {
        this.shape = shape;
        this.color = color;
    }

    public override void execute(Cairo.Context cr) {
        cr.save();
        cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
        cr.set_line_width(1.0); // Per user preference
        cr.set_antialias(Cairo.Antialias.NONE); // Per user preference
        shape.draw(cr);
        cr.stroke();
        cr.restore();
    }

    public override string to_string() {
        return @"Guide: $(shape.to_lisp_string())";
    }
}

// Matrix wrapper to store Cairo.Matrix in GLib.Object collections
public class MatrixWrapper : GLib.Object {
    public Cairo.Matrix matrix;

    public MatrixWrapper(Cairo.Matrix m) {
        matrix = m;
    }
}

// --- Main Ronin Context ---
public class RoninContext : Object {
    // Canvas state
    private Cairo.ImageSurface? surface;
    private int canvas_width = 800;
    private int canvas_height = 600;

    // Shapes and operations storage
    private ArrayList<RoninShape> shapes;
    private ArrayList<RoninOperation> operations;
    private ArrayList<RoninOperation> guide_operations;

    // Current state tracking
    public RoninShape? last_shape;
    private double mouse_x = 0;
    private double mouse_y = 0;
    private double current_x = 0;
    private double current_y = 0;
    private string status_text = "Idle.";
    private Cairo.Matrix transform_matrix;
    private ArrayList<MatrixWrapper> transform_stack; // Use MatrixWrapper to store matrices

    // Theme
    private Gdk.RGBA theme_bg = Gdk.RGBA();
    private Gdk.RGBA theme_fg = Gdk.RGBA();
    private Gdk.RGBA theme_accent = Gdk.RGBA();
    private Gdk.RGBA theme_selection = Gdk.RGBA();

    // Files storage
    private HashTable<string, Cairo.ImageSurface> loaded_files;
    public HashTable<string, Gee.List<EventCallback>> event_callbacks;

    private Gee.LinkedList<string> echo_messages;
    private const int MAX_ECHO_MESSAGES = 5;

    public Gtk.Window? window_obj = null;
    public Gtk.Application? app_obj = null;
    private unowned Theme.Manager theme_manager;

    public RoninContext() {
        shapes = new ArrayList<RoninShape> ();
        operations = new ArrayList<RoninOperation> ();
        guide_operations = new ArrayList<RoninOperation> ();
        transform_matrix = Cairo.Matrix.identity();
        transform_stack = new ArrayList<MatrixWrapper> (); // Use MatrixWrapper
        loaded_files = new HashTable<string, Cairo.ImageSurface> (str_hash, str_equal);
        event_callbacks = new HashTable<string, Gee.List<EventCallback>> (str_hash, str_equal);

        // Initialize echo message queue
        echo_messages = new Gee.LinkedList<string> ();

        // Initialize theme colors
        theme_bg.parse("#ffffff");
        theme_fg.parse("#000000");
        theme_accent.parse("#75dec2");
        theme_selection.parse("#ffbb66");

        // Initialize surface
        surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, canvas_width, canvas_height);
        clear_surface();
    }

    private void clear_surface() {
        var cr = new Cairo.Context(surface);
        cr.set_source_rgba(1.0, 1.0, 1.0, 1.0);
        cr.paint();
    }

    private void update_theme_colors() {
        theme_bg = theme_manager.get_color("theme_bg");
        theme_fg = theme_manager.get_color("theme_fg");
        theme_accent = theme_manager.get_color("theme_accent");
        theme_selection = theme_manager.get_color("theme_selection");
    }

    public string[] get_loaded_filenames() {
        string[] filenames = {};

        loaded_files.foreach((filename, surface) => {
            filenames += filename;
        });

        return filenames;
    }

    public void initialize_interop(Gtk.Window window, Gtk.Application app) {
        // Store references to the window and application
        this.window_obj = window;
        this.app_obj = app;

        // Get the theme manager and connect to theme changes
        theme_manager = Theme.Manager.get_default();
        theme_manager.theme_changed.connect(update_theme_colors);

        // Initialize theme colors
        update_theme_colors();
    }

    public RoninSize create_size(double width, double height) {
        var size = new RoninSize(width, height);
        shapes.add(size);
        last_shape = size;
        status_text = @"Created size: $width×$height";
        return size;
    }

    public bool print_to_file(string content, string? filename = null) {
        try {
            // Use a default filename if none provided
            string filepath = filename ?? "output.txt";

            // Write the content to the file
            FileUtils.set_contents(filepath, content);

            status_text = @"Printed to file: $filepath";
            return true;
        } catch (Error e) {
            print("Error writing to file: %s\n", e.message);
            status_text = @"Error writing to file: $(e.message)";
            return false;
        }
    }

    // --- State update methods ---
    public void add_echo_message(string message) {
        echo_messages.insert(0, message);

        // Keep only the most recent messages
        while (echo_messages.index_of(echo_messages.last()) > MAX_ECHO_MESSAGES) {
            echo_messages.remove_at(echo_messages.index_of(echo_messages.last()) - 1);
        }

        status_text = "Echo: " + message;
    }

    public Gee.LinkedList<string> get_echo_messages() {
        return echo_messages;
    }

    public void update_mouse_position(double x, double y) {
        mouse_x = x;
        mouse_y = y;
    }

    public void update_position(double x, double y) {
        current_x = x;
        current_y = y;
        status_text = "Position set: %0.0f, %0.0f".printf(x, y);
    }

    public string get_status_text() {
        return status_text;
    }

    public string get_position_text() {
        return "%0.0f, %0.0f".printf(mouse_x, mouse_y);
    }

    public class EventCallback : Object {
        public LispValue callback_function;

        public EventCallback(LispValue function) {
            callback_function = function;
        }
    }

    public void register_event_callback(string event_name, LispValue callback) {
        print("Registering event callback for '%s'\n", event_name);

        // Get or create the list for this event
        var callbacks = event_callbacks.get(event_name);
        if (callbacks == null) {
            callbacks = new ArrayList<EventCallback> ();
            event_callbacks.set(event_name, callbacks);
        }

        // Add the callback
        callbacks.add(new EventCallback(callback));

        status_text = @"Registered callback for event '$event_name'";
    }

    // Method to trigger an event with arguments
    public void trigger_event(string event_name, ArrayList<LispValue>? args = null) {
        // Get callbacks for this event
        var callbacks = event_callbacks.get(event_name);
        if (callbacks == null || callbacks.size == 0) {
            return;
        }

        // Call each callback
        foreach (var callback in callbacks) {
            try {
                if (callback.callback_function is LispLambda) {
                    var lambda = (LispLambda) callback.callback_function;
                    lambda.call(args, lambda.closure_context);
                } else if (callback.callback_function is LispBuiltinFunc) {
                    var builtin = (LispBuiltinFunc) callback.callback_function;
                    builtin.call(args);
                } else {
                    print("Warning: Event callback is not callable\n");
                }
            } catch (Error e) {
                print("Error in event callback: %s\n", e.message);
            }
        }
    }

    public LispList get_theme_colors() {
        // Create an object (using LispList as a map)
        var theme = new LispList();

        // Add each color
        var bg_pair = new LispList();
        bg_pair.list.add(new LispIdentifier("bg"));
        bg_pair.list.add(rgba_to_lisp_color(theme_bg));
        theme.list.add(bg_pair);

        var fg_pair = new LispList();
        fg_pair.list.add(new LispIdentifier("fg"));
        fg_pair.list.add(rgba_to_lisp_color(theme_fg));
        theme.list.add(fg_pair);

        var accent_pair = new LispList();
        accent_pair.list.add(new LispIdentifier("accent"));
        accent_pair.list.add(rgba_to_lisp_color(theme_accent));
        theme.list.add(accent_pair);

        var selection_pair = new LispList();
        selection_pair.list.add(new LispIdentifier("selection"));
        selection_pair.list.add(rgba_to_lisp_color(theme_selection));
        theme.list.add(selection_pair);

        return theme;
    }

    private LispList rgba_to_lisp_color(Gdk.RGBA color) {
        var color_list = new LispList();
        color_list.list.add(new LispNumber(color.red));
        color_list.list.add(new LispNumber(color.green));
        color_list.list.add(new LispNumber(color.blue));
        color_list.list.add(new LispNumber(color.alpha));
        return color_list;
    }

    public void resize(int width, int height) {
        canvas_width = width;
        canvas_height = height;

        // Create new surface and copy old content
        var new_surface = new Cairo.ImageSurface(Cairo.Format.ARGB32, width, height);
        var cr = new Cairo.Context(new_surface);
        cr.set_source_rgba(1.0, 1.0, 1.0, 1.0);
        cr.paint();
        cr.set_source_surface(surface, 0, 0);
        cr.paint();

        surface = new_surface;
        status_text = @"Canvas resized to $width×$height";

        // Trigger resize event
        var args = new ArrayList<LispValue> ();
        args.add(new LispNumber(width));
        args.add(new LispNumber(height));
        trigger_event("resize", args);
    }

    public RoninRect get_canvas_frame() {
        return new RoninRect(0, 0, canvas_width, canvas_height);
    }

    // --- Shape creation methods ---

    public RoninPos create_pos(double x, double y) {
        var pos = new RoninPos(x, y);
        shapes.add(pos);
        last_shape = pos;
        return pos;
    }

    public RoninLine create_line(double x1, double y1, double x2, double y2) {
        var line = new RoninLine(x1, y1, x2, y2);
        shapes.add(line);
        last_shape = line;
        status_text = @"Created line: $x1,$y1 to $x2,$y2";
        return line;
    }

    public RoninRect create_rect(double x, double y, double width, double height) {
        var rect = new RoninRect(x, y, width, height);
        shapes.add(rect);
        last_shape = rect;
        status_text = @"Created rectangle: $x,$y $width×$height";
        return rect;
    }

    public RoninCircle create_circle(double x, double y, double radius) {
        var circle = new RoninCircle(x, y, radius);
        shapes.add(circle);
        last_shape = circle;
        status_text = @"Created circle: $x,$y radius:$radius";
        return circle;
    }

    public RoninEllipse create_ellipse(double x, double y, double rx, double ry) {
        var ellipse = new RoninEllipse(x, y, rx, ry);
        shapes.add(ellipse);
        last_shape = ellipse;
        status_text = @"Created ellipse: $x,$y $rx×$ry";
        return ellipse;
    }

    public RoninArc create_arc(double x, double y, double radius, double start_angle, double end_angle) {
        var arc = new RoninArc(x, y, radius, start_angle, end_angle);
        shapes.add(arc);
        last_shape = arc;
        status_text = @"Created arc: $x,$y radius:$radius angles:$start_angle to $end_angle";
        return arc;
    }

    // Changed to accept an array of doubles instead of a generic List
    public RoninPoly create_poly(double[] points) {
        if (points.length % 2 != 0) {
            status_text = "Error: Poly requires pairs of coordinates";
            return new RoninPoly();
        }

        var poly = new RoninPoly();
        for (int i = 0; i < points.length; i += 2) {
            poly.add_point(points[i], points[i + 1]);
        }

        shapes.add(poly);
        last_shape = poly;
        status_text = @"Created polygon with $(points.length / 2) points";
        return poly;
    }

    public RoninText create_text(double x, double y, string text, string? font = null, double font_size = 16.0, string align = "left") {
        var text_shape = new RoninText(x, y, text, font, font_size, align);
        shapes.add(text_shape);
        last_shape = text_shape;
        status_text = @"Created text: \"$text\" at $x,$y";
        return text_shape;
    }

    // --- Drawing operation methods ---

    public void clear(RoninRect? rect = null) {
        print("RoninContext.clear() - operations list: %p\n", operations);

        if (operations == null) {
            operations = new ArrayList<RoninOperation> ();
        }

        operations.add(new RoninClearOperation(rect));
        print("Added clear operation\n");
    }

    public void stroke(RoninShape shape, Gdk.RGBA color, double width = 1.0) {
        operations.add(new RoninStrokeOperation(shape, color, width));
        status_text = "Stroked shape";
    }

    public void fill(RoninShape shape, Gdk.RGBA color) {
        operations.add(new RoninFillOperation(shape, color));
        status_text = "Filled shape";
    }

    public void stroke_last_shape(Gdk.RGBA color, double width = 1.0) {
        if (last_shape != null) {
            stroke(last_shape, color, width);
        } else {
            status_text = "No shape to stroke";
        }
    }

    public void fill_last_shape(Gdk.RGBA color) {
        print("fill_last_shape called with color: rgba(%f,%f,%f,%f)\n",
              color.red, color.green, color.blue, color.alpha);

        if (last_shape != null) {
            print("Adding fill operation for shape: %s\n", last_shape.to_lisp_string());
            operations.add(new RoninFillOperation(last_shape, color));
            status_text = "Filled shape";
        } else {
            print("No shape to fill!\n");
            status_text = "No shape to fill";
        }
    }

    public void guide(RoninShape shape, Gdk.RGBA color) {
        guide_operations.add(new RoninGuideOperation(shape, color));
    }

    // --- Transform methods ---
    // Method to get a copy of the current image surface
    public Cairo.ImageSurface get_surface_copy() {
        if (surface == null) {
            return new Cairo.ImageSurface(Cairo.Format.ARGB32, canvas_width, canvas_height);
        }

        var copy = new Cairo.ImageSurface(Cairo.Format.ARGB32,
                                          surface.get_width(),
                                          surface.get_height());
        var cr = new Cairo.Context(copy);
        cr.set_source_surface(surface, 0, 0);
        cr.paint();

        return copy;
    }

    // Method to apply a convolution kernel to the image
    public void apply_convolution(double[,] kernel, RoninRect? rect = null) {
        if (surface == null) {
            print("No surface to apply convolution to\n");
            return;
        }

        // Get surface dimensions
        int width = surface.get_width();
        int height = surface.get_height();

        // Get kernel dimensions
        int kernel_rows = kernel.length[0];
        int kernel_cols = kernel.length[1];

        // Calculate kernel center
        int kernel_center_x = kernel_cols / 2;
        int kernel_center_y = kernel_rows / 2;

        // Get the area to apply the convolution to
        int x = 0;
        int y = 0;
        int w = width;
        int h = height;

        if (rect != null) {
            x = (int) Math.fmax(0, rect.x);
            y = (int) Math.fmax(0, rect.y);
            w = (int) Math.fmin(width - x, rect.width);
            h = (int) Math.fmin(height - y, rect.height);
        }

        // Create a copy of the surface to read from
        var src_surface = get_surface_copy();

        // Lock both surfaces for direct pixel access
        src_surface.flush();
        surface.flush();

        // Get pointers to pixel data
        unowned uchar[] src_data = src_surface.get_data();
        unowned uchar[] dst_data = surface.get_data();

        int stride = src_surface.get_stride();

        // Apply the convolution
        for (int py = y; py < y + h; py++) {
            for (int px = x; px < x + w; px++) {
                // Initialize accumulators for each channel
                double r_acc = 0;
                double g_acc = 0;
                double b_acc = 0;
                double a_acc = 0;

                // Apply kernel
                for (int ky = 0; ky < kernel_rows; ky++) {
                    for (int kx = 0; kx < kernel_cols; kx++) {
                        // Calculate source pixel position
                        int sx = px + (kx - kernel_center_x);
                        int sy = py + (ky - kernel_center_y);

                        // Handle edge pixels with clamping
                        sx = (int) Math.fmin(Math.fmax(0, sx), width - 1);
                        sy = (int) Math.fmin(Math.fmax(0, sy), height - 1);

                        // Get kernel value
                        double k = kernel[ky, kx];

                        // Get pixel value at source position
                        int src_offset = sy * stride + sx * 4;
                        uint8 b_val = src_data[src_offset + 0];
                        uint8 g_val = src_data[src_offset + 1];
                        uint8 r_val = src_data[src_offset + 2];
                        uint8 a_val = src_data[src_offset + 3];

                        // Accumulate weighted values
                        b_acc += k * b_val;
                        g_acc += k * g_val;
                        r_acc += k * r_val;
                        a_acc += k * a_val;
                    }
                }

                // Clamp values to 0-255 range
                int r = (int) Math.fmin(Math.fmax(0, r_acc), 255);
                int g = (int) Math.fmin(Math.fmax(0, g_acc), 255);
                int b = (int) Math.fmin(Math.fmax(0, b_acc), 255);
                int a = (int) Math.fmin(Math.fmax(0, a_acc), 255);

                // Write result to destination
                int dst_offset = py * stride + px * 4;
                dst_data[dst_offset + 0] = (uint8) b;
                dst_data[dst_offset + 1] = (uint8) g;
                dst_data[dst_offset + 2] = (uint8) r;
                dst_data[dst_offset + 3] = (uint8) a;
            }
        }

        // Mark the surface as dirty
        surface.mark_dirty();

        status_text = "Applied convolution filter";
    }

    public void transform_push() {
        // Create a copy of the current transform matrix and wrap it
        var matrix_copy = transform_matrix;
        transform_stack.add(new MatrixWrapper(matrix_copy));
    }

    public void transform_pop() {
        if (transform_stack.size > 0) {
            // Unwrap the matrix from its wrapper
            var wrapper = transform_stack.get(transform_stack.size - 1);
            transform_matrix = wrapper.matrix;
            transform_stack.remove_at(transform_stack.size - 1);
        }
    }

    public void transform_reset() {
        transform_matrix = Cairo.Matrix.identity();
    }

    public void transform_translate(double dx, double dy) {
        var matrix = Cairo.Matrix.identity();
        matrix.translate(dx, dy);
        cairo_matrix_multiply(ref transform_matrix, ref matrix, ref transform_matrix);
    }

    public void transform_scale(double sx, double sy) {
        var matrix = Cairo.Matrix.identity();
        matrix.scale(sx, sy);
        cairo_matrix_multiply(ref transform_matrix, ref matrix, ref transform_matrix);
    }

    public void transform_rotate(double angle) {
        var matrix = Cairo.Matrix.identity();
        matrix.rotate(angle);
        cairo_matrix_multiply(ref transform_matrix, ref matrix, ref transform_matrix);
    }

    // --- File operations ---

    public bool load_image(string path, out Cairo.ImageSurface? img_surface) {
        img_surface = null;
        try {
            if (loaded_files.contains(path)) {
                img_surface = loaded_files.get(path);
                return true;
            }

            img_surface = new Cairo.ImageSurface.from_png(path);
            loaded_files.set(path, img_surface);
            status_text = @"Loaded image: $path";
            return true;
        } catch (Error e) {
            status_text = @"Error loading image: $(e.message)";
            return false;
        }
    }

    public bool import_image(string path, RoninRect? dest_rect = null) {
        Cairo.ImageSurface? img_surface;
        if (!load_image(path, out img_surface) || img_surface == null) {
            return false;
        }

        var cr = new Cairo.Context(surface);
        if (dest_rect != null) {
            cr.save();

            // Scale image to fit destination rectangle
            double scale_x = dest_rect.width / img_surface.get_width();
            double scale_y = dest_rect.height / img_surface.get_height();

            cr.translate(dest_rect.x, dest_rect.y);
            cr.scale(scale_x, scale_y);
            cr.set_source_surface(img_surface, 0, 0);
            cr.paint();

            cr.restore();
        } else {
            // Draw at origin without scaling
            cr.set_source_surface(img_surface, 0, 0);
            cr.paint();
        }

        status_text = @"Imported image: $path";
        return true;
    }

    public bool export_image(string path, string format = "png", int quality = 95) {
        try {
            if (format == "png" || format == "") {
                surface.write_to_png(path);
            } else {
                // For other formats, would need to use a library like GdkPixbuf
                status_text = "Only PNG export is currently supported";
                return false;
            }

            status_text = @"Exported image to: $path";
            return true;
        } catch (Error e) {
            status_text = @"Error exporting image: $(e.message)";
            return false;
        }
    }

    // --- Drawing method ---

    public void draw(Cairo.Context cr, int width, int height) {
        print("RoninContext.draw() called\n");
        print("Operations count: %d, Guides count: %d\n", operations.size, guide_operations.size);

        // Draw main canvas
        cr.save();
        cr.set_source_surface(surface, 0, 0);
        cr.set_source_rgba(theme_bg.red, theme_bg.green, theme_bg.blue, 1.0);
        cr.paint();
        cr.restore();

        // Execute all drawing operations
        if (operations.size > 0) {
            print("Executing %d drawing operations\n", operations.size);
            cr.save();
            foreach (var op in operations) {
                print("  - Executing: %s\n", op.to_string());
                op.execute(cr);
            }
            cr.restore();
        } else {
            print("No drawing operations to execute\n");
        }

        // Draw guide operations if any
        if (guide_operations.size > 0) {
            print("Executing %d guide operations\n", guide_operations.size);
            cr.save();
            foreach (var op in guide_operations) {
                op.execute(cr);
            }
            cr.restore();
        }

        print("RoninContext.draw() completed\n");
    }

    public RoninSvgPath create_svg_path(double x, double y, string path_string) {
        var svg_path = new RoninSvgPath(x, y, path_string);
        shapes.add(svg_path);
        last_shape = svg_path;
        status_text = @"Created SVG path at $x,$y";
        return svg_path;
    }

    // --- Helper for Cairo.Matrix multiplication ---
    private void cairo_matrix_multiply(ref Cairo.Matrix result, ref Cairo.Matrix a, ref Cairo.Matrix b) {
        // Matrix multiplication: result = a * b
        Cairo.Matrix tmp = Cairo.Matrix(
                                        a.xx * b.xx + a.xy * b.yx,
                                        a.xx * b.xy + a.xy * b.yy,
                                        a.yx * b.xx + a.yy * b.yx,
                                        a.yx * b.xy + a.yy * b.yy,
                                        a.x0 * b.xx + a.y0 * b.yx + b.x0,
                                        a.x0 * b.xy + a.y0 * b.yy + b.y0
        );
        result = tmp;
    }
}

/**
 * Container for Ronin LISP functions with context binding
 */
public class RoninFunctions : Object {
    // Strong reference to context
    private RoninContext context;

    private bool valid = false;

    public RoninFunctions(RoninContext ctx) {
        if (ctx == null) {
            error("RoninContext cannot be null");
        }
        this.context = ctx;
        valid = (context != null);
        print("RoninFunctions created with context %p, valid: %s\n", context, valid.to_string());
    }

    // Ensure context is valid before operations
    private void check_context() throws LispError {
        print("Checking context %p, valid: %s\n", context, valid.to_string());
        if (!valid || context == null) {
            print("FATAL ERROR: Invalid context in RoninFunctions\n");
            throw new LispError.RUNTIME("Invalid RoninContext in function");
        }
    }

    // Helper to parse color
    private Gdk.RGBA parse_color(LispValue color_value) throws LispError {
        var rgba = Gdk.RGBA();

        if (color_value is LispString) {
            string color_str = ((LispString) color_value).value.strip();

            // Check for rgb/rgba format
            if (color_str.has_prefix("rgb(") && color_str.has_suffix(")")) {
                // Handle rgb format - remove "rgb(" and ")"
                string content = color_str.substring(4, color_str.length - 1);
                string[] parts = content.split(",");

                if (parts.length != 3) {
                    throw new LispError.TYPE("rgb format requires 3 values: " + color_str);
                }

                try {
                    rgba.red = float.parse(parts[0].strip());
                    rgba.green = float.parse(parts[1].strip());
                    rgba.blue = float.parse(parts[2].strip());
                    rgba.alpha = 1.0f;

                    // Ensure values are in 0-1 range
                    rgba.red = Math.fminf(1, Math.fmaxf(0, (float) rgba.red));
                    rgba.green = Math.fminf(1, Math.fmaxf(0, (float) rgba.green));
                    rgba.blue = Math.fminf(1, Math.fmaxf(0, (float) rgba.blue));
                } catch (Error e) {
                    throw new LispError.TYPE("Invalid rgb component: " + e.message);
                }
            } else if (color_str.has_prefix("rgba(") && color_str.has_suffix(")")) {
                // Handle rgba format - remove "rgba(" and ")"
                string content = color_str.substring(5, color_str.length - 1);
                string[] parts = content.split(",");

                if (parts.length != 4) {
                    throw new LispError.TYPE("rgba format requires 4 values: " + color_str);
                }

                try {
                    rgba.red = float.parse(parts[0].strip());
                    rgba.green = float.parse(parts[1].strip());
                    rgba.blue = float.parse(parts[2].strip());
                    rgba.alpha = float.parse(parts[3].strip());

                    // Ensure values are in 0-1 range
                    rgba.red = Math.fminf(1, Math.fmaxf(0, (float) rgba.red));
                    rgba.green = Math.fminf(1, Math.fmaxf(0, (float) rgba.green));
                    rgba.blue = Math.fminf(1, Math.fmaxf(0, (float) rgba.blue));
                    rgba.alpha = Math.fminf(1, Math.fmaxf(0, (float) rgba.alpha));
                } catch (Error e) {
                    throw new LispError.TYPE("Invalid rgba component: " + e.message);
                }
            } else {
                // Use standard parse for named colors
                if (!rgba.parse(color_str)) {
                    throw new LispError.TYPE("Invalid color string: " + color_str);
                }
            }
        } else if (color_value is LispIdentifier) {
            // Handle case where color is passed as an identifier
            string id_value = ((LispIdentifier) color_value).value;

            // Check for rgb/rgba format
            if (id_value.has_prefix("rgb(") && id_value.has_suffix(")")) {
                // Handle rgb format - extract content between rgb( and )
                string content = id_value.substring(4, id_value.length - 1);
                string[] parts = content.split(",");

                if (parts.length != 3) {
                    throw new LispError.TYPE("rgb format requires 3 values: " + id_value);
                }

                try {
                    rgba.red = float.parse(parts[0].strip());
                    rgba.green = float.parse(parts[1].strip());
                    rgba.blue = float.parse(parts[2].strip());
                    rgba.alpha = 1.0f;

                    // Ensure values are in 0-1 range
                    rgba.red = Math.fminf(1, Math.fmaxf(0, (float) rgba.red));
                    rgba.green = Math.fminf(1, Math.fmaxf(0, (float) rgba.green));
                    rgba.blue = Math.fminf(1, Math.fmaxf(0, (float) rgba.blue));
                } catch (Error e) {
                    throw new LispError.TYPE("Invalid rgb component: " + e.message);
                }
            } else if (id_value.has_prefix("rgba(") && id_value.has_suffix(")")) {
                // Handle rgba format - extract content between rgba( and )
                string content = id_value.substring(5, id_value.length - 1);
                string[] parts = content.split(",");

                if (parts.length != 4) {
                    throw new LispError.TYPE("rgba format requires 4 values: " + id_value);
                }

                try {
                    rgba.red = float.parse(parts[0].strip());
                    rgba.green = float.parse(parts[1].strip());
                    rgba.blue = float.parse(parts[2].strip());
                    rgba.alpha = float.parse(parts[3].strip());

                    // Ensure values are in 0-1 range
                    rgba.red = Math.fminf(1, Math.fmaxf(0, (float) rgba.red));
                    rgba.green = Math.fminf(1, Math.fmaxf(0, (float) rgba.green));
                    rgba.blue = Math.fminf(1, Math.fmaxf(0, (float) rgba.blue));
                    rgba.alpha = Math.fminf(1, Math.fmaxf(0, (float) rgba.alpha));
                } catch (Error e) {
                    throw new LispError.TYPE("Invalid rgba component: " + e.message);
                }
            } else {
                // Try to parse as a named color
                if (!rgba.parse(id_value)) {
                    throw new LispError.TYPE("Invalid color identifier: " + id_value);
                }
            }
        } else if (color_value is LispList) {
            // Original list handling remains unchanged
            var list = ((LispList) color_value).list;
            if (list.size < 3 || list.size > 4) {
                throw new LispError.TYPE("Color list must have 3 or 4 elements (r, g, b, [a])");
            }

            float r = 0, g = 0, b = 0, a = 1;

            if (list[0] is LispNumber)r = (float) ((LispNumber) list[0]).value;
            else throw new LispError.TYPE("Color r component must be a number");

            if (list[1] is LispNumber)g = (float) ((LispNumber) list[1]).value;
            else throw new LispError.TYPE("Color g component must be a number");

            if (list[2] is LispNumber)b = (float) ((LispNumber) list[2]).value;
            else throw new LispError.TYPE("Color b component must be a number");

            if (list.size == 4) {
                if (list[3] is LispNumber)a = (float) ((LispNumber) list[3]).value;
                else throw new LispError.TYPE("Color a component must be a number");
            }

            // Ensure values are in 0-1 range
            r = Math.fminf(1, Math.fmaxf(0, r));
            g = Math.fminf(1, Math.fmaxf(0, g));
            b = Math.fminf(1, Math.fmaxf(0, b));
            a = Math.fminf(1, Math.fmaxf(0, a));

            rgba.red = r;
            rgba.green = g;
            rgba.blue = b;
            rgba.alpha = a;
        } else {
            throw new LispError.TYPE("Invalid color value: " + color_value.to_string());
        }

        return rgba;
    }

    // Helper method to get a number from a LispValue
    private double get_number(LispValue value, string param_name) throws LispError {
        if (value is LispNumber) {
            return ((LispNumber) value).value;
        } else {
            throw new LispError.TYPE(@"$param_name must be a number");
        }
    }

    // ==========================================================
    // LISP Function Implementations
    // ==========================================================

    // --- clear ---
    public LispValue fn_clear(ArrayList<LispValue> args) throws LispError {
        print("fn_clear called on RoninFunctions instance %p\n", this);
        check_context();

        if (args.size == 0) {
            print("Calling context.clear() with no args\n");
            context.clear();
            return new LispNil();
        }

        if (args.size == 1) {
            // Extract rect from args[0]
            // For now, we'll just clear everything
            print("Calling context.clear() with args\n");
            context.clear();
        }

        return new LispNil();
    }

    public LispValue fn_text(ArrayList<LispValue> args) throws LispError {
        print("fn_text called\n");
        check_context();

        if (args.size < 3) {
            throw new LispError.TYPE("text requires at least 3 arguments: x, y, text");
        }

        // Get required parameters
        double x = get_number(args[0], "x");
        double y = get_number(args[1], "y");

        // Get text content
        string text_content;
        if (args[2] is LispString) {
            text_content = ((LispString) args[2]).value;
        } else {
            text_content = args[2].to_string();
        }

        // Get optional parameters
        string? font = null;
        double font_size = 16.0;
        string align = "left";

        if (args.size > 3 && args[3] is LispString) {
            font = ((LispString) args[3]).value;
        }

        if (args.size > 4 && args[4] is LispNumber) {
            font_size = ((LispNumber) args[4]).value;
        }

        if (args.size > 5 && args[5] is LispString) {
            align = ((LispString) args[5]).value;
        }

        print("Creating text: \"%s\" at %f,%f (font: %s, size: %f, align: %s)\n",
              text_content, x, y, font, font_size, align);

        var text = context.create_text(x, y, text_content, font, font_size, align);

        var result = new LispList();
        result.list.add(new LispIdentifier("text"));
        result.list.add(new LispNumber(x));
        result.list.add(new LispNumber(y));
        result.list.add(new LispString(text_content));
        if (font != null)result.list.add(new LispString(font));
        result.list.add(new LispNumber(font_size));
        result.list.add(new LispString(align));

        return result;
    }

    // Implementation of the (poly ...pos) function
    public LispValue fn_poly(ArrayList<LispValue> args) throws LispError {
        print("fn_poly called\n");
        check_context();

        if (args.size < 2 || args.size % 2 != 0) {
            throw new LispError.TYPE("poly requires pairs of coordinates (x1 y1 x2 y2 ...)");
        }

        // Collect all the points
        double[] points = new double[args.size];
        for (int i = 0; i < args.size; i++) {
            if (args[i] is LispNumber) {
                points[i] = ((LispNumber) args[i]).value;
            } else {
                throw new LispError.TYPE("poly coordinates must be numbers");
            }
        }

        var poly = context.create_poly(points);

        // Create LISP representation of the polygon
        var result = new LispList();
        result.list.add(new LispIdentifier("poly"));
        for (int i = 0; i < points.length; i++) {
            result.list.add(new LispNumber(points[i]));
        }

        return result;
    }

    public LispValue fn_get_theme(ArrayList<LispValue> args) throws LispError {
        print("fn_get_theme called\n");
        check_context();

        if (args.size != 0) {
            throw new LispError.TYPE("get-theme doesn't take any arguments");
        }

        // Get the theme colors
        return context.get_theme_colors();
    }

    // --- circle ---
    public LispValue fn_circle(ArrayList<LispValue> args) throws LispError {
        print("fn_circle called\n");
        check_context();

        if (args.size != 3) {
            throw new LispError.TYPE("circle requires 3 arguments: x, y, radius");
        }

        double x = get_number(args[0], "x");
        double y = get_number(args[1], "y");
        double radius = get_number(args[2], "radius");

        print("Creating circle: %f, %f, %f\n", x, y, radius);
        var circle = context.create_circle(x, y, radius);

        var result = new LispList();
        result.list.add(new LispIdentifier("circle"));
        result.list.add(new LispNumber(x));
        result.list.add(new LispNumber(y));
        result.list.add(new LispNumber(radius));

        return result;
    }

    // --- rect ---
    public LispValue fn_rect(ArrayList<LispValue> args) throws LispError {
        print("fn_rect called\n");
        check_context();

        if (args.size != 4) {
            throw new LispError.TYPE("rect requires 4 arguments: x, y, width, height");
        }

        double x = get_number(args[0], "x");
        double y = get_number(args[1], "y");
        double width = get_number(args[2], "width");
        double height = get_number(args[3], "height");

        print("Creating rect: %f, %f, %f, %f\n", x, y, width, height);
        var rect = context.create_rect(x, y, width, height);

        var result = new LispList();
        result.list.add(new LispIdentifier("rect"));
        result.list.add(new LispNumber(x));
        result.list.add(new LispNumber(y));
        result.list.add(new LispNumber(width));
        result.list.add(new LispNumber(height));

        return result;
    }

    public LispValue fn_get_frame(ArrayList<LispValue> args) throws LispError {
        print("fn_get_frame called\n");
        check_context();

        if (args.size != 0) {
            throw new LispError.TYPE("get-frame doesn't take any arguments");
        }

        // Get the canvas frame as a rect
        var frame = context.get_canvas_frame();

        // Return as a LISP rect structure
        var result = new LispList();
        result.list.add(new LispIdentifier("rect"));
        result.list.add(new LispNumber(0));
        result.list.add(new LispNumber(0));
        result.list.add(new LispNumber(frame.width));
        result.list.add(new LispNumber(frame.height));

        return result;
    }

    // --- fill ---
    public LispValue fn_fill(ArrayList<LispValue> args) throws LispError {
        print("fn_fill called\n");
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("fill requires 2 arguments: shape and color");
        }

        // Process shape (assumed to be last created shape if not specified)
        if (!(args[0] is LispList)) {
            throw new LispError.TYPE("fill requires a shape as first argument");
        }

        // Process color
        Gdk.RGBA color = parse_color(args[1]);

        print("Filling last shape with color\n");
        context.fill_last_shape(color);

        return new LispNil();
    }

    // --- stroke ---
    public LispValue fn_stroke(ArrayList<LispValue> args) throws LispError {
        print("fn_stroke called\n");
        check_context();

        if (args.size < 2 || args.size > 3) {
            throw new LispError.TYPE("stroke requires 2 or 3 arguments: shape, color, [thickness]");
        }

        // Process shape (assumed to be last created shape if not specified)
        if (!(args[0] is LispList)) {
            throw new LispError.TYPE("stroke requires a shape as first argument");
        }

        // Process color
        Gdk.RGBA color = parse_color(args[1]);

        // Process width if provided
        double width = 1.0;
        if (args.size == 3) {
            if (args[2] is LispNumber) {
                width = ((LispNumber) args[2]).value;
            } else {
                throw new LispError.TYPE("stroke width must be a number");
            }
        }

        print("Stroking last shape with color and width %f\n", width);
        context.stroke_last_shape(color, width);

        return new LispNil();
    }

    public LispValue fn_svg(ArrayList<LispValue> args) throws LispError {
        print("fn_svg called\n");
        check_context();

        if (args.size != 3) {
            throw new LispError.TYPE("svg requires 3 arguments: x, y, path_string");
        }

        double x = get_number(args[0], "x");
        double y = get_number(args[1], "y");

        string path_string = "";
        if (args[2] is LispString) {
            path_string = ((LispString) args[2]).value;
        } else if (args[2] is LispIdentifier) {
            path_string = ((LispIdentifier) args[2]).value;
        } else {
            throw new LispError.TYPE("svg path must be a string or identifier");
        }

        print("Creating SVG path: %f, %f, %s\n", x, y, path_string);
        var svg_path = context.create_svg_path(x, y, path_string);

        var result = new LispList();
        result.list.add(new LispIdentifier("svg"));
        result.list.add(new LispNumber(x));
        result.list.add(new LispNumber(y));
        result.list.add(new LispString(path_string));

        return result;
    }

    public LispValue fn_resize(ArrayList<LispValue> args) throws LispError {
        print("fn_resize called\n");
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("resize requires 2 arguments: width and height");
        }

        double width = get_number(args[0], "width");
        double height = get_number(args[1], "height");

        print("Resizing canvas to: %f x %f\n", width, height);
        context.resize((int) width, (int) height);

        return new LispNil();
    }

    // Math functions
    public LispValue fn_add(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size < 2) {
            throw new LispError.TYPE("add requires at least 2 arguments");
        }

        double result = 0;
        foreach (var arg in args) {
            if (arg is LispNumber) {
                result += ((LispNumber) arg).value;
            } else {
                throw new LispError.TYPE("add arguments must be numbers");
            }
        }

        return new LispNumber(result);
    }

    public LispValue fn_mul(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size < 2) {
            throw new LispError.TYPE("mul requires at least 2 arguments");
        }

        double result = 1;
        foreach (var arg in args) {
            if (arg is LispNumber) {
                result *= ((LispNumber) arg).value;
            } else {
                throw new LispError.TYPE("mul arguments must be numbers");
            }
        }

        return new LispNumber(result);
    }

    // Implementation of the (guide shape color) function
    public LispValue fn_guide(ArrayList<LispValue> args) throws LispError {
        print("fn_guide called\n");
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("guide requires 2 arguments: shape and color");
        }

        // Process shape
        if (!(args[0] is LispList)) {
            throw new LispError.TYPE("guide requires a shape as first argument");
        }

        // Extract shape
        var shape_list = (LispList) args[0];
        RoninShape? shape = null;

        if (shape_list.list.size > 0 && shape_list.list[0] is LispIdentifier) {
            // The extraction of shape should actually be a utility function
            // but for now we'll do a simplified version
            shape = context.last_shape;
        }

        if (shape == null) {
            throw new LispError.RUNTIME("Invalid shape for guide");
        }

        // Process color
        Gdk.RGBA color = parse_color(args[1]);

        // Add guide operation
        context.guide(shape, color);

        return new LispNil();
    }

    // Implementation of the (rescale ~w ~h) function
    public LispValue fn_rescale(ArrayList<LispValue> args) throws LispError {
        print("fn_rescale called\n");
        check_context();

        if (args.size < 1 || args.size > 2) {
            throw new LispError.TYPE("rescale requires 1 or 2 arguments: width [, height]");
        }

        double scale_x = get_number(args[0], "width");
        double scale_y = args.size > 1 ? get_number(args[1], "height") : scale_x;

        // Get current dimensions
        var frame = context.get_canvas_frame();
        int new_width = (int) (frame.width * scale_x);
        int new_height = (int) (frame.height * scale_y);

        // Resize with new dimensions
        context.resize(new_width, new_height);

        // Return new dimensions as a rect
        var result = new LispList();
        result.list.add(new LispIdentifier("rect"));
        result.list.add(new LispNumber(0));
        result.list.add(new LispNumber(0));
        result.list.add(new LispNumber(new_width));
        result.list.add(new LispNumber(new_height));

        return result;
    }

    public LispValue fn_native(ArrayList<LispValue> args) throws LispError {
        print("fn_native called\n");
        check_context();

        if (args.size > 1) {
            throw new LispError.TYPE("native accepts at most 1 argument: optional object name");
        }

        string? target = null;
        if (args.size == 1) {
            if (args[0] is LispString) {
                target = ((LispString) args[0]).value;
            } else if (args[0] is LispIdentifier) {
                target = ((LispIdentifier) args[0]).value;
            } else {
                throw new LispError.TYPE("Argument to native must be a string or identifier");
            }
        }

        // Create a Lisp object to hold native objects
        var native_obj = new LispList();

        if (target == null || target == "window") {
            // Add window object if available
            if (context.window_obj != null) {
                var window_pair = new LispList();
                window_pair.list.add(new LispIdentifier("window"));
                window_pair.list.add(new LispValaObject(context.window_obj));
                native_obj.list.add(window_pair);
            }
        }

        if (target == null || target == "app" || target == "application") {
            // Add application object if available
            if (context.app_obj != null) {
                var app_pair = new LispList();
                app_pair.list.add(new LispIdentifier("app"));
                app_pair.list.add(new LispValaObject(context.app_obj));
                native_obj.list.add(app_pair);
            }
        }

        if (target == null || target == "context") {
            // Add Ronin context
            var context_pair = new LispList();
            context_pair.list.add(new LispIdentifier("context"));
            context_pair.list.add(new LispValaObject(context));
            native_obj.list.add(context_pair);
        }

        if (native_obj.list.size == 0) {
            print("Warning: No native objects were found for target: %s\n", target ?? "all");
        }

        return native_obj;
    }

    // Implementation of the (orient ~deg) function
    public LispValue fn_orient(ArrayList<LispValue> args) throws LispError {
        print("fn_orient called\n");
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("orient requires 1 argument: degrees");
        }

        double degrees = get_number(args[0], "degrees");

        // Convert to radians
        double radians = degrees * (Math.PI / 180.0);

        // Get canvas center
        var frame = context.get_canvas_frame();
        double center_x = frame.width / 2.0;
        double center_y = frame.height / 2.0;

        // Setup transformation matrix
        context.transform_reset();
        context.transform_translate(center_x, center_y);
        context.transform_rotate(radians);
        context.transform_translate(-center_x, -center_y);

        return new LispNumber(degrees);
    }

    // Implementation of the (mirror) function
    public LispValue fn_mirror(ArrayList<LispValue> args) throws LispError {
        print("fn_mirror called\n");
        check_context();

        // Default is to mirror horizontally (x-axis)
        string axis = "x";

        if (args.size > 0) {
            if (args[0] is LispString) {
                axis = ((LispString) args[0]).value;
            } else if (args[0] is LispIdentifier) {
                axis = ((LispIdentifier) args[0]).value;
            } else {
                throw new LispError.TYPE("mirror axis must be 'x' or 'y'");
            }
        }

        // Get canvas dimensions
        var frame = context.get_canvas_frame();
        double width = frame.width;
        double height = frame.height;

        // Apply mirror transformation
        context.transform_reset();

        if (axis == "x") {
            // Mirror horizontally
            context.transform_translate(width, 0);
            context.transform_scale(-1, 1);
        } else if (axis == "y") {
            // Mirror vertically
            context.transform_translate(0, height);
            context.transform_scale(1, -1);
        } else {
            throw new LispError.RUNTIME("mirror axis must be 'x' or 'y', got: " + axis);
        }

        return new LispString(axis);
    }

    // Implementation of the (gradient line ~colors) function
    public LispValue fn_gradient(ArrayList<LispValue> args) throws LispError {
        print("fn_gradient called\n");
        check_context();

        if (args.size < 2) {
            throw new LispError.TYPE("gradient requires at least 2 arguments: line and colors");
        }

        // Extract line
        if (!(args[0] is LispList)) {
            throw new LispError.TYPE("gradient requires a line as first argument");
        }

        // Parse line coordinates
        var line_list = (LispList) args[0];
        if (line_list.list.size < 5 || !(line_list.list[0] is LispIdentifier)) {
            throw new LispError.TYPE("gradient requires a valid line shape");
        }

        var shape_type = ((LispIdentifier) line_list.list[0]).value;
        if (shape_type != "line") {
            throw new LispError.TYPE("gradient requires a line shape, got: " + shape_type);
        }

        double x1, y1, x2, y2;

        if (line_list.list[1] is LispNumber &&
            line_list.list[2] is LispNumber &&
            line_list.list[3] is LispNumber &&
            line_list.list[4] is LispNumber) {

            x1 = ((LispNumber) line_list.list[1]).value;
            y1 = ((LispNumber) line_list.list[2]).value;
            x2 = ((LispNumber) line_list.list[3]).value;
            y2 = ((LispNumber) line_list.list[4]).value;
        } else {
            throw new LispError.TYPE("Invalid line coordinates for gradient");
        }

        // Get colors
        var colors = new Gdk.RGBA[args.size - 1];
        for (int i = 1; i < args.size; i++) {
            colors[i - 1] = parse_color(args[i]);
        }

        // Create a linear gradient pattern
        var gradient_pattern = new Cairo.Pattern.linear(x1, y1, x2, y2);

        // Add color stops
        if (colors.length == 1) {
            // Special case: solid color
            gradient_pattern.add_color_stop_rgba(0, colors[0].red, colors[0].green, colors[0].blue, colors[0].alpha);
            gradient_pattern.add_color_stop_rgba(1, colors[0].red, colors[0].green, colors[0].blue, colors[0].alpha);
        } else {
            // Multiple colors
            for (int i = 0; i < colors.length; i++) {
                double offset = i / (double) (colors.length - 1);
                gradient_pattern.add_color_stop_rgba(offset,
                                                     colors[i].red,
                                                     colors[i].green,
                                                     colors[i].blue,
                                                     colors[i].alpha);
            }
        }

        // Store gradient in context (this would need to be added to RoninContext)
        // context.set_current_gradient(gradient_pattern);

        // For now, we'll just return the line coordinates
        var result = new LispList();
        result.list.add(new LispIdentifier("gradient"));
        result.list.add(new LispNumber(x1));
        result.list.add(new LispNumber(y1));
        result.list.add(new LispNumber(x2));
        result.list.add(new LispNumber(y2));

        return result;
    }

    public LispValue fn_print(ArrayList<LispValue> args) throws LispError {
        print("fn_print called\n");
        check_context();

        if (args.size < 1) {
            throw new LispError.TYPE("print requires at least 1 argument: content to print");
        }

        // Convert argument to string
        string content = "";

        if (args[0] is LispString) {
            content = ((LispString) args[0]).value;
        } else {
            content = args[0].to_string();
        }

        // Get optional filename from second argument
        string? filename = null;
        if (args.size > 1) {
            if (args[1] is LispString) {
                filename = ((LispString) args[1]).value;
            } else if (args[1] is LispIdentifier) {
                filename = ((LispIdentifier) args[1]).value;
            } else {
                throw new LispError.TYPE("Filename must be a string or identifier");
            }
        }

        // Write to file
        bool success = context.print_to_file(content, filename);

        return new LispBool(success);
    }

    public LispValue fn_size(ArrayList<LispValue> args) throws LispError {
        print("fn_size called\n");
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("size requires 2 arguments: width and height");
        }

        double width = get_number(args[0], "width");
        double height = get_number(args[1], "height");

        print("Creating size: %f × %f\n", width, height);
        var size = context.create_size(width, height);

        var result = new LispList();
        result.list.add(new LispIdentifier("size"));
        result.list.add(new LispNumber(width));
        result.list.add(new LispNumber(height));

        return result;
    }

    public LispValue fn_div(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size < 2) {
            throw new LispError.TYPE("div requires at least 2 arguments");
        }

        if (!(args[0] is LispNumber)) {
            throw new LispError.TYPE("div arguments must be numbers");
        }

        double result = ((LispNumber) args[0]).value;

        for (int i = 1; i < args.size; i++) {
            if (!(args[i] is LispNumber)) {
                throw new LispError.TYPE("div arguments must be numbers");
            }

            double divisor = ((LispNumber) args[i]).value;
            if (Math.fabs(divisor) < 0.000001) {
                throw new LispError.RUNTIME("Division by zero");
            }

            result /= divisor;
        }

        return new LispNumber(result);
    }

    public LispValue fn_sub(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size < 1) {
            throw new LispError.TYPE("sub requires at least 1 argument");
        }

        if (!(args[0] is LispNumber)) {
            throw new LispError.TYPE("sub arguments must be numbers");
        }

        double result = ((LispNumber) args[0]).value;

        if (args.size == 1) {
            // Negate if only one argument
            return new LispNumber(-result);
        }

        for (int i = 1; i < args.size; i++) {
            if (args[i] is LispNumber) {
                result -= ((LispNumber) args[i]).value;
            } else {
                throw new LispError.TYPE("sub arguments must be numbers");
            }
        }

        return new LispNumber(result);
    }

    public LispValue fn_echo(ArrayList<LispValue> args) throws LispError {
        print("fn_echo called\n");
        check_context();

        // Build message from all arguments
        var message = new StringBuilder();
        for (int i = 0; i < args.size; i++) {
            if (i > 0)message.append(" ");
            message.append(args[i].to_string());
        }

        // Add the message to the echo queue
        context.add_echo_message(message.str);

        // Return the message as a string
        return new LispString(message.str);
    }

    public LispValue fn_sin(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("sin requires exactly 1 argument");
        }

        if (!(args[0] is LispNumber)) {
            throw new LispError.TYPE("sin argument must be a number");
        }

        double value = ((LispNumber) args[0]).value;
        return new LispNumber(Math.sin(value));
    }

    public LispValue fn_cos(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("cos requires exactly 1 argument");
        }

        if (!(args[0] is LispNumber)) {
            throw new LispError.TYPE("cos argument must be a number");
        }

        double value = ((LispNumber) args[0]).value;
        return new LispNumber(Math.cos(value));
    }

    // Collection functions
    public LispValue fn_range(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size < 2 || args.size > 3) {
            throw new LispError.TYPE("range requires 2 or 3 arguments: start, end, [step]");
        }

        if (!(args[0] is LispNumber) || !(args[1] is LispNumber)) {
            throw new LispError.TYPE("range arguments must be numbers");
        }

        double start = ((LispNumber) args[0]).value;
        double end = ((LispNumber) args[1]).value;
        double step = (args.size == 3 && args[2] is LispNumber) ?
            ((LispNumber) args[2]).value : 1.0;

        if (Math.fabs(step) < 0.000001) {
            throw new LispError.RUNTIME("range step cannot be 0");
        }

        var result = new LispList();

        if (step > 0) {
            for (double i = start; i <= end; i += step) {
                result.list.add(new LispNumber(i));
            }
        } else {
            for (double i = start; i >= end; i += step) {
                result.list.add(new LispNumber(i));
            }
        }

        return result;
    }

    public LispValue fn_map(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("map requires exactly 2 arguments: function and list");
        }

        if (!(args[0] is LispLambda) && !(args[0] is LispBuiltinFunc)) {
            throw new LispError.TYPE("First argument to map must be a function");
        }

        if (!(args[1] is LispList)) {
            throw new LispError.TYPE("Second argument to map must be a list");
        }

        var func = args[0];
        var input_list = ((LispList) args[1]).list;
        var result = new LispList();

        foreach (var item in input_list) {
            var func_args = new ArrayList<LispValue> ();
            func_args.add(item);

            LispValue map_result;

            if (func is LispLambda) {
                // User-defined lambda
                var lambda = (LispLambda) func;
                map_result = lambda.call(func_args, lambda.closure_context);
            } else {
                // Built-in function
                var builtin = (LispBuiltinFunc) func;
                map_result = builtin.call(func_args);
            }

            result.list.add(map_result);
        }

        return result;
    }

    public LispValue fn_on(ArrayList<LispValue> args) throws LispError {
        print("fn_on called\n");
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("on requires 2 arguments: event name and callback function");
        }

        // Get event name
        string event_name;
        if (args[0] is LispString) {
            event_name = ((LispString) args[0]).value;
        } else if (args[0] is LispIdentifier) {
            event_name = ((LispIdentifier) args[0]).value;
        } else if (args[0] is LispSymbol) {
            event_name = ((LispSymbol) args[0]).value;
        } else {
            throw new LispError.TYPE("Event name must be a string, identifier, or symbol");
        }

        // Check callback
        if (!(args[1] is LispLambda) && !(args[1] is LispBuiltinFunc)) {
            throw new LispError.TYPE("Event callback must be a function");
        }

        print("Registering callback for event '%s'\n", event_name);
        context.register_event_callback(event_name, args[1]);

        return new LispNil();
    }

    // Math functions
    public LispValue fn_mod(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("mod requires 2 arguments");
        }

        double a = get_number(args[0], "first argument");
        double b = get_number(args[1], "second argument");

        if (Math.fabs(b) < 0.000001) {
            throw new LispError.RUNTIME("Modulo by zero");
        }

        return new LispNumber(a % b);
    }

    public LispValue fn_min(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size < 1) {
            throw new LispError.TYPE("min requires at least 1 argument");
        }

        double result = double.MAX;

        foreach (var arg in args) {
            double val = get_number(arg, "min argument");
            result = Math.fmin(result, val);
        }

        return new LispNumber(result);
    }

    public LispValue fn_max(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size < 1) {
            throw new LispError.TYPE("max requires at least 1 argument");
        }

        double result = double.MIN;

        foreach (var arg in args) {
            double val = get_number(arg, "max argument");
            result = Math.fmax(result, val);
        }

        return new LispNumber(result);
    }

    public LispValue fn_sqrt(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("sqrt requires 1 argument");
        }

        double val = get_number(args[0], "argument");
        if (val < 0) {
            throw new LispError.RUNTIME("Cannot take square root of negative number");
        }

        return new LispNumber(Math.sqrt(val));
    }

    public LispValue fn_pow(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("pow requires 2 arguments");
        }

        double bse = get_number(args[0], "base");
        double exp = get_number(args[1], "exponent");

        return new LispNumber(Math.pow(bse, exp));
    }

    public LispValue fn_random(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size == 0) {
            // Return random between 0 and 1
            return new LispNumber(GLib.Random.next_double());
        } else if (args.size == 1) {
            // Return random between 0 and max
            double max = get_number(args[0], "max");
            return new LispNumber(GLib.Random.next_double() * max);
        } else if (args.size == 2) {
            // Return random between min and max
            double min = get_number(args[0], "min");
            double max = get_number(args[1], "max");
            return new LispNumber(min + (GLib.Random.next_double() * (max - min)));
        } else {
            throw new LispError.TYPE("random accepts 0, 1, or 2 arguments");
        }
    }

    // Logic functions
    public LispValue fn_gt(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("gt requires 2 arguments");
        }

        double a = get_number(args[0], "first argument");
        double b = get_number(args[1], "second argument");

        return new LispBool(a > b);
    }

    public LispValue fn_get(ArrayList<LispValue> args) throws LispError {
        print("fn_get called\n");
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("get requires 2 arguments: item and key");
        }

        var item = args[0];
        var key = args[1];

        // Handle different container types
        if (item is LispList) {
            var list = ((LispList) item).list;

            // If key is a number, use it as an index
            if (key is LispNumber) {
                int index = (int) ((LispNumber) key).value;
                if (index >= 0 && index < list.size) {
                    return list[index];
                } else {
                    throw new LispError.RUNTIME("Index out of bounds: " + index.to_string());
                }
            }

            // If list is used as an object/map (contains pairs), search by key name
            // Pairs are assumed to be small lists with the key at index 0
            string key_name = "";
            if (key is LispString) {
                key_name = ((LispString) key).value;
            } else if (key is LispIdentifier) {
                key_name = ((LispIdentifier) key).value;
            } else if (key is LispSymbol) {
                key_name = ((LispSymbol) key).value;
            } else {
                key_name = key.to_string();
            }

            // Search for a pair with matching key
            foreach (var pair in list) {
                if (pair is LispList) {
                    var pair_list = ((LispList) pair).list;
                    if (pair_list.size >= 2) {
                        var pair_key = pair_list[0];
                        string pair_key_name = "";

                        if (pair_key is LispString) {
                            pair_key_name = ((LispString) pair_key).value;
                        } else if (pair_key is LispIdentifier) {
                            pair_key_name = ((LispIdentifier) pair_key).value;
                        } else if (pair_key is LispSymbol) {
                            pair_key_name = ((LispSymbol) pair_key).value;
                        } else {
                            pair_key_name = pair_key.to_string();
                        }

                        if (pair_key_name == key_name) {
                            return pair_list[1]; // Return the value (second item)
                        }
                    }
                }
            }

            throw new LispError.RUNTIME("Key not found: " + key_name);
        }

        // Handle strings (get character at index)
        if (item is LispString && key is LispNumber) {
            string str = ((LispString) item).value;
            int index = (int) ((LispNumber) key).value;

            if (index >= 0 && index < str.length) {
                return new LispString(str.get_char(index).to_string());
            } else {
                throw new LispError.RUNTIME("String index out of bounds: " + index.to_string());
            }
        }

        throw new LispError.TYPE("Cannot get from item type: " + item.to_string());
    }

    public LispValue fn_lt(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("lt requires 2 arguments");
        }

        double a = get_number(args[0], "first argument");
        double b = get_number(args[1], "second argument");

        return new LispBool(a < b);
    }

    public LispValue fn_eq(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("eq requires 2 arguments");
        }

        if (args[0] is LispNumber && args[1] is LispNumber) {
            double a = ((LispNumber) args[0]).value;
            double b = ((LispNumber) args[1]).value;
            return new LispBool(Math.fabs(a - b) < 0.000001);
        } else {
            // Compare string representations for all other types
            return new LispBool(args[0].to_string() == args[1].to_string());
        }
    }

    public LispValue fn_and(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size < 2) {
            throw new LispError.TYPE("and requires at least 2 arguments");
        }

        foreach (var arg in args) {
            bool is_true = true;

            if (arg is LispBool) {
                is_true = ((LispBool) arg).value;
            } else if (arg is LispNil) {
                is_true = false;
            }

            if (!is_true) {
                return new LispBool(false);
            }
        }

        return new LispBool(true);
    }

    public LispValue fn_or(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size < 2) {
            throw new LispError.TYPE("or requires at least 2 arguments");
        }

        foreach (var arg in args) {
            bool is_true = true;

            if (arg is LispBool) {
                is_true = ((LispBool) arg).value;
            } else if (arg is LispNil) {
                is_true = false;
            }

            if (is_true) {
                return new LispBool(true);
            }
        }

        return new LispBool(false);
    }

    public LispValue fn_not(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("not requires 1 argument");
        }

        bool is_true = true;
        var arg = args[0];

        if (arg is LispBool) {
            is_true = ((LispBool) arg).value;
        } else if (arg is LispNil) {
            is_true = false;
        }

        return new LispBool(!is_true);
    }

    // Implementation of the (object ...entries) function
    public LispValue fn_object(ArrayList<LispValue> args) throws LispError {
        print("fn_object called\n");
        check_context();

        var obj = new LispList();

        // Process arguments as key-value pairs
        for (int i = 0; i < args.size; i += 2) {
            if (i + 1 >= args.size) {
                throw new LispError.TYPE("object requires key-value pairs");
            }

            var key = args[i];
            var value = args[i + 1];

            // Create a pair (list with key and value)
            var pair = new LispList();
            pair.list.add(key);
            pair.list.add(value);

            obj.list.add(pair);
        }

        return obj;
    }

    // Implementation of the (set item ...args) function
    public LispValue fn_set(ArrayList<LispValue> args) throws LispError {
        print("fn_set called\n");
        check_context();

        if (args.size < 3 || args.size % 2 != 1) {
            throw new LispError.TYPE("set requires at least 3 arguments: object, key, value, [key2, value2, ...]");
        }

        if (!(args[0] is LispList)) {
            throw new LispError.TYPE("First argument to set must be an object (list)");
        }

        var obj = (LispList) args[0];

        // Process key-value pairs
        for (int i = 1; i < args.size; i += 2) {
            var key = args[i];
            var value = args[i + 1];

            // Find existing key in the object
            bool found = false;
            for (int j = 0; j < obj.list.size; j++) {
                if (obj.list[j] is LispList) {
                    var pair = (LispList) obj.list[j];
                    if (pair.list.size >= 2 && key.to_string() == pair.list[0].to_string()) {
                        // Update existing value
                        pair.list[1] = value;
                        found = true;
                        break;
                    }
                }
            }

            if (!found) {
                // Add new key-value pair
                var pair = new LispList();
                pair.list.add(key);
                pair.list.add(value);
                obj.list.add(pair);
            }
        }

        return obj;
    }

    // Implementation of the (keys item) function
    public LispValue fn_keys(ArrayList<LispValue> args) throws LispError {
        print("fn_keys called\n");
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("keys requires 1 argument: object");
        }

        if (!(args[0] is LispList)) {
            throw new LispError.TYPE("Argument to keys must be an object (list)");
        }

        var obj = (LispList) args[0];
        var result = new LispList();

        // Extract keys from object pairs
        for (int i = 0; i < obj.list.size; i++) {
            if (obj.list[i] is LispList) {
                var pair = (LispList) obj.list[i];
                if (pair.list.size >= 2) {
                    result.list.add(pair.list[0]);
                }
            }
        }

        return result;
    }

    // Implementation of the (values item) function
    public LispValue fn_values(ArrayList<LispValue> args) throws LispError {
        print("fn_values called\n");
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("values requires 1 argument: object");
        }

        if (!(args[0] is LispList)) {
            throw new LispError.TYPE("Argument to values must be an object (list)");
        }

        var obj = (LispList) args[0];
        var result = new LispList();

        // Extract values from object pairs
        for (int i = 0; i < obj.list.size; i++) {
            if (obj.list[i] is LispList) {
                var pair = (LispList) obj.list[i];
                if (pair.list.size >= 2) {
                    result.list.add(pair.list[1]);
                }
            }
        }

        return result;
    }

    // Implementation of the (of h ...keys) function
    public LispValue fn_of(ArrayList<LispValue> args) throws LispError {
        print("fn_of called\n");
        check_context();

        if (args.size < 2) {
            throw new LispError.TYPE("of requires at least 2 arguments: object and keys");
        }

        if (!(args[0] is LispList)) {
            throw new LispError.TYPE("First argument to of must be an object (list)");
        }

        var obj = (LispList) args[0];
        var result = new LispList();

        // Extract requested values
        for (int i = 1; i < args.size; i++) {
            var key = args[i];
            bool found = false;

            // Look for key in object
            for (int j = 0; j < obj.list.size; j++) {
                if (obj.list[j] is LispList) {
                    var pair = (LispList) obj.list[j];
                    if (pair.list.size >= 2 && key.to_string() == pair.list[0].to_string()) {
                        result.list.add(pair.list[1]);
                        found = true;
                        break;
                    }
                }
            }

            if (!found) {
                // Key not found, add nil
                result.list.add(new LispNil());
            }
        }

        return result;
    }

    public LispValue fn_len(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("len requires 1 argument");
        }

        if (args[0] is LispList) {
            return new LispNumber(((LispList) args[0]).list.size);
        } else if (args[0] is LispString) {
            return new LispNumber(((LispString) args[0]).value.length);
        } else {
            throw new LispError.TYPE("len requires a list or string");
        }
    }

    public LispValue fn_color(ArrayList<LispValue> args) throws LispError {
        print("fn_color called\n");
        check_context();

        if (args.size < 3 || args.size > 4) {
            throw new LispError.TYPE("color requires 3 or 4 arguments: r, g, b, [a]");
        }

        // Get RGB values (between 0-1)
        double r = get_number(args[0], "r");
        double g = get_number(args[1], "g");
        double b = get_number(args[2], "b");
        double a = 1.0; // Default alpha

        // Get optional alpha
        if (args.size == 4) {
            a = get_number(args[3], "a");
        }

        // Clamp values to 0-1 range
        r = Math.fmax(0.0, Math.fmin(1.0, r));
        g = Math.fmax(0.0, Math.fmin(1.0, g));
        b = Math.fmax(0.0, Math.fmin(1.0, b));
        a = Math.fmax(0.0, Math.fmin(1.0, a));

        // Create an RGBA structure
        Gdk.RGBA rgba = Gdk.RGBA();
        rgba.red = (float) r;
        rgba.green = (float) g;
        rgba.blue = (float) b;
        rgba.alpha = (float) a;

        // Create LISP list to represent the color
        var result = new LispList();
        result.list.add(new LispIdentifier("color"));
        result.list.add(new LispNumber(r));
        result.list.add(new LispNumber(g));
        result.list.add(new LispNumber(b));
        if (a < 1.0) {
            result.list.add(new LispNumber(a));
        }

        return result;
    }

    private void hsl_to_rgb(double h, double s, double l, out double r, out double g, out double b) {
        // Normalize h to be between 0 and 1
        h = h % 360.0;
        if (h < 0)h += 360.0;
        h /= 360.0;

        r = l;
        g = l;
        b = l;

        if (s > 0.0) {
            double q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
            double p = 2.0 * l - q;

            r = hue_to_rgb(p, q, h + 1.0 / 3.0);
            g = hue_to_rgb(p, q, h);
            b = hue_to_rgb(p, q, h - 1.0 / 3.0);
        }
    }

    private double hue_to_rgb(double p, double q, double t) {
        if (t < 0)t += 1.0;
        if (t > 1)t -= 1.0;
        if (t < 1.0 / 6.0)return p + (q - p) * 6.0 * t;
        if (t < 1.0 / 2.0)return q;
        if (t < 2.0 / 3.0)return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
        return p;
    }

    public LispValue fn_hsl(ArrayList<LispValue> args) throws LispError {
        print("fn_hsl called\n");
        check_context();

        if (args.size < 3 || args.size > 4) {
            throw new LispError.TYPE("hsl requires 3 or 4 arguments: h, s, l, [a]");
        }

        // Get HSL values
        double h = get_number(args[0], "h"); // Hue in degrees (0-360)
        double s = get_number(args[1], "s"); // Saturation (0-1)
        double l = get_number(args[2], "l"); // Lightness (0-1)
        double a = 1.0; // Default alpha

        // Get optional alpha
        if (args.size == 4) {
            a = get_number(args[3], "a");
        }

        // Clamp saturation, lightness, and alpha to 0-1 range
        s = Math.fmax(0.0, Math.fmin(1.0, s));
        l = Math.fmax(0.0, Math.fmin(1.0, l));
        a = Math.fmax(0.0, Math.fmin(1.0, a));

        // Convert HSL to RGB
        double r, g, b;
        hsl_to_rgb(h, s, l, out r, out g, out b);

        // Create an RGBA structure
        Gdk.RGBA rgba = Gdk.RGBA();
        rgba.red = (float) r;
        rgba.green = (float) g;
        rgba.blue = (float) b;
        rgba.alpha = (float) a;

        // Create LISP list to represent the color
        var result = new LispList();
        result.list.add(new LispIdentifier("hsl"));
        result.list.add(new LispNumber(h));
        result.list.add(new LispNumber(s));
        result.list.add(new LispNumber(l));
        if (a < 1.0) {
            result.list.add(new LispNumber(a));
        }

        return result;
    }

    public LispValue fn_first(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("first requires 1 argument");
        }

        if (args[0] is LispList) {
            var list = ((LispList) args[0]).list;
            if (list.size > 0) {
                return list[0];
            } else {
                return new LispNil();
            }
        } else {
            throw new LispError.TYPE("first requires a list");
        }
    }

    public LispValue fn_last(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("last requires 1 argument");
        }

        if (args[0] is LispList) {
            var list = ((LispList) args[0]).list;
            if (list.size > 0) {
                return list[list.size - 1];
            } else {
                return new LispNil();
            }
        } else {
            throw new LispError.TYPE("last requires a list");
        }
    }

    public LispValue fn_list(ArrayList<LispValue> args) throws LispError {
        print("fn_list called\n");
        check_context();

        // Create a new list with all arguments
        var result = new LispList();
        foreach (var arg in args) {
            result.list.add(arg);
        }

        return result;
    }

    public LispValue fn_rest(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("rest requires 1 argument");
        }

        if (args[0] is LispList) {
            var input_list = ((LispList) args[0]).list;
            var result = new LispList();

            for (int i = 1; i < input_list.size; i++) {
                result.list.add(input_list[i]);
            }

            return result;
        } else {
            throw new LispError.TYPE("rest requires a list");
        }
    }

    public LispValue fn_filter(ArrayList<LispValue> args) throws LispError {
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("filter requires 2 arguments: list and function");
        }

        if (!(args[0] is LispList)) {
            throw new LispError.TYPE("First argument to filter must be a list");
        }

        if (!(args[1] is LispLambda) && !(args[1] is LispBuiltinFunc)) {
            throw new LispError.TYPE("Second argument to filter must be a function");
        }

        var input_list = ((LispList) args[0]).list;
        var func = args[1];
        var result = new LispList();

        foreach (var item in input_list) {
            var func_args = new ArrayList<LispValue> ();
            func_args.add(item);

            LispValue filter_result;

            if (func is LispLambda) {
                var lambda = (LispLambda) func;
                filter_result = lambda.call(func_args, lambda.closure_context);
            } else {
                var builtin = (LispBuiltinFunc) func;
                filter_result = builtin.call(func_args);
            }

            // Keep item if function returns true
            bool keep = true;

            if (filter_result is LispBool) {
                keep = ((LispBool) filter_result).value;
            } else if (filter_result is LispNil) {
                keep = false;
            }

            if (keep) {
                result.list.add(item);
            }
        }

        return result;
    }

    public LispValue fn_time(ArrayList<LispValue> args) throws LispError {
        print("fn_time called\n");
        check_context();

        // Default rate is 1 (milliseconds)
        double rate = 1.0;

        if (args.size == 1) {
            rate = get_number(args[0], "rate");
        } else if (args.size > 1) {
            throw new LispError.TYPE("time accepts 0 or 1 arguments (rate)");
        }

        // Get current time in microseconds and convert to milliseconds
        int64 time_us = GLib.get_monotonic_time();
        double time_ms = time_us / 1000.0;

        // Apply rate factor
        double result = time_ms * rate;

        return new LispNumber(result);
    }

    public LispValue fn_debug(ArrayList<LispValue> args) throws LispError {
        print("fn_debug called\n");
        check_context();

        // Just print all arguments to the console
        for (int i = 0; i < args.size; i++) {
            print("DEBUG: %s\n", args[i].to_string());
        }

        // Return the last argument or nil if none
        if (args.size > 0) {
            return args[args.size - 1];
        } else {
            return new LispNil();
        }
    }

    /**
     * Implementation of the file operations for Ronin
     */

    // Add to the RoninFunctions class

    // Implementation of the (open name ~scale) function
    public LispValue fn_open(ArrayList<LispValue> args) throws LispError {
        print("fn_open called\n");
        check_context();

        if (args.size < 1) {
            throw new LispError.TYPE("open requires at least 1 argument: filename");
        }

        // Get filename
        string filename;
        if (args[0] is LispString) {
            filename = ((LispString) args[0]).value;
        } else if (args[0] is LispIdentifier) {
            filename = ((LispIdentifier) args[0]).value;
        } else {
            throw new LispError.TYPE("Filename must be a string or identifier");
        }

        // Get optional scale parameter
        double scale = 1.0;
        if (args.size > 1 && args[1] is LispNumber) {
            scale = ((LispNumber) args[1]).value;
        }

        // Load the image
        Cairo.ImageSurface? img_surface = null;
        bool success = context.load_image(filename, out img_surface);

        if (!success || img_surface == null) {
            throw new LispError.RUNTIME("Failed to open image: " + filename);
        }

        // Create a LISP representation of the loaded image
        var result = new LispList();
        result.list.add(new LispIdentifier("image"));
        result.list.add(new LispString(filename));
        result.list.add(new LispNumber(img_surface.get_width()));
        result.list.add(new LispNumber(img_surface.get_height()));

        return result;
    }

    // Implementation of the (import name ~shape) function
    public LispValue fn_import(ArrayList<LispValue> args) throws LispError {
        print("fn_import called\n");
        check_context();

        if (args.size < 1) {
            throw new LispError.TYPE("import requires at least 1 argument: filename");
        }

        // Get filename
        string filename;
        if (args[0] is LispString) {
            filename = ((LispString) args[0]).value;
        } else if (args[0] is LispIdentifier) {
            filename = ((LispIdentifier) args[0]).value;
        } else {
            throw new LispError.TYPE("Filename must be a string or identifier");
        }

        // Get optional destination rectangle
        RoninRect? dest_rect = null;
        if (args.size > 1) {
            if (args[1] is LispList) {
                var shape_list = (LispList) args[1];
                if (shape_list.list.size > 0 && shape_list.list[0] is LispIdentifier) {
                    var shape_id = (LispIdentifier) shape_list.list[0];

                    // Check if it's a rect
                    if (shape_id.value == "rect" && shape_list.list.size >= 5) {
                        if (shape_list.list[1] is LispNumber &&
                            shape_list.list[2] is LispNumber &&
                            shape_list.list[3] is LispNumber &&
                            shape_list.list[4] is LispNumber) {

                            double x = ((LispNumber) shape_list.list[1]).value;
                            double y = ((LispNumber) shape_list.list[2]).value;
                            double width = ((LispNumber) shape_list.list[3]).value;
                            double height = ((LispNumber) shape_list.list[4]).value;

                            dest_rect = new RoninRect(x, y, width, height);
                        }
                    }
                    // Check if it's a position
                    else if (shape_id.value == "pos" && shape_list.list.size >= 3) {
                        if (shape_list.list[1] is LispNumber &&
                            shape_list.list[2] is LispNumber) {

                            double x = ((LispNumber) shape_list.list[1]).value;
                            double y = ((LispNumber) shape_list.list[2]).value;

                            // For pos, we'll import at original size
                            dest_rect = new RoninRect(x, y, 0, 0); // Size will be determined by image
                        }
                    }
                }
            }
        }

        // Import the image
        bool success = context.import_image(filename, dest_rect);

        if (!success) {
            throw new LispError.RUNTIME("Failed to import image: " + filename);
        }

        // Return success
        return new LispBool(true);
    }

    // Implementation of the (export ~format ~quality) function
    public LispValue fn_export(ArrayList<LispValue> args) throws LispError {
        print("fn_export called\n");
        check_context();

        // Default values
        string filename = "output.png";
        string format = "png";
        int quality = 95;

        // Get optional filename
        if (args.size > 0) {
            if (args[0] is LispString) {
                filename = ((LispString) args[0]).value;
            } else if (args[0] is LispIdentifier) {
                filename = ((LispIdentifier) args[0]).value;
            }
        }

        // Get optional format
        if (args.size > 1) {
            if (args[1] is LispString) {
                format = ((LispString) args[1]).value;
            } else if (args[1] is LispIdentifier) {
                format = ((LispIdentifier) args[1]).value;
            }
        }

        // Get optional quality
        if (args.size > 2 && args[2] is LispNumber) {
            quality = (int) ((LispNumber) args[2]).value;
        }

        // Export the image
        bool success = context.export_image(filename, format, quality);

        if (!success) {
            throw new LispError.RUNTIME("Failed to export image to: " + filename);
        }

        // Return the filename
        return new LispString(filename);
    }

    // Implementation of the (files) function
    public LispValue fn_files(ArrayList<LispValue> args) throws LispError {
        print("fn_files called\n");
        check_context();

        // Get the list of loaded files
        string[] filenames = context.get_loaded_filenames();

        // Create a LISP list of filenames
        var result = new LispList();
        foreach (var filename in filenames) {
            result.list.add(new LispString(filename));
        }

        return result;
    }

    // Implementation of the (rad degrees) function - Convert degrees to radians
    public LispValue fn_rad(ArrayList<LispValue> args) throws LispError {
        print("fn_rad called\n");
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("rad requires 1 argument: degrees");
        }

        double degrees = get_number(args[0], "degrees");
        double radians = degrees * (Math.PI / 180.0);

        return new LispNumber(radians);
    }

    // Implementation of the (deg radians) function - Convert radians to degrees
    public LispValue fn_deg(ArrayList<LispValue> args) throws LispError {
        print("fn_deg called\n");
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("deg requires 1 argument: radians");
        }

        double radians = get_number(args[0], "radians");
        double degrees = radians * (180.0 / Math.PI);

        return new LispNumber(degrees);
    }

    // Implementation of the (clamp val min max) function
    public LispValue fn_clamp(ArrayList<LispValue> args) throws LispError {
        print("fn_clamp called\n");
        check_context();

        if (args.size != 3) {
            throw new LispError.TYPE("clamp requires 3 arguments: value, min, max");
        }

        double value = get_number(args[0], "value");
        double min = get_number(args[1], "min");
        double max = get_number(args[2], "max");

        if (min > max) {
            throw new LispError.RUNTIME("clamp: min must be less than or equal to max");
        }

        double result = Math.fmax(min, Math.fmin(max, value));

        return new LispNumber(result);
    }

    // Implementation of the (step val step) function
    // This is a step function that returns 0.0 if x < edge, and 1.0 otherwise
    public LispValue fn_step(ArrayList<LispValue> args) throws LispError {
        print("fn_step called\n");
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("step requires 2 arguments: edge, x");
        }

        double edge = get_number(args[0], "edge");
        double x = get_number(args[1], "x");

        double result = x < edge ? 0.0 : 1.0;

        return new LispNumber(result);
    }

    // Implementation of the (ceil) function
    public LispValue fn_ceil(ArrayList<LispValue> args) throws LispError {
        print("fn_ceil called\n");
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("ceil requires 1 argument: value");
        }

        double value = get_number(args[0], "value");
        double result = Math.ceil(value);

        return new LispNumber(result);
    }

    // Implementation of the (floor) function
    public LispValue fn_floor(ArrayList<LispValue> args) throws LispError {
        print("fn_floor called\n");
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("floor requires 1 argument: value");
        }

        double value = get_number(args[0], "value");
        double result = Math.floor(value);

        return new LispNumber(result);
    }

    // Implementation of the (round) function
    public LispValue fn_round(ArrayList<LispValue> args) throws LispError {
        print("fn_round called\n");
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("round requires 1 argument: value");
        }

        double value = get_number(args[0], "value");
        double result = Math.round(value);

        return new LispNumber(result);
    }

    // Implementation of the (log) function - Natural logarithm
    public LispValue fn_log(ArrayList<LispValue> args) throws LispError {
        print("fn_log called\n");
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("log requires 1 argument: value");
        }

        double value = get_number(args[0], "value");

        if (value <= 0) {
            throw new LispError.RUNTIME("log: value must be positive");
        }

        double result = Math.log(value);

        return new LispNumber(result);
    }

    /**
     * Implementation of the remaining functions for Ronin
     */

    // Add to the RoninFunctions class

    // Implementation of the (while fn action) function
    public LispValue fn_while(ArrayList<LispValue> args) throws LispError {
        print("fn_while called\n");
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("while requires 2 arguments: condition function and action function");
        }

        // Get the condition and action functions
        if (!(args[0] is LispLambda) && !(args[0] is LispBuiltinFunc)) {
            throw new LispError.TYPE("First argument to while must be a function");
        }

        if (!(args[1] is LispLambda) && !(args[1] is LispBuiltinFunc)) {
            throw new LispError.TYPE("Second argument to while must be a function");
        }

        var condition_fn = args[0];
        var action_fn = args[1];

        // Set maximum iteration limit to prevent infinite loops
        const int MAX_ITERATIONS = 10000;
        int iteration_count = 0;

        // Execute the while loop
        LispValue? last_result = null;
        bool condition_true = true;

        while (condition_true && iteration_count < MAX_ITERATIONS) {
            // Evaluate the condition function
            LispValue condition_result;
            if (condition_fn is LispLambda) {
                var lambda = (LispLambda) condition_fn;
                condition_result = lambda.call(new ArrayList<LispValue> (), lambda.closure_context);
            } else {
                var builtin = (LispBuiltinFunc) condition_fn;
                condition_result = builtin.call(new ArrayList<LispValue> ());
            }

            // Check if condition is true
            condition_true = true;
            if (condition_result is LispBool) {
                condition_true = ((LispBool) condition_result).value;
            } else if (condition_result is LispNil) {
                condition_true = false;
            }

            // If condition is false, exit the loop
            if (!condition_true) {
                break;
            }

            // Execute the action function
            if (action_fn is LispLambda) {
                var lambda = (LispLambda) action_fn;
                last_result = lambda.call(new ArrayList<LispValue> (), lambda.closure_context);
            } else {
                var builtin = (LispBuiltinFunc) action_fn;
                last_result = builtin.call(new ArrayList<LispValue> ());
            }

            // Increment iteration count
            iteration_count++;
        }

        // Check if we hit the maximum iteration limit
        if (iteration_count >= MAX_ITERATIONS) {
            throw new LispError.RUNTIME("Maximum iteration limit reached in while loop");
        }

        // Return the last result of the action function or nil
        return last_result ?? new LispNil();
    }

    // Implementation of the (reduce arr fn acc) function
    public LispValue fn_reduce(ArrayList<LispValue> args) throws LispError {
        print("fn_reduce called\n");
        check_context();

        if (args.size != 3) {
            throw new LispError.TYPE("reduce requires 3 arguments: array, function, and accumulator");
        }

        // Get the array
        if (!(args[0] is LispList)) {
            throw new LispError.TYPE("First argument to reduce must be a list");
        }

        var input_list = ((LispList) args[0]).list;

        // Get the function
        if (!(args[1] is LispLambda) && !(args[1] is LispBuiltinFunc)) {
            throw new LispError.TYPE("Second argument to reduce must be a function");
        }

        var func = args[1];

        // Get the initial accumulator value
        var accumulator = args[2];

        // Perform the reduction
        foreach (var item in input_list) {
            var func_args = new ArrayList<LispValue> ();
            func_args.add(accumulator);
            func_args.add(item);

            if (func is LispLambda) {
                var lambda = (LispLambda) func;
                accumulator = lambda.call(func_args, lambda.closure_context);
            } else {
                var builtin = (LispBuiltinFunc) func;
                accumulator = builtin.call(func_args);
            }
        }

        return accumulator;
    }

    // Implementation of the (convolve kernel ~rect) function
    // Implementation of the (convolve kernel ~rect) function
    public LispValue fn_convolve(ArrayList<LispValue> args) throws LispError {
        print("fn_convolve called\n");
        check_context();

        if (args.size < 1 || args.size > 2) {
            throw new LispError.TYPE("convolve requires 1 or 2 arguments: kernel and optional rect");
        }

        // Get the kernel
        if (!(args[0] is LispList)) {
            throw new LispError.TYPE("First argument to convolve must be a kernel matrix (list of lists)");
        }

        var kernel_list = ((LispList) args[0]).list;

        // Validate kernel structure (must be a list of lists of numbers)
        int rows = kernel_list.size;
        if (rows == 0) {
            throw new LispError.TYPE("Kernel cannot be empty");
        }

        if (!(kernel_list[0] is LispList)) {
            throw new LispError.TYPE("Kernel must be a list of lists of numbers");
        }

        int cols = ((LispList) kernel_list[0]).list.size;
        if (cols == 0) {
            throw new LispError.TYPE("Kernel rows cannot be empty");
        }

        // Create a properly-sized 2D array using Vala's multidimensional array syntax
        var kernel = new double[rows, cols];

        // Fill the kernel with values from the LISP lists
        for (int i = 0; i < rows; i++) {
            if (!(kernel_list[i] is LispList)) {
                throw new LispError.TYPE("Kernel must be a list of lists of numbers");
            }

            var row = ((LispList) kernel_list[i]).list;

            if (row.size != cols) {
                throw new LispError.TYPE("All kernel rows must have the same length");
            }

            for (int j = 0; j < cols; j++) {
                if (!(row[j] is LispNumber)) {
                    throw new LispError.TYPE("Kernel elements must be numbers");
                }

                kernel[i, j] = ((LispNumber) row[j]).value;
            }
        }

        // Get the optional rect
        RoninRect? rect = null;
        if (args.size == 2) {
            if (!(args[1] is LispList)) {
                throw new LispError.TYPE("Second argument to convolve must be a rect");
            }

            var rect_list = (LispList) args[1];
            if (rect_list.list.size < 5) {
                throw new LispError.TYPE("Invalid rect for convolve");
            }

            if (!(rect_list.list[0] is LispIdentifier) ||
                ((LispIdentifier) rect_list.list[0]).value != "rect") {
                throw new LispError.TYPE("Second argument must be a rect shape");
            }

            double x = get_number(rect_list.list[1], "x");
            double y = get_number(rect_list.list[2], "y");
            double width = get_number(rect_list.list[3], "width");
            double height = get_number(rect_list.list[4], "height");

            rect = new RoninRect(x, y, width, height);
        }

        // Apply the convolution to the image
        print(@"Applying convolution: Kernel size $(rows)x$(cols)\n");
        context.apply_convolution(kernel, rect);

        // Return a symbolic representation of the operation
        var result = new LispList();
        result.list.add(new LispIdentifier("convolve"));
        result.list.add(args[0]);
        if (rect != null) {
            var rect_list = new LispList();
            rect_list.list.add(new LispIdentifier("rect"));
            rect_list.list.add(new LispNumber(rect.x));
            rect_list.list.add(new LispNumber(rect.y));
            rect_list.list.add(new LispNumber(rect.width));
            rect_list.list.add(new LispNumber(rect.height));
            result.list.add(rect_list);
        }

        return result;
    }

    // Implementation of the (sq a) function - Square a value
    public LispValue fn_sq(ArrayList<LispValue> args) throws LispError {
        print("fn_sq called\n");
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("sq requires 1 argument: value");
        }

        double value = get_number(args[0], "value");
        double result = value * value;

        return new LispNumber(result);
    }

    // Implementation of the (concat ...items) function
    public LispValue fn_concat(ArrayList<LispValue> args) throws LispError {
        print("fn_concat called\n");
        check_context();

        if (args.size < 1) {
            throw new LispError.TYPE("concat requires at least 1 argument");
        }

        var builder = new StringBuilder();

        foreach (var arg in args) {
            if (arg is LispString) {
                builder.append(((LispString) arg).value);
            } else {
                builder.append(arg.to_string());
            }
        }

        return new LispString(builder.str);
    }

    // Implementation of the (split string char) function
    public LispValue fn_split(ArrayList<LispValue> args) throws LispError {
        print("fn_split called\n");
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("split requires 2 arguments: string and separator");
        }

        string text;
        if (args[0] is LispString) {
            text = ((LispString) args[0]).value;
        } else {
            text = args[0].to_string();
        }

        string separator;
        if (args[1] is LispString) {
            separator = ((LispString) args[1]).value;
        } else {
            separator = args[1].to_string();
        }

        string[] parts = text.split(separator);

        var result = new LispList();
        foreach (var part in parts) {
            result.list.add(new LispString(part));
        }

        return result;
    }

    // Implementation of the (push arr ...items) function
    public LispValue fn_push(ArrayList<LispValue> args) throws LispError {
        print("fn_push called\n");
        check_context();

        if (args.size < 2) {
            throw new LispError.TYPE("push requires at least 2 arguments: array and items");
        }

        if (!(args[0] is LispList)) {
            throw new LispError.TYPE("First argument to push must be a list");
        }

        var target_list = (LispList) args[0];

        // Add all the remaining items to the list
        for (int i = 1; i < args.size; i++) {
            target_list.list.add(args[i]);
        }

        // Return the modified list
        return target_list;
    }

    // Implementation of the (pop arr) function
    public LispValue fn_pop(ArrayList<LispValue> args) throws LispError {
        print("fn_pop called\n");
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("pop requires 1 argument: array");
        }

        if (!(args[0] is LispList)) {
            throw new LispError.TYPE("Argument to pop must be a list");
        }

        var target_list = (LispList) args[0];

        if (target_list.list.size == 0) {
            // Empty list, return nil
            return new LispNil();
        }

        // Remove and return the last item
        var last_index = target_list.list.size - 1;
        var last_item = target_list.list[last_index];
        target_list.list.remove_at(last_index);

        return last_item;
    }

    // Implementation of the (cons arr ...items) function
    public LispValue fn_cons(ArrayList<LispValue> args) throws LispError {
        print("fn_cons called\n");
        check_context();

        if (args.size < 2) {
            throw new LispError.TYPE("cons requires at least 2 arguments: array and items");
        }

        if (!(args[0] is LispList)) {
            throw new LispError.TYPE("First argument to cons must be a list");
        }

        var original_list = (LispList) args[0];
        var new_list = new LispList();

        // Copy all items from the original list
        foreach (var item in original_list.list) {
            new_list.list.add(item);
        }

        // Add all the remaining items to the new list
        for (int i = 1; i < args.size; i++) {
            new_list.list.add(args[i]);
        }

        // Return the new list
        return new_list;
    }

    // Implementation of the (offset a b) function
    public LispValue fn_offset(ArrayList<LispValue> args) throws LispError {
        print("fn_offset called\n");
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("offset requires 2 arguments: position A and position B");
        }

        // Extract points
        if (!(args[0] is LispList) || !(args[1] is LispList)) {
            throw new LispError.TYPE("offset arguments must be positions");
        }

        var point_a = (LispList) args[0];
        var point_b = (LispList) args[1];

        // Check if they are pos shapes
        if (point_a.list.size < 3 || point_b.list.size < 3 ||
            !(point_a.list[0] is LispIdentifier) || !(point_b.list[0] is LispIdentifier)) {
            throw new LispError.TYPE("offset arguments must be pos shapes");
        }

        var a_type = ((LispIdentifier) point_a.list[0]).value;
        var b_type = ((LispIdentifier) point_b.list[0]).value;

        if (a_type != "pos" || b_type != "pos") {
            throw new LispError.TYPE("offset arguments must be pos shapes");
        }

        // Extract coordinates
        if (!(point_a.list[1] is LispNumber) || !(point_a.list[2] is LispNumber) ||
            !(point_b.list[1] is LispNumber) || !(point_b.list[2] is LispNumber)) {
            throw new LispError.TYPE("Invalid position coordinates");
        }

        double ax = ((LispNumber) point_a.list[1]).value;
        double ay = ((LispNumber) point_a.list[2]).value;
        double bx = ((LispNumber) point_b.list[1]).value;
        double by = ((LispNumber) point_b.list[2]).value;

        // Perform offset (a + b)
        double cx = ax + bx;
        double cy = ay + by;

        // Return new position
        var result = new LispList();
        result.list.add(new LispIdentifier("pos"));
        result.list.add(new LispNumber(cx));
        result.list.add(new LispNumber(cy));

        return result;
    }

    // Implementation of the (distance a b) function
    public LispValue fn_distance(ArrayList<LispValue> args) throws LispError {
        print("fn_distance called\n");
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("distance requires 2 arguments: position A and position B");
        }

        // Extract points
        if (!(args[0] is LispList) || !(args[1] is LispList)) {
            throw new LispError.TYPE("distance arguments must be positions");
        }

        var point_a = (LispList) args[0];
        var point_b = (LispList) args[1];

        // Check if they are pos shapes
        if (point_a.list.size < 3 || point_b.list.size < 3 ||
            !(point_a.list[0] is LispIdentifier) || !(point_b.list[0] is LispIdentifier)) {
            throw new LispError.TYPE("distance arguments must be pos shapes");
        }

        var a_type = ((LispIdentifier) point_a.list[0]).value;
        var b_type = ((LispIdentifier) point_b.list[0]).value;

        if (a_type != "pos" || b_type != "pos") {
            throw new LispError.TYPE("distance arguments must be pos shapes");
        }

        // Extract coordinates
        if (!(point_a.list[1] is LispNumber) || !(point_a.list[2] is LispNumber) ||
            !(point_b.list[1] is LispNumber) || !(point_b.list[2] is LispNumber)) {
            throw new LispError.TYPE("Invalid position coordinates");
        }

        double ax = ((LispNumber) point_a.list[1]).value;
        double ay = ((LispNumber) point_a.list[2]).value;
        double bx = ((LispNumber) point_b.list[1]).value;
        double by = ((LispNumber) point_b.list[2]).value;

        // Calculate distance
        double dx = bx - ax;
        double dy = by - ay;
        double distance = Math.sqrt(dx * dx + dy * dy);

        return new LispNumber(distance);
    }

    // Implementation of the (lum color) function
    public LispValue fn_lum(ArrayList<LispValue> args) throws LispError {
        print("fn_lum called\n");
        check_context();

        if (args.size != 1) {
            throw new LispError.TYPE("lum requires 1 argument: color");
        }

        // Parse color
        Gdk.RGBA color = parse_color(args[0]);

        // Calculate luminance (perceived brightness)
        // Using the formula: 0.2126*R + 0.7152*G + 0.0722*B
        double luminance = 0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue;

        return new LispNumber(luminance);
    }

    // Implementation of the (brightness pixel q) function
    public LispValue fn_brightness(ArrayList<LispValue> args) throws LispError {
        print("fn_brightness called\n");
        check_context();

        if (args.size != 2) {
            throw new LispError.TYPE("brightness requires 2 arguments: color and factor");
        }

        // Parse color
        Gdk.RGBA color = parse_color(args[0]);

        // Get brightness factor
        double factor = get_number(args[1], "factor");

        // Apply brightness adjustment
        double r = Math.fmax(0, Math.fmin(1, color.red + factor));
        double g = Math.fmax(0, Math.fmin(1, color.green + factor));
        double b = Math.fmax(0, Math.fmin(1, color.blue + factor));

        // Create adjusted color
        var result = new LispList();
        result.list.add(new LispIdentifier("color"));
        result.list.add(new LispNumber(r));
        result.list.add(new LispNumber(g));
        result.list.add(new LispNumber(b));
        if (color.alpha < 1.0) {
            result.list.add(new LispNumber(color.alpha));
        }

        return result;
    }

    // Implementation of the (blur) function - Returns a blur kernel
    public LispValue fn_blur(ArrayList<LispValue> args) throws LispError {
        print("fn_blur called\n");
        check_context();

        // Create a box blur kernel (3x3)
        var kernel = new LispList();

        // First row
        var row1 = new LispList();
        row1.list.add(new LispNumber(1.0 / 9.0));
        row1.list.add(new LispNumber(1.0 / 9.0));
        row1.list.add(new LispNumber(1.0 / 9.0));
        kernel.list.add(row1);

        // Second row
        var row2 = new LispList();
        row2.list.add(new LispNumber(1.0 / 9.0));
        row2.list.add(new LispNumber(1.0 / 9.0));
        row2.list.add(new LispNumber(1.0 / 9.0));
        kernel.list.add(row2);

        // Third row
        var row3 = new LispList();
        row3.list.add(new LispNumber(1.0 / 9.0));
        row3.list.add(new LispNumber(1.0 / 9.0));
        row3.list.add(new LispNumber(1.0 / 9.0));
        kernel.list.add(row3);

        return kernel;
    }

    // Implementation of the (transform) toolkit function
    public LispValue fn_transform(ArrayList<LispValue> args) throws LispError {
        print("fn_transform called\n");
        check_context();

        if (args.size < 1) {
            throw new LispError.TYPE("transform requires at least 1 argument: operation");
        }

        // Get the operation
        string operation;
        if (args[0] is LispString) {
            operation = ((LispString) args[0]).value;
        } else if (args[0] is LispIdentifier) {
            operation = ((LispIdentifier) args[0]).value;
        } else if (args[0] is LispSymbol) {
            operation = ((LispSymbol) args[0]).value;
        } else {
            throw new LispError.TYPE("First argument to transform must be an operation name");
        }

        // Process the operation
        switch (operation) {
        case "push" :
            context.transform_push();
            return new LispNil();

        case "pop" :
            context.transform_pop();
            return new LispNil();

        case "reset" :
            context.transform_reset();
            return new LispNil();

        case "move" :
        case "translate" :
            if (args.size < 3) {
                throw new LispError.TYPE("transform move requires 2 arguments: dx and dy");
            }

            double dx = get_number(args[1], "dx");
            double dy = get_number(args[2], "dy");

            context.transform_translate(dx, dy);
            return new LispNil();

        case "scale" :
            if (args.size < 2) {
                throw new LispError.TYPE("transform scale requires at least 1 argument: scale factor");
            }

            double sx = get_number(args[1], "sx");
            double sy = args.size > 2 ? get_number(args[2], "sy") : sx;

            context.transform_scale(sx, sy);
            return new LispNil();

        case "rotate" :
            if (args.size < 2) {
                throw new LispError.TYPE("transform rotate requires 1 argument: angle in radians");
            }

            double angle = get_number(args[1], "angle");

            context.transform_rotate(angle);
            return new LispNil();

            default :
            throw new LispError.RUNTIME("Unknown transform operation: " + operation);
        }
    }

    // Implementation of the (sharpen) function - Returns a sharpen kernel
    public LispValue fn_sharpen(ArrayList<LispValue> args) throws LispError {
        print("fn_sharpen called\n");
        check_context();

        // Create a sharpen kernel (3x3)
        var kernel = new LispList();

        // First row
        var row1 = new LispList();
        row1.list.add(new LispNumber(0));
        row1.list.add(new LispNumber(-1));
        row1.list.add(new LispNumber(0));
        kernel.list.add(row1);

        // Second row
        var row2 = new LispList();
        row2.list.add(new LispNumber(-1));
        row2.list.add(new LispNumber(5));
        row2.list.add(new LispNumber(-1));
        kernel.list.add(row2);

        // Third row
        var row3 = new LispList();
        row3.list.add(new LispNumber(0));
        row3.list.add(new LispNumber(-1));
        row3.list.add(new LispNumber(0));
        kernel.list.add(row3);

        return kernel;
    }

    // Implementation of the (edge) function - Returns an edge detection kernel
    public LispValue fn_edge(ArrayList<LispValue> args) throws LispError {
        print("fn_edge called\n");
        check_context();

        // Create an edge detection kernel (3x3 Sobel)
        var kernel = new LispList();

        // First row
        var row1 = new LispList();
        row1.list.add(new LispNumber(-1));
        row1.list.add(new LispNumber(-1));
        row1.list.add(new LispNumber(-1));
        kernel.list.add(row1);

        // Second row
        var row2 = new LispList();
        row2.list.add(new LispNumber(-1));
        row2.list.add(new LispNumber(8));
        row2.list.add(new LispNumber(-1));
        kernel.list.add(row2);

        // Third row
        var row3 = new LispList();
        row3.list.add(new LispNumber(-1));
        row3.list.add(new LispNumber(-1));
        row3.list.add(new LispNumber(-1));
        kernel.list.add(row3);

        return kernel;
    }
}

// --- Ronin LISP Integration ---
public class RoninLib : Object {
    // Static reference to functions to prevent garbage collection
    private static RoninFunctions functions_instance;

    // Build the Ronin library of LISP functions
    public static HashTable<string, LispValue> build_lib(RoninContext context) {
        print("Building library with context %p\n", context);

        if (context == null) {
            error("Cannot build library with null context");
        }

        var lib = new HashTable<string, LispValue> (str_hash, str_equal);
        functions_instance = new RoninFunctions(context);

        // Directly bind methods to avoid lambda context issues
        lib.set("clear", new LispBuiltinFunc((args) => {
            return functions_instance.fn_clear(args);
        }));
        lib.set("circle", new LispBuiltinFunc((args) => {
            return functions_instance.fn_circle(args);
        }));
        lib.set("rect", new LispBuiltinFunc((args) => {
            return functions_instance.fn_rect(args);
        }));
        lib.set("fill", new LispBuiltinFunc((args) => {
            return functions_instance.fn_fill(args);
        }));
        lib.set("stroke", new LispBuiltinFunc((args) => {
            return functions_instance.fn_stroke(args);
        }));
        lib.set("svg", new LispBuiltinFunc((args) => {
            return functions_instance.fn_svg(args);
        }));
        lib.set("get-frame", new LispBuiltinFunc((args) => {
            return functions_instance.fn_get_frame(args);
        }));
        lib.set("resize", new LispBuiltinFunc((args) => {
            return functions_instance.fn_resize(args);
        }));

        lib.set("get-theme", new LispBuiltinFunc((args) => {
            return functions_instance.fn_get_theme(args);
        }));
        lib.set("on", new LispBuiltinFunc((args) => {
            return functions_instance.fn_on(args);
        }));

        lib.set("size", new LispBuiltinFunc((args) => {
            return functions_instance.fn_size(args);
        }));
        lib.set("transform", new LispBuiltinFunc((args) => {
            return functions_instance.fn_transform(args);
        }));

        lib.set("while", new LispBuiltinFunc((args) => {
            return functions_instance.fn_while(args);
        }));

        lib.set("native", new LispBuiltinFunc((args) => {
            return functions_instance.fn_native(args);
        }));

        lib.set("reduce", new LispBuiltinFunc((args) => {
            return functions_instance.fn_reduce(args);
        }));

        lib.set("convolve", new LispBuiltinFunc((args) => {
            return functions_instance.fn_convolve(args);
        }));

        lib.set("time", new LispBuiltinFunc((args) => {
            return functions_instance.fn_time(args);
        }));
        lib.set("print", new LispBuiltinFunc((args) => {
            return functions_instance.fn_print(args);
        }));

        lib.set("offset", new LispBuiltinFunc((args) => {
            return functions_instance.fn_offset(args);
        }));

        lib.set("distance", new LispBuiltinFunc((args) => {
            return functions_instance.fn_distance(args);
        }));

        lib.set("lum", new LispBuiltinFunc((args) => {
            return functions_instance.fn_lum(args);
        }));

        lib.set("blur", new LispBuiltinFunc((args) => {
            return functions_instance.fn_blur(args);
        }));

        lib.set("sharpen", new LispBuiltinFunc((args) => {
            return functions_instance.fn_sharpen(args);
        }));

        lib.set("edge", new LispBuiltinFunc((args) => {
            return functions_instance.fn_edge(args);
        }));

        lib.set("brightness", new LispBuiltinFunc((args) => {
            return functions_instance.fn_brightness(args);
        }));

        lib.set("color", new LispBuiltinFunc((args) => {
            return functions_instance.fn_color(args);
        }));

        lib.set("object", new LispBuiltinFunc((args) => {
            return functions_instance.fn_object(args);
        }));

        lib.set("set", new LispBuiltinFunc((args) => {
            return functions_instance.fn_set(args);
        }));

        lib.set("keys", new LispBuiltinFunc((args) => {
            return functions_instance.fn_keys(args);
        }));

        lib.set("values", new LispBuiltinFunc((args) => {
            return functions_instance.fn_values(args);
        }));

        lib.set("of", new LispBuiltinFunc((args) => {
            return functions_instance.fn_of(args);
        }));

        lib.set("hsl", new LispBuiltinFunc((args) => {
            return functions_instance.fn_hsl(args);
        }));

        lib.set("text", new LispBuiltinFunc((args) => {
            return functions_instance.fn_text(args);
        }));

        lib.set("poly", new LispBuiltinFunc((args) => {
            return functions_instance.fn_poly(args);
        }));

        lib.set("echo", new LispBuiltinFunc((args) => {
            return functions_instance.fn_echo(args);
        }));
        lib.set("debug", new LispBuiltinFunc((args) => {
            return functions_instance.fn_debug(args);
        }));

        lib.set("get", new LispBuiltinFunc((args) => {
            return functions_instance.fn_get(args);
        }));
        lib.set("list", new LispBuiltinFunc((args) => {
            return functions_instance.fn_list(args);
        }));

        // Math constants
        lib.set("PI", new LispNumber(Math.PI));
        lib.set("TWO_PI", new LispNumber(2 * Math.PI));

        // Math functions
        lib.set("mod", new LispBuiltinFunc((args) => { return functions_instance.fn_mod(args); }));
        lib.set("min", new LispBuiltinFunc((args) => { return functions_instance.fn_min(args); }));
        lib.set("max", new LispBuiltinFunc((args) => { return functions_instance.fn_max(args); }));
        lib.set("sqrt", new LispBuiltinFunc((args) => { return functions_instance.fn_sqrt(args); }));
        lib.set("pow", new LispBuiltinFunc((args) => { return functions_instance.fn_pow(args); }));
        lib.set("random", new LispBuiltinFunc((args) => { return functions_instance.fn_random(args); }));

        // Logic functions
        lib.set("gt", new LispBuiltinFunc((args) => { return functions_instance.fn_gt(args); }));
        lib.set("lt", new LispBuiltinFunc((args) => { return functions_instance.fn_lt(args); }));
        lib.set("eq", new LispBuiltinFunc((args) => { return functions_instance.fn_eq(args); }));
        lib.set("and", new LispBuiltinFunc((args) => { return functions_instance.fn_and(args); }));
        lib.set("or", new LispBuiltinFunc((args) => { return functions_instance.fn_or(args); }));
        lib.set("not", new LispBuiltinFunc((args) => { return functions_instance.fn_not(args); }));

        // List functions
        lib.set("len", new LispBuiltinFunc((args) => { return functions_instance.fn_len(args); }));
        lib.set("first", new LispBuiltinFunc((args) => { return functions_instance.fn_first(args); }));
        lib.set("last", new LispBuiltinFunc((args) => { return functions_instance.fn_last(args); }));
        lib.set("rest", new LispBuiltinFunc((args) => { return functions_instance.fn_rest(args); }));
        lib.set("filter", new LispBuiltinFunc((args) => { return functions_instance.fn_filter(args); }));

        // Math functions
        lib.set("add", new LispBuiltinFunc((args) => {
            return functions_instance.fn_add(args);
        }));

        lib.set("mul", new LispBuiltinFunc((args) => {
            return functions_instance.fn_mul(args);
        }));

        lib.set("div", new LispBuiltinFunc((args) => {
            return functions_instance.fn_div(args);
        }));

        lib.set("sub", new LispBuiltinFunc((args) => {
            return functions_instance.fn_sub(args);
        }));

        lib.set("sin", new LispBuiltinFunc((args) => {
            return functions_instance.fn_sin(args);
        }));

        lib.set("cos", new LispBuiltinFunc((args) => {
            return functions_instance.fn_cos(args);
        }));

        lib.set("guide", new LispBuiltinFunc((args) => {
            return functions_instance.fn_guide(args);
        }));

        lib.set("rescale", new LispBuiltinFunc((args) => {
            return functions_instance.fn_rescale(args);
        }));

        lib.set("orient", new LispBuiltinFunc((args) => {
            return functions_instance.fn_orient(args);
        }));

        lib.set("mirror", new LispBuiltinFunc((args) => {
            return functions_instance.fn_mirror(args);
        }));

        lib.set("gradient", new LispBuiltinFunc((args) => {
            return functions_instance.fn_gradient(args);
        }));

        // Collection functions
        lib.set("range", new LispBuiltinFunc((args) => {
            return functions_instance.fn_range(args);
        }));

        lib.set("map", new LispBuiltinFunc((args) => {
            return functions_instance.fn_map(args);
        }));

        lib.set("open", new LispBuiltinFunc((args) => {
            return functions_instance.fn_open(args);
        }));

        lib.set("import", new LispBuiltinFunc((args) => {
            return functions_instance.fn_import(args);
        }));

        lib.set("export", new LispBuiltinFunc((args) => {
            return functions_instance.fn_export(args);
        }));

        lib.set("files", new LispBuiltinFunc((args) => {
            return functions_instance.fn_files(args);
        }));

        lib.set("rad", new LispBuiltinFunc((args) => {
            return functions_instance.fn_rad(args);
        }));

        lib.set("deg", new LispBuiltinFunc((args) => {
            return functions_instance.fn_deg(args);
        }));

        lib.set("clamp", new LispBuiltinFunc((args) => {
            return functions_instance.fn_clamp(args);
        }));

        lib.set("step", new LispBuiltinFunc((args) => {
            return functions_instance.fn_step(args);
        }));

        lib.set("ceil", new LispBuiltinFunc((args) => {
            return functions_instance.fn_ceil(args);
        }));

        lib.set("floor", new LispBuiltinFunc((args) => {
            return functions_instance.fn_floor(args);
        }));

        lib.set("round", new LispBuiltinFunc((args) => {
            return functions_instance.fn_round(args);
        }));

        lib.set("log", new LispBuiltinFunc((args) => {
            return functions_instance.fn_log(args);
        }));

        lib.set("sq", new LispBuiltinFunc((args) => {
            return functions_instance.fn_sq(args);
        }));

        lib.set("concat", new LispBuiltinFunc((args) => {
            return functions_instance.fn_concat(args);
        }));

        lib.set("split", new LispBuiltinFunc((args) => {
            return functions_instance.fn_split(args);
        }));

        lib.set("push", new LispBuiltinFunc((args) => {
            return functions_instance.fn_push(args);
        }));

        lib.set("pop", new LispBuiltinFunc((args) => {
            return functions_instance.fn_pop(args);
        }));

        lib.set("cons", new LispBuiltinFunc((args) => {
            return functions_instance.fn_cons(args);
        }));

        return lib;
    }
}
