# Compile the GResource file
ronin_resources = gnome.compile_resources(
  'com.example.ronin.gresource.xml',
  'com.example.ronin.gresource.xml',
  source_dir: meson.current_build_dir(),
  c_name: 'resources',
  install_dir: get_option('datadir') / 'com.example.ronin',
)

add_project_arguments(
  '--gresourcesdir', meson.current_build_dir(),
  language: ['vala'],
)

# Install prelude
install_data(
  'prelude.lisp',
  install_dir: get_option('datadir') / 'com.example.ronin',
)

# Install desktop file
desktop_file = i18n.merge_file(
  input: 'com.example.ronin.desktop.in',
  output: 'com.example.ronin.desktop',
  type: 'desktop',
  po_dir: '../po',
  install: true,
  install_dir: get_option('datadir') / 'applications',
)

# Validate desktop file
desktop_utils = find_program('desktop-file-validate', required: false)
if desktop_utils.found()
  test('Validate desktop file', desktop_utils, args: [desktop_file])
endif

# Install icons
install_data(
  'icons' / 'com.example.ronin.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps',
)
