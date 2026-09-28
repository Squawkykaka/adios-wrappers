{ types, promise, assertions, ... }:
{
  inputs = {
    mkWrapper.from = { parent }: parent.mkWrapper;
    nixpkgs.from = { parent }: parent.nixpkgs;
  };

  options = {
    keybinds = {
      type = types.attrsOf (
        (types.struct "keybind" {
          char = types.string;
          mod = types.string;
        }).override
          { total = false; }
      );
      description = ''
        Keybind overrides to be injected into the wrapped package's `key_bindings.ron`.

        Each attrset in the optionAttrsets are converted to RON in this manner:
        `''${action_name} = { char = "x"; mod = "y"; }; => action: Some(( code: x, modifiers: y))`

        Where
        `action_name` is a valid [Gitui action](https://github.com/gitui-org/gitui/blob/master/src/keys/key_list.rs#L83),
        `char` is an *optional* valid [Crossterm KeyCode](https://docs.rs/crossterm/latest/crossterm/event/enum.KeyCode.html)
        and `mod` is an *optional* valid [Crossterm Modifier](https://docs.rs/crossterm/latest/crossterm/event/struct.KeyModifiers.html)

        An action that does not set either `char` or `mod` disables the keybind.

        For more information on how `key_bindings.ron` is formatted and used, see the [documentation](https://github.com/gitui-org/gitui/blob/master/KEY_CONFIG.md).

        Disjoint with the `keybindsFile` option.
      '';
      example = {
        move_left = {
          char = "Char('h')";
        };
        commit_amend = {
          char = "Char('A')";
          mod = "SHIFT";
        };
        branch_find = {};
      };
    };
    keybindsFile = {
      type = types.pathLike;
      description = ''
        `key_bindings.ron` file to be injected into the wrapped package.

        See the [documentation](https://github.com/gitui-org/gitui/blob/master/KEY_CONFIG.md#key-config) for syntax and valid options.

        Disjoint with the `keybinds` option.
      '';
    };

    symbols = {
      type = types.attrsOf types.string;
      description = ''
        Key symbol overrides to be injected into the wrapped package's `key_symbols.ron`.

        Each attrset pair is converted to RON in this manner:
        `{ ''${key} = symbol }; => key: Some(symbol)`

        Where
        `key` is a valid [Gitui KeySymbol](https://github.com/gitui-org/gitui/blob/master/src/keys/symbols.rs),
        and `char` is a valid character string.

        For more information on how `key_bindings.ron` is formatted and used, see the [documentation](https://github.com/gitui-org/gitui/blob/master/KEY_CONFIG.md#key-symbols).

        Disjoint with the `symbolsFile` option.
      '';
      example = {
        page_down = "▼";
      };
    };
    symbolsFile = {
      type = types.pathLike;
      description = ''
        `key_symbols.ron` file to be injected into the wrapped package.

        See the [documentation](https://github.com/gitui-org/gitui/blob/master/KEY_CONFIG.md#key-symbols) for syntax and valid options.

        Disjoint with the `symbols` option.
      '';
    };

    theme = {
      type = types.attrsOf types.string;
      description = ''
        Theme overrides to be injected into the wrapped package's `theme.ron`.

        Each attrset pair is converted to RON in this manner:
        `{ ''${element} = color; }; => element: Some("color")`

        Where
        `element` is a valid [Gitui style element](https://github.com/gitui-org/gitui/blob/master/src/ui/style.rs#L305)
        and `color` is a valid hex string ("#FFFFFF") or [Ratatui color](https://docs.rs/crossterm/latest/crossterm/event/struct.KeyModifiers.html)

        For more information on how `key_bindings.ron` is formatted and used, see the [documentation](https://github.com/gitui-org/gitui/blob/master/THEMES.md).

        Disjoint with the `themeFile` option.
      '';
      example = {
        selection_bg = "Blue";
        selection_fg = "#ffffff";
      };
    };
    themeFile = {
      type = types.pathLike;
      description = ''
        `theme.ron` file to be injected into the wrapped package.

        See the [documentation](https://github.com/gitui-org/gitui/blob/master/THEMES.md) for syntax and valid options.

        Disjoint with the `theme` option.
      '';
    };

    syntaxFiles = {
      type = types.listOf types.pathLike;
      description = ''
        Files containing .thTheme syntax files that can be loaded by `theme.ron`

        See the [documentation](https://github.com/gitui-org/gitui/blob/master/THEMES.md) for loading `.thTheme` files
        in `theme.ron`.
      '';
    };

    package = {
      type = types.derivation;
      description = "The gitui package to be wrapped.";
      default = promise ({ inputs }: inputs.nixpkgs.pkgs.gitui);
    };
  };

  assertions = [
    (assertions.disjoint "keybinds" "keybindsFile")
    (assertions.disjoint "symbols" "symbolsFile")
    (assertions.disjoint "theme" "themeFile")
  ];

  result = promise (
    { options, inputs }:
    let
      inherit (inputs.nixpkgs.pkgs) writeText;
      inherit (builtins) mapAttrs attrValues concatStringsSep listToAttrs;
      keybindsGenerator =
        name: binds:
        writeText name ''
          (
          ${concatStringsSep "\n" (
            attrValues (
              mapAttrs (
                name: value:
                if (value ? char || value ? mod) then
                  "${name}: Some(( code: ${if value ? char then value.char else ""}, modifiers: \"${
                    if value ? mod then value.mod else ""
                  }\")),"
                else
                  "${name}: None"
              ) binds
            )
          )}
          )
        '';
      symbolsGenerator =
        name: symbols:
        writeText name ''
          (
          ${concatStringsSep "\n" (
            attrValues (mapAttrs (name: value: "${name}: Some(\"${value}\"),") symbols)
          )}
          )
        '';
      themeGenerator =
        name: palette:
        writeText name ''
          (
          ${concatStringsSep "\n" (
            attrValues (mapAttrs (name: value: "${name}: Some(\"${value}\"),") palette)
          )}
          )
        '';
    in
    inputs.mkWrapper {
      inherit (options) package;
      symlinks = {
        "$out/gitui/key_bindings.ron" =
          if options ? keybindsFile then
            options.keybindsFile
          else if options ? keybinds then
            keybindsGenerator "key_bindings.ron" options.keybinds
          else
            null;
        "$out/gitui/key_symbols.ron" =
          if options ? symbolsFile then
            options.symbolsFile
          else if options ? symbols then
            symbolsGenerator "key_symbols.ron" options.symbols
          else
            null;
        "$out/gitui/theme.ron" =
          if options ? themeFile then
            options.themeFile
          else if options ? theme then
            themeGenerator "theme.ron" options.theme
          else
            null;
      }
      // (
        if options ? syntaxFiles then
          listToAttrs (
            map (path: {
              name = "$out/gitui${baseNameOf path}";
              value = path;
            }) options.syntaxFiles
          )
        else
          {}
      );
      environment = {
        XDG_CONFIG_HOME = "$out";
      };
    }
  );

  meta = {
    maintainers = [];
  };
}
