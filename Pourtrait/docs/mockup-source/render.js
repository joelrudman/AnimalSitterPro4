const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');
const [dir, out, scale] = process.argv.slice(2);
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1900, height: 1000 }, deviceScaleFactor: Number(scale) });
  for (const f of fs.readdirSync(dir).filter(f => f.endsWith('.html')).sort()) {
    await page.goto('file://' + path.join(dir, f));
    await page.evaluate(() => document.fonts.ready);
    await page.locator('#shot').screenshot({ path: path.join(out, f.replace('.html', '.png')), omitBackground: f !== 'overview.html' });
  }
  await browser.close();
})();
