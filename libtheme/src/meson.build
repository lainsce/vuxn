theme_sources = []
theme_sources += files(
    'theme-manager.vala',
)

glib_min_version = '2.50'
gio_os_dep = dependency('gio-unix-2.0', version: '>=' + glib_min_version)
theme_deps = [
    dependency('gio-2.0', version: '>=' + glib_min_version),
    gio_os_dep,
    dependency('gtk4'),
    dependency('glib-2.0', version: '>=' + glib_min_version),
    dependency('gobject-2.0', version: '>=' + glib_min_version),
    dependency('gee-0.8'),
]

gnome = import('gnome')

# define all the names and versions
theme_gi_name = 'Theme'
theme_gi_version = '1'
theme_gi = theme_gi_name + '-' + theme_gi_version
theme_gir = theme_gi + '.gir'
theme_typelib = theme_gi + '.typelib'
theme_c_args = ['-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name())]
theme_vala_args = ['--abi-stability']

include_dir = join_paths(get_option('prefix'), get_option('includedir'))

# compile shared library, generate GIR, header, and vapi file
datadir = get_option('datadir')
typelibdir = get_option('libdir') / 'girepository-1.0'


gresource = gnome.compile_resources(
    'th-gresource',
    '..' / 'data' / 'lib.gresources.xml',
    source_dir: '../data',
)

theme = shared_library(
    'libtheme-manager-1',

    gresource,
    theme_sources,

    dependencies: [
        dependency('gtk4'),
        dependency('gee-0.8'),
    ],

    vala_gir: theme_gir,
    vala_header: 'libtheme-manager-1.h',
    vala_vapi: 'libtheme-manager-1.vapi',

    vala_args: theme_vala_args,
    c_args: theme_c_args,

    version: theme_gi_version,
    install: true,
    install_dir: [true, include_dir, true, true],
    name_prefix: '',
)

pkg = import('pkgconfig')
pkg.generate(
    theme,
    requires: ['gtk4'],
    description: 'Varavara Theme Framework'
)

libtheme_dep = declare_dependency(
    dependencies: [theme_deps],
    include_directories: [include_directories('.')],
    link_with: theme,
)