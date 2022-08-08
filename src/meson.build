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
