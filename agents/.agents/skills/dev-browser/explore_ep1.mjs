import { chromium } from 'playwright';

const EMAIL = 'badaniya+user1@extremenetworks.com';
const PASSWORD = 'Extreme@123';

(async () => {
  const browser = await chromium.launch({ headless: true });
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
    
    await page.waitForTimeout(2000);
    const usernameInput = await page.$('input[type="text"].en-c-text-field__input');
    const passwordInput = await page.$('input[type="password"].en-c-text-field__input');
    await usernameInput.fill(EMAIL);
    await passwordInput.fill(PASSWORD);
    const submitBtn = await page.$('button[type="submit"].en-c-button--full-width');
    await submitBtn.click();
    await page.waitForTimeout(8000);
    
    console.log('Logged in, URL:', page.url());
    
    // Look for navigation elements
    console.log('\nSearching for "Device" or "Onboard" links...');
    
    // Get all links
    const links = await page.$$eval('a', links => 
      links.map(link => ({
        text: link.textContent.trim(),
        href: link.href
      })).filter(l => l.text.toLowerCase().includes('device') || l.text.toLowerCase().includes('onboard'))
    );
    
    console.log('Links with "device" or "onboard":', JSON.stringify(links, null, 2));
    
    // Get all buttons
    const buttons = await page.$$eval('button', buttons => 
      buttons.map(btn => btn.textContent.trim())
        .filter(text => text.toLowerCase().includes('device') || text.toLowerCase().includes('onboard') || text.toLowerCase().includes('add'))
    );
    
    console.log('\nButtons with relevant text:', JSON.stringify(buttons, null, 2));
    
    // Try searching in menu items
    const menuItems = await page.$$eval('[role="menuitem"], [role="button"], nav a', items => 
      items.map(item => item.textContent.trim()).filter(text => text.length > 0 && text.length < 50)
    );
    
    console.log('\nMenu items:', JSON.stringify(menuItems.slice(0, 30), null, 2));
    
    await page.screenshot({ path: 'tmp/ep1-workspace.png', fullPage: true });
    
  } catch (error) {
    console.error('Error:', error.message);
  }
  
  await browser.close();
})();
