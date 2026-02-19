# Configuration file for the Sphinx documentation builder.
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -------------------------------------------------------
project = "iclaude"
author = "iclaude contributors"
release = "4.0"

# -- General configuration -----------------------------------------------------
extensions = [
    "myst_parser",
    "sphinx_design",
    "sphinx_copybutton",
    "sphinxcontrib.mermaid",
]

# sphinx-llms-txt: generates llms.txt and llms-full.txt for AI agents
# Install: pip install sphinx-llms-txt
try:
    import sphinx_llms_txt  # noqa: F401
    extensions.append("sphinx_llms_txt")
except ImportError:
    pass  # Optional — docs build without it

# MyST Parser — use Markdown with full Sphinx capabilities
myst_enable_extensions = [
    "colon_fence",   # ::: blocks as alternative to ``` for directives
    "deflist",       # Definition lists
    "fieldlist",     # Field lists
    "attrs_inline",  # Inline attributes {.class}
]

# File formats
source_suffix = {
    ".rst": "restructuredtext",
    ".md": "markdown",
}

# Exclude patterns (relative to docs/sphinx/)
exclude_patterns = [
    "_build",
    "Thumbs.db",
    ".DS_Store",
    "../plans/README.md",  # Plans index not included in main TOC
]

# -- HTML output ---------------------------------------------------------------
html_theme = "furo"
html_title = "iclaude Documentation"

# Furo theme options
html_theme_options = {
    "sidebar_hide_name": False,
    "navigation_with_keys": True,
    "top_of_page_button": "edit",
    "dark_css_variables": {
        "color-brand-primary": "#f97316",
        "color-brand-content": "#fb923c",
    },
    "light_css_variables": {
        "color-brand-primary": "#ea580c",
        "color-brand-content": "#c2410c",
    },
}

# Static files (relative to docs/sphinx/)
html_static_path = ["_static", "../_static"]

# -- sphinx-llms-txt -----------------------------------------------------------
# AI-first documentation: generates llms.txt and llms-full.txt
# These files allow AI agents to consume documentation efficiently
# See: https://llmstxt.org/
