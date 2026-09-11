---
title: 'Finished café report'
date: 2025-01-29 18:15:32 +0530
version: 001
approved: yes
contributors:
  - name: Ana
    role: Reviewer
  - name: 李
    role: Reader
versions: {fpt: '*', ghes: '*', ghec: '*'}
summary: >-
  First line
  second line
example: |-
  # Metadata is not a heading
  [ref]: nearby.md
  [^ghost]: Not a document footnote
literal: '**not bold** :smile: `#ff0000` [not a link](nearby.md) <!--metadata data-->'
emptyString: ''
emptyValue:
emptyMap: {}
emptyList: []
duplicate: first
duplicate: second
...
# Body start

[Body destination](#body-destination) and [Nearby](nearby.md#nearby-destination).

> [!NOTE]
> BODY ALERT after metadata uses original source lines.

- [ ] BODY TASK **retained** with :smile: and `#ff0000`.

BODY NOTE[^n] and repeated[^n]. Undefined metadata note [^ghost] stays literal.

[ref] stays an unresolved reference; metadata did not define it.

![FIRST missing local diagram](absent.png)![SECOND missing local diagram](absent.png)

<a id="custom-body"></a>
# Body destination

BODY DESTINATION. [Back](#body-start) [Custom](#custom-body).

# Body destination

SECOND BODY DESTINATION has duplicate suffix independent of metadata.

[^n]: BODY FOOTNOTE **retained** with :smile:.
