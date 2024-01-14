"Rules for building native binaries using the GraalVM `native-image` tool."

load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "@bazel_tools//tools/cpp:toolchain_utils.bzl",
    "use_cpp_toolchain",
)
load(
    "//internal/native_image:rules.bzl",
    _DEBUG = "DEBUG_CONDITION",
    _GVM_TOOLCHAIN_TYPE = "GVM_TOOLCHAIN_TYPE",
    _NATIVE_IMAGE_ATTRS = "NATIVE_IMAGE_ATTRS",
    _NATIVE_IMAGE_TEST_ATTRS = "NATIVE_IMAGE_TEST_ATTRS",
    _NATIVE_IMAGE_SHARED_LIB_ATTRS = "NATIVE_IMAGE_SHARED_LIB_ATTRS",
    _OUTPUT_GROUPS = "OUTPUT_GROUPS",
    _OPTIMIZATION_MODE = "OPTIMIZATION_MODE_CONDITION",
    _graal_binary_implementation = "graal_binary_implementation",
    _graal_shared_binary_implementation = "graal_shared_binary_implementation",
    _graal_test_binary_implementation = "graal_test_binary_implementation",
)
load(
    "//internal/native_image:settings.bzl",
    "NativeImageInfo",
)

_DEFAULT_NATIVE_IMAGE_TESTUTILS = Label("@rules_graalvm//graalvm/testing")

_DEFAULT_NATIVE_IMAGE_SETTINGS = Label("@rules_graalvm//internal/native_image:defaults")

_DEFAULT_CHECK_TOOLCHAINS_CONDITION = select({
    "@bazel_tools//src/conditions:windows": True,
    "//conditions:default": False,
})

_EXEUCTABLE_NAME_CONDITION = select({
    "@bazel_tools//src/conditions:windows": "%target%-bin.exe",
    "//conditions:default": "%target%-bin",
})

_TEST_NAME_CONDITION = select({
    "@bazel_tools//src/conditions:windows": "%target%-test.exe",
    "//conditions:default": "%target%-test",
})

_DEFAULT_NATIVE_IMAGE_TESTDEPS = [
    Label("@maven_gvm//:org_graalvm_sdk_nativeimage"),
    Label("@maven_gvm//:org_graalvm_buildtools_junit_platform_native"),
    Label("@maven_gvm//:org_junit_jupiter_junit_jupiter_api"),
    Label("@maven_gvm//:org_junit_jupiter_junit_jupiter_engine"),
    Label("@maven_gvm//:org_junit_jupiter_junit_jupiter_params"),
    Label("@maven_gvm//:org_junit_platform_junit_platform_console"),
    Label("@maven_gvm//:org_junit_platform_junit_platform_commons"),
    Label("@maven_gvm//:org_junit_platform_junit_platform_launcher"),
]

_SHARED_LIB_NAME_CONDITION = select({
    "//conditions:default": "%target%",
})

_modern_rule_attrs = {
    "native_image_tool": attr.label(
        cfg = "exec",
        allow_files = True,
        executable = True,
        mandatory = False,
    ),
    "native_image_settings": attr.label_list(
        providers = [[NativeImageInfo]],
        mandatory = False,
        default = [_DEFAULT_NATIVE_IMAGE_SETTINGS],
    ),
}

_modern_rule_options = {
    "fragments": [
        "apple",
        "coverage",
        "cpp",
        "java",
        "platform",
        "xcode",
    ],
    "toolchains": use_cpp_toolchain() + [
        _GVM_TOOLCHAIN_TYPE,
    ],
}

_native_image = rule(
    implementation = _graal_binary_implementation,
    attrs = dicts.add(_NATIVE_IMAGE_ATTRS, **_modern_rule_attrs),
    executable = True,
    **_modern_rule_options,
)

_native_image_test = rule(
    implementation = _graal_test_binary_implementation,
    executable = True,
    test = True,
    attrs = dicts.add(_NATIVE_IMAGE_TEST_ATTRS, dicts.add(_modern_rule_attrs, **{
        "_native_image_test_utils": attr.label(
            mandatory = False,
            default = _DEFAULT_NATIVE_IMAGE_TESTUTILS,
        ),
        "_native_test_deps": attr.label_list(
            mandatory = False,
            default = _DEFAULT_NATIVE_IMAGE_TESTDEPS,
        )
    })),
    **_modern_rule_options,
)

