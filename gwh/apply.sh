#!/usr/bin/env bash
# GWHSUPPORT: writes the app name, server address and key into the
# hbb_common submodule at build time (the submodule is not part of this fork).
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="GWHSUPPORT"
# Public address only: the office router loops it back to the server, so it
# works inside the office and outside. (SERVER_LAN kept for reference.)
SERVER_LAN="192.168.0.193"
SERVER="178.134.167.254"
KEY="3fTlZsrbotcBrJP8QKeMwNNVKAzPhH5Mpg1wVr2+dGM="

CFG=libs/hbb_common/src/config.rs
sed -i.bak \
  -e "s|RwLock::new(\"RustDesk\".to_owned())|RwLock::new(\"${APP_NAME}\".to_owned())|" \
  -e "s|^pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[.*\];|pub const RENDEZVOUS_SERVERS: \&[\&str] = \&[\"${SERVER}\"];|" \
  -e "s|^pub const RS_PUB_KEY: &str = \".*\";|pub const RS_PUB_KEY: \&str = \"${KEY}\";|" \
  "$CFG"
rm -f "$CFG.bak"

grep -q "\"${APP_NAME}\".to_owned()" "$CFG"
grep -q "RENDEZVOUS_SERVERS: &\[&str\] = &\[\"${SERVER}\"\];" "$CFG"
grep -q "\"${KEY}\"" "$CFG"
echo "GWHSUPPORT branding applied:"
grep -n "APP_NAME: RwLock\|RENDEZVOUS_SERVERS: \|RS_PUB_KEY: " "$CFG"
