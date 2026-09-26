{ config, lib, pkgs, ... }:
{
  languages.python.enable = true;
  languages.python.uv.enable = true;
  languages.javascript.enable = true;
  languages.javascript.npm.enable = true;
  languages.javascript.pnpm.enable = true;

  ## Tweaks

  # NixOS: PyPI ruff wheel fails (exit 127) without nix-ld, so use Nix's ruff
  # and shim `uvx ruff` (called by cookieplone) to it.
  packages = [ pkgs.ruff ];

  scripts.uvx.exec = ''
    if [ "$1" = ruff ]; then shift; exec ${pkgs.ruff}/bin/ruff "$@"; fi
    exec ${pkgs.uv}/bin/uvx "$@"
  '';

  # Local cache prevents conflicts with other projects
  env.UV_CACHE_DIR = "${config.devenv.root}/.devenv/state/uv-cache";
  env.UV_NO_CONFIG = "1";
  env.UV_TOOL_DIR = "${config.devenv.root}/.devenv/state/uv-tools";

  # The project Makefile expects its venv in backend/.venv.
  env.UV_PROJECT_ENVIRONMENT = lib.mkForce "${config.devenv.root}/blicca/backend/.venv";
  env.HATCH_DATA_DIR = "${config.devenv.root}/.devenv/state/hatch";

  # NixOS: hatch would otherwise run the uv binary from the PyPI wheel.
  env.HATCH_ENV_TYPE_VIRTUAL_UV_PATH = "${pkgs.uv}/bin/uv";
}