_native_image_shared_library = rule(
    implementation = _graal_shared_binary_implementation,
    attrs = dicts.add(_NATIVE_IMAGE_SHARED_LIB_ATTRS, **_modern_rule_attrs),
    **_modern_rule_options,
)

_NATIVE_IMAGE_UTILS = struct(
    output_groups = _OUTPUT_GROUPS,
)

# Exports.
def native_image(
        name,
        deps,
        main_class = None,
        executable_name = _EXEUCTABLE_NAME_CONDITION,
        include_resources = None,
        reflection_configuration = None,
        reflection_configurations = [],
        jni_configuration = None,
        jni_configurations = [],
        resource_configuration = None,
        resource_configurations = [],
        proxy_configuration = None,
        proxy_configurations = [],
        serialization_configuration = None,
        serialization_configurations = [],
        initialize_at_build_time = [],
        initialize_at_run_time = [],
        native_features = [],
        debug = _DEBUG,
        optimization_mode = _OPTIMIZATION_MODE,
        shared_library = None,
        static_zlib = None,
        c_compiler_option = [],
        data = [],
        extra_args = [],
        allow_fallback = False,
        check_toolchains = _DEFAULT_CHECK_TOOLCHAINS_CONDITION,
        native_image_tool = None,  # uses toolchains by default
        native_image_settings = [_DEFAULT_NATIVE_IMAGE_SETTINGS],
        profiles = [],
        additional_outputs = [],
        default_outputs = True,
        **kwargs):
    """Generates and compiles a GraalVM native image from a Java library target.

    Args:
        name: Name of the target; required.
        deps: Dependency `java_library` targets to assemble the classpath from. Mandatory.
        main_class: Entrypoint main class to build from; mandatory unless building a shared library.
        executable_name: Set the name of the output binary; defaults to `%target%-bin`, or `%target%-bin.exe` on Windows.
            The special string `%target%`, if present, is replaced with `name`.
        include_resources: Glob to pass to `IncludeResources`. No default; optional.
        reflection_configuration: Reflection configuration file. No default; optional.
        reflection_configurations: Reflection configuration file. No default; optional.
        jni_configuration: JNI configuration file. No default; optional.
        jni_configurations: Multiple JNI configuration files. No default; optional.
        resource_configuration: Configuration file for embedded resources. No default; optional.
        resource_configurations: Configuration files for embedded resources. No default; optional.
        proxy_configuration: Configuration file for Java class proxies. No default; optional.
        proxy_configurations: Configuration files for Java class proxies. No default; optional.
        serialization_configuration: Configuration file for Java class proxies. No default; optional.
        serialization_configurations: Configuration files for Java class proxies. No default; optional.
        initialize_at_build_time: Classes or patterns to pass to `--initialize-at-build-time`. No default; optional.
        initialize_at_run_time: Classes or patterns to pass to `--initialize-at-run-time`. No default; optional.
        native_features: GraalVM `Feature` classes to include and apply. No default; optional.
        debug: Whether to include debug symbols; by default, this flag's state is managed by Bazel. Passing
            `--compilation_mode=dbg` is sufficient to flip this to `True`, or it can be overridden via this parameter.
        optimization_mode: Behaves the same as `debug`; normally, this flag's state is managed by Bazel. Passing
            `--compilation_mode=fastbuild|opt|dbg` is sufficient to set this flag, or it can be overridden via this
            parameter.
        shared_library: Build a shared library binary instead of an executable.
        static_zlib: A cc_library or cc_import target that provides zlib as a static library.
            On Linux, this is used when Graal statically links zlib into the binary, e.g. with
            `-H:+StaticExecutableWithDynamicLibC`.
        c_compiler_option: Extra C compiler options to pass through `native-image`. No default; optional.
        data: Data files to make available during the compilation. No default; optional.
        extra_args: Extra `native-image` args to pass. Last wins. No default; optional.
        allow_fallback: Whether to allow fall-back to a partial native image; defaults to `False`.
        additional_outputs: Additional outputs to expect from the rule (for example, polyglot language resources).
        check_toolchains: Whether to perform toolchain checks in `native-image`; defaults to `True` on Windows, `False` otherwise.
        native_image_tool: Specific `native-image` executable target to use.
        native_image_settings: Suite(s) of Native Image build settings to use.
        profiles: Profiles to use for profile-guided optimization (PGO) and obtained from a native image compiled with `--pgo-instrument`.
        default_outputs: Whether to consider default output files; when `False`, the developer specifies all outputs on top of the
            binary itself.
        **kwargs: Extra keyword arguments are passed to the underlying `native_image` rule.
    """

    if shared_library:
        # buildifier: disable=print
        print("GraalVM rules for Bazel at >0.11.x uses `native_image_shared_library`. Please migrate at your convenience.")

    _native_image(
        name = name,
        deps = deps,
        main_class = main_class,
        include_resources = include_resources,
        reflection_configuration = reflection_configuration,
        reflection_configurations = reflection_configurations,
        jni_configuration = jni_configuration,
        jni_configurations = jni_configurations,
        resource_configuration = resource_configuration,
        resource_configurations = resource_configurations,
        proxy_configuration = proxy_configuration,
        proxy_configurations = proxy_configurations,
        serialization_configuration = serialization_configuration,
        serialization_configurations = serialization_configurations,
        initialize_at_build_time = initialize_at_build_time,
        initialize_at_run_time = initialize_at_run_time,
        native_features = native_features,
        debug = debug,
        optimization_mode = optimization_mode,
        shared_library = shared_library,
        data = data,
        extra_args = extra_args,
        check_toolchains = check_toolchains,
        static_zlib = static_zlib,
        c_compiler_option = c_compiler_option,
        allow_fallback = allow_fallback,
        executable_name = executable_name,
        native_image_tool = native_image_tool,
        native_image_settings = native_image_settings,
        profiles = profiles,
        additional_outputs = additional_outputs,
        default_outputs = default_outputs,
        **kwargs
    )

