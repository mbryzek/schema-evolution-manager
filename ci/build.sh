#!/usr/bin/env bash
#
# The fleet's `ci` check for this repo. Landing this file enrols
# `schema-evolution-manager` in the merge lane: `dev ci verify` runs it at a pull
# request's head sha and posts the `ci` status the lane reads.
# devops/templates/ci/build.sh is the reference and devops/docs/ci.md carries
# what is load-bearing about it. ISS-17278
#
# It runs the rspec suite (test/run.rb, which installs rspec into ./gems).
# Most specs create and drop a database, so the suite needs a Postgres server.
# This script starts one in a throwaway container on a port Docker picks, points
# the specs at it through SEM_TEST_PGHOST / SEM_TEST_PGPORT (test/init.rb), and
# removes the container on exit. It never connects to localhost:5432: that is a
# developer's own Postgres on these machines, and the specs create and drop
# databases on whatever server they are handed.
#
# Exit 75 is the fleet's "this box could not measure the change" code: no Docker
# daemon, no psql or ruby, or a container that never came up. It is posted as an
# infrastructure fault rather than a red on the branch.
#
# TEST HEALTH (ISS-24445, DES-18577 "Every repository with CI"). Each rspec file
# under test/specs is one SPEC: `ci_step` from `ci/test-steps.sh` — devops'
# `templates/ci/test-steps.sh`, byte for byte, which says how — runs it, writes
# its JUnit report where the line below names, leaves out a file the lists hold
# as quarantined or slow, and reruns a failed file once. A failed file does not
# stop the build: every file runs and `ci_steps_end` fails it. A step's name is
# the file's path under test/specs with `/` as `.` and `.rb` dropped
# (`lib.db_spec`), and renaming a file starts its history over.
# ci-test-reports: target/ci-test-reports/*.xml
# ci-test-lists: required
set -euo pipefail

echo "building ${CI_REPO:-?} @ ${CI_SHA:-?} (${CI_EVENT:-?}, clean=${CI_CLEAN_BUILD:-?})"

INFRA_EXIT=75
PG_IMAGE=${SEM_CI_PG_IMAGE:-postgres:18}

infra() {
  echo "ci/build.sh: $*; nothing was measured" >&2
  exit "$INFRA_EXIT"
}

cd "$(dirname "$0")/.."

for tool in docker psql pg_isready ruby git; do
  command -v "$tool" >/dev/null 2>&1 || infra "$tool is not on PATH"
done
docker info >/dev/null 2>&1 || infra "the Docker daemon is not answering"

# Say what this build covered (ISS-2175); devops/templates/ci/build.sh has the
# contract. An unset CI_COVERAGE_FILE — somebody running this by hand — leaves
# the echo.
ci_report() {                      # ci_report covered|not-run "<short phrase>"
  local line="ci-$1: $2"
  echo "$line"
  [ -z "${CI_COVERAGE_FILE:-}" ] || printf '%s\n' "$line" >>"$CI_COVERAGE_FILE"
}

source ci/test-steps.sh
ci_steps_begin

# The specs commit into scratch git repositories. An identity in the
# environment reaches those commits without writing anybody's git config.
export GIT_AUTHOR_NAME="sem ci" GIT_AUTHOR_EMAIL="sem-ci@example.invalid"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

echo "--- postgres ($PG_IMAGE)"
container="sem-ci-$$-$RANDOM"
cleanup() { docker rm -f "$container" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# `127.0.0.1::5432` publishes on a host port Docker chooses, so concurrent
# builds on one box never contend for a port and none can land on :5432.
docker run -d --rm --name "$container" \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  -p 127.0.0.1::5432 \
  "$PG_IMAGE" >/dev/null || infra "could not start a $PG_IMAGE container"

mapping=$(docker port "$container" 5432/tcp | head -1) || infra "could not read the container's port"
port=${mapping##*:}
case $port in
  "" | *[!0-9]*) infra "could not parse a host port from '$mapping'" ;;
  5432) infra "Docker published the container on 5432, which this build never uses" ;;
esac

# The image's entrypoint runs initdb with TCP closed and restarts the server
# once it is done, so a TCP answer means the final server is up.
ready=false
for _ in $(seq 1 60); do
  if pg_isready -q -h 127.0.0.1 -p "$port" -U postgres; then
    ready=true
    break
  fi
  sleep 1
done
$ready || infra "postgres on 127.0.0.1:$port did not accept connections within 60s"
psql --no-psqlrc -q -h 127.0.0.1 -p "$port" -U postgres -d postgres -c 'select 1' >/dev/null ||
  infra "postgres on 127.0.0.1:$port refused a query"
echo "postgres ready on 127.0.0.1:$port"

export SEM_TEST_PGHOST=127.0.0.1 SEM_TEST_PGPORT=$port

echo "--- rspec"
ci_step test-steps-template "ci/test-steps.sh is devops' template" ci_steps_template_check

# One spec file, run alone by test/run.rb (which installs rspec on first use).
rspec_file() {                     # rspec_file <path under test/>
  cd test
  ./run.rb "$1"
}

while IFS= read -r spec; do
  name=${spec#specs/}
  name=${name%.rb}
  ci_step "${name//\//.}" "rspec $spec" rspec_file "$spec"
done < <(cd test && find specs -type f -name '*spec.rb' | LC_ALL=C sort)

ci_steps_end
