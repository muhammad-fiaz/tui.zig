import { defineConfig } from 'vitepress'

const SITE_URL = 'https://muhammad-fiaz.github.io/tui.zig'
const GA_ID = 'G-6BVYCRK57P'
const GTM_ID = 'GTM-P4M9T8ZR'
const ADSENSE_CLIENT_ID = 'ca-pub-2040560600290490'
const CLARITY_ID = 'z5vdzih779'
const DEFAULT_KEYWORDS =
  'zig, zig 0.17.0, tui, terminal ui, cli framework, ansi, OKLCH Color, oklch, cross-platform, widgets, charts, canvas, custom widgets'

const websiteJsonLd = JSON.stringify({
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  name: 'tui.zig',
  applicationCategory: 'DeveloperApplication',
  operatingSystem: 'Windows, Linux, macOS, BSD',
  programmingLanguage: 'Zig',
  softwareVersion: '0.1.0',
  license: 'https://opensource.org/licenses/MIT',
  url: `${SITE_URL}/`,
  codeRepository: 'https://github.com/muhammad-fiaz/tui.zig',
  author: {
    '@type': 'Person',
    name: 'Muhammad Fiaz',
    url: 'https://github.com/muhammad-fiaz'
  },
  publisher: {
    '@type': 'Person',
    name: 'Muhammad Fiaz',
    url: 'https://github.com/muhammad-fiaz'
  },
  description:
    'Native Zig 0.17.0+ terminal user interface library with double-buffered diff rendering, constraint layouts, OKLCH Color palettes, Unicode support, and 30+ reusable widgets.'
})

