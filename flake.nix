{
  description = "Nori SDK playground";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # root keeps each variant's checkouts and .venv apart, so trying HEAD never touches the pinned setup.
        mkPlaygroundShell = { root, sdkRev, descriptionRev }: pkgs.mkShell {
          packages = [ pkgs.uv pkgs.git ];

          shellHook = ''
            # uv's standalone Python avoids Nix Python / MuJoCo wheel linking issues on macOS.
            export UV_PYTHON_PREFERENCE=only-managed

            root=${root}
            mkdir -p "$root" || exit 1

            # Pinned checkouts are fetched once and checked; HEAD checkouts are refreshed on every entry.
            # A first fetch goes into a temporary directory so an interrupted fetch is retried next time.
            sync_checkout() {
              if [ ! -d "$1" ]; then
                rm -rf "$1.tmp"
                git init -q "$1.tmp" &&
                  git -C "$1.tmp" fetch -q --depth 1 "$2" "$3" &&
                  git -C "$1.tmp" checkout -q FETCH_HEAD &&
                  mv "$1.tmp" "$1"
              elif [ "$3" = HEAD ]; then
                git -C "$1" fetch -q --depth 1 "$2" HEAD && git -C "$1" checkout -q FETCH_HEAD ||
                  echo "warning: could not update $1; using $(git -C "$1" rev-parse --short HEAD)" >&2
              elif [ "$(git -C "$1" rev-parse HEAD)" != "$3" ]; then
                echo "warning: $1 is not at the tested commit $3" >&2
              fi
            }
            sync_checkout "$root/nori-sdk-py" https://github.com/Nori-Robotics/nori-sdk-py ${sdkRev} || exit 1
            sync_checkout "$root/nori_description" https://github.com/Nori-Robotics/nori_description ${descriptionRev} || exit 1

            [ -d "$root/.venv" ] || uv venv --python 3.12 "$root/.venv" || exit 1

            # Install only when the SDK's dependencies or this request change, so later entries work offline.
            install_args="-e ./$root/nori-sdk-py[all] mujoco"
            install_key=$( { echo "$install_args"; cat "$root/nori-sdk-py/pyproject.toml"; } | git hash-object --stdin )
            if [ "$(cat "$root/.venv/.nori-install-key" 2>/dev/null)" != "$install_key" ]; then
              uv pip install --python "$root/.venv/bin/python" $install_args || exit 1
              echo "$install_key" > "$root/.venv/.nori-install-key"
            fi
            source "$root/.venv/bin/activate"

            echo "Nori playground ready ($root: sdk $(git -C "$root/nori-sdk-py" rev-parse --short HEAD), description $(git -C "$root/nori_description" rev-parse --short HEAD)): python main.py"
          '';
        };
      in {
        # Upstream commits tested with main.py and a MuJoCo load of the robot model.
        devShells.default = mkPlaygroundShell {
          root = ".";
          sdkRev = "a8db25b972ac8c066048962b2f4790daddfff1f4";
          descriptionRev = "1c384121e51998d714ddc39185e491648fec9367";
        };

        # Latest upstream, for checking whether a newer commit is worth pinning: nix develop .#head
        devShells.head = mkPlaygroundShell {
          root = ".head";
          sdkRev = "HEAD";
          descriptionRev = "HEAD";
        };
      });
}
