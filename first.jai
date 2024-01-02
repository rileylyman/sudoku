build :: () {
    context.print_style.default_format_struct.use_newlines_if_long_form = true;
    compiler.set_build_options_dc(.{do_output=false});
    w := compiler.compiler_create_workspace("Target Program");

    build_opts := compiler.get_build_options(w);
    build_opts.output_executable_name = "target";
    build_opts.output_path = ".build";
    import_path: [..] string;
    array_copy(*import_path, build_opts.import_path);
    array_add(*import_path, "src/", ".");
    build_opts.import_path = import_path;
    compiler.set_build_options(build_opts, w);

    bindfile := "raylib.jai";
    raylib_path := "../raylib-5.0_win64_msvc16/raylib-5.0_win64_msvc16";
    opts: bindgen.Generate_Bindings_Options;
    array_add(*opts.libnames, "raylib");
    opts.static_library_suffix = ".lib";
    array_add(*opts.libpaths, tprint("%/lib", raylib_path));
    array_add(*opts.include_paths, tprint("%/include", raylib_path));
    array_add(*opts.source_files, tprint("%/include/raylib.h", raylib_path));
    opts.visitor = visitor;

    bindgen.generate_bindings(opts, bindfile);

    compiler.add_build_file("src/main.jai", w);
}

visitor :: (decl: *bindgen.Declaration, parent_decl: *bindgen.Declaration) -> bindgen.Declaration_Visit_Result {
    if decl.name == "TraceLogCallback" || decl.name == "SetTraceLogCallback" {
        decl.decl_flags = .OMIT_FROM_OUTPUT;
    }
    return .RECURSE;
}

#run build();

bindgen :: #import "Bindings_Generator";
compiler :: #import "Compiler";
#import "Basic";