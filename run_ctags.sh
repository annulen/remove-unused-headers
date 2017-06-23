#!/bin/sh

# u - do not sort
# n - only line number
# +p - function prototypes
# -n - exclude namespaces
# +a - access information

ctags -un --file-scope=no --c++-kinds=+p-n  --fields=+a "$@"
