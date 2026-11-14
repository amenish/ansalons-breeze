#!/usr/bin/env bash
# Genera dist/ansalon-sddm-<versión>.tar.gz con la carpeta ansalon/ lista para instalar
set -euo pipefail
cd "$(dirname "$0")"
ver=$(sed -n 's/^Version=//p' metadata.desktop)
mkdir -p dist
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/ansalon"
cp -r *.qml metadata.desktop theme.conf default-logo.svg 5120x2880.png preview.png faces "$tmp/ansalon/"
tar -czf "dist/ansalon-sddm-$ver.tar.gz" -C "$tmp" ansalon
cp packaging/PKGBUILD packaging/ansalon.conf dist/
sed -i "s/^pkgver=.*/pkgver=$ver/" dist/PKGBUILD
echo "dist/ansalon-sddm-$ver.tar.gz"
