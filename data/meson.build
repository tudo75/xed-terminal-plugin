conf_data = configuration_data()
conf_data.set('VERSION', meson.project_version())

config_header = configure_file(
    input: 'terminal-plugin.desktop.in.in',
    output: 'terminal-plugin.desktop.in',
    configuration: conf_data
)

i18n.merge_file(
    input: config_header,
    output: 'terminal.plugin',
    po_dir: join_paths(meson.source_root(), 'po'),
    type: 'desktop',
    install: true,
    install_dir: pluginslibdir,
)

install_data(
    meson.project_name() + '.gschema.xml',
    install_dir: join_paths(
        get_option('datadir'), 
        'glib-2.0', 
        'schemas'
    ),
    rename: meson.project_name() + '.gschema.xml',
)

# not install compile only for local testing
gnome.compile_schemas(
    build_by_default: true,
    depend_files: meson.project_name() + '.gschema.xml',
)
