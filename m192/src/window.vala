public class Window : He.ApplicationWindow {
    private Gtk.Box main_box;
    private Gtk.Box header_box;
    private Gtk.Box controls_box;
    private Gtk.Label window_title_label;
    private MarqueeLabel title_label;
    private Gtk.Label album_label;
    private Gtk.Label artist_label;
    private Gtk.Label time_label_current;
    private Gtk.Label time_label_total;
    private Gtk.ProgressBar progress_bar;
    private Gtk.ListBox music_list;
    private File music_dir;
    private File current_directory;
    private Gst.Element player;
    private uint progress_timeout;
    private Gtk.ListBoxRow current_row;
    private Gtk.Button play_button;
    private Gtk.Button prev_button;
    private Gtk.Button next_button;
    private Gtk.Button repeat_button; // New repeat button
    private Gtk.Button shuffle_button; // New shuffle button
    private Gtk.Image play_icon;
    private Gtk.Image pause_icon;
    private Gtk.Image repeat_icon; // New repeat icon
    private Gtk.Image repeat_active_icon; // New active repeat icon
    private Gtk.Image shuffle_icon; // New shuffle icon
    private Gtk.Image shuffle_active_icon; // New active shuffle icon
    private Gst.PbUtils.Discoverer discoverer;
    private bool repeat_enabled = false; // Track repeat state
    private bool shuffle_enabled = false; // Track shuffle state

    public Window(He.Application app) {
        GLib.Object(application: app);

        this.title = "M192";
        this.default_width = 128;
        this.default_height = 450;
        this.resizable = false;
        this.add_css_class("window");

        setup_ui();
        setup_discoverer();
        load_music_files();
        setup_player();
    }

    private void setup_ui() {
        main_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        this.set_child(main_box);

        main_box.append(create_titlebar());

        // Header section
        header_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 5);
        header_box.margin_top = 11;
        header_box.add_css_class("header-box");

        // Title and album info
        title_label = new MarqueeLabel();
        title_label.text = "No Track";
        header_box.append(title_label);

        artist_label = new Gtk.Label("Unknown Artist");
        artist_label.add_css_class("artist-label");
        artist_label.halign = Gtk.Align.CENTER;
        header_box.append(artist_label);

        album_label = new Gtk.Label("Unknown Album");
        album_label.add_css_class("album-label");
        album_label.halign = Gtk.Align.CENTER;
        header_box.append(album_label);

        main_box.append(header_box);

        // Controls section
        controls_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
        controls_box.valign = Gtk.Align.CENTER;
        controls_box.add_css_class("controls-box");

        // Player controls (repeat, prev, play/pause, next, shuffle)
        var player_controls = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 13);
        player_controls.halign = Gtk.Align.CENTER;
        player_controls.margin_top = 8;
        player_controls.margin_bottom = 8;

        // Create icons for buttons
        repeat_icon = new Gtk.Image.from_icon_name("no-repeat-symbolic");
        repeat_icon.pixel_size = 16;

        repeat_active_icon = new Gtk.Image.from_icon_name("repeat-symbolic");
        repeat_active_icon.pixel_size = 16;
        repeat_active_icon.add_css_class("active-control-icon");

        var prev_icon = new Gtk.Image.from_icon_name("previous-symbolic");
        prev_icon.pixel_size = 16;

        play_icon = new Gtk.Image.from_icon_name("play-symbolic");
        play_icon.pixel_size = 16;

        pause_icon = new Gtk.Image.from_icon_name("pause-symbolic");
        pause_icon.pixel_size = 16;

        var next_icon = new Gtk.Image.from_icon_name("next-symbolic");
        next_icon.pixel_size = 16;

        shuffle_icon = new Gtk.Image.from_icon_name("no-shuffle-symbolic");
        shuffle_icon.pixel_size = 16;

        shuffle_active_icon = new Gtk.Image.from_icon_name("shuffle-symbolic");
        shuffle_active_icon.pixel_size = 16;
        shuffle_active_icon.add_css_class("active-control-icon");

        // Create buttons with icons
        repeat_button = new Gtk.Button();
        repeat_button.set_child(repeat_icon);
        repeat_button.valign = Gtk.Align.CENTER;
        repeat_button.add_css_class("control-button");
        repeat_button.tooltip_text = "Repeat";

        prev_button = new Gtk.Button();
        prev_button.set_child(prev_icon);
        prev_button.valign = Gtk.Align.CENTER;
        prev_button.add_css_class("control-button");
        prev_button.tooltip_text = "Previous";

        play_button = new Gtk.Button();
        play_button.set_child(play_icon);
        play_button.valign = Gtk.Align.CENTER;
        play_button.add_css_class("control-button-main");
        play_button.tooltip_text = "Play";

        next_button = new Gtk.Button();
        next_button.set_child(next_icon);
        next_button.valign = Gtk.Align.CENTER;
        next_button.add_css_class("control-button");
        next_button.tooltip_text = "Next";

        shuffle_button = new Gtk.Button();
        shuffle_button.set_child(shuffle_icon);
        shuffle_button.valign = Gtk.Align.CENTER;
        shuffle_button.add_css_class("control-button");
        shuffle_button.tooltip_text = "Shuffle";

        player_controls.append(repeat_button);
        player_controls.append(prev_button);
        player_controls.append(play_button);
        player_controls.append(next_button);
        player_controls.append(shuffle_button);

        controls_box.append(player_controls);

        // Time display
        var timed_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
        timed_box.valign = Gtk.Align.CENTER;
        timed_box.add_css_class("timed-box");
        var time_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);

        time_label_current = new Gtk.Label("--:--");
        time_label_current.add_css_class("time-label");
        time_label_current.halign = Gtk.Align.START;
        time_label_current.margin_start = 9;

        time_label_total = new Gtk.Label("--:--");
        time_label_total.add_css_class("time-label");
        time_label_total.halign = Gtk.Align.END;
        time_label_total.hexpand = true;
        time_label_total.margin_end = 9;

        time_box.append(time_label_current);
        time_box.append(time_label_total);
        timed_box.append(time_box);

        // Progress bar
        progress_bar = new Gtk.ProgressBar();
        progress_bar.add_css_class("progress-bar");
        progress_bar.fraction = 0.0;
        progress_bar.margin_start = 6;
        progress_bar.margin_end = 6;
        timed_box.append(progress_bar);

        main_box.append(controls_box);
        main_box.append(timed_box);

        // Music list
        music_list = new Gtk.ListBox();
        music_list.add_css_class("music-list");
        music_list.selection_mode = Gtk.SelectionMode.SINGLE;
        music_list.row_activated.connect(on_row_activated);

        var scrolled = new Gtk.ScrolledWindow();
        scrolled.set_child(music_list);
        scrolled.vexpand = true;

        main_box.append(scrolled);

        // Connect button signals
        play_button.clicked.connect(on_play_clicked);
        prev_button.clicked.connect(on_prev_clicked);
        next_button.clicked.connect(on_next_clicked);
        repeat_button.clicked.connect(on_repeat_clicked);
        shuffle_button.clicked.connect(on_shuffle_clicked);
    }

    private Gtk.Widget create_titlebar() {
        // Create classic Mac-style title bar
        var title_bar = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        title_bar.width_request = 128;
        title_bar.add_css_class("title-bar");

        // Close button on the left
        var close_button = new Gtk.Button();
        close_button.add_css_class("close-button");
        close_button.tooltip_text = "Close";
        close_button.valign = Gtk.Align.CENTER;
        close_button.margin_start = 8;
        close_button.clicked.connect(() => {
            this.close();
        });

        window_title_label = new Gtk.Label("M192");
        window_title_label.add_css_class("title-box");
        window_title_label.hexpand = true;
        window_title_label.max_width_chars = 17;
        window_title_label.ellipsize = Pango.EllipsizeMode.START;
        window_title_label.valign = Gtk.Align.CENTER;
        window_title_label.halign = Gtk.Align.CENTER;

        title_bar.append(close_button);
        title_bar.append(window_title_label);

        var winhandle = new Gtk.WindowHandle();
        winhandle.set_child(title_bar);

        // Main layout
        var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
        vbox.append(winhandle);

        return vbox;
    }

    private void setup_discoverer() {
        try {
            discoverer = new Gst.PbUtils.Discoverer((Gst.ClockTime) (5 * Gst.SECOND));
        } catch (Error e) {
            warning("Failed to create discoverer: %s", e.message);
        }
    }

    private void on_play_clicked() {
        if (player.current_state == Gst.State.PLAYING) {
            player.set_state(Gst.State.PAUSED);
            update_play_button_state(false);
        } else {
            // If nothing is playing, start the first track
            if (current_row == null) {
                var first_row = music_list.get_row_at_index(0);
                if (first_row != null) {
                    music_list.select_row(first_row);
                    on_row_activated(first_row);
                    return;
                }
            }
            player.set_state(Gst.State.PLAYING);
            update_play_button_state(true);
        }
    }

    // New function to handle repeat button click
    private void on_repeat_clicked() {
        repeat_enabled = !repeat_enabled;
        update_repeat_button_state();
    }

    // New function to handle shuffle button click
    private void on_shuffle_clicked() {
        shuffle_enabled = !shuffle_enabled;
        update_shuffle_button_state();
    }

    // New function to update repeat button state
    private void update_repeat_button_state() {
        var current_child = repeat_button.get_child();
        if (current_child != null) {
            repeat_button.set_child(null);
        }

        if (repeat_enabled) {
            repeat_button.set_child(repeat_active_icon);
            repeat_button.tooltip_text = "Repeat: On";
        } else {
            repeat_button.set_child(repeat_icon);
            repeat_button.tooltip_text = "Repeat: Off";
        }
    }

    // New function to update shuffle button state
    private void update_shuffle_button_state() {
        var current_child = shuffle_button.get_child();
        if (current_child != null) {
            shuffle_button.set_child(null);
        }

        if (shuffle_enabled) {
            shuffle_button.set_child(shuffle_active_icon);
            shuffle_button.tooltip_text = "Shuffle: On";
        } else {
            shuffle_button.set_child(shuffle_icon);
            shuffle_button.tooltip_text = "Shuffle: Off";
        }
    }

    private void update_play_button_state(bool is_playing) {
        var current_child = play_button.get_child();
        if (current_child != null) {
            play_button.set_child(null);
        }

        if (is_playing) {
            play_button.set_child(pause_icon);
            play_button.tooltip_text = "Pause";
        } else {
            play_button.set_child(play_icon);
            play_button.tooltip_text = "Play";
        }
    }

    private void on_prev_clicked() {
        play_previous_track();
    }

    private void on_next_clicked() {
        play_next_track();
    }

    private void play_previous_track() {
        if (current_row == null)return;

        // Get the index of the current row
        int current_index = current_row.get_index();

        if (shuffle_enabled) {
            play_random_track();
            return;
        }

        // Check if there's a previous row
        if (current_index > 0) {
            var prev_row = music_list.get_row_at_index(current_index - 1);
            music_list.select_row(prev_row);
            on_row_activated(prev_row);
        } else if (repeat_enabled) {
            // If repeat is enabled and we're at the first track, go to the last track
            int last_index = get_last_track_index();
            if (last_index >= 0) {
                var last_row = music_list.get_row_at_index(last_index);
                music_list.select_row(last_row);
                on_row_activated(last_row);
            }
        }
    }

    private void play_next_track() {
        if (current_row == null)return;

        // If repeat is enabled and no shuffle, just replay current track
        if (repeat_enabled && !shuffle_enabled) {
            on_row_activated(current_row);
            return;
        }

        // If shuffle is enabled, play a random track
        if (shuffle_enabled) {
            play_random_track();
            return;
        }

        // Otherwise, play the next track in sequence
        int current_index = current_row.get_index();
        var next_row = music_list.get_row_at_index(current_index + 1);

        if (next_row != null) {
            music_list.select_row(next_row);
            on_row_activated(next_row);
        } else if (repeat_enabled) {
            // If repeat is enabled and we're at the last track, go back to the first track
            var first_row = music_list.get_row_at_index(0);
            if (first_row != null) {
                music_list.select_row(first_row);
                on_row_activated(first_row);
            }
        }
    }

    // New function to play a random track
    private void play_random_track() {
        // Count the number of tracks
        int track_count = 0;
        var row = music_list.get_first_child();
        while (row != null) {
            if (row is Gtk.ListBoxRow) {
                track_count++;
            }
            row = row.get_next_sibling();
        }

        if (track_count <= 1)return;

        // Pick a random track that's not the current one
        int current_index = current_row.get_index();
        int random_index = 0;

        do {
            random_index = GLib.Random.int_range(0, track_count);
        } while (random_index == current_index && track_count > 1);

        var random_row = music_list.get_row_at_index(random_index);
        if (random_row != null) {
            music_list.select_row(random_row);
            on_row_activated(random_row);
        }
    }

    // Helper function to get the index of the last track
    private int get_last_track_index() {
        int last_index = -1;
        var row = music_list.get_first_child();
        while (row != null) {
            if (row is Gtk.ListBoxRow) {
                last_index++;
            }
            row = row.get_next_sibling();
        }
        return last_index;
    }

    // Update play indicator on all rows
    private void update_play_indicator(Gtk.ListBoxRow? playing_row) {
        // Clear all indicators first
        var row = music_list.get_first_child();
        while (row != null) {
            if (row is Gtk.ListBoxRow) {
                var box = (Gtk.Box) ((Gtk.ListBoxRow) row).get_child();
                var first_child = box.get_first_child();

                // Check for both Label and PixelPlayIndicator
                if (first_child != null) {
                    if (first_child is Gtk.Label) {
                        var label = (Gtk.Label) first_child;
                        if (label.has_css_class("play-indicator")) {
                            label.label = "⠀";
                        }
                    } else if (first_child is Indicator) {
                        var indicator = (Indicator) first_child;
                        indicator.playing = false;
                    }
                }
            }
            row = row.get_next_sibling();
        }

        // Set indicator on the playing row
        if (playing_row != null) {
            var box = (Gtk.Box) playing_row.get_child();
            var first_child = box.get_first_child();

            if (first_child != null) {
                if (first_child is Gtk.Label) {
                    // Fallback to old indicator if no PixelPlayIndicator
                    var label = (Gtk.Label) first_child;
                    if (label.has_css_class("play-indicator")) {
                        label.label = "⠀";
                    }
                } else if (first_child is Indicator) {
                    var indicator = (Indicator) first_child;
                    // Show pixel indicator when playing
                    indicator.playing = true;
                }
            }
        }
    }

    private void load_music_files() {
        music_dir = File.new_for_path(Environment.get_home_dir() + "/Music");
        current_directory = music_dir;

        if (!music_dir.query_exists()) {
            warning("Music directory doesn't exist: %s", music_dir.get_path());
            return;
        }

        print("Scanning music directory: %s\n", music_dir.get_path());

        // Clear existing list and populate with directory contents
        music_list.remove_all();
        populate_directory_list(current_directory);
    }

    private void populate_directory_list(File dir) {
        try {
            var enumerator = dir.enumerate_children(
                                                    "standard::name,standard::type,standard::content-type",
                                                    FileQueryInfoFlags.NONE,
                                                    null
            );

            FileInfo file_info;
            var directory_items = new List<FileInfo> ();
            var file_items = new List<FileInfo> ();

            // First, separate directories and files
            while ((file_info = enumerator.next_file(null)) != null) {
                var name = file_info.get_name();

                // Skip hidden files/folders
                if (name.has_prefix("."))continue;

                if (file_info.get_file_type() == FileType.DIRECTORY) {
                    directory_items.append(file_info);
                } else if (file_info.get_file_type() == FileType.REGULAR) {
                    // Check for music file extensions
                    if (name.has_suffix(".mp3") ||
                        name.has_suffix(".flac") ||
                        name.has_suffix(".wav") ||
                        name.has_suffix(".ogg") ||
                        name.has_suffix(".m4a")) {
                        file_items.append(file_info);
                    }
                }
            }

            // Sort directories and files alphabetically
            directory_items.sort((a, b) =>
                                 strcmp(a.get_name().down(), b.get_name().down())
            );
            file_items.sort((a, b) =>
                            strcmp(a.get_name().down(), b.get_name().down())
            );

            // Add a "Back" option if not at the root Music directory
            if (!dir.equal(music_dir)) {
                var back_row = new Gtk.ListBoxRow();
                var back_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
                var back_label = new Gtk.Label("⠀...");
                back_label.halign = Gtk.Align.START;
                back_label.hexpand = true;
                back_box.append(back_label);
                back_row.set_child(back_box);
                back_row.set_data("is_back_option", true);
                music_list.append(back_row);
            }

            // Add directories first
            foreach (var dir_info in directory_items) {
                var row = new Gtk.ListBoxRow();
                var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);

                // Add play indicator that will show when this track is playing
                var indicator = new Indicator();
                indicator.add_css_class("play-indicator");

                var label = new Gtk.Label(dir_info.get_name());
                label.halign = Gtk.Align.START;
                label.hexpand = true;
                label.ellipsize = Pango.EllipsizeMode.END;

		var dir_label = new Gtk.Label(">");
                dir_label.halign = Gtk.Align.END;
		dir_label.margin_end = 8;
                dir_label.ellipsize = Pango.EllipsizeMode.END;

                box.append(indicator);
                box.append(label);
		box.append(dir_label);
                row.set_child(box);
                row.set_data("file", dir.get_child(dir_info.get_name()));
                row.set_data("is_directory", true);

                music_list.append(row);
            }

            // Then add music files
            foreach (var file_inf in file_items) {
                var child = dir.get_child(file_inf.get_name());
                var track_info = Utils.extract_metadata(discoverer, child.get_path());

                var row = new Gtk.ListBoxRow();
                var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);

                // Add play indicator that will show when this track is playing
                Gtk.Widget indicator;
                indicator = new Indicator();
                indicator.add_css_class("play-indicator");
                ((Indicator) indicator).playing = false; // Default hidden

                box.append(indicator);

                var label = new Gtk.Label(track_info.title);
                label.halign = Gtk.Align.START;
                label.hexpand = true;
                label.ellipsize = Pango.EllipsizeMode.END;
                label.valign = Gtk.Align.CENTER;

                box.append(label);

                row.set_child(box);
                row.set_data("track-info", track_info);
                row.set_data("file-path", child.get_path());
                music_list.append(row);
            }

            // If no items found, add a "No items" row
            if (directory_items.length() + file_items.length() == 0) {
                var no_items_row = new Gtk.ListBoxRow();
                var label = new Gtk.Label("No items");
                label.halign = Gtk.Align.CENTER;
                label.margin_top = label.margin_bottom = 20;
                no_items_row.set_child(label);
                music_list.append(no_items_row);
            }

            // Update window title with current directory path
            update_title_with_current_path(dir);
        } catch (Error e) {
            warning("Error scanning directory: %s", e.message);
        }
    }

    private void scan_for_music_files(File dir) throws Error {
        var enumerator = dir.enumerate_children(
                                                "standard::name,standard::type", 0, null);

        FileInfo file_info;
        while ((file_info = enumerator.next_file(null)) != null) {
            var name = file_info.get_name();
            var child = dir.get_child(name);

            if (file_info.get_file_type() == FileType.DIRECTORY) {
                // Recursively scan subdirectories
                scan_for_music_files(child);
            } else if (file_info.get_file_type() == FileType.REGULAR) {
                // Check for music file extensions
                if (name.has_suffix(".mp3") ||
                    name.has_suffix(".flac") ||
                    name.has_suffix(".wav") ||
                    name.has_suffix(".ogg") ||
                    name.has_suffix(".m4a")) {

                    // Extract metadata
                    var track_info = Utils.extract_metadata(discoverer, child.get_path());

                    // Add this music file to the list
                    var row = new Gtk.ListBoxRow();

                    var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);

                    // Add play indicator that will show when this track is playing
                    Gtk.Widget indicator = new Indicator();
                    indicator.add_css_class("play-indicator");
                    ((Indicator) indicator).playing = false;

                    box.append(indicator);

                    var label = new Gtk.Label(track_info.title);
                    label.halign = Gtk.Align.START;
                    label.hexpand = true;
                    label.ellipsize = Pango.EllipsizeMode.END;
                    label.valign = Gtk.Align.CENTER;

                    box.append(label);

                    row.set_child(box);
                    row.set_data("track-info", track_info);
                    row.set_data("file-path", child.get_path());
                    music_list.append(row);

                    print("Added music file: %s\n", child.get_path());
                }
            }
        }
    }

    private void setup_player() {
        player = Gst.ElementFactory.make("playbin3", "player");
        if (player == null) {
            error("Failed to create playbin element. Check GStreamer installation.");
        }

        // Set default volume (0.0 to 1.0)
        player.set_property("volume", 0.7);

        // Connect to bus for messages
        var bus = player.get_bus();
        bus.add_watch(GLib.Priority.DEFAULT, on_bus_message);

        print("GStreamer player initialized\n");
    }

    private bool on_bus_message(Gst.Bus bus, Gst.Message msg) {
        switch (msg.type) {
        case Gst.MessageType.EOS :
            print("End of stream reached\n");
            player.set_state(Gst.State.NULL);
            update_play_indicator(null);

            // If repeat is enabled, play the same track again
            if (repeat_enabled && !shuffle_enabled && current_row != null) {
                on_row_activated(current_row);
            } else {
                play_next_track();
            }
            break;

        case Gst.MessageType.ERROR:
            Error err;
            string debug;
            msg.parse_error(out err, out debug);
            print("Playback error: %s\nDebug info: %s\n", err.message, debug);
            player.set_state(Gst.State.NULL);
            reset_progress();
            update_play_button_state(false);
            update_play_indicator(null);
            break;

        case Gst.MessageType.STATE_CHANGED:
            if (msg.src == player) {
                Gst.State old_state, new_state, pending;
                msg.parse_state_changed(out old_state, out new_state, out pending);
                print("Player state changed: %s -> %s (pending: %s)\n",
                      old_state.to_string(), new_state.to_string(), pending.to_string());

                if (new_state == Gst.State.PLAYING) {
                    update_play_button_state(true);
                    update_play_indicator(current_row);
                    title_label.start();
                } else if (new_state == Gst.State.PAUSED || new_state == Gst.State.NULL) {
                    update_play_button_state(false);
                    title_label.stop();
                    // Keep indicator when paused
                    if (new_state == Gst.State.NULL) {
                        update_play_indicator(null);
                    }
                }
            }
            break;

        case Gst.MessageType.TAG:
            Gst.TagList tag_list;
            msg.parse_tag(out tag_list);

            // Update track info if we receive new tag information
            if (current_row != null) {
                Utils.TrackInfo info = (Utils.TrackInfo) current_row.get_data<Utils.TrackInfo> ("track-info");

                // Update artist if available
                string artist;
                if (tag_list.get_string(Gst.Tags.ARTIST, out artist)) {
                    info.artist = artist;
                    artist_label.label = artist;
                }

                // Update album if available
                string album;
                if (tag_list.get_string(Gst.Tags.ALBUM, out album)) {
                    info.album = album;
                    album_label.label = album;
                }

                // Update title if available
                string title;
                if (tag_list.get_string(Gst.Tags.TITLE, out title)) {
                    info.title = title;
                    title_label.text = title;
                }
            }
            break;

        default:
            break;
        }
        return true;
    }

    private void reset_progress() {
        progress_bar.fraction = 0;
        time_label_current.label = "--:--";
        time_label_total.label = "--:--";
    }

    private void on_row_activated(Gtk.ListBoxRow row) {
        // Check if this is a "Back" option
        var is_back = row.get_data<bool> ("is_back_option");
        if (is_back) {
            // Go back to parent directory
            var parent_dir = current_directory.get_parent();
            if (parent_dir != null) {
                current_directory = parent_dir;
                music_list.remove_all();
                populate_directory_list(current_directory);
            }
            return;
        }

        // Check if this is a directory
        var is_directory = row.get_data<bool> ("is_directory");
        if (is_directory) {
            // Navigate into the directory
            var dir = row.get_data<File> ("file");
            if (dir != null) {
                current_directory = dir;
                music_list.remove_all();
                populate_directory_list(current_directory);
            }
            return;
        }

        // If it's a music file, proceed with existing playback logic
        // Stop any currently playing audio
        player.set_state(Gst.State.NULL);

        current_row = row;

        // Get the file path and track info
        string file_path = (string) row.get_data<string> ("file-path");
        Utils.TrackInfo track_info = (Utils.TrackInfo) row.get_data<Utils.TrackInfo> ("track-info");

        if (file_path == null || track_info == null) {
            return;
        }

        // Update UI with track info
        title_label.text = track_info.title;
        artist_label.label = track_info.artist;
        album_label.label = track_info.album;
        time_label_current.label = "00:00";

        title_label.start();

        // Update play indicator
        update_play_indicator(row);

        // Set the URI and play
        var file = File.new_for_path(file_path);
        player.set_property("uri", file.get_uri());

        print("Playing: %s\n", file.get_uri());
        player.set_state(Gst.State.PLAYING);
        update_play_button_state(true);

        // Start progress tracking
        if (progress_timeout != 0) {
            GLib.Source.remove(progress_timeout);
        }
        progress_timeout = GLib.Timeout.add(500, update_progress);
    }

    private void update_title_with_current_path(File dir) {
        // Get relative path from Music directory
        string relative_path = "";
        try {
            relative_path = music_dir.get_relative_path(dir);
        } catch (Error e) {
            // If we can't get relative path, just use the directory name
            relative_path = dir.get_basename();
        }

        // Update the title in the title bar
        window_title_label.label = relative_path != "" ? "/" + relative_path : "/Music";
    }

    private bool update_progress() {
        if (player.current_state != Gst.State.PLAYING) {
            return true; // Keep the timer active even when paused
        }

        Gst.Format fmt = Gst.Format.TIME;
        int64 duration, position = 0;

        if (player.query_duration(fmt, out duration) &&
            player.query_position(fmt, out position)) {

            double fraction = (double) position / (double) duration;
            progress_bar.fraction = fraction;

            time_label_current.label = Utils.format_time(position);
            time_label_total.label = Utils.format_time(duration);
        }

        return true;
    }
}
