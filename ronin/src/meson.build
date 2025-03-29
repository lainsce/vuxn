# Update the src/meson.build to correctly compile and install resources
ronin_sources = [
  'main.vala',
  'ronin.vala',
  'lain.vala',
]

ronin_deps = dependencies

# Create executable
executable(
  meson.project_name(),
  ronin_sources + ronin_resources,
  vala_args: [
    '--target-glib=2.66',
  ],
  dependencies: ronin_deps,
  install: true,
)
