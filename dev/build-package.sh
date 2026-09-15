#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
package_dir=$(dirname -- "$script_dir")
package_name=$(awk '/^Package:/ { print $2 }' "$package_dir/DESCRIPTION")
package_version=$(awk '/^Version:/ { print $2 }' "$package_dir/DESCRIPTION")
tarball="${package_name}_${package_version}.tar.gz"
build_dir="$package_dir/build"
temporary_dir=$(mktemp -d "$(dirname -- "$package_dir")/.${package_name}-build.XXXXXX")

cleanup() {
    rm -rf -- "$temporary_dir"
    rm -f -- "$package_dir/inst/build-provenance.json"
}
trap cleanup EXIT HUP INT TERM

mkdir -p -- "$build_dir"
python3 "$script_dir/artifact-provenance.py" write
(
    cd -- "$temporary_dir"
    R CMD build "$package_dir"
)

test -f "$temporary_dir/$tarball"
mv -f -- "$temporary_dir/$tarball" "$build_dir/$tarball"
python3 "$script_dir/artifact-provenance.py" archive "$build_dir/$tarball"
