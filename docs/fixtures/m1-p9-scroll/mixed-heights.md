# P9 top

AMBER is the top sentinel. This is a read-only, local, mixed-height scrolling corpus. [End sentinel](#p9-end) is an explicit navigation control, not a scrolling trigger. The document contains no images or background network activity.

## Short root

A short paragraph.

## Wrapping root

BRONZE begins a deliberately longer paragraph. A reading surface must let a person move naturally through a report without losing their place when another section becomes visible. This passage wraps at narrow widths and takes less vertical space at wide widths. It contains **strong emphasis**, ordinary words, and *emphasis*, but no automatic action. Its height is intentionally different from the short paragraph immediately above it. The next sentence extends this same root rather than adding another root, so the native text measurement has a different shape from the surrounding headings. Reading the content must not modify its bytes or modification date.

> CHARLIE starts a quote with a longer wrapping passage. Its inset reduces the available line width while its vertical extent depends on actual text measurement. The quoted text must remain readable when a root above it first appears during upward travel.
>
> This is a second paragraph in the same quote container.
>
> - A quoted list item.
> - Another quoted item with enough text to wrap across several lines at a narrow reading width, retaining the native selection surface.

## Tall code root

```text
DELTA code line 01
DELTA code line 02
DELTA code line 03
DELTA code line 04
DELTA code line 05
DELTA code line 06
DELTA code line 07
DELTA code line 08
DELTA code line 09
DELTA code line 10
DELTA code line 11
DELTA code line 12
DELTA code line 13
DELTA code line 14
DELTA code line 15
DELTA code line 16
DELTA code line 17
DELTA code line 18
DELTA code line 19
DELTA code line 20
DELTA code line 21
DELTA code line 22
DELTA code line 23
DELTA code line 24
DELTA code line 25
DELTA code line 26
DELTA code line 27
DELTA code line 28
DELTA code line 29
DELTA code line 30
```

ECHO is the short root immediately after the tall code block.

---

## List container

1. FOXTROT starts an ordered item with a longer description. It provides an uneven measured height next to short siblings, while retaining the order and indentation of the source.
2. A short second item.
3. A third item with a nested list:
   - First nested text.
   - Second nested text with a longer sentence that wraps at narrower widths and remains plain read-only prose throughout the scroll.

## Second wrapping root

GOLF begins another long paragraph after the list. Reports often contain an unpredictable mixture of headings, brief conclusions, literal output and lengthy explanation. A layout cannot assume that every root has the average height of its neighbors. This fixture intentionally includes those differences without relying on images finishing a download or a file being rewritten. Any stopped momentum observed here should therefore be recorded separately from image-loading and external-refresh cases. A repeated trip through this same paragraph can help the user distinguish first materialization from later travel, but the fixture has not been run by triage and is not a claimed reproduction.

## Wide local code

```text
HOTEL local overflow: alpha bravo charlie delta echo foxtrot golf hotel india juliet kilo lima mike november oscar papa quebec romeo sierra tango uniform victor whiskey xray yankee zulu
short second line
```

INDIGO is a short prose sentinel after local horizontal overflow. The whole reading column must still scroll only vertically.

## Final quote

> JADE starts a final quote. Reading upward past this section encounters several differently sized roots. Text selection and explicit navigation must remain available; neither is invoked merely by moving the trackpad.
>
> Another short quote paragraph.

KILO is the last body paragraph. It is intentionally short compared with the longer prose and code roots above it.

# P9 end

LIMA is the end sentinel. [Top sentinel](#p9-top) is explicit link navigation and must not be confused with a trackpad flick toward the top.
