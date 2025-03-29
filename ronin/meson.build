project(
  'com.example.ronin',
  'vala',
  'c',
  version: '0.1.0',
  meson_version: '>= 0.57.0',
  default_options: [
    'warning_level=2',
  ],
)

# Application ID
app_id = 'com.example.ronin'

# Import modules
gnome = import('gnome')
i18n = import('i18n')

# Set up vala compiler options
add_project_arguments('-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()), language: 'c')

# Get compilation dependencies
dependencies = [
  dependency('glib-2.0', version: '>= 2.66'),
  dependency('gobject-2.0'),
  dependency('gtk4', version: '>= 4.4.0'),
  dependency('cairo'),
  dependency('gee-0.8'),
  dependency('libtheme-manager-1'),
  meson.get_compiler('vala').find_library('posix', required: true),
  meson.get_compiler('c').find_library('m', required: true),
]

# Add subfolders
subdir('data')
subdir('src')
subdir('po')

gnome.post_install(
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
