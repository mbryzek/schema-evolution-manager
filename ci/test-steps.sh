# shellcheck shell=bash
#
# TEST HEALTH FOR A REPOSITORY WHOSE ci/build.sh IS ITS TEST RUNNER (ISS-19891,
# design DES-18577 "Every repository with CI").
#
# Some repositories have no test runner of their own: no build.sbt, package.json,
# elm.json or dune-project. Their `ci/build.sh` is a list of checks, and that list
# IS the suite. This file makes each named check one SPEC, so such a repository
# meets the four lines of the contract `dev ci test-health` reads:
#
#   1. reports  every step leaves `TEST-<step>.xml`, one JUnit suite holding one
#               case, under `${CI_STEP_REPORTS:-target/ci-test-reports}`;
#   2. lists    the file `CI_TEST_LISTS` names is read once, the
#               `ci-lists: version <n> quarantined <q> slow <s>` line is printed,
#               and a step named `quarantined <step>` or `slow <step>` is left out;
#   3. slow     with `CI_SLOW_SPECS=1` only the steps named `slow` run;
#   4. rerun    a step that fails runs once more: `ci-flake: <step>` when the rerun
#               passes (the step counts as passed), `ci-rerun: failed again: <step>`
#               when it fails too, and `ci-rerun: done` once any rerun has run.
#
# A step named `proof <step>` — the lists of a pull request fixing that step's
# quarantine — runs `CI_PROOF_RUNS` (20) more times after it passes, each run
# leaving `PROOF-alone-<run>-<step>.xml`; the first failed run ends the proof red.
#
# COPY IT, DO NOT EDIT IT. The adopting repository carries this file byte for byte
# as `ci/test-steps.sh`, and runs `ci_steps_template_check` as a step of its own,
# which diffs the copy against `dev repo cat devops templates/ci/test-steps.sh`.
#
# USE, in ci/build.sh:
#
#   # ci-test-reports: target/ci-test-reports/*.xml
#   # ci-test-lists: required
#   source ci/test-steps.sh
#   ci_steps_begin
#   ci_step test-steps-template "ci/test-steps.sh is devops' template" ci_steps_template_check
#   ci_step <step> "<what it covers>" <command> [args...]
#   ...
#   ci_steps_end
#
# A STEP'S NAME IS ITS SPEC: the name the lists, the ledger and every `ci-` line
# use, so it is one word of letters, digits, `.`, `_` and `-`, unique in the build,
# and renaming one starts its history over. The command is any command or shell
# function; it runs in a subshell under `set -e`, its output streams to the build
# log, and its exit status is the step's verdict.
#
# A FAILED STEP DOES NOT STOP THE BUILD. Every step runs, so the ledger reads every
# spec of every build, and `ci_steps_end` exits 1 naming the steps that failed.
# A step that cannot run without an earlier one belongs in that step's command.
#
# WHAT EACH STEP REPORTS. `ci_report covered "<what it covers>"` when it passes and
# `ci_report not-run "..."` when the lists leave it out, through the repository's
# own `ci_report` (templates/ci/build.sh) when it defines one.
#
# A STEP THAT COULD NOT MEASURE ANYTHING IS THE BOX, NOT A FAILURE. A step's
# command marks itself unmeasured with `ci_steps_unmeasured_mark` before it
# fails (`ci_steps_template_check` does when devops' template cannot be read
# twice), and a step that exits 75 — the fleet's meaning of 75 everywhere — is
# unmeasured without marking; a step that is still unmeasured after its rerun is
# reported not-run, and when no step failed `ci_steps_end` exits 75 naming it.
#
# UNSET CI_TEST_LISTS LEAVES NOTHING OUT: that is a person running the build by
# hand. A lists file that is not the format, and CI_SLOW_SPECS=1 with no lists,
# stop the build at 75 with nothing measured — the box, not the branch.

ci_steps_infra_exit=75

