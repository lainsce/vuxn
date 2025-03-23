/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (c) 2025 Lains
 *
 * Complete demo app showing all custom style support for 1-bit mode
 */

public class ThemeCompleteExample : He.Application {
    private Gtk.ApplicationWindow window;
    private Theme.Manager theme_manager;

    // Color swatches
    private Gtk.DrawingArea bg_swatch;
    private Gtk.DrawingArea fg_swatch;
    private Gtk.DrawingArea sel_swatch;
    private Gtk.DrawingArea acc_swatch;

    // Custom chart for drawing demonstration
    private CustomChart chart;

    public ThemeCompleteExample() {
        Object(
               application_id: "com.example.theme-complete-example",
               flags: ApplicationFlags.FLAGS_NONE
        );
    }

    protected override void activate() {
        // Get the theme manager instance
        theme_manager = Theme.Manager.get_default();

        // Try to load saved preference
        theme_manager.load_color_mode();

        // Create the main window
        window = new He.ApplicationWindow(this) {
            title = "Complete Theme Example",
            default_width = 865,
            default_height = 600
        };

        // Create a simple layout
        var main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        window.set_child(main_box);

        main_box.prepend(create_titlebar());

        var content_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 16) {
            margin_start = 16,
            margin_end = 16,
            margin_top = 16,
            margin_bottom = 16
        };
        var scrolled_window = new Gtk.ScrolledWindow() {
            vexpand = true,
            hexpand = true
        };
        scrolled_window.set_child(content_box);

        main_box.append(scrolled_window);

        // Add a title label
        var title = new Gtk.Label("Complete Theme Contrast Example");
        title.add_css_class("title-1");
        title.margin_bottom = 8;
        content_box.append(title);

        // Add description
        var desc = new Gtk.Label("This example demonstrates contrast handling for all custom CSS classes from base-styles.css in both 2-bit and 1-bit modes.");
        desc.wrap = true;
        desc.margin_bottom = 16;
        content_box.append(desc);

