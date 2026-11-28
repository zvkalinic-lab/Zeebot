"""Build the hosted/installable version (site/) from the single-file game index.html.
Usage: python3 build_site.py [version-tag]   e.g. python3 build_site.py v3
Then copy site/* into the Zeebot GitHub repo root and push."""
import sys, re, os
here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, 'index.html')).read()
D = os.path.join(here, 'site') + '/'
head = '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="#0a0e2c">
<meta name="description" content="Zeebot's Star Math: a space math game for kids. Multiply, divide and beat the boss.">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Zeebot">
<link rel="manifest" href="manifest.webmanifest">
<link rel="icon" href="icon-192.png" type="image/png">
<link rel="apple-touch-icon" href="icon-180.png">
<style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}html,body{margin:0}</style>
'''
src = src.replace('<meta name="claude:viewport-fit-sides" content="cover">\n', '')
i = src.index('<div id="app">')
out = head + src[:i] + '</head>\n<body>\n' + src[i:]
# Register the offline service worker right after the debug handle line (whatever it lists).
out, n = re.subn(r"(window\.__bleep = \{[^}]*\};)", r"""\1
if('serviceWorker' in navigator && location.protocol==='https:') addEventListener('load',()=>navigator.serviceWorker.register('sw.js').catch(()=>{}));""", out, count=1)
if n != 1: raise SystemExit('build_site: could not add the service worker registration')
out += '\n</body>\n</html>\n'
open(D + 'index.html', 'w').write(out)
if len(sys.argv) > 1:
    sw = open(D + 'sw.js').read()
    sw = re.sub(r"const VERSION = '[^']*';", f"const VERSION = 'zeebot-{sys.argv[1]}';", sw)
    open(D + 'sw.js', 'w').write(sw)
print('built', D)