# The `ci-lists:` line for the lists file [1], or a refusal on stderr and exit 2.
ci_steps_lists_summary() {         # ci_steps_lists_summary <file>
  awk '
    function refuse(why) { printf "line %d: %s\n", NR, why >"/dev/stderr"; bad = 1; exit 2 }
    { sub(/\r$/, "") }
    NR == 1 { if ($0 ~ /^(version )?[0-9]+$/) { version = $NF; next } refuse("not a lists version") }
    /^[ \t]*$/ { next }
    /^quarantined [^ \t]+$/ { quarantined++; next }
    /^slow [^ \t]+$/ { slow++; next }
    /^proof [^ \t]+$/ { next }
    { refuse("neither quarantined, slow nor proof") }
    END {
      if (bad) exit 2
      if (NR == 0) { print "the file is empty" >"/dev/stderr"; exit 2 }
      printf "ci-lists: version %s quarantined %d slow %d\n", version, quarantined + 0, slow + 0
    }
  ' "$1"
}

# Whether the lists name [2] under the word [1].
ci_steps_listed() {                # ci_steps_listed quarantined|slow|proof <step>
  [ -n "$ci_steps_lists" ] && tr -d '\r' <"$ci_steps_lists" | grep -qxF "$1 $2"
}

# Every spec the lists name, one per line.
ci_steps_listed_specs() {
  [ -n "$ci_steps_lists" ] || return 0
  tr -d '\r' <"$ci_steps_lists" | awk 'NR > 1 && NF == 2 { print $2 }' | sort -u
}

ci_steps_report() {                # ci_steps_report covered|not-run "<phrase>"
  if declare -F ci_report >/dev/null; then
    ci_report "$1" "$2"
  else
    echo "ci-$1: $2"
  fi
}

ci_steps_begin() {
  ci_steps_reports=${CI_STEP_REPORTS:-target/ci-test-reports}
  rm -rf "$ci_steps_reports"
  mkdir -p "$ci_steps_reports"
  # An explicit XXXXXX template: GNU mktemp refuses `-t <prefix>` without one, BSD
  # appends its own, and this spelling means the same on both (ISS-21944).
  ci_steps_work=$(mktemp -d "${TMPDIR:-/tmp}/ci-test-steps.XXXXXX")
  ci_steps_defined=()
  ci_steps_failed=()
  ci_steps_unmeasured=()
  ci_steps_last_unmeasured=false
  ci_steps_reran=false
  ci_steps_phase_start=$SECONDS
  ci_steps_slow_only=false
  [ "${CI_SLOW_SPECS:-}" != "1" ] || ci_steps_slow_only=true
  ci_steps_lists=""
  if [ -n "${CI_TEST_LISTS:-}" ]; then
    if ! ci_steps_lists_summary "$CI_TEST_LISTS"; then
      echo "ci/build.sh: INFRASTRUCTURE FAULT — CI_TEST_LISTS=$CI_TEST_LISTS is not a lists file, so this build cannot know which steps to leave out; nothing about the tree was measured" >&2
      exit "$ci_steps_infra_exit"
    fi
    ci_steps_lists=$CI_TEST_LISTS
  elif [ "$ci_steps_slow_only" = "true" ]; then
    echo "ci/build.sh: INFRASTRUCTURE FAULT — CI_SLOW_SPECS=1 runs only the slow steps and CI_TEST_LISTS names no lists; nothing about the tree was measured" >&2
    exit "$ci_steps_infra_exit"
  else
    echo "ci-lists: none, CI_TEST_LISTS is unset so every step runs"
  fi
}

# [1] with every ANSI sequence and every character XML 1.0 refuses removed, and
# the five characters markup reserves escaped.
ci_steps_xml_text() {
  sed $'s/\x1b\\[[0-9;?]*[A-Za-z]//g' "$1" | LC_ALL=C tr -d '\000-\010\013\014\016-\037' |
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&apos;/g"
}

