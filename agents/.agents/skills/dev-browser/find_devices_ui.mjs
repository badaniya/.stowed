import { chromium } from 'playwright';

const EMAIL = 'badaniya+user1@extremenetworks.com';
const PASSWORD = 'Extreme@123';

(async () => {
  const browser = await chromium.launch({ headless: false }); // Use headful to see what's happening
  const context = await browser.newContext({ 
    viewport: { width: 1920, height: 1080 },
    ignoreHTTPSErrors: true
  });
  const page = await context.newPage();
  
  try {
    // Login
    console.log('Logging in...');
    await page.goto('https://brianna-vmr1.qa.xcloudiq.com/', { 
      waitUntil: 'networkidle',
      timeout: 60000 
    });
    
    await page.waitForTimeout(3000);
    const usernameInput = await page.$('input[type="text"].en-c-text-field__input');
    const passwordInput = await page.$('input[type="password"].en-c-text-field__input');
    await usernameInput.fill(EMAIL);
    await passwordInput.fill(PASSWORD);
    const submitBtn = await page.$('button[type="submit"].en-c-button--full-width');
    await submitBtn.click();
    await page.waitForTimeout(10000); // Wait longer for SPA to load
    
    console.log('Logged in, URL:', page.url());
    await page.screenshot({ path: 'tmp/ep1-home.png', fullPage: true });
    
    // Get all text content to search for navigation
    const bodyText = await page.textContent('body');
    console.log('\nPage contains "Devices":', bodyText.includes('Devices'));
    console.log('Page contains "Device":', bodyText.includes('Device'));
    console.log('Page contains "Inventory":', bodyText.includes('Inventory'));
    console.log('Page contains "Onboard":', bodyText.includes('Onboard'));
    
    // Try to find any clickable elements with "Device" text
    try {
      console.log('\nLooking for clickable elements with "Device"...');
      const deviceElement = await page.getByText('Devices', { exact: false }).first();
      if (deviceElement) {
        console.log('Found element with "Devices" text');
        await deviceElement.click();
        await page.waitForTimeout(3000);
        console.log('After click, URL:', page.url());
        await page.screenshot({ path: 'tmp/after-device-click.png', fullPage: true });
      }
    } catch (e) {
      console.log('Could not find/click Devices element:', e.message);
    }
    
    // Keep browser open for 30 seconds to inspect manually
    console.log('\nBrowser will stay open for 30 seconds...');
    await page.waitForTimeout(30000);
    
  } catch (error) {
    console.error('Error:', error.message);
  }
  
  await browser.close();
})();
