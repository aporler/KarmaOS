#!/bin/bash
set -euo pipefail
source /home/ubuntu/KarmaOS/snaps/karmaos-welcome/parts/assets/run/environment.sh
set -x
cp --archive --link --no-dereference . "/home/ubuntu/KarmaOS/snaps/karmaos-welcome/parts/assets/install"
