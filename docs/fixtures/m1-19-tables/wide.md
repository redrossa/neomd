# Local overflow

BEFORE_COLUMN_SENTINEL: this surrounding prose wraps within the ordinary reading column.

| C01 | C02 | C03 | C04 | C05 | C06 | C07 | C08 | C09 | C10 | C11 | C12 |
| :--- | ---: | :---: | --- | :--- | ---: | :---: | --- | :--- | ---: | :---: | --- |
| left edge | 200 | middle | ordinary | wrapping comparison text with several words | 600 | middle | AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA | next | 1000 | center | RIGHT_EDGE_SENTINEL |
| **bold** | *italic* | `code` | plain | [local](nearby.md#destination) | 2 | 3 | 4 | 5 | 6 | 7 | [return](#local-overflow) |
| | | | | | | | | | | | |

AFTER_COLUMN_SENTINEL: the page itself must not acquire a horizontal scroll range because of the table above.

## A second independent table

| First | Second | Third | Fourth | Fifth | Sixth | Seventh | Eighth |
| --- | --- | --- | --- | --- | --- | --- | --- |
| one | two | three | four | five | six | seven | SECOND_RIGHT_EDGE |

The two tables own independent horizontal offsets. No fixed-height inner vertical reader is intended.
