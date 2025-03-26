project('com.example.nowlog', 'vala', 'c', version: '0.1.0')

gnome = import('gnome')
i18n = import('i18n')

# Convert the app id to a GNOME style path identifier
path_identifier = '/' + meson.project_name().replace('.', '/') + '/'

# Dependencies
gtk_dep = dependency('gtk4')
gee_dep = dependency('gee-0.8')

# Source Files
src_files = [
    'nowlog.vala',
    'shard.vala',
    'shardgrid.vala',
]

gresources = gnome.compile_resources(
    'resources',
    configure_file(
        input: 'gresource.xml.in',
        output: meson.project_name() + '.gresource.xml',
        configuration: {
            'APP_ID': meson.project_name(),
            'APP_PATH': path_identifier,
        },
    ),
    source_dir: meson.current_build_dir(),
    c_name: 'resources',
    install_dir: get_option('datadir') / meson.project_name(),
)

add_project_arguments(
    '--gresourcesdir',
    meson.current_build_dir(),
    language: ['vala'],
)


# Executable
executable(
    'com.example.nowlog',
    gresources,
    src_files,
    dependencies: [
        gtk_dep,
        gee_dep,
        dependency('libtheme-manager-1'),
        meson.get_compiler('c').find_library('m', required: true)
    ],
    install: true,
)

desktop_file = i18n.merge_file(
    input: configure_file(
        input: 'com.example.nowlog.desktop.in.in',
        output: meson.project_name() + '.desktop.in',
        configuration: {
            'ICON_NAME': meson.project_name(),
            'COMMAND': meson.project_name(),
        },
    ),
    output: meson.project_name() + '.desktop',
    po_dir: meson.project_source_root() / 'po',
    type: 'desktop',
    install: true,
    install_dir: get_option('datadir') / 'applications',
)

desktop_file_validate = find_program('desktop-file-validate', required: false)
if desktop_file_validate.found()
    test('validate-desktop', desktop_file_validate, args: [desktop_file])
endif


gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true,
    update_desktop_database: true,
)