# One JUnit report: the suite [1], its seconds [2], its exit status [3], and the
# file holding its output [4]. A failure carries the output's last 200 lines and,
# as its message, the last line that is not blank.
ci_steps_junit() {
  local name=$1 seconds=$2 status=$3 out=$4 failures=0 tail message
  [ "$status" -eq 0 ] || failures=1
  printf '<?xml version="1.0" encoding="UTF-8"?>\n'
  printf '<testsuite name="%s" tests="1" failures="%d" errors="0" skipped="0" time="%d">\n' \
    "$name" "$failures" "$seconds"
  printf '  <testcase classname="%s" name="%s" time="%d">\n' "$name" "$name" "$seconds"
  if [ "$status" -ne 0 ]; then
    tail=$(mktemp "$ci_steps_work/tail.XXXXXX")
    tail -n 200 "$out" >"$tail"
    message=$(ci_steps_xml_text "$tail" | awk 'NF { last = $0 } END { print substr(last, 1, 300) }')
    printf '    <failure type="exit %d" message="%s">' "$status" "$message"
    ci_steps_xml_text "$tail"
    printf '</failure>\n'
  fi
  printf '  </testcase>\n</testsuite>\n'
}

# Runs the command [3..] once as the step [1], leaving its report as [2].
ci_steps_run() {
  local name=$1 report=$2 out status start errexit=false
  shift 2
  out="$ci_steps_work/$name.out"
  start=$SECONDS
  case $- in *e*) errexit=true ;; esac
  echo "ci-step: $name: $*"
  rm -f "$ci_steps_work/unmeasured"
  set +e
  ( set -e; "$@" ) 2>&1 | tee "$out"
  status=${PIPESTATUS[0]}
  [ "$errexit" = "false" ] || set -e
  ci_steps_last_unmeasured=false
  [ "$status" -eq 0 ] || [ ! -f "$ci_steps_work/unmeasured" ] || ci_steps_last_unmeasured=true
  [ "$status" -ne "$ci_steps_infra_exit" ] || ci_steps_last_unmeasured=true
  ci_steps_junit "$name" $((SECONDS - start)) "$status" "$out" >"$ci_steps_reports/$report"
  return "$status"
}

# The proof of the step [1]: CI_PROOF_RUNS runs, ending at the first that fails.
ci_steps_proof() {
  local name=$1 runs=${CI_PROOF_RUNS:-20} run
  shift
  for ((run = 1; run <= runs; run++)); do
    if ! ci_steps_run "$name" "PROOF-alone-$run-$name.xml" "$@"; then
      echo "ci-proof: failed $name on run $run of $runs"
      return 1
    fi
  done
  echo "ci-proof: passed $name ($runs runs)"
}

ci_step() {                        # ci_step <step> "<what it covers>" <command> [args...]
  local name=$1 covers=$2 seen
  shift 2
  if [ -z "${ci_steps_reports:-}" ]; then
    echo "ci/build.sh: ci_step $name before ci_steps_begin" >&2
    exit 2
  fi
  if ! [[ $name =~ ^[A-Za-z0-9._-]+$ ]] || [ "$#" -eq 0 ]; then
    echo "ci/build.sh: ci_step needs a one-word name ([A-Za-z0-9._-]) and a command, given: $name $*" >&2
    exit 2
  fi
  for seen in ${ci_steps_defined[@]+"${ci_steps_defined[@]}"}; do
    if [ "$seen" = "$name" ]; then
      echo "ci/build.sh: the step $name is defined twice; a step's name is its spec" >&2
      exit 2
    fi
  done
  ci_steps_defined+=("$name")

  if ci_steps_listed quarantined "$name"; then
    echo "ci-step: $name: quarantined, not run"
    ci_steps_report not-run "$covers (quarantined: $name)"
    return 0
  fi
  if [ "$ci_steps_slow_only" = "true" ]; then
    ci_steps_listed slow "$name" || return 0
  elif ci_steps_listed slow "$name"; then
    echo "ci-step: $name: slow, left to the slow run"
    ci_steps_report not-run "$covers (slow: $name)"
    return 0
  fi

  if ! ci_steps_run "$name" "TEST-$name.xml" "$@"; then
    mv "$ci_steps_reports/TEST-$name.xml" "$ci_steps_reports/FIRST-$name.xml"
    ci_steps_reran=true
    echo "ci-rerun: running $name once more"
    if ci_steps_run "$name" "TEST-$name.xml" "$@"; then
      echo "ci-flake: $name"
    elif [ "$ci_steps_last_unmeasured" = "true" ]; then
      echo "ci-rerun: failed again: $name"
      ci_steps_unmeasured+=("$name")
      ci_steps_report not-run "$covers (unmeasured: $name)"
      return 0
    else
      echo "ci-rerun: failed again: $name"
      ci_steps_failed+=("$name")
      return 0
    fi
  fi

  if [ "$ci_steps_slow_only" = "false" ] && ci_steps_listed proof "$name"; then
    if ! ci_steps_proof "$name" "$@"; then
      ci_steps_failed+=("$name")
      return 0
    fi
  fi
  ci_steps_report covered "$covers"
}

