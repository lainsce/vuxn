project('com.example.donsol', 'vala', 'c',
  version: '0.1.0',
  default_options: [
    'warning_level=2',
  ],
)
gnome = import('gnome')
i18n = import('i18n')

add_project_arguments(
    '-DGETTEXT_PACKAGE="com.example.donsol"',
    language: 'c'
)

# Include source directory
subdir('src')

# Resource files
gresources = gnome.compile_resources(
    'ditto-resources',
    'data/com.example.donsol.gresource.xml',
    source_dir: 'data'
)

# Create the executable
executable(
  'com.example.donsol',
  gresources,
  sources,
  dependencies: [
    dependency('gtk4'),
    dependency('gobject-2.0'),
    dependency('gio-2.0'),
    dependency('glib-2.0'),
    dependency('libtheme-manager-1'),
    meson.get_compiler('vala').find_library('posix', required: true),
    meson.get_compiler('c').find_library('m', required: true),
  ],
  install: true,
)

# Install desktop file
install_data(
    'data/com.example.donsol.desktop',
    install_dir: join_paths(get_option('datadir'), 'applications')
)

# Install icons
install_data(
    'data/icons/com.example.donsol.svg',
    install_dir: join_paths(get_option('datadir'), 'icons/hicolor/scalable/apps')
)

gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true,
    update_desktop_database: true,
)