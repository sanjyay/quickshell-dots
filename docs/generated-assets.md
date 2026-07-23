# Generated Assets

`versions/default/shaders/logo-tint.frag` is the maintained source for
`logo-tint.frag.qsb`. The compiled shader pack is tracked because Quickshell
loads it directly and end users are not required to install Qt shader tools.

The current tracked pack has SHA-256:

```text
273894db4725dc886ad3b62738838ba9e07633f92a04f52eef1baa2167ca8be2
```

It is a QSB version 9 fragment pack containing SPIR-V 100, GLSL 100 ES, GLSL
120, GLSL 150, HLSL 50, and MSL 12 variants. Its reflection contract is:

- texture sampler `source` at binding 1
- input `qt_TexCoord0` at location 0
- output `fragColor` at location 0
- uniform block `buf` at binding 0 containing `qt_Matrix`, `qt_Opacity`, and
  `tintColor`

Regenerate from the repository root with a compatible Qt 6 Shader Baker:

```bash
/usr/lib/qt6/bin/qsb --qt6 \
  -o versions/default/shaders/logo-tint.frag.qsb \
  versions/default/shaders/logo-tint.frag
```

Different Qt versions can produce a byte-different but behaviorally equivalent
pack. Before replacing the tracked binary, run `qsb --dump` on both files and
compare the stage list, reflection contract, and generated shader behavior.
The compiled pack is referenced by launcher and Claude logo effects and must
not be removed merely because it is generated.

Repository PNG/SVG files are static assets, not generated source and not code.
Picker scan lists and thumbnails are runtime caches documented separately in
`state-and-cache.md`; they are not tracked generated files.
