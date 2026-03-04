const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ 
    viewport: { width: 1920, height: 1080 },
    ignoreHTTPSErrors: true
  });
  const page = await context.newPage();
  
  try {
    console.log('Navigating to XIQ...');
    await page.goto('https://brianna-vmr1.qa.xcloudiq.com/', { 
      waitUntil: 'networkidle',
      timeout: 60000 
    });
    
    await page.waitForTimeout(5000);
    
    console.log('URL:', page.url());
    console.log('Title:', await page.title());
    
    await page.screenshot({ path: 'tmp/xiq-vmr1-login.png' });
    console.log('Screenshot saved: tmp/xiq-vmr1-login.png');
    
    // Check if login form exists
    const hasLoginForm = await page.$('input[type="email"], input[type="text"][name*="email"], input[name="username"]');
    console.log('Has login form:', !!hasLoginForm);
    
  } catch (error) {
    console.error('Error:', error.message);
    await page.screenshot({ path: 'tmp/xiq-vmr1-error.png' });
  }
  
  await browser.close();
})();
