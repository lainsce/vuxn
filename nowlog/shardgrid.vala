using Theme;

public class ShardGrid : Gtk.Grid {
    private ShardManager shard_manager;
    private string? current_filter_tag = null;
    
    private const int COLUMNS = 3;
    private const int SPACING = 8;
    
    public ShardGrid (ShardManager manager) {
        this.shard_manager = manager;
        
        // Setup grid properties
        this.row_spacing = SPACING;
        this.column_spacing = SPACING;
        this.margin_start = SPACING;
        this.margin_end = SPACING;
        this.margin_top = SPACING;
        this.margin_bottom = SPACING;
        
        // Connect to changes
        shard_manager.shards_changed.connect (refresh);
        
        // Connect to theme changes
        Theme.Manager.get_default().theme_changed.connect(() => {
            refresh();
        });
        
        // Initial population
        refresh ();
    }
    
    public void filter_tag (string? tag) {
        if (this == null) {
            return;
        }
        current_filter_tag = tag;
        refresh ();
    }
    
    public void refresh () {
        // Remove all children
        var child = this.get_first_child ();
        while (child != null) {
            var next = child.get_next_sibling ();
            this.remove (child);
            child = next;
        }
        
        // Get shards (filtered if needed)
        Gee.List<Shard> shards;
        if (current_filter_tag == null) {
            shards = shard_manager.get_all_shards ();
        } else {
            shards = shard_manager.get_shards_by_tag (current_filter_tag);
        }
        
        // Add shard cards to grid
        int column = 0;
        int row = 0;
        
        foreach (var shard in shards) {
            var card = new ShardCard (shard);
            card.delete_requested.connect (() => {
                confirm_delete (shard);
            });
            
            this.attach (card, column, row, 1, 1);
            
            // Update grid position
            column++;
            if (column >= COLUMNS) {
                column = 0;
                row++;
            }
        }
    }
    
    private void confirm_delete (Shard shard) {
        var dialog = new Gtk.AlertDialog ("");
        dialog.message = "Delete this shard?";
        dialog.detail = "This action cannot be undone.";
        dialog.buttons = {"Cancel", "Delete"};
        dialog.default_button = 0;
        dialog.cancel_button = 0;
        
        dialog.choose.begin ((Gtk.Window)this.get_root(), null, (obj, res) => {
            try {
                int response = dialog.choose.end (res);
                if (response == 1) { // Delete button
                    shard_manager.remove_shard (shard);
                }
            } catch (Error e) {
                warning ("Dialog error: %s", e.message);
            }
        });
    }
}

public class ShardCard : Gtk.Widget {
    private Shard shard;
    private const int WIDTH = 320;
    private const int MIN_HEIGHT = 200;
    private const int TITLE_HEIGHT = 32;
    private const int PADDING = 8;
    
    // Remove hardcoded color constants - using theme colors instead
    
    public signal void delete_requested ();
    
    public ShardCard (Shard shard) {
        this.shard = shard;
        
        set_size_request (WIDTH, MIN_HEIGHT);
        
        // Make widget focusable and handle key events
        this.can_focus = true;
        this.focusable = true;
        
        // Add controllers
        var click = new Gtk.GestureClick ();
        click.set_button (0); // Any button
        click.pressed.connect ((gesture, n_press, x, y) => {
            handle_click (gesture, n_press, x, y);
        });
        this.add_controller (click);
        
        var key = new Gtk.EventControllerKey ();
        key.key_pressed.connect (handle_key_press);
        this.add_controller (key);
    }
    
    private bool handle_click (Gtk.GestureClick gesture, int n_press, double x, double y) {
        // Handle right-click for delete
        if (gesture.get_current_button () == Gdk.BUTTON_SECONDARY) {
            delete_requested ();
            return true;
        }
        
        // Select with left-click
        if (gesture.get_current_button () == Gdk.BUTTON_PRIMARY) {
            this.grab_focus ();
            return true;
        }
        
        return false;
    }
    
    private bool handle_key_press (uint keyval, uint keycode, Gdk.ModifierType state) {
        // Delete key to remove shard
        if (keyval == Gdk.Key.Delete) {
            delete_requested ();
            return true;
        }
        return false;
    }
    
    public override void measure (Gtk.Orientation orientation, int for_size, out int minimum, out int natural, out int minimum_baseline, out int natural_baseline) {
        if (orientation == Gtk.Orientation.HORIZONTAL) {
            minimum = natural = WIDTH;
        } else {
            // Calculate height based on content
            int calculated_height = MIN_HEIGHT;
            
            // For now, just use minimum height
            // In a real app, we'd calculate based on text length
            
            minimum = natural = calculated_height;
        }
        
        minimum_baseline = natural_baseline = -1;
    }
    
    public override void snapshot (Gtk.Snapshot snapshot) {
        int width = get_width ();
        int height = get_height ();
        
        // Create a Cairo context for drawing
        var cr_snapshot = snapshot.append_cairo ({{0, 0}, {width, height}});
        
        // Use the Cairo context directly with theme colors
        draw_with_cairo (cr_snapshot, width, height);
        
        cr_snapshot = null;
    }
    
