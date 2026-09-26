{
  config,
  lib,
  pkgs,
  devenv-module-operaton,
  ...
}:
let
  # One public port: the proxy serves Plone at / and Operaton at /operaton.
  # Plone and Operaton also have fixed ports of their own, so that they can
  # reach each other at localhost. Only the proxy is forwarded by Codespaces.
  proxyPort = 8000;
  plonePort = 8080;
  operatonPort = 8800;
  tasksPort = 8081;

  # Rewrites requests to Plone into its VirtualHostMonster, so that Plone
  # generates URLs for the public address, and tells Operaton the public scheme
  # and port (Codespaces terminates https on 443). VHM_BASE, PUBLIC_SCHEME and
  # PUBLIC_PORT are set by the proxy process below.
  caddyfile = pkgs.writeText "Caddyfile" ''
    {
      admin off
      auto_https off
    }
    :${toString proxyPort} {
      @operaton path /operaton /operaton/*
      handle @operaton {
        reverse_proxy localhost:${toString operatonPort} {
          header_up X-Forwarded-Proto {$PUBLIC_SCHEME}
          header_up X-Forwarded-Port {$PUBLIC_PORT}
        }
      }
      handle {
        rewrite * {$VHM_BASE}{uri}
        reverse_proxy localhost:${toString plonePort}
      }
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
    # Login for Cockpit, Tasklist and Admin. Operaton creates the user only
    # when it does not exist yet, so changes need a fresh database.
    adminUser.id = "demo";
    adminUser.password = "demo";
    # Only ping.bpmn: the other diagrams are illustrations for the docs, and
    # Operaton refuses to deploy them (no history time to live, missing refs).
    deployment = lib.fileset.toSource {
      root = ../docs/diagrams;
      fileset = ../docs/diagrams/ping.bpmn;
    };
    forwardHeadersStrategy = "native";
    package = devenv-module-operaton.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };

  # Reachable only through the proxy (and the workers) at localhost.
  processes.operaton.env.SERVER_ADDRESS = "127.0.0.1";

  processes.plone = {
    exec = "make plone-serve PORT=${toString plonePort}";
    ready.exec = "${pkgs.curl}/bin/curl -sf -o /dev/null http://localhost:${toString plonePort}/Plone";
  };

  processes.proxy.exec = ''
    if [ -n "''${CODESPACE_NAME:-}" ]; then
      export PUBLIC_SCHEME=https
      export PUBLIC_PORT=443
      export VHM_BASE="/VirtualHostBase/https/''${CODESPACE_NAME}-${toString proxyPort}.''${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}:443/Plone/VirtualHostRoot"
    else
      export PUBLIC_SCHEME=http
      export PUBLIC_PORT=${toString proxyPort}
      export VHM_BASE="/VirtualHostBase/http/localhost:${toString proxyPort}/Plone/VirtualHostRoot"
    fi
    exec ${pkgs.caddy}/bin/caddy run --config ${caddyfile} --adapter caddyfile
  '';

  ## Environment

  # Where operaton-tasks finds the engine. Its default is port 8080 (Plone).
  env.ENGINE_REST_BASE_URL = "http://localhost:${toString operatonPort}/engine-rest";

  # Runs the operaton-tasks worker from tasks/, with its own virtualenv (the
  # shell's UV_PROJECT_ENVIRONMENT is Plone's), e.g.
  #   operaton-tasks serve tasks/tasks.py
  scripts.operaton-tasks.exec = ''
    export UV_PROJECT_ENVIRONMENT=${config.devenv.root}/tasks/.venv
    export LOG_LEVEL="''${LOG_LEVEL:-INFO}"
    uv sync --quiet --project ${config.devenv.root}/tasks
    # serve runs uvicorn (health check at /healthz), whose default port 8000
    # belongs to the proxy: keep it on loopback at ${toString tasksPort}.
    if [ "''${1:-}" = serve ] && ! printf '%s\n' "$@" | grep -qx -- '--'; then
      set -- "$@" -- --host 127.0.0.1 --port ${toString tasksPort}
    fi
    exec ${config.devenv.root}/tasks/.venv/bin/operaton-tasks "$@"
  '';

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
