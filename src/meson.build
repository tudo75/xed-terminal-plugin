conf = configuration_data()
conf.set('prefix', get_option('prefix'))
conf.set('libdir', get_option ('libdir'))
conf.set('PROJECT_NAME', 'com.github.tudo75.xed-terminal-plugin')
conf.set('PROJECT_VERSION', meson.project_version())

pluginsdatadir = join_paths(datadir, 'xed', 'plugins')
pluginslibdir = join_paths(libdir, 'xed', 'plugins')

sources = files(
    'terminal.vala',
)

libterminal = library(
    'terminal',
    sources,
    vala_header: 'terminal.h',
    dependencies : dependencies,
    vala_args: [
        '--abi-stability'
    ],
    install: true,
    include_directories: include_dirs,
    install_rpath: join_paths(prefix, libdir, 'xed'),
    install_dir: [
        pluginslibdir,
        true,
        vapidir,
    ]
)
