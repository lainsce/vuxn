/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (c) 2025 Lains
 *
 * This file is part of the Theme Manager library which provides
 * runtime theme loading and monitoring capabilities for GTK applications.
 */

namespace Theme {
    public class ContrastHelper : Object {
        // Constants for 1-bit mode colors
        public const string ONE_BIT_BG = "#ffffff";
        public const string ONE_BIT_FG = "#000000";

        // CSS blocks for common contrast scenarios
        private const string TEXT_ON_ACCENT_CSS = @"
            /* Ensure text remains visible on accent backgrounds in 1-bit mode */

            /* Standard GTK buttons and selections */
            button.accent-button,
            button.accent,
            .accent-button,
            .accent {
                color: #ffffff;
            }

            button:checked,
            button:active {
                color: #ffffff;
            }

            selection {
                color: #ffffff;
            }

            treeview row:selected,
            list row:selected {
                color: #ffffff;
            }

            progressbar progress {
                color: #ffffff;
            }

            menuitem:hover {
                color: #ffffff;
            }

            infobar {
                color: #ffffff;
            }

            .notification {
                color: #ffffff;
            }

            popover.menu menuitem:hover {
                color: #ffffff;
            }

            expander title:hover {
                color: #ffffff;
            }

            stackswitcher button:checked {
                color: #ffffff;
            }

            /* Custom theme classes from base-styles.css */
            .title-bar {
                color: #ffffff;
            }

            .title-box {
                color: #ffffff;
            }

            .close-button {
                color: #ffffff;
            }

            .close-button:hover {
                color: #ffffff;
            }

            .close-button:active {
                color: #ffffff;
            }

            button.accent-button {
                color: #ffffff;
            }

            button.accent-button:hover {
                color: #ffffff;
            }

            button.titlebutton {
                color: #ffffff;
            }

            button.titlebutton:hover {
                color: #ffffff;
            }

            headerbar button.titlebutton {
                color: #ffffff;
            }

            tabview tab:checked {
                color: #ffffff;
            }

            tabview tab:hover:not(:checked) {
                color: #ffffff;
            }

            notebook tab:checked {
                color: #ffffff;
            }

            notebook tab:hover:not(:checked) {
                color: #ffffff;
            }

            checkbutton check:checked {
                color: #ffffff;
            }

            checkbutton radio:checked {
                color: #ffffff;
            }

            switch:checked {
                color: #ffffff;
            }

            listview row:hover:not(:selected) {
                color: #ffffff;
            }

            listview row:selected {
                color: #ffffff;
            }

            listview row:active {
                color: #ffffff;
            }

            list row:hover:not(:selected) {
                color: #ffffff;
            }

            list row:selected {
                color: #ffffff;
            }

            list row:active {
                color: #ffffff;
            }

            listview scrollbar slider {
                color: #ffffff;
            }

            list scrollbar slider {
                color: #ffffff;
            }

            /* Color swatches */
            .fg-swatch {
                color: #ffffff;
            }

            .acc-swatch {
                color: #ffffff;
            }

            popover.menu menuitem:hover {
                color: #ffffff;
            }

            dropdown button:hover,
            combobox button:hover {
                color: #ffffff;
            }

            spinbutton button:hover {
                color: #ffffff;
            }

            spinbutton button:active {
                color: #ffffff;
            }

            progressbar progress {
                color: #ffffff;
            }

            scale slider:hover {
                color: #ffffff;
            }

            scale slider:active {
                color: #ffffff;
            }

            scale fill {
                color: #ffffff;
            }

            menubar > menuitem:hover {
                color: #ffffff;
            }

            menuitem:hover {
                color: #ffffff;
            }

            calendar:selected {
                color: #ffffff;
            }

            calendar.highlight {
                color: #ffffff;
            }

            infobar.info {
                color: #ffffff;
            }

            infobar.warning {
                color: #ffffff;
            }

            infobar.error {
                color: #ffffff;
            }

            infobar.question {
                color: #ffffff;
            }

            expander title:hover {
                color: #ffffff;
            }

            stackswitcher button:checked {
                color: #ffffff;
            }

            scrollbar button:hover {
                color: #ffffff;
            }

            scrollbar button:active {
                color: #ffffff;
            }

            scrollbar slider {
                color: #ffffff;
            }

            scrollbar slider:hover {
                color: #ffffff;
            }

            /* Theme utility classes */
            .theme-accent {
                color: #ffffff;
            }

            .theme-selection {
                color: #ffffff;
            }

            /* Error and warning states */
            .error {
                color: #ffffff;
            }

