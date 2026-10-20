# Nori playground

A starting point for the [Nori SDK](https://github.com/Nori-Robotics/nori-sdk-py).
`main.py` connects to a mock robot, discovers its joints, moves the base, sets a
gripper position, reads telemetry, and confirms an emergency stop before closing.
It runs without a physical robot.

## Run

From this directory, with a flakes-enabled Nix installation:

```sh
nix develop
python main.py
```

Or run it directly:

```sh
nix develop --command python main.py
```

The first shell entry downloads tested commits of the upstream SDK and robot
description, creates `.venv` with uv-managed Python 3.12, and installs the SDK's
`all` extras and MuJoCo. This needs internet access. Later entries reuse the
checkouts and environment and work offline; they reinstall only when the SDK's
`pyproject.toml` changes. Setup errors stop shell entry rather than displaying a
success message.

For automatic activation with direnv, run `direnv allow` once in this directory.
The `.envrc` uses `use flake` from nix-direnv.

## Files

```text
main.py             Your experiment; start editing here
flake.nix           Nix development shell
flake.lock          Pinned Nix inputs
.envrc              Optional direnv activation
nori-sdk-py/        Downloaded SDK source and examples (ignored by Git)
nori_description/   Downloaded robot models (ignored by Git)
.venv/              Python environment (ignored by Git)
```

The SDK is installed in editable mode: changes inside `nori-sdk-py/src/` take
effect immediately. The SDK and robot description commits are pinned in
`flake.nix` (`sdkRev`, `descriptionRev`); `flake.lock` only locks the Nix tools.
Python dependency versions are not pinned.

### Try upstream HEAD

```sh
nix develop .#head
python main.py
```

This shell keeps its own checkouts and `.venv` under `.head/` (ignored by Git),
so the pinned setup is untouched. It fetches the latest upstream commits on every
entry; offline, it warns and uses the last fetched ones. The ready message shows
which commits are in use.

To move the pinned setup to a newer commit, test it here, update `sdkRev` or
`descriptionRev` in `flake.nix`, and delete the old checkout so the default shell
fetches the new one.

## Models and simulation

MuJoCo and `nori_description` are included in the development shell for later
experiments. `main.py` uses the SDK's in-memory mock; it does not open a 3D viewer
or connect the SDK to MuJoCo. The description repository contains URDF/xacro
assets, not a ready-to-run MuJoCo scene. See its
[README](https://github.com/Nori-Robotics/nori_description#readme) for model details.

For hardware later, the SDK's [quickstart](https://github.com/Nori-Robotics/nori-sdk-py#quickstart-against-a-robot)
shows `RemoteTeleop`, `SupabaseSignaling`, and authentication. A passing mock run
checks application logic; it does not validate a physical robot or its network.
