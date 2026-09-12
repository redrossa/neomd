# Invalid UTF-8 fixture

Latin-1 café (lone 0xE9)
Lone continuation byte: [€]
Overlong slash: [À¯]
Encoded UTF-16 surrogate: [í €]
Out-of-range 0xF5..0xFF: [õþÿ]
Windows-1252 smart quotes: “quoted” and euro €

Valid tail: **bold** and `code` and a [link](https://example.com).
