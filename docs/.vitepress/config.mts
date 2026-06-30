import { defineConfig } from 'vitepress'

// Google Analytics and Google Tag Manager IDs
export const GA_ID = "G-6BVYCRK57P";
export const GTM_ID = "GTM-P4M9T8ZR";

// Google AdSense Client ID
export const ADSENSE_CLIENT_ID = "ca-pub-2040560600290490";

export default defineConfig({
  title: 'TUI.zig',
  description: 'A modern Terminal User Interface library for Zig',
  base: '/tui.zig/',
  lastUpdated: true,
  cleanUrls: true,

  head: [
    ['link', { rel: 'icon', href: '/tui.zig/favicon.ico' }],
    ['meta', { name: 'theme-color', content: '#f7a41d' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: 'TUI.zig' }],
    ['meta', { property: 'og:description', content: 'A modern Terminal User Interface library for Zig' }],
    ['meta', { property: 'og:image', content: '/tui.zig/og-image.png' }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
    ['meta', { name: 'twitter:title', content: 'TUI.zig' }],
    ['meta', { name: 'twitter:description', content: 'A modern Terminal User Interface library for Zig' }],
    ['meta', { name: 'twitter:image', content: '/tui.zig/og-image.png' }],
    // Web App Manifest
    ['link', { rel: 'manifest', href: '/tui.zig/manifest.json' }],
    // Google Analytics
    ['script', { async: true, src: `https://www.googletagmanager.com/gtag/js?id=${GA_ID}` }],
    ['script', {}, `
      window.dataLayer = window.dataLayer || [];
      function gtag(){dataLayer.push(arguments);}
      gtag('js', new Date());
      gtag('config', '${GA_ID}');
    `],
    // Google Tag Manager
    ['script', {}, `
      (function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
      new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
      j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
      'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
      })(window,document,'script','dataLayer','${GTM_ID}');
    `],
    // Google AdSense
    ['script', { async: true, src: `https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${ADSENSE_CLIENT_ID}`, crossorigin: 'anonymous' }],
    // Google Tag Manager (noscript)
    ['noscript', {}, `
      <iframe src="https://www.googletagmanager.com/ns.html?id=${GTM_ID}"
      height="0" width="0" style="display:none;visibility:hidden"></iframe>
    `],
  ],

  sitemap: {
    hostname: 'https://muhammad-fiaz.github.io/tui.zig',
    lastmodDateOnly: false,
    xml: {
      spaces: 4,
    },
  },

  themeConfig: {
    logo: '/logo.svg',

    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guide', link: '/guide/getting-started' },
      { text: 'API', link: '/api/' },
      {
        text: 'Links',
        items: [
          { text: 'GitHub', link: 'https://github.com/muhammad-fiaz/tui.zig' },
          { text: 'Releases', link: 'https://github.com/muhammad-fiaz/tui.zig/releases' },
          { text: 'Issues', link: 'https://github.com/muhammad-fiaz/tui.zig/issues' },
        ]
      }
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Introduction',
          items: [
            { text: 'What is TUI.zig?', link: '/guide/introduction' },
            { text: 'Installation', link: '/guide/installation' },
            { text: 'Getting Started', link: '/guide/getting-started' },
          ]
        },
        {
          text: 'Core Concepts',
          items: [
            { text: 'Application', link: '/guide/application' },
            { text: 'Widgets', link: '/guide/widgets' },
            { text: 'Events', link: '/guide/events' },
            { text: 'Styling', link: '/guide/styling' },
            { text: 'Layout', link: '/guide/layout' },
            { text: 'Animation', link: '/guide/animation' },
          ]
        },
        {
          text: 'Form Widgets',
          items: [
            { text: 'Input Field', link: '/guide/widgets/input-field' },
            { text: 'Text Area', link: '/guide/widgets/text-area' },
            { text: 'Checkbox', link: '/guide/widgets/checkbox' },
            { text: 'Radio Group', link: '/guide/widgets/radio' },
            { text: 'Switch', link: '/guide/widgets/switch' },
            { text: 'Slider', link: '/guide/widgets/slider' },
          ]
        },
        {
          text: 'Display Widgets',
          items: [
            { text: 'Text', link: '/guide/widgets/text' },
            { text: 'Badge', link: '/guide/widgets/badge' },
            { text: 'Card', link: '/guide/widgets/card' },
            { text: 'Table', link: '/guide/widgets/table' },
            { text: 'List View', link: '/guide/widgets/list-view' },
            { text: 'Tree View', link: '/guide/widgets/tree' },
            { text: 'Image', link: '/guide/widgets/image' },
          ]
        },
        {
          text: 'Navigation',
          items: [
            { text: 'Navbar', link: '/guide/widgets/navbar' },
            { text: 'Sidebar', link: '/guide/widgets/sidebar' },
            { text: 'Breadcrumb', link: '/guide/widgets/breadcrumb' },
            { text: 'Tabs', link: '/guide/widgets/tabs' },
            { text: 'Menu', link: '/guide/widgets/menu' },
            { text: 'Pagination', link: '/guide/widgets/pagination' },
          ]
        },
        {
          text: 'Feedback',
          items: [
            { text: 'Alert', link: '/guide/widgets/alert' },
            { text: 'Toast', link: '/guide/widgets/toast' },
            { text: 'Modal', link: '/guide/widgets/modal' },
            { text: 'Progress Bar', link: '/guide/widgets/progress-bar' },
            { text: 'Spinner', link: '/guide/widgets/spinner' },
            { text: 'Skeleton', link: '/guide/widgets/skeleton' },
          ]
        },
        {
          text: 'Layout',
          items: [
            { text: 'Grid', link: '/guide/widgets/grid' },
            { text: 'Accordion', link: '/guide/widgets/accordion' },
            { text: 'Split View', link: '/guide/widgets/split-view' },
            { text: 'Scroll View', link: '/guide/widgets/scroll-view' },
            { text: 'Separator', link: '/guide/widgets/separator' },
          ]
        },
        {
          text: 'Advanced',
          items: [
            { text: 'Custom Widgets', link: '/guide/custom-widgets' },
            { text: 'Themes', link: '/guide/themes' },
            { text: 'Unicode & CJK', link: '/guide/unicode' },
            { text: 'Performance', link: '/guide/performance' },
          ]
        }
      ],
      '/api/': [
        {
          text: 'API Reference',
          items: [
            { text: 'Overview', link: '/api/' },
            { text: 'App', link: '/api/app' },
            { text: 'Screen', link: '/api/screen' },
            { text: 'Style', link: '/api/style' },
            { text: 'Color', link: '/api/color' },
            { text: 'Event', link: '/api/event' },
            { text: 'Layout', link: '/api/layout' },
            { text: 'Widget', link: '/api/widget' },
          ]
        }
      ]
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/muhammad-fiaz/tui.zig' }
    ],

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright 2025 Muhammad Fiaz'
    },

    search: {
      provider: 'local'
    },

    editLink: {
      pattern: 'https://github.com/muhammad-fiaz/tui.zig/edit/main/docs/:path',
      text: 'Edit this page on GitHub'
    },

    outline: {
      level: [2, 3],
      label: 'On this page'
    },

    returnToTopLabel: 'Back to top',
    sidebarMenuLabel: 'Menu',
    darkModeSwitchLabel: 'Theme',
    lightModeSwitchTitle: 'Switch to light mode',
    darkModeSwitchTitle: 'Switch to dark mode',
  }
})
