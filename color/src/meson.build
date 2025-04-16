add_project_arguments(
  '-w',
  '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
  language: 'c',
)

sources = [gresources, 'application.vala', 'picker.vala', 'window.vala', 'utils.vala', 'x11_helper.c']

dependencies = [
  dependency('gtk4'),
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gio-2.0'),
  dependency('gee-0.8'),
  dependency('gmodule-2.0'),
  dependency('libtheme-manager-1'),
  dependency('x11'),           # For X11
  meson.get_compiler('vala').find_library('posix', required: true),
  meson.get_compiler('c').find_library('m', required: true),
]

executable(
  meson.project_name(),
  sources,
  dependencies: dependencies,
  install: true,
)