def native_image_test(
        name,
        tests,
        deps = [],
        main_class = None,
        discovery = True,
        executable_name = _TEST_NAME_CONDITION,
        include_resources = None,
        reflection_configuration = None,
        reflection_configurations = [],
        jni_configuration = None,
        jni_configurations = [],
        resource_configuration = None,
        resource_configurations = [],
        proxy_configuration = None,
        proxy_configurations = [],
        serialization_configuration = None,
        serialization_configurations = [],
        initialize_at_build_time = [],
        initialize_at_run_time = [],
        native_features = [],
        debug = _DEBUG,
        optimization_mode = _OPTIMIZATION_MODE,
        shared_library = None,
        static_zlib = None,
        c_compiler_option = [],
        data = [],
        extra_args = [],
        allow_fallback = False,
        check_toolchains = _DEFAULT_CHECK_TOOLCHAINS_CONDITION,
        native_image_tool = None,  # uses toolchains by default
        native_image_settings = [_DEFAULT_NATIVE_IMAGE_SETTINGS],
        profiles = [],
        additional_outputs = [],
        default_outputs = True,
        **kwargs):
    """Generates and compiles a GraalVM native image from a Java library target.

    Args:
        name: Name of the target; required.
        tests: Java test targets to build and run natively.
        deps: Dependency `java_library` targets to assemble the classpath from. Mandatory.
        main_class: Testrunner to use; defaults to Bazel's test runner.
        discovery: Enable test discovery support; injects classes to discover tests. Defaults to `True`.
        executable_name: Set the name of the output binary; defaults to `%target%-test`, or `%target%-test.exe` on Windows.
            The special string `%target%`, if present, is replaced with `name`.
        include_resources: Glob to pass to `IncludeResources`. No default; optional.
        reflection_configuration: Reflection configuration file. No default; optional.
        reflection_configurations: Reflection configuration file. No default; optional.
        jni_configuration: JNI configuration file. No default; optional.
        jni_configurations: Multiple JNI configuration files. No default; optional.
        resource_configuration: Configuration file for embedded resources. No default; optional.
        resource_configurations: Configuration files for embedded resources. No default; optional.
        proxy_configuration: Configuration file for Java class proxies. No default; optional.
        proxy_configurations: Configuration files for Java class proxies. No default; optional.
        serialization_configuration: Configuration file for Java class proxies. No default; optional.
        serialization_configurations: Configuration files for Java class proxies. No default; optional.
        initialize_at_build_time: Classes or patterns to pass to `--initialize-at-build-time`. No default; optional.
        initialize_at_run_time: Classes or patterns to pass to `--initialize-at-run-time`. No default; optional.
        native_features: GraalVM `Feature` classes to include and apply. No default; optional.
        debug: Whether to include debug symbols; by default, this flag's state is managed by Bazel. Passing
            `--compilation_mode=dbg` is sufficient to flip this to `True`, or it can be overridden via this parameter.
        optimization_mode: Behaves the same as `debug`; normally, this flag's state is managed by Bazel. Passing
            `--compilation_mode=fastbuild|opt|dbg` is sufficient to set this flag, or it can be overridden via this
            parameter.
        shared_library: Build a shared library binary instead of an executable.
        static_zlib: A cc_library or cc_import target that provides zlib as a static library.
            On Linux, this is used when Graal statically links zlib into the binary, e.g. with
            `-H:+StaticExecutableWithDynamicLibC`.
        c_compiler_option: Extra C compiler options to pass through `native-image`. No default; optional.
        data: Data files to make available during the compilation. No default; optional.
        extra_args: Extra `native-image` args to pass. Last wins. No default; optional.
        allow_fallback: Whether to allow fall-back to a partial native image; defaults to `False`.
        additional_outputs: Additional outputs to expect from the rule (for example, polyglot language resources).
        check_toolchains: Whether to perform toolchain checks in `native-image`; defaults to `True` on Windows, `False` otherwise.
        native_image_tool: Specific `native-image` executable target to use.
        native_image_settings: Suite(s) of Native Image build settings to use.
        profiles: Profiles to use for profile-guided optimization (PGO) and obtained from a native image compiled with `--pgo-instrument`.
        default_outputs: Whether to consider default output files; when `False`, the developer specifies all outputs on top of the
            binary itself.
        **kwargs: Extra keyword arguments are passed to the underlying `native_image` rule.
    """

    _native_image_test(
        name = name,
        tests = tests,
        deps = deps,
        main_class = main_class,
        discovery = discovery,
        include_resources = include_resources,
        reflection_configuration = reflection_configuration,
        reflection_configurations = reflection_configurations,
        jni_configuration = jni_configuration,
        jni_configurations = jni_configurations,
        resource_configuration = resource_configuration,
        resource_configurations = resource_configurations,
        proxy_configuration = proxy_configuration,
        proxy_configurations = proxy_configurations,
        serialization_configuration = serialization_configuration,
        serialization_configurations = serialization_configurations,
        initialize_at_build_time = initialize_at_build_time,
        initialize_at_run_time = initialize_at_run_time,
        native_features = native_features,
        debug = debug,
        optimization_mode = optimization_mode,
        shared_library = shared_library,
        data = data,
        extra_args = extra_args,
        check_toolchains = check_toolchains,
        static_zlib = static_zlib,
        c_compiler_option = c_compiler_option,
        allow_fallback = allow_fallback,
        executable_name = executable_name,
        native_image_tool = native_image_tool,
        native_image_settings = native_image_settings,
        profiles = profiles,
        additional_outputs = additional_outputs,
        default_outputs = default_outputs,
        **kwargs
    )