export default defineConfig({
  title: 'tui.zig',
  titleTemplate: ':title | TUI.zig',
  description:
    'Native Zig 0.17.0+ terminal user interface library with explicit memory management, cross-platform backends, layout engine, OKLCH Color palettes, and custom widget support.',
  base: '/tui.zig/',
  lang: 'en-US',
  cleanUrls: false,
  lastUpdated: true,

  sitemap: {
    hostname: `${SITE_URL}/`,
    transformItems: (items) =>
      items.map((item) => ({
        ...item,
        url: item.url.startsWith('http') ? item.url : `${SITE_URL}/${item.url.replace(/^\/+/, '')}`
      }))
  },

  markdown: {
    theme: {
      light: 'github-light',
      dark: 'one-dark-pro'
    },
    lineNumbers: true
  },

  head: [
    ['meta', { name: 'theme-color', content: '#f7a41d' }],
    ['meta', { name: 'robots', content: 'index, follow' }],
    ['meta', { name: 'author', content: 'Muhammad Fiaz' }],
    ['meta', { name: 'publisher', content: 'Muhammad Fiaz' }],
    ['meta', { name: 'google-adsense-account', content: ADSENSE_CLIENT_ID }],
    ['link', { rel: 'icon', type: 'image/svg+xml', href: '/tui.zig/favicon.svg' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:site_name', content: 'tui.zig' }],
    ['meta', { property: 'og:image', content: `${SITE_URL}/og-image.svg` }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
    ['meta', { name: 'twitter:image', content: `${SITE_URL}/og-image.svg` }],
    [
      'script',
      {
        async: '',
        src: `https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${ADSENSE_CLIENT_ID}`,
        crossorigin: 'anonymous'
      }
    ],
    [
      'script',
      {},
      `(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src='https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);})(window,document,'script','dataLayer','${GTM_ID}');`
    ],
    [
      'script',
      {
        async: '',
        src: `https://www.googletagmanager.com/gtag/js?id=${GA_ID}`
      }
    ],
    [
      'script',
      {},
      `window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}gtag('js',new Date());gtag('config','${GA_ID}');`
    ],
    [
      'script',
      { type: 'text/javascript' },
      `(function(c,l,a,r,i,t,y){c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/"+i;y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);})(window, document, "clarity", "script", "${CLARITY_ID}");`
    ],
    ['script', { type: 'application/ld+json' }, websiteJsonLd]
  ],

  transformHead({ pageData }) {
    const cleanPath = pageData.relativePath
      .replace(/index\.md$/, '')
      .replace(/\.md$/, '')
    const canonical = cleanPath ? `${SITE_URL}/${cleanPath}` : `${SITE_URL}/`
    const pageTitle = pageData.frontmatter.title || pageData.title || 'tui.zig'
    const pageDesc =
      pageData.frontmatter.description ||
      pageData.description ||
      'Native Zig terminal user interface framework documentation.'
    const pageKeywords = pageData.frontmatter.keywords || DEFAULT_KEYWORDS

    const breadcrumbJsonLd = JSON.stringify({
      '@context': 'https://schema.org',
      '@type': 'BreadcrumbList',
      itemListElement: [
        { '@type': 'ListItem', position: 1, name: 'tui.zig', item: `${SITE_URL}/` },
        ...(cleanPath
          ? [{ '@type': 'ListItem', position: 2, name: pageTitle, item: canonical }]
          : [])
      ]
    })

    return [
      ['link', { rel: 'canonical', href: canonical }],
      ['meta', { name: 'keywords', content: pageKeywords }],
      ['meta', { property: 'og:url', content: canonical }],
      ['meta', { property: 'og:title', content: `${pageTitle} | TUI.zig` }],
      ['meta', { property: 'og:description', content: pageDesc }],
      ['meta', { name: 'twitter:title', content: `${pageTitle} | TUI.zig` }],
      ['meta', { name: 'twitter:description', content: pageDesc }],
      ['script', { type: 'application/ld+json' }, breadcrumbJsonLd]
    ]
  },

  themeConfig: {
    siteTitle: 'tui.zig',
    logo: '/favicon.svg',
    search: {
      provider: 'local'
    },
    editLink: {
      pattern: 'https://github.com/muhammad-fiaz/tui.zig/edit/main/docs/:path',
      text: 'Edit this page on GitHub'
    },
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guides', link: '/guides/getting-started', activeMatch: '/guides/' },
      { text: 'Examples', link: '/examples/', activeMatch: '/examples/' },
      { text: 'API Reference', link: '/api/', activeMatch: '/api/' },
      {
        text: 'Support',
        items: [
          { text: 'GitHub Sponsors', link: 'https://github.com/sponsors/muhammad-fiaz' },
          { text: 'Donate', link: 'https://pay.muhammadfiaz.com' },
          { text: 'Support & Sponsoring', link: '/support' },
          { text: 'Contributing', link: 'https://github.com/muhammad-fiaz/tui.zig/blob/main/CONTRIBUTING.md' },
          { text: 'Security Policy', link: '/security' },
          { text: 'MIT License', link: '/license' }
        ]
      }
    ],

    sidebar: {
      '/guides/': [
        {
          text: 'Introduction',
          items: [
            { text: 'Getting Started', link: '/guides/getting-started' },
            { text: 'Installation & Build Setup', link: '/guides/installation' },
            { text: 'Architecture Overview', link: '/guides/architecture' },
            { text: 'Cross-Platform Backends', link: '/guides/cross-platform-support' }
          ]
        },
        {
          text: 'Core Concepts',
          items: [
            { text: 'Terminal Lifecycle', link: '/guides/terminal-lifecycle' },
            { text: 'Rendering Pipeline & Diffing', link: '/guides/rendering-pipeline' },
            { text: 'Layout Engine & Constraints', link: '/guides/layout-and-constraints' },
            { text: 'Styles, Colors & Themes', link: '/guides/styles-colors-and-themes' },
            { text: 'Unicode & Text Wrapping', link: '/guides/unicode-and-text' },
            { text: 'Events, Keys & Mouse', link: '/guides/events-and-input' }
          ]
        },
        {
          text: 'Widgets & Patterns',
          items: [
            { text: 'Widgets Overview', link: '/guides/widgets-overview' },
            { text: 'Stateful Widgets', link: '/guides/stateful-widgets' },
            { text: 'Custom Widgets & Client UIs', link: '/guides/custom-widgets' },
            { text: 'Forms & Schema Validation', link: '/guides/forms-and-validation' },
            { text: 'Charts, Sparklines & Canvas', link: '/guides/charts-and-canvas' },
            { text: 'Popups, Modals & Toasts', link: '/guides/popups-and-dialogs' },
            { text: 'Scrolling & Navigation Chrome', link: '/guides/scrolling-and-navigation' },
            { text: 'Terminal, Logs & Diff Viewers', link: '/guides/terminal-view' },
            { text: 'Animations, Effects & Custom Loops', link: '/guides/animations-and-effects' },
            { text: 'Fonts, Symbols & i18n', link: '/guides/fonts-and-i18n' }
          ]
        },
        {
          text: 'Quality & Operations',
          items: [
            { text: 'Headless Testing', link: '/guides/testing-and-headless' },
            { text: 'Memory Management', link: '/guides/performance-and-memory' },
            { text: 'Troubleshooting', link: '/guides/troubleshooting' },
            { text: 'FAQ', link: '/guides/faq' }
          ]
        }
      ],
      '/examples/': [
        {
          text: 'Examples Gallery',
          items: [
            { text: 'All 38 Examples', link: '/examples/' },
            { text: 'Hello World & Quickstart', link: '/examples/hello-world' },
            { text: 'Layout, Borders & Styling', link: '/examples/layout-and-styling' },
            { text: 'Forms, Inputs & Validation', link: '/examples/forms-and-inputs' },
            { text: 'Lists, Tables, Tabs & Trees', link: '/examples/lists-and-tables' },
            { text: 'Charts, Gauges & Canvas', link: '/examples/charts-and-canvas' },
            { text: 'Events, Mouse & Resize', link: '/examples/events-and-mouse' },
            { text: 'Custom & Stateful Widgets', link: '/examples/custom-widgets' },
            { text: 'Full Multi-Pane Applications', link: '/examples/advanced-apps' }
          ]
        }
      ],
      '/api/': [
        {
          text: 'API Reference',
          items: [
            { text: 'Overview & Conventions', link: '/api/' },
            { text: 'App, Terminal & Backends', link: '/api/app-and-terminal' },
            { text: 'Ui, Buffer & Layout Core', link: '/api/core-and-layout' },
            { text: 'Style, Colors, Themes & Text', link: '/api/style-and-text' },
            { text: 'Events & VT Parser', link: '/api/events' },
            { text: 'All Widgets & State Types', link: '/api/widgets' }
          ]
        }
      ]
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/muhammad-fiaz/tui.zig' }
    ],

    footer: {
      message: 'Released under the <a href="/tui.zig/license">MIT License</a>.',
      copyright: 'Copyright © 2026 Muhammad Fiaz'
    }
  }
})
