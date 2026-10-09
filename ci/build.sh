#!/usr/bin/env bash
#
# The fleet's `ci` check for schema-evolution-manager. Landing this file is the
# enrolment: the fleet verify job runs it at a pull request's head sha and posts
# the `ci` status the merge lane reads. devops/templates/ci/build.sh is the
# reference and devops/docs/ci.md carries what is load-bearing about it.
#
# The suite is test/run.rb: rspec over test/specs, about half of it against a
# real Postgres server on which each DB-backed spec creates and drops its own
# throwaway database. That server is this build's own session database, never
# localhost:5432.
#
# ci-needs: docker, registry, database
set -euo pipefail

echo "building ${CI_REPO:-schema-evolution-manager} @ ${CI_SHA:-working tree} (${CI_EVENT:-local}, clean=${CI_CLEAN_BUILD:-?})"

root=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$root"

# The database this build OWNS. The fleet mints `ci-<repo>-<sha>-...` and
# reclaims by that exact name, so it is honoured verbatim. Any other value is
# somebody else's session (the pre-push hook runs this script with the pushing
# session's environment), so the name is keyed on this checkout instead, and
# the EXIT trap below never ends a database a session is using.
ci_session_id() {                  # ci_session_id "<ambient id>" "<checkout path>"
  case "$1" in
    ci-*) printf '%s\n' "$1" ;;
    *) printf 'local-%s-%s\n' "$(basename -- "$2")" "$(printf '%s' "$2" | cksum | awk '{print $1}')" ;;
  esac
}
export CLAUDE_SESSION_ID
CLAUDE_SESSION_ID=$(ci_session_id "${CLAUDE_SESSION_ID:-}" "$root")
echo "session database: $CLAUDE_SESSION_ID"

# A build killed before its EXIT trap fires leaves its container running;
# `dev db session gc` takes it once this pid is gone.
export DEV_DB_SESSION_OWNER_PID=$$

# Captured on its own line and checked: a `start | sed` pipeline reports only
# sed's status, so a failed start would leave CONF_DB_DEV_URL unset. No port is
# named, so a stopped Docker daemon is started by `start` itself. The platform
# image is used only as a Postgres server: the specs create their own databases.
db_out=$(dev db session start --app platform)
printf '%s\n' "$db_out" | grep -v '^CONF_DB_DEV_URL='
export CONF_DB_DEV_URL
CONF_DB_DEV_URL=$(printf '%s\n' "$db_out" | sed -n 's/^CONF_DB_DEV_URL=//p')
[ -n "$CONF_DB_DEV_URL" ] || { echo "dev db session start produced no CONF_DB_DEV_URL" >&2; exit 1; }
trap 'dev db session end || true' EXIT

# test/init.rb prefers SEM_TEST_DB_URL over CONF_DB_DEV_URL, so an ambient one
# (a developer's Postgres.app) is overridden rather than built against.
export SEM_TEST_DB_URL="$CONF_DB_DEV_URL"

# The specs commit into throwaway git repositories; give them an identity that
# does not depend on the machine's global git config.
export GIT_AUTHOR_NAME="sem ci" GIT_AUTHOR_EMAIL="sem-ci@example.invalid"
export GIT_COMMITTER_NAME="sem ci" GIT_COMMITTER_EMAIL="sem-ci@example.invalid"

# run.rb installs rspec into ./gems (gitignored) on first use and exits 1 on
# any failing example.
cd test
./run.rb
