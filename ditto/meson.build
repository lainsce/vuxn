project(
    'com.example.ditto',
    'vala',
    'c',
    version: '0.1.0'
)

gnome = import('gnome')
i18n = import('i18n')

add_project_arguments(
    '-DGETTEXT_PACKAGE="com.example.ditto"',
    language: 'c'
)

# Dependencies
dependencies = [
    dependency('gtk4'),
    dependency('gobject-2.0'),
    dependency('gio-2.0'),
    dependency('glib-2.0'),
    dependency('libtheme-manager-1'),
    meson.get_compiler('vala').find_library('posix', required: true),
    meson.get_compiler('c').find_library('m', required: true),
]

# Resource files
resources = gnome.compile_resources(
    'ditto-resources',
    'data/com.example.ditto.gresource.xml',
    source_dir: 'data'
)

# Source files
sources = [
    'src/application.vala',
    'src/indicator.vala',
    'src/window.vala',
    'src/utils.vala'
]

# Create executable
executable(
    'com.example.ditto',
    sources,
    resources,
    dependencies: dependencies,
    install: true
)

# Install desktop file
install_data(
    'data/com.example.ditto.desktop',
    install_dir: join_paths(get_option('datadir'), 'applications')
)

# Install icons
install_data(
    'data/icons/com.example.ditto.svg',
    install_dir: join_paths(get_option('datadir'), 'icons/hicolor/scalable/apps')
)

gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true,
    update_desktop_database: true,
)
