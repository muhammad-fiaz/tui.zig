import DefaultTheme from 'vitepress/theme'
import { h } from 'vue'
import './custom.css'

export default {
  extends: DefaultTheme,
  Layout() {
    return h(DefaultTheme.Layout, null, {
      'layout-top': () =>
        h('noscript', null, [
          h('iframe', {
            src: 'https://www.googletagmanager.com/ns.html?id=GTM-P4M9T8ZR',
            height: '0',
            width: '0',
            style: 'display:none;visibility:hidden'
          })
        ])
    })
  }
}
