#!/usr/bin/env sh

set -e

# Available targets
# Not supported yet: i686-pc-windows-gnu x86_64-pc-windows-gnu
TARGETS=(x86_64-unknown-linux-gnu x86_64-apple-darwin x86_64-unknown-freebsd)

RELEASE_DIR="./target/gh-release"

export RUSTFLAGS="-C lto"
export PKG_CONFIG_ALLOW_CROSS=1
export PATH=/opt/osxcross/bin:$PATH

release() {
    rm -rf $RELEASE_DIR
    mkdir -p $RELEASE_DIR

    git_tag=$(git describe --exact-match --tags $(git log -n1 --pretty='%h'))

    for target in "${TARGETS[@]}"
    do
        cross build --release --target=${target}

        binary=$(find "./target/${target}/release/" -maxdepth 1 -iname "battop*" -type f -executable)
        binary_filename=$(basename -- "$binary")
        #binary_name="${binary_filename%.*}"
        #binary_ext="${binary_filename##*.}"
        binary_ext=""

        new_name="battop-${git_tag}-${target}${binary_ext}"
        new_path="${RELEASE_DIR}/${new_name}"

        cp -p $binary $new_path

        cd ${RELEASE_DIR}

        sha512sum -b $new_name > "${new_name}.sha512"
        gpg -ab --yes $new_name

        cd -
    done

    archives=("${git_tag}.zip" "${git_tag}.tar.gz")
    for archive in "${archives[@]}"
    do
        long_name="rust-battop-${archive}"
        wget https://github.com/svartalf/rust-battop/archive/$archive -O ${RELEASE_DIR}/${long_name}
        cd ${RELEASE_DIR}

        sha512sum -b $long_name > "${long_name}.sha512"
        gpg -ab --yes $long_name

        cd -
    done
}

aur() {
    echo "Do the following:"
    echo "cd packages/arch-linux"
    echo "Update version"
    echo "makepkg --printsrcinfo > .SRCINFO"
    echo "ssh-add ~/.ssh/aur"
    echo "git commit -m '' -s"
    echo "git push"
}

reprotest() {
    reprotest -vv --vary=-time,-domain_host --source-pattern 'Cargo.* src/' '
        CARGO_HOME="$PWD/.cargo" RUSTUP_HOME='"$HOME/.rustup"' \
            RUSTFLAGS="--remap-path-prefix=$HOME=/remap-home --remap-path-prefix=$PWD=/remap-pwd" \
            cargo build --release --verbose' \
        target/release/battop
    }

case $1 in
	release)
	    release
		;;
    reprotest)
        reprotest
        ;;
    aur)
        aur
        ;;
	*)
		echo "Usage: $0 release|reprotest"
		;;
esac