            .warning {
                color: #ffffff;
            }

            /* Levelbar blocks */
            levelbar block.filled {
                color: #ffffff;
            }

            levelbar block.high {
                color: #ffffff;
            }

            levelbar block.low {
                color: #ffffff;
            }

            scale trough highlight {
                background: #000000;
            }

            scale slider:hover,
            scale slider:active {
                background: #000000;
                color: #ffffff;
            }

            scale mark {
                background: #000000;
            }

            scale.marks-before marks,
            scale.marks-after marks {
                color: #000000;
            }
        ";

        /**
         * Generates additional CSS rules for ensuring contrast in 1-bit mode
         */
        public static string get_contrast_css() {
            return TEXT_ON_ACCENT_CSS;
        }

        /**
         * Inverts a color for contrast (white becomes black, black becomes white)
         */
        public static Gdk.RGBA invert_color(Gdk.RGBA color) {
            var inverted = Gdk.RGBA();

            // Calculate luminance - simplified version
            double luminance = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue;

            if (luminance > 0.5) {
                inverted.parse(ONE_BIT_FG); // Dark color for light backgrounds
            } else {
                inverted.parse(ONE_BIT_BG); // Light color for dark backgrounds
            }

            inverted.alpha = color.alpha;
            return inverted;
        }

        /**
         * Determines appropriate text color for a given background in 1-bit mode
         * (for custom widgets that need manual contrast handling)
         */
        public static Gdk.RGBA get_contrast_text_color(Gdk.RGBA background) {
            return invert_color(background);
        }

        /**
         * Converts a color to the nearest 1-bit equivalent
         */
        public static Gdk.RGBA to_one_bit(Gdk.RGBA color) {
            var result = Gdk.RGBA();

            // Calculate luminance - simplified version
            double luminance = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue;

            if (luminance > 0.5) {
                result.parse(ONE_BIT_BG); // White
            } else {
                result.parse(ONE_BIT_FG); // Black
            }

            result.alpha = color.alpha;
            return result;
        }

        /**
         * Helper for custom widgets in 1-bit mode
         * Returns the appropriate CSS class to use for a background color
         */
        public static string get_contrast_class(Gdk.RGBA bg_color) {
            // Calculate luminance - simplified version
            double luminance = 0.299 * bg_color.red + 0.587 * bg_color.green + 0.114 * bg_color.blue;

            if (luminance <= 0.5) {
                // For dark backgrounds, add this class which should have white text
                return "one-bit-inverted";
            }
            return "";
        }

        /**
         * Creates a Cairo pattern for drawing theme-aware text with proper contrast
         * This is useful for custom drawing widgets that don't use CSS
         */
        public static void set_text_color_for_background(Cairo.Context cr, Gdk.RGBA bg_color) {
            // Calculate luminance - simplified version
            double luminance = 0.299 * bg_color.red + 0.587 * bg_color.green + 0.114 * bg_color.blue;

            if (luminance <= 0.5) {
                // For dark backgrounds, use white text
                cr.set_source_rgb(1.0, 1.0, 1.0);
            } else {
                // For dark backgrounds, use black text
                cr.set_source_rgb(0.0, 0.0, 0.0);
            }
        }
    }

    /**
     * Theme color mode enum
     */
    public enum ColorMode {
        /**
         * Two-bit mode with four colors (bg, fg, selection, accent)
         */
        TWO_BIT,

        /**
         * One-bit mode with black and white colors
         */
        ONE_BIT;

        /**
         * Convert enum value to string representation
         */
        public string to_string() {
            switch (this) {
            case TWO_BIT:
                return "two-bit";
            case ONE_BIT:
                return "one-bit";
            default:
                return "unknown";
            }
        }

        /**
         * Parse string to enum value
         */
        public static ColorMode from_string(string mode_str) {
            switch (mode_str.down()) {
            case "one-bit":
            case "1bit":
            case "1-bit":
                return ONE_BIT;
            case "two-bit":
            case "2bit":
            case "2-bit":
            default:
                return TWO_BIT;
            }
        }
    }

    /**
     * Manager class for handling theme loading and monitoring.
     */
    public class Manager : Object {
        private static Once<Manager> _instance;
        private Gtk.CssProvider base_provider;
        private Gtk.CssProvider theme_provider;
        private Gtk.CssProvider one_bit_provider; // Dedicated provider for 1-bit mode
        private FileMonitor? monitor = null;
        private string theme_path;
        private string? last_theme_data = null;
        private uint theme_change_timeout_id = 0;
        private uint sourceview_generation_timeout_id = 0;
        private bool theme_needs_update = false;

