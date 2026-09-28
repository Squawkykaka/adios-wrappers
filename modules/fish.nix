{ types, promise, assertions, ... } @ adios:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    # TODO: add mergeFunc for completions and functions options
    completions = {
      type = types.attrsOf types.string;
      description = ''
        Custom completions to be injected into the wrapped package.

        Each attribute should map the name of a command to inline fish script defining how the command should be completed.

        Disjoint with the `completionFiles` option.
      '';
    };
    completionsFiles = {
      type = types.listOf types.pathLike;
      description = ''
        Files containing custom completions to be injected into the wrapped package.

        Disjoint with the `completions` option.
      '';
      mergeFunc = adios.lib.merge.lists.concat;
    };

    functions = {
      type = types.attrsOf types.string;
      description = ''
        Custom functions to be injected into the wrapped package.

        Each attribute should map the name of a function to inline fish script defining its functionality.

        Disjoint with the `functionsFiles` option.
      '';
    };
    functionsFiles = {
      type = types.listOf types.pathLike;
      description = ''
        Files containing custom functions to be injected into the wrapped package.

        Disjoint with the `functions` option.
      '';
      mergeFunc = adios.lib.merge.lists.concat;
    };

    abbreviations = {
      type =
        let
          # Just renamed for a nicer internal name
          abbrType = types.rename "abbr" (
            types.either types.string (
              types.struct "abbrWithCursor" {
                setCursor = types.bool;
                expansion = types.string;
              }
            )

          );
        in
        types.attrsOf (types.either abbrType (types.listOf (types.attrsOf abbrType)));
      description = ''
        Custom abbreviations to be injected into the wrapped package.

        Each attribute should map an abbreviation to its expansion.
        The values can either be:
        - a normal string with no extra logic
        - a special struct, allowing abbrs to set the location of the cursor on expansion
        - a list, allowing abbrs to only expand when the commandline starts with a given command
        See the example for a demo.
      '';
      example = {
        s = "git status";
        c = "git commit";
        git = [
          { m = "merge"; }
          {
            rbi = {
              setCursor = true;
              expansion = "rebase -i HEAD~%";
            };
          }
        ];
      };
      mergeFunc = adios.lib.merge.attrs.flat;
    };

    # TODO: add impure variant of this, and make abbreviations work without
    # merging this
    interactiveShellInit = {
      type = types.string;
      description = ''
        Shell initialization code to be automatically injected into the wrapped package.

        Only ran when Fish is initialized interactively.
      '';
      mergeFunc =
        let
          inherit (builtins) attrNames concatMap concatStringsSep isAttrs isString replaceStrings;
          abbrsToString =
            let
              escapeQuotes = replaceStrings [ "'" ] [ "\\'" ];
              abbrToString =
                {
                  setCursor ? false,
                  command,
                  abbr,
                  expansion
                }:
                "abbr --add "
                + (if setCursor then "--set-cursor " else "")
                + (if command != null then "--command ${command} " else "")
                + "-- ${abbr} '${escapeQuotes expansion}'";
              flattenAbbrs =
                command: abbrs:
                concatMap (
                  abbr:
                  let
                    expansion = abbrs.${abbr};
                  in
                  if isString expansion then
                    [
                      (abbrToString {
                        inherit command abbr expansion;
                      })
                    ]
                  else if isAttrs expansion then
                    [
                      (abbrToString {
                        inherit command abbr;
                        inherit (expansion) setCursor expansion;
                      })
                    ]
                  else
                    # Note that fish doesn't work with "nested" commands. You would
                    # think `--command 'foo bar' -- b baz` would work. but it
                    # doesn't. While technically the code could recurse twice here,
                    # the type prevents it
                    concatMap (flattenAbbrs abbr) expansion
                ) (attrNames abbrs);
            in
            abbrs: concatStringsSep "\n" (flattenAbbrs null abbrs);
        in
        { mutators, options }:
        concatStringsSep "\n" (
          [
            "status is-interactive || exit 0"
          ]
          ++ mutators
          ++ (
            if options ? abbreviations then
              [ (abbrsToString options.abbreviations) ]
            else
              []
          )
        );
    };

    package = {
      type = types.derivation;
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.fish;
      description = "The Fish package to be wrapped.";
    };
  };

  assertions = [
    (assertions.disjoint "completions" "completionsFiles")
    (assertions.disjoint "functions" "functionsFiles")
  ];

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (builtins) listToAttrs attrNames;
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/share/fish/vendor_conf.d/config.fish" =
          if options ? interactiveShellInit then
            writeText "config.fish" options.interactiveShellInit
          else
            null;
      }
      // (
        if options ? completionsFiles then
          listToAttrs (
            map (path: {
              name = "$out/share/fish/vendor_completions.d/${baseNameOf path}";
              value = path;
            }) options.completionsFiles
          )
        else if options ? completions then
          listToAttrs (
            map (path: {
              name = "$out/share/fish/vendor_completions.d/${path}.fish";
              value = writeText path options.completions.${path};
            }) (attrNames options.completions)
          )
        else
          {}
      )
      // (
        if options ? functionsFiles then
          listToAttrs (
            map (path: {
              name = "$out/share/fish/vendor_functions.d/${baseNameOf path}";
              value = path;
            }) options.functionsFiles
          )
        else if options ? functions then
          listToAttrs (
            map (path: {
              name = "$out/share/fish/vendor_functions.d/${path}.fish";
              value = writeText path options.functions.${path};
            }) (attrNames options.functions)
          )
        else
          {}
      );
    }
  );

  meta = {
    maintainers = [ "llakala" ];
  };
}
