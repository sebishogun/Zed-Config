; extends

(fenced_code_block
  (info_string (language) @lang)
  (#any-of? @lang "dot" "graphviz")
  (code_fence_content) @image.content
  (#set! injection.language "dot")
  (#set! image.lang "dot")
  (#set! image.ext "chart.png")
) @image
