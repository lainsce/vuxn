add_project_arguments(
  '-w',
  '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
  language: 'c',
)

sources = [
  gresources,
  'main.vala',
  'orca_app.vala',
  'orca_grid.vala',
  'orca_engine.vala',
  'orca_midi.vala',
  'orca_synth.vala',
  'orca_window.vala',
]

dependencies = [
  dependency('gtk4'),
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gio-2.0'),
  dependency('gee-0.8'),
  dependency('gmodule-2.0'),
  dependency('libtheme-manager-1'),
  dependency('gstreamer-1.0'),
  dependency('gstreamer-base-1.0'),
  dependency('gstreamer-audio-1.0'),
  meson.get_compiler('vala').find_library('posix', required: true),
  meson.get_compiler('c').find_library('m', required: true),
]

executable(
  meson.project_name(),
  sources,
  dependencies: dependencies,
  install: true,
)
