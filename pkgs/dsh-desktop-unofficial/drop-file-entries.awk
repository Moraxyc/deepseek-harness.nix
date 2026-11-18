# Drops yarn.lock entries resolved from local `file:` paths, which
# yarn-berry-fetcher cannot fetch.
/^".*@file:/ { skip = 1; next }
skip && /^$/ { skip = 0; next }
!skip { print }
