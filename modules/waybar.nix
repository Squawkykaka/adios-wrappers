{ types, promise, assertions, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `config.jsonc`.

        See the [documentation](https://github.com/Alexays/Waybar/wiki/Configuration) for valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.jsonc` file to be injected into the wrapped package.

        See the [documentation](https://github.com/Alexays/Waybar/wiki/Configuration) for syntax and valid options.

        Disjoint with the `settings` option.
      '';
    };

    barStyle = {
      type = types.string;
      description = ''
        CSS to be injected into the wrapped package's `style.css`.

        See the [documentation](https://github.com/Alexays/Waybar/wiki/Styling) for writing waybar themes.

        Disjoint with the `cssFile` option.
      '';
    };
    cssFile = {
      type = types.pathLike;
      description = ''
        `style.css` file to be injected into the wrapped package.

        See the [documentation](https://github.com/Alexays/Waybar/wiki/Styling) for writing waybar themes.

        Live reloading of themes can be accomplished with an impure path and options.interactiveEnv set to true.

        Disjoint with the `barStyle` option.
      '';
    };

    interactiveEnv = {
      type = types.bool;
      description = ''
        Sets GTK_DEBUG=interactive to launch the wrapped package with the GTK CSS Inspector.

        See the [documentation](https://developer.gnome.org/documentation/tools/inspector.html) for use of the inspection tool.

        Can be used with an impure path in options.cssFile to enable live theme reloading.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.waybar;
      description = "The waybar package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "settings" "configFile")
    (assertions.disjoint "barStyle" "cssFile")
  ];

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText formats;
      generator = formats.json {};
      configFlag =
        if options ? configFile then
          [ "--config=${options.configFile}" ]
        else if options ? settings then
          [ "--config=${generator.generate "config.jsonc" options.settings}" ]
        else
          [];
      styleFlag =
        if options ? cssFile then
          [ "--style=${options.cssFile}" ]
        else if options ? barStyle then
          [ "--style=${writeText "style.css" options.barStyle}" ]
        else
          [];
    in
    inputs.mkWrapper {
      inherit (options) package;
      flags = configFlag ++ styleFlag;
      environment = {
        GTK_DEBUG = if (options.interactiveEnv or false) then "interactive" else null;
      };
    }
  );

  meta = {
    maintainers = [];
  };
}
