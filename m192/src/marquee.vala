public class MarqueeLabel : Gtk.Box {
    private Gtk.Label label;
    private int current_position;
    private bool is_active;
    private uint timeout_id;
    private bool should_scroll = false;

    // Public property for text, similar to Gtk.Label
    private string _text;
    public string text {
        get { return _text; }
        set {
            _text = value;
            update_scroll_state ();
            if (is_active) {
                reset ();
            }
        }
    }

    // Public property for speed
    private int _speed;
    public int speed {
        get { return _speed; }
        set {
            _speed = value;
            if (is_active) {
                stop ();
                start ();
            }
        }
    }

    // Public property for label alignment
    public Gtk.Align xalign {
        get { return label.halign; }
        set { label.halign = value; }
    }

    // Public property for label justification
    public Gtk.Justification justify {
        get { return label.justify; }
        set { label.justify = value; }
    }

    /**
     * Creates a new MarqueeLabel instance.
     */
    public MarqueeLabel (string? text = null) {
        Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 0);
        add_css_class ("marquee-label");

        // Initialize marquee variables
        _text = text ?? "";
        current_position = 0;
        is_active = false;
        timeout_id = 0;
        _speed = 300; // Default speed in milliseconds

        // Create the label
        label = new Gtk.Label ("");
        label.hexpand = true;
        label.set_size_request (200, -1);

        // Add the label to this container
        this.append (label);
    }

    /**
     * Determines if the text needs scrolling based on its width
     */
    private void update_scroll_state () {
        // Use Pango layout to measure text width
        var layout = label.create_pango_layout (_text);
        int text_width, text_height;
        layout.get_pixel_size (out text_width, out text_height);

        // Check if text width exceeds label width (210px)
        should_scroll = text_width > 210;

        // If no scrolling needed, set full text
        if (!should_scroll) {
            label.set_text (_text);
        }
    }

    /**
     * Legacy method for compatibility - sets the text to be displayed.
     * @param text The text to display
     */
    public void set_label (string text) {
        this.text = text;
    }

    /**
     * Starts the marquee animation.
     */
    public void start () {
        if (is_active || !should_scroll) {
            return;
        }

        is_active = true;
        current_position = 0;
        label.set_text ("");

        // Start the timer
        timeout_id = Timeout.add (_speed, update_marquee);
    }

    /**
     * Stops the marquee animation.
     */
    public void stop () {
        if (timeout_id != 0) {
            Source.remove (timeout_id);
            timeout_id = 0;
        }
        is_active = false;

        // If scrolling is not needed, reset to full text
        if (!should_scroll) {
            label.set_text (_text);
        }
    }

    /**
     * Resets the marquee animation.
     */
    public void reset () {
        stop ();
        current_position = 0;
        label.set_text ("");
        start ();
    }

    /**
     * Updates the marquee display on each timer tick.
     * @return true to continue the timer, false to stop it
     */
    private bool update_marquee () {
        if (!is_active || !should_scroll) {
            return false;
        }

        if (current_position < _text.length) {
            // Show text up to the current position
            string displayed_text = _text.substring (0, current_position + 1);
            label.set_text (displayed_text);
            current_position++;
        } else {
            // Reset to beginning when we reach the end
            current_position = 0;
            label.set_text ("");
        }

        return true; // Keep the timer running
    }
}
