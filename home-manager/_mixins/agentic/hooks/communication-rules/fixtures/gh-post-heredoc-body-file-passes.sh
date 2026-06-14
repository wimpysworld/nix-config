#!/usr/bin/env bash

cat > heredoc-post-body.md <<'EOF'
Done.
EOF
gh issue comment 42 --body-file heredoc-post-body.md
