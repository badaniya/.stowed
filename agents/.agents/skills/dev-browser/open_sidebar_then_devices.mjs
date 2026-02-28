import { chromium } from 'playwright';

const EMAIL = 'badaniya+user1@extremenetworks.com';
const PASSWORD = 'Extreme@123';
const SERIALS = ['SIM51200-19291', 'SIM51200-19281'];

(async () => {
  const browser = await chromium.launch({ headless: true, slowMo: 500 }); // Slow down for debugging
  const context = await browser.newContext({ 
    viewport: { width: 1920, height: 1080 },
    ignoreHTTPSErrors: true
  });
  const page = await context.newPage();
  
  try {
    // Login
    console.log('1. Logging in...');
    await page.goto('https://brianna-vmr1.qa.xcloudiq.com/', { waitUntil: 'networkidle', timeout: 60000 });
    await page.waitForTimeout(3000);
    const usernameInput = await page.$('input[type="text"].en-c-text-field__input');
    const passwordInput = await page.$('input[type="password"].en-c-text-field__input');
    await usernameInput.fill(EMAIL);
    await passwordInput.fill(PASSWORD);
    const submitBtn = await page.$('button[type="submit"].en-c-button--full-width');
    await submitBtn.click();
    await page.waitForTimeout(10000);
    console.log('   Logged in');
    await page.screenshot({ path: 'tmp/01-logged-in.png', fullPage: true });
    
    // Find and click sidebar toggle
    console.log('2. Looking for sidebar/menu toggle...');
    
    // Common patterns for hamburger menus
    const toggleSelectors = [
      'button[aria-label*="menu" i]',
      'button[aria-label*="navigation" i]',
      'button[aria-label*="sidebar" i]',
      '[data-testid*="menu"]',
      '[data-testid*="sidebar"]',
      '.hamburger',
      '.menu-toggle',
      'button:has(svg) >> visible=true' // Button with icon
    ];
    
    let sidebarOpened = false;
    for (const selector of toggleSelectors) {
      try {
        const toggleBtn = await page.$(selector);
        if (toggleBtn) {
          const isVisible = await toggleBtn.isVisible();
          console.log(`   Found toggle "${selector}", visible: ${isVisible}`);
          if (isVisible) {
            await toggleBtn.click();
            await page.waitForTimeout(1500);
            console.log('   Clicked sidebar toggle');
            sidebarOpened = true;
            await page.screenshot({ path: 'tmp/02-sidebar-opened.png', fullPage: true });
            break;
          }
        }
      } catch (e) {
        // Continue trying
      }
    }
    
    if (!sidebarOpened) {
      console.log('   Sidebar toggle not found, trying to find all buttons...');
      const buttons = await page.$$('button:visible');
      console.log(`   Found ${buttons.length} visible buttons, checking first 10...`);
      
      for (let i = 0; i < Math.min(10, buttons.length); i++) {
        const btn = buttons[i];
        const ariaLabel = await btn.getAttribute('aria-label');
        const text = await btn.textContent();
        console.log(`   Button ${i}: aria-label="${ariaLabel}", text="${text.trim().substring(0, 30)}"`);
        
        // Try clicking first button (often the menu toggle)
        if (i === 0 && (!text || text.trim().length < 5)) {
          console.log('   Trying to click first button (likely menu)...');
          await btn.click();
          await page.waitForTimeout(2000);
          sidebarOpened = true;
          await page.screenshot({ path: 'tmp/02-after-first-btn.png', fullPage: true });
          break;
        }
      }
    }
    
    // Now try clicking Network Devices
    console.log('3. Attempting to click "Network Devices"...');
    await page.waitForTimeout(1000);
    
    try {
      // Try force click since element exists but may be hidden by overflow
      const networkDevicesEl = await page.$('text="Network Devices"');
      if (networkDevicesEl) {
        // Scroll parent into view first
        await page.evaluate(() => {
          const el = document.querySelector('span.nav-menu-label');
          if (el && el.textContent.includes('Network Devices')) {
            el.parentElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
          }
        });
        
        await page.waitForTimeout(1000);
        await networkDevicesEl.click({ force: true });
        await page.waitForTimeout(4000);
        console.log('   Clicked Network Devices');
        console.log('   URL:', page.url());
        await page.screenshot({ path: 'tmp/03-devices-page.png', fullPage: true });
      }
    } catch (e) {
      console.log('   Failed to click Network Devices:', e.message);
      
      // Alternative: try using keyboard navigation
      console.log('   Trying keyboard navigation...');
      await page.keyboard.press('Tab');
      await page.keyboard.press('Tab');
      await page.keyboard.press('Tab');
      await page.keyboard.press('Enter');
      await page.waitForTimeout(3000);
      await page.screenshot({ path: 'tmp/03-after-keyboard.png', fullPage: true });
    }
    
    // Check if we made it to devices page
    const currentUrl = page.url();
    const bodyText = await page.textContent('body');
    
    if (currentUrl.includes('device') || bodyText.toLowerCase().includes('onboard')) {
      console.log('4. ✅ On devices page!');
      
      // Look for Onboard button
      console.log('5. Looking for Onboard/Add Device button...');
      const pageContent = await page.textContent('body');
      console.log('   Page contains "Onboard":', pageContent.includes('Onboard'));
      console.log('   Page contains "Add":', pageContent.includes('Add'));
      
      // Take final screenshot
      await page.screenshot({ path: 'tmp/04-devices-page-ready.png', fullPage: true });
      
      console.log('\n=== Successfully navigated to devices page ===');
      console.log('Manual inspection of screenshot needed to identify onboard UI');
      
    } else {
      console.log('4. ⚠️  Did not reach devices page');
      console.log('   Current URL:', currentUrl);
      await page.screenshot({ path: 'tmp/04-navigation-failed.png', fullPage: true });
    }
    
  } catch (error) {
    console.error('Error:', error.message);
    await page.screenshot({ path: 'tmp/error.png', fullPage: true });
  }
  
  await browser.close();
})();