        // Add mode toggle
        var toggle_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 16) {
            halign = Gtk.Align.CENTER,
            margin_bottom = 24
        };

        var toggle_label = new Gtk.Label("1-bit Mode (Black & White)") {
            valign = Gtk.Align.CENTER
        };
        toggle_box.append(toggle_label);

        var toggle = new Gtk.Switch() {
            active = theme_manager.color_mode == Theme.ColorMode.ONE_BIT,
            valign = Gtk.Align.CENTER
        };

        // Connect to switch state changes
        toggle.state_set.connect((state) => {
            var new_mode = state ? Theme.ColorMode.ONE_BIT : Theme.ColorMode.TWO_BIT;

            if (theme_manager.color_mode != new_mode) {
                theme_manager.color_mode = new_mode;

                // Save the mode preference
                try {
                    theme_manager.save_color_mode();
                } catch (Error e) {
                    warning("Failed to save color mode: %s", e.message);
                }
            }

            return true;
        });

        toggle_box.append(toggle);
        content_box.append(toggle_box);

        // Create swatches section
        add_swatches_section(content_box);

        // Create custom UI elements section
        add_custom_elements_section(content_box);

        // Create custom drawing section
        add_custom_drawing_section(content_box);

        // Add Mac-style UI section
        add_mac_style_section(content_box);

        // Show the window
        window.present();

        theme_manager.apply_to_display();

        setup_system_theme_loader();
    }

    private void setup_system_theme_loader() {
        // Get reference to theme manager
        theme_manager = Theme.Manager.get_default();

        // Apply current settings to display
        theme_manager.apply_to_display();

        // Set up the system theme file check
        var theme_file = Path.build_filename(Environment.get_home_dir(), ".theme");

        debug("Monitoring system theme file: %s", theme_file);

        // Set up the recurring check for theme file changes
        GLib.Timeout.add(40, () => {
            if (FileUtils.test(theme_file, FileTest.EXISTS)) {
                try {
                    theme_manager.load_theme_from_file(theme_file);
                    debug("Loaded system theme from %s", theme_file);
                } catch (Error e) {
                    warning("Theme load failed: %s", e.message);
                }
            }
            return true; // Continue the timeout
        });
    }

    private void add_swatches_section(Gtk.Box content_box) {
        var swatches_frame = new Gtk.Frame(null);
        var swatches_label = new Gtk.Label("Theme Colors");
        swatches_frame.set_label_widget(swatches_label);

        var swatches_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 16) {
            homogeneous = true,
            margin_start = 16,
            margin_end = 16,
            margin_top = 16,
            margin_bottom = 16
        };
        swatches_frame.set_child(swatches_box);

        // Background swatch
        var bg_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        var bg_label = new Gtk.Label("Background");
        bg_box.append(bg_label);

        bg_swatch = new Gtk.DrawingArea() {
            content_width = 80,
            content_height = 40,
            margin_top = 8
        };
        bg_swatch.add_css_class("bg-swatch");
        bg_swatch.set_draw_func((area, cr, width, height) => {
            var bg_color = theme_manager.get_color("theme_bg");
            cr.set_source_rgba(bg_color.red, bg_color.green, bg_color.blue, 1.0);
            cr.rectangle(0, 0, width, height);
            cr.fill();

            // Add border
            cr.set_source_rgb(0, 0, 0);
            cr.rectangle(0, 0, width, height);
            cr.stroke();
        });
        bg_box.append(bg_swatch);
        swatches_box.append(bg_box);

        // Foreground swatch
        var fg_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        var fg_label = new Gtk.Label("Foreground");
        fg_box.append(fg_label);

        fg_swatch = new Gtk.DrawingArea() {
            content_width = 80,
            content_height = 40,
            margin_top = 8
        };
        fg_swatch.add_css_class("fg-swatch");
        fg_swatch.set_draw_func((area, cr, width, height) => {
            var fg_color = theme_manager.get_color("theme_fg");
            cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, 1.0);
            cr.rectangle(0, 0, width, height);
            cr.fill();

            // Add text with contrast
            Theme.ContrastHelper.set_text_color_for_background(cr, fg_color);
            cr.select_font_face("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(12);
            cr.move_to(10, 25);
            cr.show_text("Text");
        });
        fg_box.append(fg_swatch);
        swatches_box.append(fg_box);

        // Selection swatch
        var sel_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        var sel_label = new Gtk.Label("Selection");
        sel_box.append(sel_label);

        sel_swatch = new Gtk.DrawingArea() {
            content_width = 80,
            content_height = 40,
            margin_top = 8
        };
        sel_swatch.add_css_class("sel-swatch");
        sel_swatch.set_draw_func((area, cr, width, height) => {
            var sel_color = theme_manager.get_color("theme_selection");
            cr.set_source_rgba(sel_color.red, sel_color.green, sel_color.blue, 1.0);
            cr.rectangle(0, 0, width, height);
            cr.fill();

            // Add text with contrast
            Theme.ContrastHelper.set_text_color_for_background(cr, sel_color);
            cr.select_font_face("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(12);
            cr.move_to(10, 25);
            cr.show_text("Text");
        });
        sel_box.append(sel_swatch);
        swatches_box.append(sel_box);

        // Accent swatch
        var acc_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        var acc_label = new Gtk.Label("Accent");
        acc_box.append(acc_label);

        acc_swatch = new Gtk.DrawingArea() {
            content_width = 80,
            content_height = 40,
            margin_top = 8
        };
        acc_swatch.add_css_class("acc-swatch");
        acc_swatch.set_draw_func((area, cr, width, height) => {
            var acc_color = theme_manager.get_color("theme_accent");
            cr.set_source_rgba(acc_color.red, acc_color.green, acc_color.blue, 1.0);
            cr.rectangle(0, 0, width, height);
            cr.fill();

            // Add text with contrast
            Theme.ContrastHelper.set_text_color_for_background(cr, acc_color);
            cr.select_font_face("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(12);
            cr.move_to(10, 25);
            cr.show_text("Text");
        });
        acc_box.append(acc_swatch);
        swatches_box.append(acc_box);

        content_box.append(swatches_frame);

        // Update swatches when theme changes
        theme_manager.theme_changed.connect(() => {
            bg_swatch.queue_draw();
            fg_swatch.queue_draw();
            sel_swatch.queue_draw();
            acc_swatch.queue_draw();
        });
    }

    private void add_custom_elements_section(Gtk.Box content_box) {
        var elements_frame = new Gtk.Frame(null) {
            margin_top = 16
        };
        var elements_label = new Gtk.Label("Custom UI Elements");
        elements_frame.set_label_widget(elements_label);

        var elements_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 16) {
            margin_start = 16,
            margin_end = 16,
            margin_top = 16,
            margin_bottom = 16
        };
        elements_frame.set_child(elements_box);

        // Add standard and accent buttons
        var button_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 16) {
            homogeneous = true
        };

        var standard_button = new Gtk.Button.with_label("Standard Button");
        button_box.append(standard_button);

        var accent_button = new Gtk.Button.with_label("Accent Button");
        accent_button.add_css_class("accent-button");
        button_box.append(accent_button);

        var theme_button = new Gtk.Button.with_label("Theme Accent");
        theme_button.add_css_class("theme-accent");
        button_box.append(theme_button);

        elements_box.append(button_box);

        // Add custom styled elements
        var custom_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 16) {
            homogeneous = true,
            margin_top = 16
        };

        // Use the custom accent button
        var custom_accent_button = new CustomAccentButton("Custom Accent Button");
        custom_box.append(custom_accent_button);

        // Create a list with selection
        var list_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        var list_label = new Gtk.Label("Selection Example");
        list_box.append(list_label);

        var list = new Gtk.ListBox();
        list.selection_mode = Gtk.SelectionMode.SINGLE;

        for (int i = 1; i <= 5; i++) {
            var row = new Gtk.ListBoxRow();
            var row_label = new Gtk.Label("Item " + i.to_string());
            row_label.margin_start = 8;
            row_label.margin_end = 8;
            row_label.margin_top = 4;
            row_label.margin_bottom = 4;
            row.set_child(row_label);
            list.append(row);

            // Select the second item
            if (i == 2) {
                list.select_row(row);
            }
        }

        list_box.append(list);
        custom_box.append(list_box);

        elements_box.append(custom_box);

        // Add additional UI elements
        var controls_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 16) {
            homogeneous = true,
            margin_top = 16
        };

        // Progress bar
        var progress_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        var progress_label = new Gtk.Label("Progress Bar");
        progress_box.append(progress_label);

        var progress = new Gtk.ProgressBar();
        progress.fraction = 0.7;
        progress_box.append(progress);

        controls_box.append(progress_box);

        // Scale/slider
        var scale_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        var scale_label = new Gtk.Label("Scale");
        scale_box.append(scale_label);

        var scale = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1);
        scale.set_value(70);
        scale_box.append(scale);

        controls_box.append(scale_box);

        elements_box.append(controls_box);

        // Add class examples section
        var class_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8) {
            margin_top = 16
        };
        var class_label = new Gtk.Label("CSS Class Examples");
        class_label.halign = Gtk.Align.START;
        class_box.append(class_label);

        var class_grid = new Gtk.Grid() {
            column_spacing = 16,
            row_spacing = 8
        };

        // Add various labeled examples
        add_themed_box(class_grid, "theme-accent", 0, 0);
        add_themed_box(class_grid, "theme-selection", 1, 0);
        add_themed_box(class_grid, "fg-swatch", 2, 0);
        add_themed_box(class_grid, "acc-swatch", 3, 0);

        // Add information widgets
        add_themed_box(class_grid, "error", 0, 1);
        add_themed_box(class_grid, "warning", 1, 1);
        add_themed_box(class_grid, "info", 2, 1);
        add_themed_box(class_grid, "success", 3, 1);

        class_box.append(class_grid);
        elements_box.append(class_box);

        content_box.append(elements_frame);
    }

    private void add_themed_box(Gtk.Grid grid, string css_class, int col, int row) {
        var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 4) {
            margin_top = 4,
            margin_bottom = 4,
            margin_start = 4,
            margin_end = 4
        };

        var label = new Gtk.Label(css_class);
        label.halign = Gtk.Align.CENTER;

        var sample = new Gtk.Box(Gtk.Orientation.VERTICAL, 0) {
            width_request = 100,
            height_request = 30
        };

        var sample_text = new Gtk.Label("Text");
        sample_text.halign = Gtk.Align.CENTER;
        sample_text.valign = Gtk.Align.CENTER;

        sample.add_css_class(css_class);
        sample.append(sample_text);

        box.append(label);
        box.append(sample);

        grid.attach(box, col, row);
    }

    private void add_custom_drawing_section(Gtk.Box content_box) {
        var drawing_frame = new Gtk.Frame(null) {
            margin_top = 16
        };
        var drawing_label = new Gtk.Label("Custom Drawing");
        drawing_frame.set_label_widget(drawing_label);

        var drawing_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 16) {
            margin_start = 16,
            margin_end = 16,
            margin_top = 16,
            margin_bottom = 16
        };
        drawing_frame.set_child(drawing_box);

        // Add description
        var desc = new Gtk.Label("This example shows how to use ContrastHelper with custom drawing widgets:");
        desc.halign = Gtk.Align.START;
        drawing_box.append(desc);

        // Create a custom chart instance
        chart = new CustomChart();
        drawing_box.append(chart);

        content_box.append(drawing_frame);
    }

    private void add_mac_style_section(Gtk.Box content_box) {
        var mac_frame = new Gtk.Frame(null) {
            margin_top = 16
        };
        var mac_label = new Gtk.Label("Mac-Style Elements");
        mac_frame.set_label_widget(mac_label);

        var mac_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 16) {
            margin_start = 16,
            margin_end = 16,
            margin_top = 16,
            margin_bottom = 16
        };
        mac_frame.set_child(mac_box);

        // Add description
        var desc = new Gtk.Label("Mac-style UI elements that use custom CSS patterns:");
        desc.halign = Gtk.Align.START;
        mac_box.append(desc);

        // Create a mock title bar example
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        title_bar.add_css_class("title-bar");

        // Close button on the left
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;

        var title_label = new Gtk.Label("Sample Title Bar");
        title_label.add_css_class("title-box");
        title_label.hexpand = true;
        title_label.valign = Gtk.Align.CENTER;
        title_label.halign = Gtk.Align.CENTER;

        title_bar.append(close_button);
        title_bar.append(title_label);

        mac_box.append(title_bar);

        content_box.append(mac_frame);
    }

    // Title bar for the window
    private Gtk.Widget create_titlebar() {
        // Create classic Mac-style title bar
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = 800;
        title_bar.add_css_class("title-bar");

        // Close button on the left
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;
        close_button.clicked.connect(() => {
            window.close();
        });

        var title_label = new Gtk.Label("Theme Contrast Demo");
        title_label.add_css_class("title-box");
        title_label.hexpand = true;
        title_label.valign = Gtk.Align.CENTER;
        title_label.halign = Gtk.Align.CENTER;

        title_bar.append(close_button);
        title_bar.append(title_label);

        var winhandle = new Gtk.WindowHandle();
        winhandle.set_child(title_bar);

        // Main layout
        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        vbox.append(winhandle);

        return vbox;
    }

    public static int main(string[] args) {
        var app = new ThemeCompleteExample();
        return app.run(args);
    }
}

