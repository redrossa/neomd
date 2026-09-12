---
title: Reading-size mixed hierarchy
review: Read-only fixture; scale is an app preference
---
# Reading-size atlas

TOP CHECKPOINT ALPHA: This document is deliberately local and inert. Its text, Markdown structure and source modification time must not change when a reader changes the reading size. The readable column should reflow while code and wide tables keep their own horizontal overflow.

The paragraph mixes **strong emphasis**, *italic emphasis*, ***combined emphasis***, ~~struck text~~, `inline code`, H<sub>2</sub>O, x<sup>3</sup> and <ins>underlined text</ins>. A [local second document](second.md) and a [middle destination](#middle-checkpoint) remain explicit actions, never automatic opening instructions.

## Heading level two

ALPHA SECOND PARAGRAPH: Every supported size should preserve ordinary prose as prose. A paragraph wraps at the available width rather than requiring the whole document to scroll sideways. Café, 日本語 and combining text café remain exact visible content, not resized source characters.

### Heading level three

The typography distinguishes this heading from the paragraphs around it. The distinction includes weight and other existing semantic styling, not only an assumption about strictly descending point sizes.

#### Heading level four

A short paragraph establishes hierarchy between smaller heading levels and body text.

##### Heading level five with `code`

Inline code must remain monospaced within the existing heading policy.

###### Heading level six

Small-heading secondary styling remains legible with the body at each supported size.

## Nested lists and quotations

5. First ordered item keeps its authored starting number.
6. Second ordered item contains **emphasis** and `literal code`.
   - Nested bullet with a paragraph long enough to wrap when the reading column is narrow and the reading size is increased.
   - Another nested bullet.

- [ ] Pending task remains pending.
  - [x] Completed nested task remains completed.
- [x] Completed sibling keeps its read-only state.

> QUOTE CHECKPOINT BRAVO: A quotation keeps its rule and readable text when the surrounding document grows.
>
> > NESTED CHECKPOINT CHARLIE: This nested quotation is a useful within-block reading-position target. Its words are deliberately distinct from the paragraphs above and below it, so a locator can preserve the same content rather than an absolute pixel offset after reflow. The paragraph spans several lines at larger sizes.

> [!NOTE]
> Cue text and its label inherit the same reading-size policy. Known larger-size cue/reflow failures belong to deferred #38, not a passing visual oracle.

> [!TIP]
> An app preference belongs outside this Markdown file.

> [!IMPORTANT]
> Do not reset a valid reading anchor to the beginning just because the font changes.

> [!WARNING]
> A changed scale must not launch a link or modify a task state.

> [!CAUTION]
> Deferred tests are not passed tests. A new unrelated defect is not automatically waived.

## Code preserves whitespace

CODE PREFACE DELTA: The following block has indented lines and a deliberately wide line. Reading-size changes must not strip indentation or insert Markdown fence delimiters into the rendered code.

```swift
struct ReadingExample {
    let label = "Scale changes presentation, not document bytes"

    func describe() -> String {
        return "A deliberately long code line stays available through code-local horizontal scrolling without widening every prose paragraph in this read-only document."
    }
}
```

The literal code sample below is content only, never executed by NeoMD.

```text
    four spaces
        eight spaces
  two spaces
```

## Middle checkpoint

MIDDLE CHECKPOINT AMBER: Keep this passage near the reading line when increasing from one to one-and-a-half to two, decreasing again, or resetting. Approximate position means the same content and nearby within-block fraction after wrapping, not the same absolute scroll offset. This deliberately long paragraph establishes a meaningful fraction for value-only capture and restore units as well as the future user-owned native check. It mentions no network resource and triggers no side effect. A latest desired size should replace an older pending transition rather than repeatedly restoring stale coordinates.

MIDDLE AFTER AMBER: This next paragraph provides a distinct neighbour for locator context. It must not be confused with the repeated-content pair below. Rapid commands during an existing reflow should keep the original pending content anchor until layout settles or newer explicit user navigation cancels restoration.

Repeated short passage used to check stable reading order.

BETWEEN REPEATS INDIGO: The matching text above and below has different neighbour context.

Repeated short passage used to check stable reading order.

## Aligned formatted table

TABLE PREFACE ECHO: Table headers, cell formatting and associations remain structural. A table is not flattened into paragraphs on a size change.

| Left heading | Center heading | Right heading |
| :--- | :---: | ---: |
| **strong cell** | *italic cell* | `code cell` |
| H<sub>2</sub>O | <ins>underline</ins> | 123.45 |
| TABLE CHECKPOINT JADE: distinct cell target | a wrapping table paragraph with enough words to occupy several lines as size increases | 678.90 |
| [middle link](#middle-checkpoint) | literal [ ] cell text | ~~old~~ new |
| Café | 日本語 | café |
| | empty neighbour retained | |

TABLE AFTER ECHO: This prose remains in the reading column even when a table needs horizontal overflow.

## Wide table

WIDE TABLE PREFACE FOXTROT: The independent table below is intentionally wider than a narrow viewport at the supported scales. It should retain every column, with local horizontal scrolling and no document-wide horizontal scrollbar.

| One | Two | Three | Four | Five | Six | Seven | Eight |
| --- | --- | --- | --- | --- | --- | --- | --- |
| one-long-cell | two-long-cell | three-long-cell | four-long-cell | five-long-cell | six-long-cell | seven-long-cell | eight-long-cell |
| **bold** | *italic* | `code` | 4 | 5 | 6 | 7 | WIDE CHECKPOINT PEARL |

WIDE TABLE AFTER FOXTROT: Prose after the wide table is still readable at the same page width. Returning to the default size should clamp any local table offset according to existing table geometry without replacing its native hosts solely because scale changed.

---

## Closing section

CLOSING CHECKPOINT GOLF: A scale change preserves the prepared presentation identity. It does not reread or reparse this unchanged source, clear its image state, manufacture a history entry containing size, or replace its native window.

A note reference[^size] supplies the existing footnote path for the future combined navigation check. Ordinary reading does not activate it automatically.

BOTTOM CHECKPOINT ZULU: At the end of the document, the bottom-edge reading anchor remains a valid choice. A fresh document with no recorded position should use initial top placement and the current app reading-size preference. The app's remembered size is shared; the reading place is not shared between readers.

[^size]: FOOTNOTE CHECKPOINT SIERRA: The note remains readable at each supported size, with its return link and content retained.
