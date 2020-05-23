#!/usr/bin/env bash
# Mac C. compile-ios.sh

# Defaults
set -e

unset CFLAGS
unset CXXFLAGS
unset LDFLAGS

# Parse args. 
usage(){
cat << EOF
${0##*/}: usage

    Description:
       This simple script builds aria2 for all 64-bit *-apple-darwin devices.

    Arguments:
    --extra-cflags <arg>: Pass defines or includes to clang.
    --extra-cxxflags <arg>: Pass defines or includes to clang++.
    --extra-ldflags <arg>: Pass libs or includes to ld64.
EOF
exit 1
}

while (( $# )); do
   case "$1" in
      --extra-cflags) shift; export CFLAGS_="${1}" ;;
      --extra-cxxflags) shift; export CXXFLAGS_="${1}" ;;
      --extra-ldflags) shift; export LDFLAGS_="${1}" ;;

      --help) usage ;;
      *) echo -e "Unknown option: ${1}\n"; usage ;;
   esac
   shift
done 

# Start building.
echo "Building..."
MAKEJOBS="$(sysctl -n hw.ncpu || echo 1)"
CC_="$(xcrun -f clang || echo clang)"
CXX_="$(xcrun -f clang++ || echo clang++)"

builddir="${TMPDIR:-/tmp}/${RANDOM:-'xxxxx'}-compile-ios-build"
cwd="$(realpath ${PWD} 2>/dev/null || echo ${PWD})"

t_exit() {
cat << EOF

A error as occured.
    aria2 location: ${cwd}

    Provide config.log and console logs when posting a issue.

EOF
}
trap t_exit ERR

# for arch in i386 x86_64 armv7 armv7s arm64; do
 for arch in x86_64 arm64; do
     if [[ "$arch" = "i386" || "$arch" = "x86_64" ]]; then
         SYSROOT=$(xcrun -f --sdk iphonesimulator --show-sdk-path)
     else
         SYSROOT=$(xcrun -f --sdk iphoneos --show-sdk-path)
     fi
     HOST="${arch}-apple-darwin"
     [[ "${arch}" = "arm64" ]] && HOST="aarch64-apple-darwin"

# AppleTLSContext.cc:135:27: warning: 'SecCopyErrorMessageString' is only available on iOS 11.3 or newer
#  No support for 32-bit devices without compiling openssl/gnutls
#  Append with-openssl / with-gnutls with cflags/ldflags if needed

     CFLAGS="-arch ${arch} -miphoneos-version-min=11.3 -isysroot ${SYSROOT} ${CFLAGS_} -D_REENTRANT"
     CXXFLAGS="-arch ${arch} -miphoneos-version-min=11.3 -isysroot ${SYSROOT} ${CXXFLAGS_} -D_REENTRANT -DCIPHER_NO_DHPARAM"
     LDFLAGS="-arch ${arch} -miphoneos-version-min=11.3 -isysroot ${SYSROOT} ${LDFLAGS_}"
     CC="${CC_} ${CFLAGS}"
     CXX="${CXX_} ${CXXFLAGS}"

     cd ${cwd}
     [[ ! -f ./configure ]] && autoreconf -ivf
     CC=${CC} CXX=${CXX} CFLAGS=${CFLAGS} CXXFLAGS=${CXXFLAGS} LDFLAGS=${LDFLAGS} \
     ./configure --host=${HOST} --build=$(./config.guess) --enable-docs=no --enable-shared=no --enable-static=yes --prefix=/	\
          --without-libxml2 --with-appletls --without-openssl --without-gnutls --without-libgmp --without-libnettle --without-libgcrypt --enable-libaria2
     make -j${MAKEJOBS} install DESTDIR="${cwd}/ios/${arch}"
     make distclean
 done

mkdir -p "${cwd}/ios/dest/lib"
# lipo, make a static lib.
# lipo -create -output ${cwd}/ios/dest/lib/libaria2.a ${cwd}/ios/aria2/{i386,x86_64,armv7,armv7s,arm64}/lib/libaria2.a
lipo -create -output ${cwd}/ios/dest/lib/libaria2.a ${cwd}/ios/{x86_64,arm64}/lib/libaria2.a

# Take the arm64 headers- the most common target.
cp -r ${cwd}/ios/aria2/arm64/include ${cwd}/ios/dest/
rm -rf ${cwd}/build/ios/{i386,x86_64,armv7,armv7s,arm64} || :

echo "Output to ${cwd}/ios/dest"
