## What changed

## Why

## Which checks apply

Tick what a reviewer should run. More than one usually applies.

- [ ] **Reference** — a TypeScript equivalent exists at <link>. Compare the public API,
      callbacks, status values, and error codes against it.
- [ ] **Backend contract** — this parses or sends values a Crossmint service defines
      (status strings, event names, error reasons, locator formats, endpoint shapes).
- [ ] **Evidence** — this needs platform knowledge to read. QA output is below.
- [ ] **Public API removed or narrowed** — check the other repos for consumers before it goes.

## Notes for reviewers

<!-- The part no documentation contains: why the fix is shaped this way, what you already
     ruled out, which call sites you checked. Platform facts the reviewer needs are the
     skill's job, not yours. -->

## QA evidence

<!-- Delete if the Evidence box is unticked. Paste the /sdk-qa output, screenshots, or a
     recording, from this branch rather than main. -->

## Checklist

- [ ] New public surface has a direct unit test
- [ ] No change to shipped public API without a deprecation
- [ ] Ran the review pass locally and addressed the findings
