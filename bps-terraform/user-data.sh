#!/bin/bash
set -euxo pipefail

apt-get update

apt-get install -y \
  curl \
  wget \
  unzip \
  ca-certificates

wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb \
  -O /tmp/packages-microsoft-prod.deb

dpkg -i /tmp/packages-microsoft-prod.deb

apt-get update

apt-get install -y aspnetcore-runtime-8.0

mkdir -p /opt/bps

cat > /opt/bps/status.txt <<EOF
BPS .NET 8 server is ready.
Deploy BPS.Api.dll to /opt/bps/ during CI/CD.
EOF
