#!/bin/bash

BASE=$(dirname $(realpath $0))
cd ${BASE}

sourcename="xdebug"
softname="php-xdebug"
version="3.1.6"
TAG="1-tit"
sourcedir="${sourcename}-${version}"
STORAGE=$(realpath ${HOME}/local/packages )
OS=$(cat /etc/slackware-version | cut -f2 -d' ')

if [[ ${OS} == *"+" ]]; then
  OS="current"
fi


if [ -z "$ARCH" ]; then
  case "$( uname -m )" in
    i?86) ARCH=i586 ;;
    arm*) ARCH=arm ;;
       *) ARCH=$( uname -m ) ;;
  esac
fi

if [ "$ARCH" = "i586" ]; then
  SLKCFLAGS="-O2 -march=i586 -mtune=i686"
  LIBDIRSUFFIX=""
elif [ "$ARCH" = "i686" ]; then
  SLKCFLAGS="-O2 -march=i686 -mtune=i686"
  LIBDIRSUFFIX=""
elif [ "$ARCH" = "x86_64" ]; then
  SLKCFLAGS="-O2 -fPIC"
  LIBDIRSUFFIX="64"
else
  SLKCFLAGS="-O2"
  LIBDIRSUFFIX=""
fi

packagedir="${softname}-${version}-${ARCH}-${OS}-${TAG}"

SRC_URL="https://github.com/xdebug/xdebug/archive/refs/tags/${version}.tar.gz"

[ -d ${BASE}/packages ] || mkdir -p ${BASE}/packages
[ -f ${BASE}/packages/${sourcename}-${version}.tar.gz ] || {
	cd ${BASE}/packages
	echo "* get src: ${sourcename}-${version}"

	wget -vNc $SRC_URL -O ${BASE}/packages/${sourcename}-${version}.tar.gz \
    || { echo "wget ${sourcename}-${version}.tar.gz failed..."; exit 1; }
	cd ${BASE}
}

rm -fr ${BASE}/${sourcename}*

tar xvf ${BASE}/packages/${sourcedir}.tar.gz || exit 1

cd ${BASE}/${sourcedir} || exit 1

chown -R root:root .
find -L . \
  \( -perm 777 -o -perm 775 -o -perm 750 -o -perm 711 -o -perm 555 -o -perm 511 \) \
  -exec chmod 755 {} \; -o \
  \( -perm 666 -o -perm 664 -o -perm 600 -o -perm 444 -o -perm 440 -o -perm 400 \) \
  -exec chmod 644 {} \;

/usr/bin/phpize \
  || { echo "phpize failed"; exit 1; }

CFLAGS="$SLKCFLAGS" \
CXXFLAGS="$SLKCFLAGS" \
./configure \
  --prefix=/usr \
  --libdir=/usr/lib${LIBDIRSUFFIX} \
  --sysconfdir=/etc \
  --localstatedir=/var \
  --mandir=/usr/man \
  --docdir=/usr/doc/${softname}-${version} \
  --with-php-config=/usr/bin/php-config \
  --build=$ARCH-slackware-linux \
  --enable-xdebug \
  || { echo "configure failed"; exit 1; }

make -j$(nproc) \
  || { echo "make failed"; exit 1; }

destdir=${BASE}/${packagedir}
extdir=${destdir}/$(/usr/bin/php-config --extension-dir)
mkdir -p ${extdir}

make install DESTDIR=${destdir} EXTENSION_DIR=${extdir}

mkdir -p ${destdir}/etc/php.d
install -m 644 ${BASE}/${sourcedir}/xdebug.ini ${destdir}/etc/php.d/xdebug.ini.new

sed -i "s/LIBDIR/lib${LIBDIRSUFFIX}/g" ${destdir}/etc/php.d/xdebug.ini.new
sed -e "1,2d" xdebug.ini >> ${destdir}/etc/php.d/xdebug.ini.new

mkdir -p ${destdir}/usr/lib${LIBDIRSUFFIX}/php/.pkgxml
install -m 644 ${BASE}/${sourcedir}/package.xml ${destdir}/usr/lib${LIBDIRSUFFIX}/php/.pkgxml/xdebug.xml

find ${destdir} | xargs file | grep -e "executable" -e "shared object" | grep ELF \
  | cut -f 1 -d : | xargs strip --strip-unneeded 2> /dev/null || true

mkdir -p ${destdir}/usr/doc/${softname}-${version}
cp -a CREDITS LICENSE README.rst \
  ${destdir}/usr/doc/${softname}-${version}

cp -a ${BASE}/assets ${destdir}/usr/doc/${softname}-${version}
cp -a ${BASE}/$(basename $0) ${destdir}/usr/doc/${softname}-${version}

mkdir -p ${destdir}/install
cat ${BASE}/assets/slack-desc > ${destdir}/install/slack-desc
sed "s|LIBDIRSUFFIX|${LIBDIRSUFFIX}|" ${BASE}/assets/doinst.sh > ${destdir}/install/doinst.sh

cd ${destdir}
/sbin/makepkg -l y -c n ${destdir}.txz

