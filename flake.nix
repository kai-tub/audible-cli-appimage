#
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/x86_64-linux";
    # nix-filter.url = "github:numtide/nix-filter";
    # devshell.url = "github:numtide/devshell";
    nix-appimage = {
      url = "github:ralismark/nix-appimage";
      # inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    self,
    nixpkgs,
    systems,
    nix-appimage,
    # nix-filter,
    # devshell,
  } @ inputs: let
    eachSystem = nixpkgs.lib.genAttrs (import systems);
    # pkgsFor = eachSystem (system: (nixpkgs.legacyPackages.${system}.extend devshell.overlays.default));
    pkgsFor = eachSystem (system: (nixpkgs.legacyPackages.${system}));
    # filter = nix-filter.lib;
  in rec {
    formatter = eachSystem (system: pkgsFor.${system}.alejandra);
    checks = eachSystem (system: self.packages.${system});

    packages = eachSystem (system: let
      pkgs = pkgsFor.${system};
    in rec {
      # FUTURE: Wrap the appimage in such way that the `audible` binary
      # is called by default but that it auto-forwards calls to
      # audible-quickstart if called via `quickstart`
      "audibleAppImage" = inputs.nix-appimage.mkappimage.${system} {
        drv = audible-cli;
        name = audible-cli.name;
        entrypoint = pkgs.lib.getExe audible-cli;
      };

      isbnlib = pkgs.python3Packages.buildPythonApplication rec {
        pname = "isbnlib";
        version = "3.10.14";
        pyproject = true;

        src = pkgs.fetchFromGitHub {
          owner = "xlcnd";
          repo = "isbnlib";
          rev = "refs/tags/v${version}";
          hash = "sha256-d6p0wv7kj+NOZJRE2rzQgb7PXv+E3tASIibYCjzCdx8=";
        };

        nativeBuildInputs = with pkgs.python3Packages; [
          setuptools
        ];
        # propagatedBuildInputs = with pkgs.python3Packages; []

        # not bothered to get the internal tests up and running
        # but they are defined via pytest in `setup.cfg`
        doCheck = false;

        pythonImportsCheck = [
          "isbnlib"
        ];

        passthru.updateScript = pkgs.nix-update-script {};

        meta = with pkgs.lib; {
          description = "A Python library to validate, clean, transform and get metadata of ISBN strings (for devs).";
          license = licenses.lgpl3Plus;
          homepage = "https://github.com/xlcnd/isbnlib";
          changelog = "https://github.com/xlcnd/isbnlib/tree/v${src.rev}/CHANGES.txt";
          maintainers = with pkgs.lib.maintainers; [kai-tub];
        };
      };

      isbntools = pkgs.python3Packages.buildPythonApplication rec {
        pname = "isbntools";
        version = "4.3.29";
        pyproject = true;

        src = pkgs.fetchFromGitHub {
          owner = "xlcnd";
          repo = "isbntools";
          rev = "refs/tags/v${version}";
          hash = "sha256-s47y14YHL/ihAUCnneDcTlyVQj3rUgUnBLD2dPBGD/Y=";
        };

        nativeBuildInputs = with pkgs.python3Packages; [
          setuptools
        ];
        propagatedBuildInputs = with pkgs.python3Packages; [
          isbnlib
        ];

        # not bothered to get the internal tests up and running
        # but they are defined via pytest in `setup.cfg`
        doCheck = false;

        pythonImportsCheck = [
          "isbntools"
        ];

        passthru.updateScript = pkgs.nix-update-script {};

        meta = with pkgs.lib; {
          description = "A Python framework for 'all things ISBN' including metadata, descriptions, covers...";
          license = licenses.lgpl3Plus;
          homepage = "https://github.com/xlcnd/isbntools";
          changelog = "https://github.com/xlcnd/isbntools/tree/v${src.rev}/CHANGES.txt";
          maintainers = with pkgs.lib.maintainers; [kai-tub];
        };
      };

      default = audible-cli;

      # Most of the code was taken from nixpkgs and with special thanks to the
      # upstream maintainer `jvanbruegge`
      # https://github.com/NixOS/nixpkgs/blob/63c3a29ca82437c87573e4c6919b09a24ea61b0f/pkgs/by-name/au/audible-cli/package.nix
      audible-cli = let
        rev = "b3adb9a33157322cd6d79ff59f5dacf06dc3e034";
      in
        pkgs.python3Packages.buildPythonApplication rec {
          pname = "audible-cli";
          # version = "0.3.2";
          version = "${builtins.substring 0 6 rev}";
          pyproject = true;

          src = pkgs.fetchFromGitHub {
            owner = "mkb79";
            repo = "audible-cli";
            # rev = "refs/tags/v${version}";
            # hard-coding master branch for now
            inherit rev;
            hash = "sha256-tzmpOe0Q6VvhxcycPgfGXmNgXdVLLeYeQhAez5O1QhA=";
            # hash = pkgs.lib.fakeHash;
          };

          # there is no real benefit of trying to make ffmpeg smaller, as it
          # only takes about 25MB, whereas Python takes >120MB.
          # So there is nothing much I can do.
          dependencies = [pkgs.ffmpeg-headless];
          makeWrapperArgs = ["--set AUDIBLE_PLUGIN_DIR $src/plugin_cmds"];

          nativeBuildInputs = with pkgs.python3Packages; [
            pythonRelaxDepsHook
            setuptools
          ];
          # ++ [
          #   pkgs.installShellFiles
          # ];

          propagatedBuildInputs = with pkgs.python3Packages;
            [
              aiofiles
              audible
              click
              httpx
              packaging
              pillow
              questionary
              setuptools
              tabulate
              toml
              tqdm
            ]
            ++ [
              isbntools
            ];

          pythonRelaxDeps = [
            "httpx"
          ];

          # FUTURE: Fix fish code_completions & re-enable them
          # postInstall = ''
          #   export PATH=$out/bin:$PATH
          #   installShellCompletion --cmd audible \
          #     --bash <(source utils/code_completion/audible-complete-bash.sh) \
          #     --fish <(source utils/code_completion/audible-complete-zsh-fish.sh) \
          #     --zsh <(source utils/code_completion/audible-complete-zsh-fish.sh)
          # '';

          # upstream has no tests
          doCheck = false;

          pythonImportsCheck = [
            "audible_cli"
          ];

          passthru.updateScript = pkgs.nix-update-script {};

          meta = with pkgs.lib; {
            description = "A command line interface for audible package. With the cli you can download your Audible books, cover, chapter files";
            license = licenses.agpl3Only;
            homepage = "https://github.com/mkb79/audible-cli";
            changelog = "https://github.com/mkb79/audible-cli/blob/${src.rev}/CHANGELOG.md";
            maintainers = with maintainers; [kai-tub];
            mainProgram = "audible";
          };
        };
    });
  };
}