def native_image_shared_library(
        name,
        deps,
        lib_name = _SHARED_LIB_NAME_CONDITION,
        include_resources = None,
        reflection_configuration = None,
        reflection_configurations = [],
        jni_configuration = None,
        jni_configurations = [],
        resource_configuration = None,
        resource_configurations = [],
        proxy_configuration = None,
        proxy_configurations = [],
        serialization_configuration = None,
        serialization_configurations = [],
        initialize_at_build_time = [],
        initialize_at_run_time = [],
        native_features = [],
        debug = _DEBUG,
        optimization_mode = _OPTIMIZATION_MODE,
        static_zlib = None,
        c_compiler_option = [],
        data = [],
        extra_args = [],
        allow_fallback = False,
        check_toolchains = _DEFAULT_CHECK_TOOLCHAINS_CONDITION,
        native_image_tool = None,  # uses toolchains by default
        native_image_settings = [_DEFAULT_NATIVE_IMAGE_SETTINGS],
        profiles = [],
        out_headers = [],
        additional_outputs = [],
        default_outputs = True,
        **kwargs):
    """Generates and compiles a GraalVM native image from a Java library target.

    Args:
        name: Name of the target; required.
        deps: Dependency `java_library` targets to assemble the classpath from. Mandatory.
        lib_name: Set the name of the output library binary; defaults to `%target%`.
            The special string `%target%`, if present, is replaced with `name`.
        include_resources: Glob to pass to `IncludeResources`. No default; optional.
        reflection_configuration: Reflection configuration file. No default; optional.
        reflection_configurations: Reflection configuration file. No default; optional.
        jni_configuration: JNI configuration file. No default; optional.
        jni_configurations: Multiple JNI configuration files. No default; optional.
        resource_configuration: Configuration file for embedded resources. No default; optional.
        resource_configurations: Configuration files for embedded resources. No default; optional.
        proxy_configuration: Configuration file for Java class proxies. No default; optional.
        proxy_configurations: Configuration files for Java class proxies. No default; optional.
        serialization_configuration: Configuration file for Java class proxies. No default; optional.
        serialization_configurations: Configuration files for Java class proxies. No default; optional.
        initialize_at_build_time: Classes or patterns to pass to `--initialize-at-build-time`. No default; optional.
        initialize_at_run_time: Classes or patterns to pass to `--initialize-at-run-time`. No default; optional.
        native_features: GraalVM `Feature` classes to include and apply. No default; optional.
        debug: Whether to include debug symbols; by default, this flag's state is managed by Bazel. Passing
            `--compilation_mode=dbg` is sufficient to flip this to `True`, or it can be overridden via this parameter.
        optimization_mode: Behaves the same as `debug`; normally, this flag's state is managed by Bazel. Passing
            `--compilation_mode=fastbuild|opt|dbg` is sufficient to set this flag, or it can be overridden via this
            parameter.
        static_zlib: A cc_library or cc_import target that provides zlib as a static library.
            On Linux, this is used when Graal statically links zlib into the binary, e.g. with
            `-H:+StaticExecutableWithDynamicLibC`.
        c_compiler_option: Extra C compiler options to pass through `native-image`. No default; optional.
        data: Data files to make available during the compilation. No default; optional.
        extra_args: Extra `native-image` args to pass. Last wins. No default; optional.
        allow_fallback: Whether to allow fall-back to a partial native image; defaults to `False`.
        out_headers: Shared library headers expected to be emitted by the rule (in addition to defaults).
        additional_outputs: Additional outputs to expect from the rule (for example, polyglot language resources).
        check_toolchains: Whether to perform toolchain checks in `native-image`; defaults to `True` on Windows, `False` otherwise.
        native_image_tool: Specific `native-image` executable target to use.
        native_image_settings: Suite(s) of Native Image build settings to use.
        profiles: Profiles to use for profile-guided optimization (PGO) and obtained from a native image compiled with `--pgo-instrument`.
        default_outputs: Whether to consider default output files; when `False`, the developer specifies all outputs on top of the
            binary itself.
        **kwargs: Extra keyword arguments are passed to the underlying `native_image` rule.
    """

    _native_image_shared_library(
        name = name,
        deps = deps,
        include_resources = include_resources,
        reflection_configuration = reflection_configuration,
        reflection_configurations = reflection_configurations,
        jni_configuration = jni_configuration,
        jni_configurations = jni_configurations,
        resource_configuration = resource_configuration,
        resource_configurations = resource_configurations,
        proxy_configuration = proxy_configuration,
        proxy_configurations = proxy_configurations,
        serialization_configuration = serialization_configuration,
        serialization_configurations = serialization_configurations,
        initialize_at_build_time = initialize_at_build_time,
        initialize_at_run_time = initialize_at_run_time,
        native_features = native_features,
        debug = debug,
        optimization_mode = optimization_mode,
        shared_library = True,
        data = data,
        extra_args = extra_args,
        check_toolchains = check_toolchains,
        static_zlib = static_zlib,
        c_compiler_option = c_compiler_option,
        allow_fallback = allow_fallback,
        lib_name = lib_name,
        native_image_tool = native_image_tool,
        native_image_settings = native_image_settings,
        profiles = profiles,
        out_headers = out_headers,
        additional_outputs = additional_outputs,
        default_outputs = default_outputs,
        **kwargs
    )

# Aliases.
utils = _NATIVE_IMAGE_UTILS
