project('com.example.orca', 'vala', 'c')

# Add gnome module for GResource handling
gnome = import('gnome')

gtkdep = dependency('gtk4')
gst_dep = dependency('gstreamer-1.0')
gstbase_dep = dependency('gstreamer-base-1.0')
gstaudio_dep = dependency('gstreamer-audio-1.0')

# Define resource files
gresource = gnome.compile_resources(
    'com.example.orca.resources',
    'data/com.example.orca.gresource.xml',
    source_dir: 'data',
    c_name: 'orca_resources'
)

# Application icon installation
install_data(
    'data/icons/com.example.orca.svg',
    install_dir: join_paths(get_option('datadir'), 'icons/hicolor/scalable/apps')
)

executable(
    'com.example.orca',
    'src/main.vala',
    'src/orca_app.vala',
    'src/orca_grid.vala',
    'src/orca_engine.vala',
    'src/orca_midi.vala',
    'src/orca_synth.vala',
    'src/orca_window.vala',
    gresource,  # Include compiled resources
    dependencies: [
        gtkdep,
        gst_dep,
        gstbase_dep,
        gstaudio_dep,
        dependency('alsa'),
        dependency('libtheme-manager-1'),
        dependency('gee-0.8'),
        meson.get_compiler('c').find_library('m', required: true)
    ],
    install: true
)

# Desktop file installation
install_data(
    'data/com.example.orca.desktop',
    install_dir: join_paths(get_option('datadir'), 'applications')
)

gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true,
    update_desktop_database: true,
)