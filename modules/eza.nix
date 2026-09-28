{ types, promise, assertions, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    # TODO: add impure variant when makeBinaryWrapper supports it
    flags = {
      type = types.listOf types.string;
      description = ''
        Flags to be appended by default when running eza.
      '';
    };

    theme = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `theme.yml`.

        See the [documentation](https://github.com/eza-community/eza/blob/main/man/eza_colors-explanation.5.md) for valid options.

        Disjoint with the `themeFile` option.
      '';
    };
    themeFile = {
      type = types.pathLike;
      description = ''
        `theme.yml` file to be injected into the wrapped package.

        See the [documentation](https://github.com/eza-community/eza/blob/main/man/eza_colors-explanation.5.md) for valid options.

        Disjoint with the `theme` option.
      '';
    };

    package = {
      type = types.derivation;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.eza);
      description = "The eza package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "theme" "themeFile")
  ];

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) formats;
      generator = formats.json {};
    in
    inputs.mkWrapper {
      inherit (options) package flags;
      symlinks = {
        "$out/eza-config/theme.yml" =
          if options ? themeFile then
            options.themeFile
          else if options ? theme then
            generator.generate "theme.yml" options.theme
          else
            null;
      };
      environment = {
        EZA_CONFIG_DIR = "$out/eza-config";
      };
    }
  );

  meta = {
    maintainers = [ "EpicEric" ];
  };
}