/**
 * A custom chart widget that demonstrates proper 1-bit mode compatibility
 */
public class CustomChart : Gtk.DrawingArea {
    private Theme.Manager theme_manager;
    private double[] data = { 20, 35, 15, 40, 25, 30 };
    private string[] labels = { "Jan", "Feb", "Mar", "Apr", "May", "Jun" };

    public CustomChart() {
        theme_manager = Theme.Manager.get_default();

        set_content_width(768);
        set_content_height(250);

        // Set the draw function
        set_draw_func(draw_chart);

        // Redraw when theme changes
        theme_manager.theme_changed.connect(() => {
            queue_draw();
        });
    }

    /**
     * The draw function for our custom chart
     */
    private void draw_chart(Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
        // Get theme colors (use contrast-aware versions)
        var bg_color = theme_manager.get_color("theme_bg");
        var fg_color = theme_manager.get_color("theme_fg");
        var accent_color = theme_manager.get_color("theme_accent");
        var selection_color = theme_manager.get_color("theme_selection");

        // Fill background
        cr.set_source_rgba(bg_color.red, bg_color.green, bg_color.blue, 1.0);
        cr.rectangle(0, 0, width, height);
        cr.fill();

        // Calculate dimensions
        double chart_width = width - 60;
        double chart_height = height - 60;
        double bar_width = chart_width / data.length * 0.7;
        double max_value = 0;

        foreach (double value in data) {
            if (value > max_value) {
                max_value = value;
            }
        }

        // Draw chart title
        cr.select_font_face("Chicago 12.1", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
        cr.set_font_size(16);

        // Use foreground color for main text
        cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, 1.0);
        cr.move_to(20, 10);
        cr.show_text("Monthly Data Chart");

        // Draw axes
        cr.set_line_width(1);
        cr.move_to(40, 50);
        cr.line_to(40, height - 40);
        cr.line_to(width - 20, height - 40);
        cr.stroke();

        // Draw grid lines
        cr.set_dash(new double[] { 2, 2 }, 0);
        for (int i = 1; i <= 5; i++) {
            double y = height - 40 - (i * chart_height / 5);
            cr.move_to(40, y);
            cr.line_to(width - 20, y);

            // Draw tick labels
            cr.move_to(20, y + 5);
            cr.show_text((i * (int) max_value / 5).to_string());
        }
        cr.stroke();
        cr.set_dash(null, 0);

        // Draw bars
        for (int i = 0; i < data.length; i++) {
            double x = 40 + (i * chart_width / data.length) + (chart_width / data.length * 0.15);
            double bar_height = (data[i] / max_value) * chart_height;
            double y = height - 40 - bar_height;

            // First use the accent color for bars
            if (theme_manager.color_mode == Theme.ColorMode.TWO_BIT) {
                // In 2-bit mode, use accent color
                cr.set_source_rgba(accent_color.red, accent_color.green, accent_color.blue, 1.0);
            } else {
                // In 1-bit mode, use black for bars
                cr.set_source_rgb(0, 0, 0);
            }

            cr.rectangle(x, y, bar_width, bar_height);
            cr.fill();

            // Draw the label below each bar
            cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, 1.0);
            cr.move_to(x + bar_width / 2 - 10, height - 20);
            cr.show_text(labels[i]);

            // Draw the value above each bar
            // THIS IS IMPORTANT: We need to ensure proper contrast for text on the background
            cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, 1.0);
            cr.move_to(x + bar_width / 2 - 10, y - 10);
            cr.show_text(data[i].to_string());
        }

        // Draw a legend using all theme colors and demonstrating contrast management
        draw_chart_legend(cr, width, height, bg_color, fg_color, accent_color, selection_color);
    }

    /**
     * Draw a legend demonstrating proper color usage in both modes
     */
    private void draw_chart_legend(Cairo.Context cr, int width, int height,
                                   Gdk.RGBA bg_color, Gdk.RGBA fg_color,
                                   Gdk.RGBA accent_color, Gdk.RGBA selection_color) {
        // Position for the legend
        double legend_x = width - 150;
        double legend_y = 60;
        double legend_width = 130;
        double legend_height = 120;

        // Draw legend background
        cr.set_source_rgba(bg_color.red, bg_color.green, bg_color.blue, 1.0);
        cr.rectangle(legend_x, legend_y, legend_width, legend_height);
        cr.fill();

        // Draw legend border
        cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, 1.0);
        cr.rectangle(legend_x, legend_y, legend_width, legend_height);
        cr.stroke();

        // Draw legend title
        cr.move_to(legend_x + 10, legend_y + 20);
        cr.show_text("Legend");

        // Draw color samples with proper contrast handling

        // 1. Foreground color sample
        cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, 1.0);
        cr.rectangle(legend_x + 10, legend_y + 30, 20, 20);
        cr.fill();

        // Get contrast-aware text color for this background
        Theme.ContrastHelper.set_text_color_for_background(cr, fg_color);
        cr.move_to(legend_x + 15, legend_y + 45);
        cr.show_text("Fg");

        // Restore foreground color for labels
        cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, 1.0);
        cr.move_to(legend_x + 40, legend_y + 45);
        cr.show_text("Foreground");

        // 2. Accent color sample
        cr.set_source_rgba(accent_color.red, accent_color.green, accent_color.blue, 1.0);
        cr.rectangle(legend_x + 10, legend_y + 60, 20, 20);
        cr.fill();

        // Get contrast-aware text color for this background
        Theme.ContrastHelper.set_text_color_for_background(cr, accent_color);
        cr.move_to(legend_x + 15, legend_y + 75);
        cr.show_text("Ac");

        // Restore foreground color for labels
        cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, 1.0);
        cr.move_to(legend_x + 40, legend_y + 75);
        cr.show_text("Accent");

        // 3. Selection color sample
        cr.set_source_rgba(selection_color.red, selection_color.green, selection_color.blue, 1.0);
        cr.rectangle(legend_x + 10, legend_y + 90, 20, 20);
        cr.fill();

        // Get contrast-aware text color for this background
        Theme.ContrastHelper.set_text_color_for_background(cr, selection_color);
        cr.move_to(legend_x + 15, legend_y + 105);
        cr.show_text("Sel");


        // Restore foreground color for labels
        cr.set_source_rgba(fg_color.red, fg_color.green, fg_color.blue, 1.0);
        cr.move_to(legend_x + 40, legend_y + 105);
        cr.show_text("Selection");
    }
}

