# Maintainer: Amenish <amenish@ansalon.es>
pkgname=sddm-theme-ansalon
pkgver=1.1
pkgrel=1
pkgdesc="Tema SDDM Ansalon basado en Breeze (Qt6)"
arch=(any)
url="https://github.com/amenish/ansalons-breeze"
license=(LGPL-2.0-or-later)
depends=(sddm plasma-desktop qt6-5compat)
makedepends=(git)
optdepends=('breeze: tema de cursor breeze_cursors')
backup=(usr/lib/sddm/sddm.conf.d/ansalon.conf)
source=("$pkgname::git+$url.git#tag=v$pkgver")
sha256sums=(SKIP)

package() {
  cd "$pkgname"
  local dest="$pkgdir/usr/share/sddm/themes/ansalon"
  install -Dm644 -t "$dest" *.qml metadata.desktop theme.conf default-logo.svg 5120x2880.png preview.png
  install -Dm644 -t "$dest/faces" faces/.face.icon
  install -Dm644 -t "$pkgdir/usr/lib/sddm/sddm.conf.d" sddm.conf.d/ansalon.conf
}
