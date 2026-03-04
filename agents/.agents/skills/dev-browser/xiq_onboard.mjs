import { chromium } from 'playwright';

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ 
    viewport: { width: 1920, height: 1080 },
    ignoreHTTPSErrors: true
  });
  const page = await context.newPage();
  
  try {
    console.log('Navigating to XIQ with correct hostname (brianna-vmr1)...');
    await page.goto('https://brianna-vmr1.qa.xcloudiq.com/', { 
      waitUntil: 'domcontentloaded',
      timeout: 60000 
    });
    
    await page.waitForTimeout(5000);
    
    console.log('Current URL:', page.url());
    console.log('Page title:', await page.title());
    
    await page.screenshot({ path: 'tmp/xiq-vmr1-page.png', fullPage: true });
    console.log('Screenshot saved: tmp/xiq-vmr1-page.png');
    
    // Check for login fields
    const emailField = await page.$('input[type="email"], input[name*="email"], input[name*="username"]');
    const passwordField = await page.$('input[type="password"]');
    console.log('Has email field:', !!emailField);
    console.log('Has password field:', !!passwordField);
    
  } catch (error) {
    console.error('Navigation error:', error.message);
    await page.screenshot({ path: 'tmp/xiq-vmr1-error.png' });
  }
  
  await browser.close();
})();