        // Theme color mode
        private ColorMode _color_mode = ColorMode.TWO_BIT;

        // Original unprocessed theme data for mode switching
        private string? original_theme_data = null;

        // Concurrency control
        private Mutex theme_lock = Mutex();
        private bool worker_active = false;

        // Cache the display to avoid repeated lookups
        private unowned Gdk.Display display;

        // Cache for color lookups to avoid creating widgets repeatedly
        private HashTable<string, Gdk.RGBA?> color_cache;

        // For color lookups
        private Gtk.Label dummy_widget;

        // Controls whether to generate GTKSourceView schemes
        private bool _generate_sourceview_scheme = true;

        // Specify GTKSourceView version (4 or 5, null for auto-detect)
        private string? _sourceview_version = null;

        // Cache for previously generated scheme
        private string? last_scheme_hash = null;

        /**
         * Get the singleton instance of the Theme Manager.
         */
        public static unowned Manager get_default() {
            return _instance.once(() => {
                return new Manager();
            });
        }

        /**
         * Whether to generate GTKSourceView schemes when the theme changes.
         */
        public bool generate_sourceview_schemes {
            get { return _generate_sourceview_scheme; }
            set { _generate_sourceview_scheme = value; }
        }

        /**
         * Set the GTKSourceView version to target.
         */
        public string? sourceview_version {
            get { return _sourceview_version; }
            set { _sourceview_version = value; }
        }

        /**
         * Get or set the current color mode.
         * Changing this will trigger a theme reload.
         */
        public ColorMode color_mode {
            get { return _color_mode; }
            set {
                if (_color_mode != value) {
                    // Store old mode for reference
                    var old_mode = _color_mode;

                    // Update the mode
                    _color_mode = value;

                    // Call appropriate method based on the new mode
                    if (_color_mode == ColorMode.ONE_BIT) {
                        apply_one_bit_mode();
                    } else {
                        // If switching from 1-bit back to 2-bit
                        if (old_mode == ColorMode.ONE_BIT) {
                            restore_two_bit_mode();
                        }
                    }

                    // Clear the color cache since colors have changed
                    color_cache.remove_all();

                    // Emit mode change signal
                    color_mode_changed(_color_mode);
                }
            }
        }

        /**
         * Signal emitted when the theme is changed.
         */
        public signal void theme_changed();

        /**
         * Signal emitted when the color mode is changed.
         */
        public signal void color_mode_changed(ColorMode new_mode);

        /**
         * Private constructor to enforce singleton pattern
         */
        private Manager() {
            // Initialization moved to construct
        }

        /**
         * Initialization of the Theme Manager.
         */
        construct {
            base_provider = new Gtk.CssProvider();
            theme_provider = new Gtk.CssProvider();
            one_bit_provider = new Gtk.CssProvider(); // Initialize the 1-bit provider

            // Initialize color cache
            color_cache = new HashTable<string, Gdk.RGBA?> (str_hash, str_equal);

            // Create a reusable widget for style lookups
            dummy_widget = new Gtk.Label("");
            dummy_widget.set_name("theme-manager-dummy-widget");

            // Cache the display for better performance
            display = Gdk.Display.get_default();

            theme_path = Path.build_filename(
                                             Environment.get_home_dir(),
                                             ".theme"
            );

            // Load base styles from resource
            try {
                base_provider.load_from_resource("/com/example/theme/base-styles.css");
                Gtk.StyleContext.add_provider_for_display(
                                                          display,
                                                          base_provider,
                                                          Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION - 10
                );

                // Add theme provider too
                Gtk.StyleContext.add_provider_for_display(
                                                          display,
                                                          theme_provider,
                                                          Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                );

                // Setup file monitor only after providers are set up
                setup_file_monitor();

                // Try to load initial theme after providers are set up
                try_load_initial_theme();
            } catch (Error e) {
                warning("Failed to load base styles: %s", e.message);
            }
        }

