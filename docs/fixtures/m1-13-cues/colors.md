# Bounded inline-code color references

COLORS START. Codes below retain their parser-normalized text. White/black swatches need a neutral visible border in both themes.

C-hex-blue: `#0969DA`

C-hex-lower: `#abcdef`

C-white: `#FFFFFF`

C-black: `#000000`

C-rgb-blue: `rgb(9, 105, 218)`

C-rgb-boundary: `rgb(0,255,0)`

C-rgb-space: `rgb( 9 ,	105 , 218 )`

C-hsl-red: `hsl(0,100%,50%)`

C-hsl-endpoint: `hsl(360, 100%, 50%)`

C-hsl-green: `hsl(120,100%,50%)`

C-hsl-blue: `hsl(240,100%,50%)`

C-hsl-gray: `hsl(212.5, 0%, 45.5%)`

C-hsl-decimal: `hsl(212.5, 92.25%, 45.5%)`

C-hsl-white: `hsl(360,100%,100%)`

C-hsl-black: `hsl(0,0%,0%)`

C-invalid-01: `#fff`

C-invalid-02: `#FFFF`

C-invalid-03: `#12345678`

C-invalid-04: `#12GG56`

C-invalid-05: `red`

C-invalid-06: `prefix #0969DA`

C-invalid-07: `#0969DA suffix`

C-invalid-08: `  #0969DA `

C-invalid-09: ` #0969DA  `

C-invalid-10: `RGB(9,105,218)`

C-invalid-11: `rgb(256,0,0)`

C-invalid-12: `rgb(-1,0,0)`

C-invalid-13: `rgb(1.5,2,3)`

C-invalid-14: `rgb(1%,2%,3%)`

C-invalid-15: `rgb(1 2 3)`

C-invalid-16: `rgba(1,2,3,1)`

C-invalid-17: `rgb(1,2)`

C-invalid-18: `rgb(1,2,3,4)`

C-invalid-19: `rgb(NaN,0,0)`

C-invalid-20: `rgb(1e2,0,0)`

C-invalid-21: `hsl(361,100%,50%)`

C-invalid-22: `hsl(-1,100%,50%)`

C-invalid-23: `hsl(0,101%,50%)`

C-invalid-24: `hsl(0,100%,-1%)`

C-invalid-25: `hsl(0,50%,101%)`

C-invalid-26: `hsl(NaN,50%,50%)`

C-invalid-27: `hsl(inf,50%,50%)`

C-invalid-28: `hsl(0,50,50)`

C-invalid-29: `hsla(0,50%,50%,1)`

C-invalid-30: `hsl(0 50% 50%)`

C-invalid-31: `hsl(0,50%,50%)/1`

C-invalid-32: `hsl(calc(2),50%,50%)`

C-invalid-33: `hsl(1e2,50%,50%)`

C-invalid-34: `rgb(999999999999999999999999,0,0)`

Normalization positive: ` #0969DA ` becomes `#0969DA` according to Markdown code-span normalization and is swatch-eligible. This is not a raw-source whitespace rule.

Ordinary prose #0969DA rgb(9,105,218) hsl(212,92%,45%) has no swatches.

```text
#0969DA
rgb(9,105,218)
hsl(212,92%,45%)
```

COLORS END.
