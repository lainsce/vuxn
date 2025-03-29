# Compile the GResource file
ronin_resources = gnome.compile_resources(
  app_id,
  app_id + '.gresource.xml',
  gresource_bundle: true,
  install: true,
  install_dir: get_option('datadir') / 'ronin',
)

# Install prelude
install_data(
  'prelude.lisp',
  install_dir: get_option('datadir') / 'ronin',
)

# Install desktop file
desktop_file = i18n.merge_file(
  input: app_id + '.desktop.in',
  output: app_id + '.desktop',
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
  'icons' / app_id + '.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps',
)
