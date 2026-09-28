{ types, promise, assertions, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    configContents = {
      type = types.string;
      description = ''
        Lua configuration to be injected into the wrapped package's `wezterm.lua`.

        See the [documentation](https://wezterm.org/config/lua/general.html) for valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `wezterm.lua` file to be injected into the wrapped package.

        See the [documentation](https://wezterm.org/config/lua/general.html) for valid options.

        Disjoint with the `configContents` option.
      '';
    };

    configModules = {
      type = types.listOf types.pathLike;
      description = ''
        Files containing .lua configuration modules to be injected into the wrapped package.

        See the [documentation](https://wezterm.org/config/files.html?h=modules#making-your-own-lua-modules) to learn how to refer to modules in your wezterm.lua file.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.wezterm;
      description = "The wezterm package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "configContents" "configFile")
  ];

  result = promise (
    { options, inputs }:
    let
      inherit (builtins) listToAttrs;
      inherit (inputs.nixpkgs.pkgs) writeText;
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/wezterm-config/wezterm.lua" =
          if options ? configFile then
            options.configFile
          else if options ? configContents then
            writeText "wezterm.lua" options.configContents
          else
            null;
      }
      // (
        if options ? configModules then
          listToAttrs (
            map (path: {
              name = "$out/wezterm-config/${baseNameOf path}";
              value = path;
            }) options.configModules
          )
        else
          {}
      );
      environment = {
        WEZTERM_CONFIG_FILE = "$out/wezterm-config/wezterm.lua";
        # Lua is dum sometimes
        LUA_PATH = "$out/wezterm-config/?.lua";
      };
    }
  );

  meta = {
    maintainers = [];
  };
}
