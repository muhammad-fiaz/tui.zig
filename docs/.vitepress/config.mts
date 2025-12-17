import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'TUI.zig',
  description: 'A modern Terminal User Interface library for Zig',
  base: '/tui.zig/',
  
  head: [
    ['link', { rel: 'icon', href: '/tui.zig/favicon.ico' }],
    ['meta', { name: 'theme-color', content: '#f7a41d' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: 'TUI.zig' }],
    ['meta', { property: 'og:description', content: 'A modern Terminal User Interface library for Zig' }],
  ],

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
            { text: 'Getting Started', link: '/guide/getting-started' },
            { text: 'Installation', link: '/guide/installation' },
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
            { text: 'Progress Bar', link: '/guide/widgets/progress' },
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
      copyright: 'Copyright © 2025 Muhammad Fiaz'
    },

    search: {
      provider: 'local'
    },

    editLink: {
      pattern: 'https://github.com/muhammad-fiaz/tui.zig/edit/main/docs/:path',
      text: 'Edit this page on GitHub'
    }
  }
})
