# Embedding diagrams

Diagrams are added with the `bpmn` directive provided by the in-repository
Sphinx extension `docs/_ext/sphinx_bpmn.py`. It renders the `.bpmn` file with
[bpmn-to-image](https://github.com/datakurre/bpmn-to-image) at build time.

## Interactive token simulation

The default mode embeds a live [bpmn-js](https://bpmn.io/toolkit/bpmn-js/)
viewer with [token simulation](https://github.com/bpmn-io/bpmn-js-token-simulation):

````md
```{bpmn} ../diagrams/publishing.bpmn
:height: 300px
:caption: Optional caption
```
````

```{bpmn} ../diagrams/publishing.bpmn
:height: 300px
```

## Static images

Use `:mode: svg` or `:mode: png` for a static picture:

```{bpmn} ../diagrams/publishing.bpmn
:mode: svg
:alt: The publishing process as a static image
:width: 100%
```

## Options

`:mode:`
: `interactive` (default), `svg`, `png`, or the animated `gif`, `apng`, `webp`.

`:width:`, `:height:`
: Any CSS length.

`:align:`
: `left`, `center` or `right`.

`:alt:`
: Alternative text for static and animated images.

`:caption:`
: Wraps the diagram in a figure with this caption.

`:scenario:`
: A [scenario](https://github.com/datakurre/bpmn-to-image#animated-executions)
  TOML file that steers an animated mode.

The `bpmn_default_mode` and `bpmn_to_image` (executable) settings in `conf.py`
change the defaults.
