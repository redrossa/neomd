---
base: &base
  name: Shared
  values: [one, two]
firstCopy: *base
secondCopy: *base
old: &name first
oldCopy: *name
new: &name second
newCopy: *name
tagged: !report 'tag is inert'
standard: !!str 001
binary: !!binary SGVsbG8=
? [compound, key]
: structured key value
---
# Alias and tag body

ALIAS BODY follows a bounded readable table, not constructed objects.
