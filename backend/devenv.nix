{
  config,
  lib,
  pkgs,
  devenv-module-operaton,
  ...
}:
let
  # The public entry is the proxy on 8000; Plone and Operaton are also
  # forwarded by Codespaces so that they can be opened directly.
  proxyPort = 8000;
  plonePort = 8080;
  operatonPort = 8800;
  tasksPort = 8081;

  # Rewrites requests into Plone's VirtualHostMonster, so that Plone generates
  # URLs for the public address. VHM_BASE is set by the proxy process below.
  caddyfile = pkgs.writeText "Caddyfile" ''
    {
      admin off
      auto_https off
    }
    :${toString proxyPort} {
      rewrite * {$VHM_BASE}{uri}
      reverse_proxy localhost:${toString plonePort}
    }
  '';
in
{
  languages.python.enable = true;
  languages.python.uv.enable = true;
  languages.javascript.enable = true;
  languages.javascript.npm.enable = true;
  languages.javascript.pnpm.enable = true;

  cachix.pull = [ "vasara-bpm" ];

  ## Services

  services.operaton = {
    enable = true;
    port = operatonPort;
    # Only ping.bpmn: the other diagrams are illustrations for the docs, and
    # Operaton refuses to deploy them (no history time to live, missing refs).
    deployment = lib.fileset.toSource {
      root = ../docs/diagrams;
      fileset = ../docs/diagrams/ping.bpmn;
    };
    forwardHeadersStrategy = "native";
    package = devenv-module-operaton.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };

  processes.plone = {
    exec = "make plone-serve PORT=${toString plonePort}";
    ready.exec = "${pkgs.curl}/bin/curl -sf -o /dev/null http://localhost:${toString plonePort}/Plone";
  };

  processes.proxy.exec = ''
    if [ -n "''${CODESPACE_NAME:-}" ]; then
      export VHM_BASE="/VirtualHostBase/https/''${CODESPACE_NAME}-${toString proxyPort}.''${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}:443/Plone/VirtualHostRoot"
    else
      export VHM_BASE="/VirtualHostBase/http/localhost:${toString proxyPort}/Plone/VirtualHostRoot"
    fi
    exec ${pkgs.caddy}/bin/caddy run --config ${caddyfile} --adapter caddyfile
  '';

  # External task worker for Operaton. operaton-tasks runs its own uvicorn
  # server, which must not take the default port 8000 from the proxy.
  processes.tasks = {
    exec = ''
      export UV_PROJECT_ENVIRONMENT=${config.devenv.root}/tasks/.venv
      export LOG_LEVEL=INFO
      exec uv run --project tasks operaton-tasks serve tasks/tasks.py -- --port ${toString tasksPort}
    '';
    after = [ "devenv:processes:operaton" ];
  };

  ## Environment

  # Where operaton-tasks finds the engine. Its default is port 8080 (Plone).
  env.ENGINE_REST_BASE_URL = "http://localhost:${toString operatonPort}/engine-rest";

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
  env.UV_PYTHON_DOWNLOADS = "never";

  # The generated project's Makefile expects its venv in site/backend/.venv.
  env.UV_PROJECT_ENVIRONMENT = lib.mkForce "${config.devenv.root}/site/backend/.venv";
  env.HATCH_DATA_DIR = "${config.devenv.root}/.devenv/state/hatch";

  # NixOS: hatch would otherwise run the uv binary from the PyPI wheel.
  env.HATCH_ENV_TYPE_VIRTUAL_UV_PATH = "${pkgs.uv}/bin/uv";
}