# Marks the running step as having measured nothing; call it, then fail.
ci_steps_unmeasured_mark() {
  [ -z "${ci_steps_work:-}" ] || : >"$ci_steps_work/unmeasured"
}

# Whether this file is still devops' template, byte for byte. Run it as a step.
# The template is read into a file, and read once more when that fails: a read
# that fails twice compared the copy against nothing, so it is the box and never
# a drift in the copy.
ci_steps_template_check() {
  local copy=${BASH_SOURCE[0]} bytes read_rc=0 diff_rc=0
  bytes=$(mktemp "${TMPDIR:-/tmp}/ci-template.XXXXXX")
  dev repo cat devops templates/ci/test-steps.sh >"$bytes" ||
    dev repo cat devops templates/ci/test-steps.sh >"$bytes" || read_rc=$?
  [ "$read_rc" -ne 0 ] || diff -u "$bytes" "$copy" || diff_rc=$?
  rm -f "$bytes"
  if [ "$read_rc" -ne 0 ]; then
    echo "ci/build.sh: could not read devops templates/ci/test-steps.sh (dev repo cat exit $read_rc, twice) -- a read failure, not a drift in $copy; nothing was measured" >&2
    ci_steps_unmeasured_mark
    return "$ci_steps_infra_exit"
  fi
  if [ "$diff_rc" -ne 0 ]; then
    echo "ci/build.sh: sync it — dev repo cat devops templates/ci/test-steps.sh > $copy" >&2
    return 1
  fi
}

ci_steps_end() {
  local spec seen known count=0
  if [ -n "$ci_steps_lists" ] && [ "$ci_steps_slow_only" = "false" ]; then
    while IFS= read -r spec; do
      [ -n "$spec" ] || continue
      count=$((count + 1))
      known=false
      for seen in ${ci_steps_defined[@]+"${ci_steps_defined[@]}"}; do
        [ "$seen" != "$spec" ] || known=true
      done
      [ "$known" = "true" ] || echo "ci-lists: unknown $spec"
    done < <(ci_steps_listed_specs)
    echo "ci-lists: checked $count listed spec(s)"
  fi
  echo "ci-test-phase: $((SECONDS - ci_steps_phase_start))s"
  [ "$ci_steps_slow_only" = "true" ] || echo "ci-scope: full every step of ci/build.sh"
  [ "$ci_steps_reran" = "false" ] || echo "ci-rerun: done"
  rm -rf "$ci_steps_work"
  if [ "${#ci_steps_failed[@]}" -gt 0 ]; then
    echo "ci/build.sh: ${#ci_steps_failed[@]} step(s) failed: ${ci_steps_failed[*]}" >&2
    return 1
  fi
  if [ "${#ci_steps_unmeasured[@]}" -gt 0 ]; then
    echo "ci/build.sh: INFRASTRUCTURE FAULT — ${#ci_steps_unmeasured[@]} step(s) could not be measured on this box: ${ci_steps_unmeasured[*]}; nothing about them was measured" >&2
    return "$ci_steps_infra_exit"
  fi
}
