// Reviewable review completion condition — https://docs.reviewable.io/admincenter.html
//
// BACKEND repo. Mike reviews these in Reviewable, so completion falls back to
// Reviewable's default condition (all files reviewed + discussions resolved).
// This script only:
//   - groups files in the matrix (specs first, tests last, generated last), and
//   - marks generated code reviewed + vendored so it's collapsed and never
//     needs to be looked at.
// Groups sort alphabetically; the digit prefixes force the order.

function isGenerated(path) {
  return /(^|\/)generated\//i.test(path);
}

function groupOf(path) {
  if (isGenerated(path)) return '4. Generated';
  if (/\.json$/.test(path)) return '1. Specs & JSON';
  if (
    /(^|\/)tests?\//i.test(path) ||
    /Spec\.scala$/.test(path) ||
    /\.(test|spec)\.[jt]s$/.test(path)
  ) return '3. Tests';
  return '2. Source';
}

var files = review.files.map(function (f) {
  var gen = isGenerated(f.path);
  var out = {path: f.path, group: groupOf(f.path)};
  if (gen) {
    out.vendored = true;
    // Mark generated files reviewed automatically — no clicks needed.
    out.revisions = (f.revisions || []).map(function (r) {
      return {key: r.key, reviewed: true};
    });
  }
  return out;
});

// Only override file grouping; top-level completion uses Reviewable's default.
return {files: files};
