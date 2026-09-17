{ types, ... }: {
  # thank you to Gerg-L, for his work on mnw as most of the bash is copied from there.
  inputs = {
    nixpkgs.from = { parent }: parent.nixpkgs;
    mkWrapper.from = { parent }: parent.mkWrapper;
  };

  options = {
    initLuaFile = {
      type = types.pathLike;
      description = ''
        `init.lua` file to be run on startup.

        Disjoint with the initLuaContents option.
      '';
      example = "./init.lua";
    };
    initLuaContents = {
      type = types.string;
      description = ''
        The contents of the `init.lua` file to be run on startup.

        Disjoint with the initLuaFile option.
      '';
      example = ''
        require("keybinds")
        require("plugins")
        require("options")
      '';
    };
    aliases = {
      type = types.listOf types.string;
      description = ''
        Additional program names to launch `nvim` under.
      '';
      example = [
        "vi"
        "vim"
      ];
    };
    extraPackages = {
      type = types.listOf types.derivation;
      description = "A list of extra packages to be included in neovim's $PATH";
      example = ''
        with inputs.nixpkgs; [
          pkgs.rg
          pkgs.fzf
        ]
      '';
    };
    extraLuaPackages = {
      type = types.function;
      description = ''
        A function returning a list of extra packages to be included in lua's $PATH.
      '';
      example = ''
        ps: [ ps.jsregexp ]
      '';
      default = _: [];
    };
    startPlugins = {
      type = types.attrsOf types.pathLike;
      description = ''
        An attrset of neovim *plugins* which are loaded on startup.

        Your personal config should be declared as a plugin here, and then loaded
        via the 'initLuaFile'/'initLuaContents' option:

        ```lua
        -- this loads nvim/lua/init.lua
        require("init")
        ```

        Plugins that are set to strings will be treated as absolute paths
        and loaded impurely at runtime, rather than at buildtime. This allows
        for "hot reloading", which is helpful inside a devshell.

        A plugin's structure is described [here](https://neovim.io/doc/user/pack/#package-create).
      '';
      example = ''
        {
          inherit (pkgs.vimPlugins) fzf-lua nvim-surround;
          custom-plugin = pkgs.callPackage ./startPlugins/foo.nix {};

          # loading your personal config without hot reloading
          myconfig = ./nvim;
          # alternatively, setting up hot reloading inside a flake
          myconfig = "/home/your-username/Projects/nixos-config/wrappers/neovim/nvim";
          # and if you don't use flakes, this works too:
          myconfig = toString ./nvim;
        }
      '';
    };
    optPlugins = {
      type = types.attrsOf (types.either types.path types.derivation);
      description = ''
        A attrset of nvim plugins that are only loaded when `packadd` is called.

        This follows the same ruleset as startPlugins, but doesn't support impure paths.
      '';
    };
    treesitterPackage = {
      # TODO: should this have a default?
      type = types.derivation;
      description = ''
        The nvim-treesitter package to be used.

        This should also include the grammars as dependencies, which can be done via either
        `nvim-treesitter.withAllGrammars` or `nvim-treesitter.withPlugins (p: [ p.foo p.bar ])`.
      '';
      example = "pkgs.vimPlugins.nvim-treesitter.withAllGrammars";
    };
    package = {
      type = types.derivation;
      description = "The neovim package to be wrapped.";
      defaultFunc = { inputs }: inputs.nixpkgs.pkgs.neovim-unwrapped;
    };
  };

  impl =
    { inputs, options }:
    let
      inherit (builtins)
        attrValues
        baseNameOf
        concatStringsSep
        foldl'
        hashString
        isAttrs
        isPath
        isString
        substring
        ;
      inherit (inputs.nixpkgs.pkgs) symlinkJoin writeText;
      inherit (inputs.nixpkgs.lib) filterAttrs getName makeBinPath removePrefix;

      transformPlugins =
        let
          recurse =
            parent: isDep:
            foldl'
              (
                acc: e:
                let
                  name = removePrefix "vimplugin-" (
                    if isAttrs e then getName e else "${baseNameOf e}-${substring 0 7 (hashString "md5" "${e}")}"
                  );

                  item.${name} = e;
                in {
                  deps = (
                    if isDep then
                      acc.deps // item
                    else
                      acc.deps
                  )
                  // (
                    if e ? dependencies then
                      (recurse name true e.dependencies).deps
                    else
                      {}
                  );
                  notDeps =
                    if isDep then
                      acc.notDeps
                    else
                      acc.notDeps // item;
                }
              )
              {
                deps = {};
                notDeps = {};
              };
        in
        recurse "" false;

      # TODO: this needs fixing, we're currently not using the benefits of the
      # attrset form at all if we just take attrValues. whole idea is that the
      # names are determined by the attribute names instead, we need to decide
      # if that's valuable
      transformedOpt = transformPlugins (attrValues (options.optPlugins or {}));
      transformedStart = transformPlugins (attrValues (options.startPlugins or {}));
      transformedTreesitter = transformPlugins [ options.treesitterPackage ];

      startAttrs = transformedOpt.deps // transformedStart.deps // transformedStart.notDeps;

      optPlugins = transformedOpt.notDeps;

      # TODO: dev plugins that were paths didn't seem to work for me. can we get
      # this working? if not, should we go back to a separate option?
      startPlugins = (filterAttrs (_: v: v != null && !isString v && !isPath v) startAttrs) // (
        if options ? treesitterPackage then
          {
            nvim-treesitter-grammars = symlinkJoin {
              name = "nvim-treesitter-grammars";
              paths = attrValues transformedTreesitter.deps;
            };
          }
          // transformedTreesitter.notDeps
        else
          {}
      );
      devPlugins = filterAttrs (_: v: isString v || isPath v) startAttrs;

      generatedInitLua =
        let
          luaEnv = options.package.lua.withPackages options.extraLuaPackages;
          inherit (options.package.lua.pkgs) luaLib;

          sourceLua =
            if options ? initLuaFile then "dofile('${options.initLuaFile}')" else options.initLuaContents;
        in
        # can't be adios-wrappers, lua doesn't support `-` inside variables
        writeText "init.lua" /* lua */ ''
          adioswrappers = { configDir = "$out" }
          vim.env.PATH = vim.env.PATH .. ":${makeBinPath (options.extraPackages or [])}"
          package.path = "${luaLib.genLuaPathAbsStr luaEnv};$LUA_PATH" .. package.path
          package.cpath = "${luaLib.genLuaCPathAbsStr luaEnv};$LUA_CPATH" .. package.cpath

          ${sourceLua}
        '';

      configDir = import ./configDir.nix inputs.nixpkgs.pkgs {
        inherit (options) package;
        inherit startPlugins optPlugins generatedInitLua;
      };
    in
    assert options ? initLuaFile != options ? initLuaContents;
    # TODO: should we set dontFixup, as mnw says it reduces build time? does it matter?
    inputs.mkWrapper {
      package = options.package // {
        passthru = options.package.passthru // {
          inherit configDir;
          config = options;
        };
      };
      pname = "neovim";
      binaryName = "nvim";
      environment.VIMINIT = "source ${configDir}/init.lua";
      flags = [
        "--cmd"
        "lua vim.opt.packpath:prepend('${configDir}'); vim.opt.runtimepath:prepend('${configDir}'); ${
          if devPlugins != {} then
            ''
              vim.opt.runtimepath:prepend('${
                concatStringsSep "," (attrValues devPlugins)
              }'); vim.opt.runtimepath:append('${
                concatStringsSep "," (map (p: p + "/after") (attrValues devPlugins))
              }')
            ''
          else
            ""
        }"
      ];
      postWrap = ''
        ${concatStringsSep "\n" (
          map (x: ''ln -s "$out/bin/nvim" "$out/bin/"'${x}' '') options.aliases or []
        )}
      '';
    };

  meta = {
    maintainers = [ "Squawkykaka" ];
  };
}
