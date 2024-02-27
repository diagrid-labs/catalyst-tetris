curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux --init none --no-confirm
bash "../../nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"