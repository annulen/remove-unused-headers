#!/bin/sh

# -f- - print to stdout
# u - do not sort
# n - only line number
# +p - function prototypes
# -n - exclude namespaces
# +a - access information

ctags -f- --language-force=c++ -un --file-scope=no --c++-kinds=+p-n  --fields=+a "$@" | grep -vw 'access:private' | grep -vw 'access:protected' | egrep -v '^~' | egrep -v '^!' > tags
