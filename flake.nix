{
  description = "Documentation for BPMN with Plone";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Renders BPMN diagrams (and the token simulation embed) for the Sphinx
    # extension in docs/_ext/sphinx_bpmn.py.
    bpmn-to-image = {
      url = "github:datakurre/bpmn-to-image";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      bpmn-to-image,
    }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});

      # plone-sphinx-theme supports Python >=3.10,<3.14.
      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
      overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };

      pythonSets = forAllSystems (
        _system: pkgs:
        (pkgs.callPackage pyproject-nix.build.packages { python = pkgs.python313; }).overrideScope (
          lib.composeManyExtensions [
            pyproject-build-systems.overlays.wheel
            overlay
          ]
        )
      );

      # Sphinx and its extensions, as locked in uv.lock.
      docsEnvs = forAllSystems (
        system: _pkgs: pythonSets.${system}.mkVirtualEnv "bpmn-with-plone-docs-env" workspace.deps.default
      );

      # The same plus the development tools (sphinx-autobuild).
      devEnvs = forAllSystems (
        system: _pkgs: pythonSets.${system}.mkVirtualEnv "bpmn-with-plone-dev-env" workspace.deps.all
      );
    in
    {
      packages = forAllSystems (
        system: pkgs: {
          # The built HTML site, ready to be published.
          docs = pkgs.stdenvNoCC.mkDerivation {
            pname = "bpmn-with-plone-docs";
            version = "0.1.0";

            src = lib.fileset.toSource {
              root = ./.;
              fileset = ./docs;
            };

            nativeBuildInputs = [
              docsEnvs.${system}
              bpmn-to-image.packages.${system}.default
            ];

            dontConfigure = true;

            buildPhase = ''
              runHook preBuild
              # Fail on warnings, so broken references do not get published.
              sphinx-build -W --keep-going -b html docs build
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              cp -r build $out
              runHook postInstall
            '';
          };

          default = self.packages.${system}.docs;
        }
      );

      apps = forAllSystems (
        system: pkgs: {
          # Rebuild and reload the docs in the browser on every change.
          serve = {
            type = "app";
            program = lib.getExe (
              pkgs.writeShellApplication {
                name = "serve-docs";
                runtimeInputs = [
                  devEnvs.${system}
                  bpmn-to-image.packages.${system}.default
                ];
                text = ''
                  exec sphinx-autobuild --host 0.0.0.0 --watch docs/_ext docs build/html "$@"
                '';
              }
            );
          };
        }
      );

      devShells = forAllSystems (
        system: pkgs: {
          default = pkgs.mkShell {
            packages = [
              devEnvs.${system}
              bpmn-to-image.packages.${system}.default
              pkgs.uv
              pkgs.git
            ];
            env = {
              # Nix owns the environment; uv is only used to update uv.lock.
              UV_NO_SYNC = "1";
              UV_PYTHON = "${devEnvs.${system}}/bin/python";
              UV_PYTHON_DOWNLOADS = "never";
            };
            shellHook = ''
              unset PYTHONPATH
            '';
          };
        }
      );

      checks = forAllSystems (system: _pkgs: { docs = self.packages.${system}.docs; });

      formatter = forAllSystems (_system: pkgs: pkgs.nixfmt-tree);
    };
}
