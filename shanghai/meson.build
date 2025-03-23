project('com.example.shanghai', ['c', 'vala'], version: '0.1.0')

# Convert the app id to a GNOME style path identifier
path_identifier = '/' + meson.project_name().replace('.', '/') + '/'

gnome = import('gnome')
i18n = import('i18n')

subdir('data')

# Compile settings schema
schemas_dir = join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
install_data('data/com.example.shanghai.gschema.xml', install_dir: schemas_dir)

subdir('src')

gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true,
    update_desktop_database: true,
)
