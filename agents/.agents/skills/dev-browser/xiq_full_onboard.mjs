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
    
    await page.waitForTimeout(2000);
    
    console.log('2. Filling login form...');
    // Find inputs by class
    const usernameInput = await page.$('input[type="text"].en-c-text-field__input');
    const passwordInput = await page.$('input[type="password"].en-c-text-field__input');
    
    if (!usernameInput || !passwordInput) {
      throw new Error('Could not find login inputs');
    }
    
    await usernameInput.fill(EMAIL);
    await passwordInput.fill(PASSWORD);
    
    await page.screenshot({ path: 'tmp/01-filled-login.png' });
    console.log('3. Submitting login...');
    
    // Click the submit button
    const submitBtn = await page.$('button[type="submit"].en-c-button--full-width');
    await submitBtn.click();
    
    console.log('4. Waiting for navigation after login...');
    await page.waitForTimeout(8000); // Wait for redirect and page load
    
    console.log('5. After login, URL:', page.url());
    await page.screenshot({ path: 'tmp/02-after-login.png', fullPage: true });
    
    // Check if login was successful
    if (page.url().includes('login')) {
      console.error('Still on login page - login may have failed');
      const errorText = await page.textContent('body');
      console.log('Page text preview:', errorText.substring(0, 500));
    } else {
      console.log('Login successful!');
    }
    
    // Step 2: Navigate to devices page
    console.log('6. Navigating to devices page...');
    await page.goto('https://brianna-vmr1.qa.xcloudiq.com/#/devices', { 
      waitUntil: 'domcontentloaded',
      timeout: 30000 
    });
    await page.waitForTimeout(5000);
    
    console.log('7. On devices page, URL:', page.url());
    await page.screenshot({ path: 'tmp/03-devices-page.png', fullPage: true });
    
    console.log('\nNext: Need to find the onboarding UI elements');
    console.log('Serials ready:', SERIALS);
    
  } catch (error) {
    console.error('Error:', error.message);
    console.error(error.stack);
    await page.screenshot({ path: 'tmp/error-page.png' });
  }
  
  await browser.close();
})();