/**
 * A custom button that demonstrates proper 1-bit mode compatibility using CSS classes
 */
public class CustomAccentButton : Gtk.Button {
    private Theme.Manager theme_manager;

    /**
     * Construct the custom accent button
     */
    public CustomAccentButton(string label_text) {
        theme_manager = Theme.Manager.get_default();

        // Set the label
        child = new Gtk.Label(label_text);

        // Add our custom accent class
        add_css_class("custom-accent");

        // Set up CSS provider for our custom styling
        var provider = new Gtk.CssProvider();
        try {
            // Create CSS for our custom button
            string css = """
                       .custom-accent {
                           background-color: @theme_accent;
                           color: @theme_bg;
                           border: 1px solid @theme_fg;
                           padding: 8px 16px;
                           border-radius: 0;
                       }

                       .custom-accent:hover {
                           background-color: @theme_selection;
                       }
                   """;

            provider.load_from_string(css);

            // Apply the provider
            Gtk.StyleContext.add_provider_for_display(
                                                      Gdk.Display.get_default(),
                                                      provider,
                                                      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        } catch (Error e) {
            warning("Failed to load custom CSS: %s", e.message);
        }

        // Listen for theme changes
        theme_manager.theme_changed.connect(() => {
            update_one_bit_compatibility();
        });

        // Apply initial compatibility
        update_one_bit_compatibility();
    }

    /**
     * Update compatibility with 1-bit mode
     */
    private void update_one_bit_compatibility() {
        if (theme_manager.color_mode == Theme.ColorMode.ONE_BIT) {
            // In 1-bit mode, add the utility class that ensures white text on black background
            if (!has_css_class("one-bit-inverted")) {
                add_css_class("one-bit-inverted");
            }
        } else {
            // In regular mode, remove the utility class
            if (has_css_class("one-bit-inverted")) {
                remove_css_class("one-bit-inverted");
            }
        }
    }
}