    private void draw_with_cairo (Cairo.Context cr, int width, int height) {
        // Get colors from theme manager
        var theme = Theme.Manager.get_default();
        var bg_color = theme.get_color("theme_bg");
        var fg_color = theme.get_color("theme_fg");
        var accent_color = theme.get_color("theme_accent");
        var selection_color = theme.get_color("theme_selection");
        
        // Disable antialiasing for crisp 2-bit look
        cr.set_antialias (Cairo.Antialias.NONE);
        
        // Draw background
        cr.set_source_rgb (bg_color.red, bg_color.green, bg_color.blue);
        cr.rectangle (0, 0, width, height);
        cr.fill ();
        
        // Draw border
        cr.set_source_rgb (fg_color.red, fg_color.green, fg_color.blue);
        cr.set_line_width (1);
        cr.rectangle (0.5, 0.5, width - 1, height - 1);
        cr.stroke ();
        
        // Draw title background
        cr.set_source_rgb (selection_color.red, selection_color.green, selection_color.blue);
        cr.rectangle (1, 1, width - 2, TITLE_HEIGHT);
        cr.fill ();
        
        // Draw date
        string arvelie_date = shard.get_arvelie_date ();
        
        // Update text color based on background to ensure contrast
        Theme.ContrastHelper.set_text_color_for_background(cr, selection_color);
        
        // Use Chicago12.1 font for the date
        cr.select_font_face ("Chicago12.1", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        cr.set_font_size (16);
        
        cr.move_to (PADDING, TITLE_HEIGHT / 2 + 4);
        cr.show_text (arvelie_date);
        
        // Draw title with Geneva font
        cr.select_font_face ("Geneva", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
        cr.set_font_size (16);
        
        // Truncate title if too long
        string title = shard.title;
        Cairo.TextExtents extents;
        cr.text_extents (title, out extents);
        
        while (extents.width > width - PADDING * 2 - 80 && title.length > 3) {
            title = title.substring (0, title.length - 4) + "...";
            cr.text_extents (title, out extents);
        }
        
        cr.move_to (PADDING + 70, TITLE_HEIGHT / 2 + 4);
        cr.show_text (title);
        
        // Use Times font for the content text
        cr.select_font_face ("Times", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        cr.set_font_size (16);
        
        // Set text color to foreground color
        cr.set_source_rgb (fg_color.red, fg_color.green, fg_color.blue);
        
        // Direct text rendering without word splitting
        string text = shard.text;
        int x = PADDING;
        int y = TITLE_HEIGHT + PADDING + 12; // Initial position
        
        // Text wrapping with character-by-character approach
        double line_width = 0;
        string current_line = "";
        int max_width = width - PADDING * 2;
        
        // Process the text character by character
        for (int i = 0; i < text.length; i++) {
            unichar c = text.get_char (text.index_of_nth_char (i));
            string char_str = c.to_string ();
            
            // Check width
            Cairo.TextExtents char_extents;
            cr.text_extents (char_str, out char_extents);
            
            // If adding this character would exceed the line width, start a new line
            if (line_width + char_extents.width > max_width && current_line != "") {
                // Render the current line
                cr.move_to (x, y);
                cr.show_text (current_line);
                
                // Start a new line
                current_line = char_str;
                line_width = char_extents.width;
                y += 18; // Line height
            } else {
                // Add the character to the current line
                current_line += char_str;
                line_width += char_extents.width;
            }
        }
        
        // Render any remaining text
        if (current_line != "") {
            cr.move_to (x, y);
            cr.show_text (current_line);
        }
        
        // Draw tags at the bottom with Los Angeles font
        if (shard.tags.length > 0) {
            y = height - PADDING - 12;
            x = PADDING;
            
            cr.select_font_face ("Los Angeles", Cairo.FontSlant.ITALIC, Cairo.FontWeight.NORMAL);
            cr.set_font_size (10);
            
            // Explicitly set the text color to foreground color for tags
            cr.set_source_rgb (fg_color.red, fg_color.green, fg_color.blue);
            
            string tags_text = "Tags: " + string.joinv (", ", shard.tags);
            cr.text_extents (tags_text, out extents);
            
            // Truncate if too long
            while (extents.width > width - PADDING * 2 && tags_text.length > 10) {
                tags_text = tags_text.substring (0, tags_text.length - 4) + "...";
                cr.text_extents (tags_text, out extents);
            }
            
            cr.move_to (x, y);
            cr.show_text (tags_text);
        }
        
        // Draw a focused indicator if widget has focus
        if (has_focus) {
            cr.set_source_rgb (accent_color.red, accent_color.green, accent_color.blue);
            cr.set_line_width (2);
            cr.rectangle (2.5, 2.5, width - 5, height - 5);
            cr.stroke ();
        }
    }
}