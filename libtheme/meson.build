project(
  'libtheme-manager',
  'vala', 'c',
  version: '1.1.0',
  license: 'LGPL-3.0-or-later',
  meson_version: '>=0.59.0',
  default_options: [
        'warning_level=1',
        'buildtype=debugoptimized',
        'c_std=gnu11',
  ]
)

vala_os_arg = ['--define=LINUX']
glib_min_version = '2.50'
add_project_arguments(
    vala_os_arg,
    '--target-glib=' + glib_min_version,
    language: ['vala'],
)

add_project_arguments(
  '-w',
  language: 'c',
)

# Add subdirectories in correct order
subdir('src')
subdir('demo')