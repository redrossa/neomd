---
broken: [unterminated
# FALLBACK IS NOT A HEADING
[fallthrough]: nearby.md
[^fallthrough]: FALLBACK IS NOT A FOOTNOTE
image: '![NOT AN IMAGE](absent.png)'
link: '[NOT A LINK](nearby.md)'
html: '<sup>NOT SUPERSCRIPT</sup><!--FALLBACK COMMENT DATA-->'
cue: ':smile: `#ff0000`'
---
# Recovery body

RECOVERY BODY remains ordinary **rendered Markdown**.

[fallthrough] and [^fallthrough] stay unresolved: fallback definitions did not enter cmark.

[Nearby](nearby.md#nearby-destination) remains a real body link.
