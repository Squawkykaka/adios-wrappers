{ types, promise, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    settings = {
      type = types.attrs;
      description = ''
        Settings to be injected into the wrapped package's `config.yml`.

        See the [documentation](https://cli.github.com/manual/gh_config).

        Disjoint with the `configDir` option.
      '';
    };
    hosts = {
      type = types.attrs;
      description = ''
        Host information to be injected into the wrapped package's `hosts.yml`.

        Disjoint with the `configDir` option.
      '';
    };
    configDir = {
      type = types.pathLike;
      description = ''
        Folder containing gh configuration files to be injected into the wrapped package.

        This folder should contain a `config.yml` and/or a `hosts.yml`.

        Disjoint with the `settings` and `hosts` options.
      '';
    };

    package = {
      type = types.derivation;
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.gh);
      description = "The gh package to be wrapped.";
    };
  };

  # TODO: consider adding 'assertions.disjointSets' for this usecase
  assertions = [
    {
      verify = { options }: !(options ? configDir && (options ? settings || options ? hosts));
      explain =
        { options }: "'options.configDir' is disjoint with 'options.settings' and 'options.hosts'";
    }
  ];

  mutations = {
    "/git".settings = promise (
      { options, inputs }:
      let
        inherit (inputs.nixpkgs.lib) getExe;
        finalWrapper = options {};
      in {
        credential."https://github.com".helper = "${getExe finalWrapper} auth git-credential";
      }
    );
  };

  result = promise (
    { options, inputs }:
    let
      inherit (builtins) mapAttrs;
      inherit (inputs.nixpkgs.pkgs) formats;
      generator = formats.yaml {};
      mapBools = mapAttrs (
        _: value:
        if value == true then
          "enabled"
        else if value == false then
          "disabled"
        else
          value
      );
    in
    if options ? configDir then
      inputs.mkWrapper {
        inherit (options) package;
        environment = {
          GH_CONFIG_DIR = options.configDir;
        };
      }
    else
      inputs.mkWrapper {
        inherit (options) package;
        symlinks = {
          "$out/gh/config.yml" =
            if options ? settings then
              generator.generate "config" (mapBools options.settings)
            else
              null;
          "$out/gh/hosts.yml" =
            if options ? hosts then
              generator.generate "hosts" (mapBools options.hosts)
            else
              null;
        };
        environment = {
          GH_CONFIG_DIR = "$out/gh";
        };
      }
  );

  meta = {
    maintainers = [ "llakala" ];
  };
}
