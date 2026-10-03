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
        Settings to be injected into the wrapped package's `config.toml`.

        See the jujutsu [documentation](https://docs.jj-vcs.dev/latest/config/) for valid options.

        Disjoint with the `configFile` option.
      '';
    };
    configFile = {
      type = types.pathLike;
      description = ''
        `config.toml` file to be injected into the wrapped package.

        See the jujutsu [documentation](https://docs.jj-vcs.dev/latest/config/) for valid options.

        Disjoint with the `settings` option.
      '';
    };

    extraPackages = {
      type = types.listOf types.derivation;
      description = ''
        Packages to be automatically added to jujutsu's path. Can be used to enable 3-pane diff editing by using Meld or diffedit3.

        See the jujutsu [documentation](https://docs.jj-vcs.dev/latest/config/#experimental-3-pane-diff-editing) on how to achieve this.
      '';
    };
    package = {
      type = types.derivation;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.jujutsu);
      description = "The jujutsu package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "settings" "configFile")
  ];

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) formats;
      inherit (inputs.nixpkgs.lib) makeBinPath;
      generator = formats.toml {};
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/jj-config/config.toml" =
          if options ? configFile then
            options.configFile
          else if options ? settings then
            generator.generate "config.toml" options.settings
          else
            null;
      };
      wrapperArgs =
        if options ? extraPackages then
          ''
            --prefix PATH : ${makeBinPath options.extraPackages}
          ''
        else
          "";
      environment = {
        JJ_CONFIG = "$out/jj-config";
      };
    }
  );

  meta = {
    maintainers = [ "es-sai-fi" ];
  };
}
