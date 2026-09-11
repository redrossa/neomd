# Visible<!--HIDDEN-HEADING--> title

Before<!--HIDDEN-INLINE-->after café 😀.

<!-- HIDDEN-BLOCK
HIDDEN-MULTILINE <a id="hidden-anchor"></a> # hidden heading
-->

<!--HIDDEN-SUFFIX-->VISIBLE SUFFIX

- [ ] Task<!--HIDDEN-TASK--> description

> Quote<!--HIDDEN-QUOTE--> visible

[Label<!--HIDDEN-LABEL--> visible](nearby.md)

![Alt<!--HIDDEN-ALT--> visible](absent.png)

Note[^n].

[^n]: Footnote<!--HIDDEN-NOTE--> visible.

Literal escaped opener: \<!--ESCAPED-LITERAL-->.

Literal entity opener: &lt;!--ENTITY-LITERAL--&gt;.

Inline example `# Heading [link](nearby.md) <!--CODE-LITERAL-->`.

```markdown
---
title: FENCED YAML LITERAL
---
# Heading [link](nearby.md) <!--FENCED-LITERAL-->
```

    <!--INDENTED-LITERAL-->

<span title="<!--ATTRIBUTE-LITERAL--> >">unsupported wrapper text</span>

<script>const text = '<!--RAWTEXT-LITERAL-->'; noExecution();</script>

<pre><code><!--PRE-CODE-LITERAL--></code></pre>

<sup>supported</sup> <sub>supported</sub> <ins>supported</ins>.

<div>Unsupported but readable wrapper.</div>

Incomplete final comment remains readable: <!--UNCLOSED-LITERAL
