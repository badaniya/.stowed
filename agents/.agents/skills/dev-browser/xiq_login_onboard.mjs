import { chromium } from 'playwright';

const EMAIL = 'badaniya+user1@extremenetworks.com';
const PASSWORD = 'Extreme@123';
const SERIALS = ['SIM51200-19291', 'SIM51200-19281']; // EXOS-5302, VOSS-5701

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ 
    viewport: { width: 1920, height: 1080 },
    ignoreHTTPSErrors: true
  });
  const page = await context.newPage();
  
  try {
    // Step 1: Navigate and login
    console.log('1. Navigating to XIQ...');
    await page.goto('https://brianna-vmr1.qa.xcloudiq.com/', { 
      waitUntil: 'networkidle',
      timeout: 60000 
    });
    
    console.log('2. Logging in...');
    await page.fill('input[type="email"], input[name*="email"]', EMAIL);
    await page.fill('input[type="password"]', PASSWORD);
    await page.screenshot({ path: 'tmp/01-before-login.png' });
    
    await page.click('button[type="submit"], button:has-text("Sign In"), button:has-text("Log In")');
    await page.waitForTimeout(5000);
    await page.waitForLoadState('networkidle', { timeout: 30000 });
    
    console.log('3. After login, URL:', page.url());
    await page.screenshot({ path: 'tmp/02-after-login.png', fullPage: true });
    
    // Step 2: Navigate to devices page
    console.log('4. Navigating to devices page...');
    await page.goto('https://brianna-vmr1.qa.xcloudiq.com/#/devices', { 
      waitUntil: 'networkidle',
      timeout: 30000 
    });
    await page.waitForTimeout(3000);
    
    console.log('5. On devices page, URL:', page.url());
    await page.screenshot({ path: 'tmp/03-devices-page.png', fullPage: true });
    
    // Step 3: Look for onboard/add device button
    console.log('6. Looking for add device button...');
    const pageText = await page.textContent('body');
    console.log('Page contains "Add" button:', pageText.includes('Add'));
    console.log('Page contains "Onboard" text:', pageText.includes('Onboard') || pageText.includes('onboard'));
    
    await page.screenshot({ path: 'tmp/04-ready-to-onboard.png', fullPage: true });
    console.log('\nReady for device onboarding. Screenshots saved in tmp/ directory.');
    console.log('Device serials to onboard:', SERIALS);
    
  } catch (error) {
    console.error('Error:', error.message);
    await page.screenshot({ path: 'tmp/error-page.png' });
  }
  
  await browser.close();
})();
