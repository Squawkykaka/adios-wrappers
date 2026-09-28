{ types, promise, assertions, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    flags = {
      type = types.listOf types.string;
      description = ''
        Flags to be automatically appended when running fd.

        See the [documentation](https://github.com/sharkdp/fd#command-line-options) for valid options.
      '';
    };

    ignoreContents = {
      type = types.string;
      description = ''
        Content to be injected into the wrapped package's ignore file.

        See the [documentation](https://github.com/sharkdp/fd#excluding-specific-files-or-directories) for more info.

        Disjoint with the `ignoreFile` option.
      '';
    };
    ignoreFile = {
      type = types.pathLike;
      description = ''
        Ignore file to be injected into the wrapped package.

        See the [documentation](https://github.com/sharkdp/fd#excluding-specific-files-or-directories) for more info.

        Disjoint with the `ignoreContents` option.
      '';
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.fd;
      description = "The fd package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "ignoreContents" "ignoreFile")
  ];

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/fd/fdignore" =
          if options ? ignoreContents then
            writeText "fdignore" options.ignoreContents
          else if options ? ignoreFile then
            options.ignoreFile
          else
            null;
      };

      flags = (options.flags or []) ++ (
        if options ? ignoreContents || options ? ignoreFile then
          [
            "--ignore-file"
            "$out/fd/fdignore"
          ]
        else
          []
      );
    }
  );

  meta = {
    maintainers = [ "itsyunaya" ];
  };
}
