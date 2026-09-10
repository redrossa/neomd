# Literal and structural alert controls

## A-no-escaped-open

> \[!NOTE]
> Escaped opening bracket.

## A-no-escaped-bang

> [\!NOTE]
> Escaped bang.

## A-no-escaped-close

> [!NOTE\]
> Escaped closing bracket.

## A-no-entity-open

> &#91;!NOTE]
> Entity opening bracket.

## A-no-entity-bang

> [&#33;NOTE]
> Entity bang.

## A-no-entity-name

> [!NO&#84;E]
> Entity in name.

## A-no-entity-close

> [!NOTE&#93;
> Entity close.

## A-no-code

> `[!NOTE]`
> Inline code marker.

## A-no-fence

```md
> [!NOTE]
> Fenced body.
```

## A-no-formatted

> **[!NOTE]**
> Formatted marker.

## A-no-linked

> [[!NOTE]](#target)
> Linked marker.

## A-no-reference-linked

> [!NOTE]
> Reference-linked marker.

[!NOTE]: https://example.com

## A-no-unknown

> [!DANGER]
> Unknown type.

## A-no-lowercase

> [!note]
> Lowercase type.

## A-no-extra-title

> [!NOTE] Custom title
> Extra marker-line prose.

## A-no-mid-paragraph

> First paragraph line.
> [!NOTE]
> Later marker.

## A-no-later-paragraph

> First paragraph.
>
> [!NOTE]
> Later paragraph.

## A-no-leading-blank

>
> [!NOTE]
> Quote did not open with marker.

## A-no-nested-quote

> > [!NOTE]
> > Nested quote.

## A-no-list-contained

- > [!NOTE]
  > List-contained quote.

## A-no-footnote-contained

Reference[^n].

[^n]:
    > [!NOTE]
    > Note-contained quote.

## A-no-definition-first

> [ref]: https://example.com
>
> [!NOTE]
> Removed definition must not promote later marker.

## A-no-nonquote

[!NOTE]
Not a quote.
