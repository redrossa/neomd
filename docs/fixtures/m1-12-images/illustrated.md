# Illustrated explanation

LOCAL START

## Wide screenshot

A screenshot wider than the reading column keeps its aspect ratio and shrinks to the column.

![Wide orange screenshot](img/wide.png)

## Small figure

A figure narrower than the column stays at its natural size and is not stretched.

![Small green figure](img/small.png)

## Inline badges

Badges stay in the flow of a sentence: ![Photo badge](img/photo.jpg) and a linked badge [![Small linked badge](img/small.png)](https://example.com/badge) end the sentence.

## Other decodable formats

- ![Magenta JPEG photo](img/photo.jpg)
- ![Two frame GIF](img/anim.gif)
- ![Purple vector](img/vector.svg)

> ![Quoted small figure](img/small.png)
>
> Quoted images keep the quote indentation.

## Appearance-specific illustration

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="img/moon.png">
  <source media="(prefers-color-scheme: light)" srcset="img/sun.png">
  <img alt="Shows a yellow sun square in light mode and a blue moon square in dark mode." src="img/fallback.png">
</picture>

## Picture without a matching source

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="img/moon.png">
  <img alt="Gray fallback in light mode, blue moon square in dark mode." src="img/fallback.png">
</picture>

## Picture that is not the documented form

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="img/moon.png">
</picture>

## Unavailable images

![Missing diagram](img/absent.png)

![Private diagram](img/private.png)

![Corrupt diagram](img/not-an-image.png)

![](img/small.png)

Text after the unavailable images is still readable.

LOCAL END
