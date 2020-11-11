# https://nixos.wiki/wiki/Cheatsheet#Adding_files_to_the_store
LARGE_FILE="`realpath $1`"

(sudo unshare -m bash) <<EOF
  set -x
  HASH=\$(nix-hash --type sha256 --flat --base32 ${LARGE_FILE})
  STOREPATH=\$(nix-store --print-fixed-path sha256 \${HASH} $(basename ${LARGE_FILE}))
  mount -o remount,rw /nix/store
  cp $LARGE_FILE \$STOREPATH
  printf "\$STOREPATH\n\n0\n" | nix-store --register-validity --reregister
EOF
