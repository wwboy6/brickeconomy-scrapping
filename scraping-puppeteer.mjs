import async from 'async'
// import puppeteer from 'puppeteer';
import puppeteer from 'puppeteer-extra'
import StealthPlugin from 'puppeteer-extra-plugin-stealth'

puppeteer.use(StealthPlugin()) 

/*
(async () => {
  // Launch the browser and open a new blank page
  const browser = await puppeteer.launch();
  const page = await browser.newPage();

  // Navigate the page to a URL
  await page.goto('https://developer.chrome.com/');

  // Set screen size
  await page.setViewport({width: 1080, height: 1024});

  // Type into search box
  await page.type('.search-box__input', 'automate beyond recorder');

  // Wait and click on first result
  const searchResultSelector = '.search-box__link';
  await page.waitForSelector(searchResultSelector);
  await page.click(searchResultSelector);

  // Locate the full title with a unique string
  const textSelector = await page.waitForSelector(
    'text/Customize and automate'
  );
  const fullTitle = await textSelector?.evaluate(el => el.textContent);

  // Print the full title
  console.log('The title of this blog post is "%s".', fullTitle);

  await browser.close();
})();
*/

let page

async function main () {
  const browser = await puppeteer.launch();
  page = await browser.newPage();

  let itemUrls = await scrapeThemePages('brickheadz')
  
  // await page.screenshot({'path': 'screenshot.png'})
  await browser.close();
}

async function scrapeThemePages(themeId) {
  await page.goto(`https://www.brickeconomy.com/sets/theme/${themeId}`);
  await page.setViewport({width: 1080, height: 1024});
  let itemUrls = await scrapeThemePage()
  // check if have other pages
  const pageButtons = await page.$$('a.page-link')
  // console.log('page buttons', pageButtons.length)
  for (let i = 2; i <= pageButtons.length - 2; ++i) {
    // click page button
    await pageButtons[i].click()
    const firstLink = itemUrls[0]
    // wait until result list is changed
    await page.waitForFunction(`$('td.ctlsets-left a:first-child')[0].href != '${firstLink}'`)
    //
    itemUrls = [...itemUrls, ...await scrapeThemePage()]
  }
  return itemUrls
}

async function scrapeThemePage() {
  let selector = 'td.ctlsets-left a:first-child'
  await page.waitForSelector(selector);
  let elements = await page.$$(selector)
  let itemUrls = await Promise.all(elements.map(eh => eh.evaluate(element => element.href)))
  return itemUrls
}

main()
