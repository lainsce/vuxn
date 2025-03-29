# Update the src/meson.build to correctly compile and install resources
ronin_sources = [
  'main.vala',
  'ronin.vala',
  'lain.vala',
]

ronin_deps = dependencies

# Create executable
executable(
  'com.example.ronin',
  ronin_resources,
  ronin_sources,
  vala_args: [
    '--target-glib=2.66',
  ],
  dependencies: ronin_deps,
  install: true,
)
