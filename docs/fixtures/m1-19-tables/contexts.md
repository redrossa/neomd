---
title: Table context packet
purpose: YAML metadata remains a separate surface
---
# Table contexts

- [x] Completed outer task

  | Task context | Value |
  | --- | ---: |
  | **retained** | 5 |
  | [ ] not a checkbox | 6 |

> A quote before its table.
>
> | Quoted header | Result |
> | :--- | ---: |
> | quoted text | 7 |

> [!NOTE]
> Tables inside an alert retain the surrounding alert label.
>
> | Alert header | Meaning |
> | --- | --- |
> | :smile: | `#FFFFFF` |

| Duplicate | Duplicate | |
| --- | --- | --- |
| first column | second column | blank-header column |
| <a id="empty-cell"></a> | [empty anchor](#empty-cell) | third |
| repeated[^same] | repeated[^same] | Unicode: café 日本語 |
| [![badge](badge.svg)](nearby.md#destination)![badge](badge.svg) | ![](badge.svg) | ![missing illustration](absent.png) |

[Back to the empty cell](#empty-cell).

[^same]: A note with a table.

    | Note header | Note value |
    | --- | --- |
    | body | **retained** |

    Footnote return links should still return to each referencing cell.

## fn-same

This authored heading deliberately collides with a generated footnote preference.

## After contexts

Metadata, task, quotation, alert, general tables and footnote bodies retain separate semantics.