        /**
         * Apply 1-bit mode (black and white) regardless of the current theme
         * Background and Selection are white, Foreground and Accent are black
         */
        private void apply_one_bit_mode() {
            debug("Applying 1-bit mode (black and white)");

            // Create CSS for 1-bit mode - white background, black text
            var css = @"
            @define-color theme_bg #ffffff;
            @define-color theme_fg #000000;
            @define-color theme_selection #ffffff;
            @define-color theme_accent #000000;

            .title-bar {
                background:
                    linear-gradient(#ffffff, #ffffff) top / 100% 3px no-repeat,
                    linear-gradient(#ffffff, #ffffff) bottom / 100% 3px
                        no-repeat,
                    repeating-linear-gradient(
                            to bottom,
                            #ffffff 0px,
                            #ffffff 1px,
                            #000000 1px,
                            #000000 2px,
                            #ffffff 2px,
                            #ffffff 3px,
                            #000000 3px,
                            #000000 4px,
                            #ffffff 4px,
                            #ffffff 5px,
                            #000000 5px,
                            #000000 6px,
                            #ffffff 6px,
                            #ffffff 7px,
                            #000000 7px,
                            #000000 8px,
                            #ffffff 8px,
                            #ffffff 9px,
                            #000000 9px,
                            #000000 10px,
                            #ffffff 10px
                        )
                        0 0 / 100% 100% no-repeat;
                border-bottom: 1px solid #000000;
                box-shadow: inset 0 0 0 1px #ffffff;
                color: #000000;
            }

            .title-box {
                background-color: #ffffff;
                color: #000000;
            }

            .close-button {
                background-color: #ffffff;
                color: #000000;
                box-shadow:
                    inset 0 0 0 1px #000000,
                    0 0 0 1px #ffffff;
            }

            .close-button:hover,
            .close-button:active {
                color: #000000;
            }
            ";

            try {
                // Load the 1-bit CSS
                one_bit_provider.load_from_string(css);

                // Add the one-bit provider with higher priority than the theme provider
                Gtk.StyleContext.add_provider_for_display(
                                                          display,
                                                          one_bit_provider,
                                                          Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 10
                );

                // Notify theme change
                theme_changed();
            } catch (Error e) {
                warning("Failed to apply 1-bit mode: %s", e.message);
            }
        }

        /**
         * Restore the original 2-bit mode theme
         */
        private void restore_two_bit_mode() {
            debug("Restoring 2-bit mode");

            // Remove the 1-bit provider
            Gtk.StyleContext.remove_provider_for_display(display, one_bit_provider);

            // Clear the color cache
            color_cache.remove_all();

            // If we have theme data, reload it
            if (original_theme_data != null) {
                try_update_theme_with_mode();
            }
        }

        /**
         * Sets up a file monitor to watch for changes to the theme file.
         */
        private void setup_file_monitor() {
            var file = File.new_for_path(theme_path);

            // Create directory if it doesn't exist
            try {
                File parent = file.get_parent();
                if (!parent.query_exists()) {
                    parent.make_directory_with_parents();
                }
            } catch (Error e) {
                warning("Failed to create theme directory: %s", e.message);
            }

            try {
                monitor = file.monitor(FileMonitorFlags.NONE);
                monitor.changed.connect(on_theme_file_changed);
            } catch (Error e) {
                warning("File monitoring error: %s", e.message);
            }
        }

        /**
         * Handles file change events from the file monitor.
         */
        private void on_theme_file_changed(File src, File? dest, FileMonitorEvent event) {
            if (event == FileMonitorEvent.CHANGES_DONE_HINT ||
                event == FileMonitorEvent.CREATED ||
                event == FileMonitorEvent.CHANGED) {

                // Cancel any pending timeout to avoid multiple rapid updates
                if (theme_change_timeout_id > 0) {
                    Source.remove(theme_change_timeout_id);
                    theme_change_timeout_id = 0;
                }

                // Schedule a new update with longer debounce time
                theme_change_timeout_id = GLib.Timeout.add(100, () => {
                    theme_change_timeout_id = 0;

                    // Mark theme for update, will be processed on next idle
                    theme_needs_update = true;

                    // Schedule actual update on idle to avoid blocking UI
                    Idle.add_once(() => {
                        if (theme_needs_update) {
                            theme_needs_update = false;
                            try_load_theme();
                        }
                    });

                    return Source.REMOVE;
                });
            }
        }

        /**
         * Attempts to load the initial theme file if it exists.
         */
        private void try_load_initial_theme() {
            if (FileUtils.test(theme_path, FileTest.EXISTS)) {
                try_load_theme();
            } else {
                // If no theme file exists, check if we should apply 1-bit mode anyway
                if (_color_mode == ColorMode.ONE_BIT) {
                    apply_one_bit_mode();
                }
            }
        }

        /**
         * Loads the theme file and applies it.
         */
        private void try_load_theme() {
            // Prevent concurrent processing
            theme_lock.lock();
            try {
                // Modern way to load file contents
                var file = File.new_for_path(theme_path);

                // Check if file exists first to avoid errors
                if (!file.query_exists()) {
                    // If no theme file exists, check if we should apply 1-bit mode anyway
                    if (_color_mode == ColorMode.ONE_BIT) {
                        apply_one_bit_mode();
                    }
                    return;
                }

                // Load the file content
                uint8[] contents;
                string etag_out;
                file.load_contents(null, out contents, out etag_out);

                // Convert to string and process
                string theme_data = (string) contents;
                string trimmed_data = theme_data.strip();

                // Store the original theme data for mode switching
                original_theme_data = trimmed_data;

                // Skip processing if theme hasn't changed and not in 1-bit mode
                if (last_theme_data != null && last_theme_data == trimmed_data &&
                    _color_mode == ColorMode.TWO_BIT) {
                    debug("Theme data unchanged, skipping update");
                    return;
                }

                // If in 1-bit mode, apply black and white theme
                if (_color_mode == ColorMode.ONE_BIT) {
                    apply_one_bit_mode();
                } else {
                    // Otherwise process and apply the theme data
                    if (!update_theme_variables(trimmed_data)) {
                        warning("Failed to update theme variables");
                        return;
                    }
                }

                // Cache the theme data
                last_theme_data = trimmed_data;

                // Clear color cache on theme change
                color_cache.remove_all();

                // Schedule GTKSourceView scheme generation to happen in background
                if (generate_sourceview_schemes) {
                    schedule_sourceview_generation();
                }

                // Notify listeners
                theme_changed();
            } catch (Error e) {
                warning("Theme load failed: %s", e.message);
            } finally {
                theme_lock.unlock();
            }
        }

        /**
         * Update the theme with the current color mode using the stored original theme data.
         */
        private void try_update_theme_with_mode() {
            if (original_theme_data == null) {
                return;
            }

            theme_lock.lock();
            try {
                // If in 1-bit mode, apply black and white theme
                if (_color_mode == ColorMode.ONE_BIT) {
                    apply_one_bit_mode();
                } else {
                    // Otherwise process and apply the normal theme data
                    if (!update_theme_variables(original_theme_data)) {
                        warning("Failed to update theme variables");
                        return;
                    }
                }

                // Clear color cache since theme has changed
                color_cache.remove_all();

                // Schedule GTKSourceView scheme generation to happen in background
                if (generate_sourceview_schemes) {
                    schedule_sourceview_generation();
                }

                // Notify listeners
                theme_changed();
            } catch (Error e) {
                warning("Theme mode update failed: %s", e.message);
            } finally {
                theme_lock.unlock();
            }
        }

        /**
         * Schedule GTKSourceView scheme generation to happen without blocking the UI.
         */
        private void schedule_sourceview_generation() {
            // Cancel any pending generation
            if (sourceview_generation_timeout_id > 0) {
                Source.remove(sourceview_generation_timeout_id);
                sourceview_generation_timeout_id = 0;
            }

            // Schedule generation on idle to avoid blocking UI
            sourceview_generation_timeout_id = Idle.add(() => {
                sourceview_generation_timeout_id = 0;

                // Run in a separate thread to avoid blocking UI
                if (!worker_active) {
                    worker_active = true;

                    new Thread<void*> ("theme-sourceview-generator", () => {
                        theme_lock.lock();
                        try {
                            generate_sourceview_scheme();
                        } catch (Error e) {
                            warning("Failed to generate GTKSourceView scheme: %s", e.message);
                        } finally {
                            worker_active = false;
                            theme_lock.unlock();
                        }
                        return null;
                    });
                }

                return Source.REMOVE;
            });
        }

        /**
         * Parses and applies the theme data for two-bit mode (four colors).
         */
        private bool update_theme_variables(string theme_data) {
            // Only log in debug mode
            debug("Processing two-bit theme data: '%s'", theme_data);

            string[] parts = theme_data.split(" ");

            if (parts.length != 3) {
                warning("Invalid theme format: expected 3 parts, got %d", parts.length);
                return false;
            }

            // Validate parts
            foreach (string part in parts) {
                if (part.length != 4) {
                    warning("Invalid color code: '%s' (expected 4 characters)", part);
                    return false;
                }
            }

            // Extract and expand colors with optimized string building
            string[] colors = new string[4];
            var sb = new StringBuilder();

            for (int col = 0; col < 4; col++) {
                sb.assign("");
                foreach (string part in parts) {
                    char c = part[col];
                    sb.append_c(c).append_c(c);
                }
                colors[col] = sb.str;
            }

            // Build CSS with modern string builder pattern
            sb.assign("");
            // Fixed mapping:
            sb.append_printf("@define-color theme_bg #%s;\n", colors[0]);
            sb.append_printf("@define-color theme_fg #%s;\n", colors[1]);
            sb.append_printf("@define-color theme_accent #%s;\n", colors[2]);
            sb.append_printf("@define-color theme_selection #%s;", colors[3]);

            string css = sb.str;

            try {
                theme_provider.load_from_string(css);
                return true;
            } catch (Error e) {
                warning("Failed to load theme CSS: %s", e.message);
                return false;
            }
        }

        /**
         * Loads a theme from a specified file path.
         */
        public void load_theme_from_file(string path) throws Error {
            theme_lock.lock();
            try {
                var file = File.new_for_path(path);
                if (!file.query_exists()) {
                    throw new FileError.NOENT("Theme file does not exist: %s", path);
                }

                uint8[] contents;
                file.load_contents(null, out contents, null);

                string theme_data = (string) contents;
                string trimmed_data = theme_data.strip();

                // Store the original theme data for mode switching
                original_theme_data = trimmed_data;

                debug("Loaded theme data: '%s'", trimmed_data);

                // Skip processing if theme hasn't changed and not in 1-bit mode
                if (last_theme_data != null && last_theme_data == trimmed_data &&
                    _color_mode == ColorMode.TWO_BIT) {
                    debug("Theme data unchanged, skipping update");
                    return;
                }

                // If in 1-bit mode, keep using black and white theme
                if (_color_mode == ColorMode.ONE_BIT) {
                    debug("In 1-bit mode, applying black and white theme");
                    apply_one_bit_mode();
                } else {
                    // Otherwise process and apply the theme data
                    if (!update_theme_variables(trimmed_data)) {
                        throw new IOError.FAILED("Failed to update theme variables");
                    }
                }

                // Cache the theme data
                last_theme_data = trimmed_data;

                // Clear color cache when theme changes
                color_cache.remove_all();

                // Schedule GTKSourceView scheme generation to happen in background
                if (generate_sourceview_schemes) {
                    schedule_sourceview_generation();
                }

                theme_changed(); // Emit signal so UI can update
            } finally {
                theme_lock.unlock();
            }
        }

        /**
         * Method to generate and save a GTKSourceView color scheme based on the current theme.
         */
        public void generate_sourceview_scheme() throws Error {
            // Get all theme colors
            var bg_color = get_color("theme_bg");
            var fg_color = get_color("theme_fg");
            var selection_color = get_color("theme_selection");
            var accent_color = get_color("theme_accent");

            // Convert colors to hex
            string bg_hex = color_to_hex(bg_color);
            string fg_hex = color_to_hex(fg_color);
            string selection_hex = color_to_hex(selection_color);
            string accent_hex = color_to_hex(accent_color);

            // Create a hash of the current colors to check if we need to regenerate
            string current_hash = "%s:%s:%s:%s".printf(bg_hex, fg_hex, selection_hex, accent_hex);

            // Skip generation if colors haven't changed
            if (last_scheme_hash != null && last_scheme_hash == current_hash) {
                debug("Scheme colors unchanged, skipping generation");
                return;
            }

            // Update the hash cache
            last_scheme_hash = current_hash;

            // Detect sourceview version only when needed
            string sv_version = _sourceview_version ?? detect_sourceview_version();

            // Build XML scheme file content - this is a potentially expensive operation
            var builder = new StringBuilder();
            builder.append("""<?xml version="1.0" encoding="UTF-8"?>
<style-scheme id="varavara" name="Generated Theme" version="1.0">
  <author>Theme Manager</author>
  <description>Automatically generated from application theme</description>

  <!-- Colors from Theme Manager (only 4 are available) -->
  <color name="bg" value="#%s"/>
  <color name="fg" value="#%s"/>
  <color name="selection" value="#%s"/>
  <color name="accent" value="#%s"/>

  <!-- Styles -->
  <style name="text" foreground="fg" background="bg"/>
  <style name="cursor" foreground="accent"/>
  <style name="selection" background="accent"/>
  <style name="current-line" background="bg" foreground="selection"/>
  <style name="line-numbers" foreground="accent" background="bg"/>
  <style name="right-margin" foreground="fg" background="bg"/>
  <style name="bracket-match" foreground="fg" background="bg"/>
  <style name="bracket-mismatch" foreground="bg" background="fg"/>
  <style name="search-match" foreground="bg" background="accent"/>

  <!-- Programming languages -->
  <style name="def:comment" foreground="selection"/>
  <style name="def:constant" foreground="fg"/>
  <style name="def:identifier" foreground="fg"/>
  <style name="def:statement" foreground="fg"/>
  <style name="def:type" foreground="accent"/>
  <style name="def:preprocessor" foreground="accent"/>
  <style name="def:error" foreground="bg" background="accent"/>
  <style name="def:note" foreground="bg" background="accent"/>
  <style name="def:underlined" foreground="fg"/>

  <!-- String highlighting -->
  <style name="def:string" foreground="fg"/>
  <style name="def:special-char" foreground="fg"/>

  <!-- Numbers -->
  <style name="def:number" foreground="fg"/>
  <style name="def:floating-point" foreground="fg"/>

  <!-- Keywords -->
  <style name="def:keyword" foreground="fg"/>
  <style name="def:builtin" foreground="fg"/>
  <style name="def:function" foreground="fg"/>
</style-scheme>
""".printf(bg_hex, fg_hex, selection_hex, accent_hex));

            // Determine the path to save the scheme based on detected version
            var scheme_dir = Path.build_filename(
                                                 Environment.get_home_dir(),
                                                 ".local",
                                                 "share",
                                                 "gtksourceview-%s".printf(sv_version),
                                                 "styles"
            );

            // Create directory if it doesn't exist, with error recovery
            var dir = File.new_for_path(scheme_dir);
            if (!dir.query_exists()) {
                try {
                    dir.make_directory_with_parents();
                } catch (Error e) {
                    debug("Trying alternative directory for GTKSourceView scheme");
                    // Try alternative directory
                    scheme_dir = Path.build_filename(
                                                     Environment.get_user_data_dir(),
                                                     "gtksourceview-%s".printf(sv_version),
                                                     "styles"
                    );
                    dir = File.new_for_path(scheme_dir);
                    if (!dir.query_exists()) {
                        dir.make_directory_with_parents();
                    }
                }
            }

            // Path for scheme file
            var scheme_path = Path.build_filename(scheme_dir, "theme-manager-generated.xml");
            var scheme_file = File.new_for_path(scheme_path);

            // Write the scheme file
            var output = scheme_file.replace(null, false, FileCreateFlags.NONE);
            var data_stream = new DataOutputStream(output);
            data_stream.put_string(builder.str);
            data_stream.close();
        }

        /**
         * Detects the installed GTKSourceView version with caching.
         */
        private string detect_sourceview_version() {
            // Use static variables for caching
            bool version_detected = false;
            string detected_version = "4"; // Default to 4

            // Return cached version if already detected
            if (version_detected) {
                return detected_version;
            }

            // Check for GtkSourceView 5 directory first
            var sv5_dir = Path.build_filename(
                                              Environment.get_home_dir(),
                                              ".local",
                                              "share",
                                              "gtksourceview-5"
            );

            if (FileUtils.test(sv5_dir, FileTest.IS_DIR)) {
                detected_version = "5";
                version_detected = true;
                return detected_version;
            }

            // Check for system-wide installation
            var sys_sv5_dir = Path.build_filename(
                                                  "/usr",
                                                  "share",
                                                  "gtksourceview-5"
            );

            if (FileUtils.test(sys_sv5_dir, FileTest.IS_DIR)) {
                detected_version = "5";
                version_detected = true;
                return detected_version;
            }

            // Default to GTKSourceView 4
            version_detected = true;
            return detected_version;
        }

        /**
         * Converts a Gdk.RGBA color to a hex string without the # prefix.
         */
        private string color_to_hex(Gdk.RGBA color) {
            return "%02x%02x%02x".printf(
                                         (uint) (color.red * 255),
                                         (uint) (color.green * 255),
                                         (uint) (color.blue * 255)
            );
        }

        /**
         * Applies the current theme providers to the application display.
         */
        public void apply_to_display() {
            // Re-add providers to ensure they're applied
            Gtk.StyleContext.add_provider_for_display(
                                                      display,
                                                      base_provider,
                                                      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION - 10
            );

            Gtk.StyleContext.add_provider_for_display(
                                                      display,
                                                      theme_provider,
                                                      Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );

            // If in 1-bit mode, ensure the 1-bit provider is applied
            if (_color_mode == ColorMode.ONE_BIT) {
                Gtk.StyleContext.add_provider_for_display(
                                                          display,
                                                          one_bit_provider,
                                                          Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION - 20
                );
            }
        }

        /**
         * Retrieves a color from the theme by its CSS variable name.
         */
        public Gdk.RGBA get_color(string name) {
            // Use local variable for thread safety
            var local_cache = color_cache;

            // Check cache first for better performance
            var cached_color = local_cache.lookup(name);
            if (cached_color != null) {
                return cached_color;
            }

            // If not in cache, look it up and store it
            var color = Gdk.RGBA();

            // Get style context only once and reuse
            var ctx = dummy_widget.get_style_context();
            if (ctx.lookup_color(name, out color)) {
                // Store in cache for future lookups
                local_cache.insert(name, color);
                return color;
            }

            // Fallback to a default color if lookup fails
            warning("Color '%s' not found in theme", name);
            if (name == "theme_bg" || name == "theme_selection") {
                color.parse("white");
            } else {
                color.parse("black");
            }

            return color;
        }

        /**
         * Gets the path to the current theme file.
         */
        public string get_theme_path() {
            return theme_path;
        }

        /**
         * Sets a new theme using the specified color codes.
         */
        public void set_theme(string bg_color, string fg_color, string sel_color) throws Error {
            if (bg_color.length != 4 || fg_color.length != 4 || sel_color.length != 4) {
                throw new IOError.INVALID_ARGUMENT("Invalid color code format");
            }

            string theme_data = "%s %s %s".printf(sel_color, fg_color, bg_color);

            // Store the original theme data for mode switching
            original_theme_data = theme_data;

            // Skip processing if theme hasn't changed and not in 1-bit mode
            if (last_theme_data != null && last_theme_data == theme_data &&
                _color_mode == ColorMode.TWO_BIT) {
                debug("Theme data unchanged, skipping update");
                return;
            }

            theme_lock.lock();
            try {
                // Save to file
                var file = File.new_for_path(theme_path);
                file.replace_contents(theme_data.data, null, false,
                                      FileCreateFlags.REPLACE_DESTINATION, null);

                // If in 1-bit mode, apply black and white theme
                if (_color_mode == ColorMode.ONE_BIT) {
                    apply_one_bit_mode();
                } else {
                    // Otherwise process and apply the theme data
                    if (!update_theme_variables(theme_data)) {
                        throw new IOError.FAILED("Failed to update theme variables");
                    }
                }

                // Cache the theme data
                last_theme_data = theme_data;

                // Clear color cache when theme changes
                color_cache.remove_all();

                // Schedule GTKSourceView scheme generation to happen in background
                if (generate_sourceview_schemes) {
                    schedule_sourceview_generation();
                }

                theme_changed();
            } finally {
                theme_lock.unlock();
            }
        }

        /**
         * Saves the current color mode to a file.
         */
        public void save_color_mode() throws Error {
            var mode_path = Path.build_filename(
                                                Environment.get_home_dir(),
                                                ".theme-mode"
            );

            var file = File.new_for_path(mode_path);
            file.replace_contents(_color_mode.to_string().data, null, false,
                                  FileCreateFlags.REPLACE_DESTINATION, null);
        }

        /**
         * Loads the color mode from a file.
         */
        public bool load_color_mode() {
            var mode_path = Path.build_filename(
                                                Environment.get_home_dir(),
                                                ".theme-mode"
            );

            if (!FileUtils.test(mode_path, FileTest.EXISTS)) {
                return false;
            }

            try {
                var file = File.new_for_path(mode_path);
                uint8[] contents;
                file.load_contents(null, out contents, null);

                string mode_str = (string) contents;
                ColorMode loaded_mode = ColorMode.from_string(mode_str.strip());

                // Set the mode directly to avoid recursive calls
                if (_color_mode != loaded_mode) {
                    // Store the new mode value
                    _color_mode = loaded_mode;

                    // Apply appropriate theme based on mode
                    if (_color_mode == ColorMode.ONE_BIT) {
                        apply_one_bit_mode();
                    } else {
                        // If switching back to 2-bit mode, restore normal theme
                        if (original_theme_data != null) {
                            update_theme_variables(original_theme_data);
                        }
                    }

                    // Notify about the mode change
                    color_mode_changed(_color_mode);
                }

                return true;
            } catch (Error e) {
                warning("Failed to load color mode: %s", e.message);
                return false;
            }
        }

        /**
         * Cleanup resources when no longer needed.
         */
        ~Manager() {
            // Cancel any pending timeouts
            if (theme_change_timeout_id > 0) {
                Source.remove(theme_change_timeout_id);
                theme_change_timeout_id = 0;
            }

            if (sourceview_generation_timeout_id > 0) {
                Source.remove(sourceview_generation_timeout_id);
                sourceview_generation_timeout_id = 0;
            }

            // Wait for any active worker to complete
            if (worker_active) {
                theme_lock.lock();
                theme_lock.unlock();
            }

            if (monitor != null) {
                monitor.cancel();
                monitor = null;
            }

            color_cache.remove_all();
        }
    }
}
