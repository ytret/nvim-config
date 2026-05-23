#!/usr/bin/env bash
# vim: set ts=4 sw=4 noet:

NVIM="${NVIM:-nvim}"
test_dir="tests"

usage() {
	cat <<- EOF
	Usage: $0 [-h] [test_directory]

	Run plenary.nvim test harness inside a headless Neovim instance.

	Arguments:
	  test_directory  directory containing test files (default: tests/)

	Options:
	  -h  show this help message and exit
	EOF
}

while getopts "h" opt; do
	case "$opt" in
		h) usage; exit 0 ;;
		*) usage 1>&2; exit 1 ;;
	esac
done
shift $((OPTIND - 1))

if [ $# -gt 1 ]; then
	echo "Error: unexpected positional arguments: $*" >&2
	usage >&2
	exit 1
fi

if [ $# -eq 1 ]; then
	test_dir="$1"
fi

cd "$(dirname "$0")"
exec "$NVIM" --headless \
	-c "lua require('plenary.test_harness').test_directory('${test_dir}', {minimal_init='tests/init.lua'})" \
	-c "q"
