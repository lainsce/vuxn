# Theme Manager

A system-wide theme manager for GTK4 applications  
based on Varavara's interface customization standard.  
[Read More](https://wiki.xxiivv.com/site/theme.html)

## Building

```bash
meson setup build
ninja -C build
sudo ninja -C build install
```

## Usage

```vala
public class MyApp : Gtk.Application {
    Theme.Manager theme = Theme.Manager.get_default();
}
```

## License

LGPL-3.0-or-later

## To Use This Library

1. Clone the repository

2. Build and install:

```bash
meson setup build
ninja -C build
sudo ninja -C build install
```

3.In your application's meson.build:

```meson
project_dependencies = [
  dependency('theme-1'),
  dependency('gtk4')
]

executable('myapp', 'src/main.vala', dependencies: project_dependencies)
```