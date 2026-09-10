# Link cursor fixture

CURSOR START. Ordinary selectable text before [External reference](https://example.com/neomd-cursor), [Local file](nearby.md#local-target), and [In-document target](#cursor-target). Ordinary selectable text after.

[Long **bold** and *emphasized* linked label with enough words to wrap onto another line at narrow reading widths](#cursor-target) followed by unlinked text.

Footnote reference[^cursor]. Repeated reference[^cursor].

## Linked images

[![Internal linked image](img/badge.png)](#cursor-target)

Before [![Local linked image](img/badge.png)](nearby.md#local-target) between [![External linked image](img/badge.png)](https://example.com/neomd-cursor-image) after.

Loading/unavailable linked fallback: [![Missing linked image](img/absent.png)](#cursor-target).

## Negative controls

Ordinary text with **bold**, *italic*, and `inline code` stays selectable, not a hand region.

![Unlinked image only](img/badge.png)

Before ![Unlinked mixed image](img/badge.png) after.

Literal code: `[not a link](https://example.com/not-actionable)`.

> Quoted [reference](#cursor-target) followed by ordinary quote text.

- [ ] Read-only task with [reference](#cursor-target), not an actionable checkbox.

## Cursor target

CURSOR TARGET. [Back to start](#link-cursor-fixture).

[^cursor]: Footnote body with [authored reference](#cursor-target). Generated return links remain actionable too.

CURSOR END.
