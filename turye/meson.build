project(
  'com.example.turye',
  'vala',
  'c',
  version: '0.1.0',
  default_options: [
    'warning_level=2',
  ],
)

# Convert the app id to a GNOME style path identifier
path_identifier = '/' + meson.project_name().replace('.', '/') + '/'

gnome = import('gnome')
i18n = import('i18n')

dependencies = [
  dependency('gtk4'),
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gio-2.0'),
  dependency('libtheme-manager-1'),
  meson.get_compiler('vala').find_library('posix', required: true),
  meson.get_compiler('c').find_library('m', required: true)
]

vapi_dir = meson.current_source_dir() / 'vapi'
add_project_arguments('--vapidir', vapi_dir, language: 'vala')

add_project_arguments(
  '-w',
  '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
  language: 'c',
)

subdir('data')

sources = [
  gresources, 
  'src/application.vala',
  'src/utils.vala',
  'src/window.vala',
]

executable(
  'com.example.turye',
  sources,
  dependencies: dependencies,
  install: true,
)

gnome.post_install(
    gtk_update_icon_cache: true,
    update_desktop_database: true,
)
