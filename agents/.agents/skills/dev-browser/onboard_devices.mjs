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
    // Step 1: Login
    console.log('1. Logging in to XIQ...');
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
    await page.waitForTimeout(10000);
    
    console.log('2. Logged in successfully, URL:', page.url());
    await page.screenshot({ path: 'tmp/01-logged-in.png', fullPage: true });
    
    // Step 2: Look for menu/navigation sidebar toggle
    console.log('3. Looking for navigation menu...');
    
    // Try common menu toggle patterns
    const menuSelectors = [
      'button[aria-label*="menu"]',
      'button[aria-label*="Menu"]',
      '[data-testid="menu-button"]',
      '.menu-toggle',
      'button.hamburger',
      'button:has(svg)',
      '[role="button"]:has-text("Menu")'
    ];
    
    let menuOpened = false;
    for (const selector of menuSelectors) {
      try {
        const menuBtn = await page.$(selector);
        if (menuBtn) {
          console.log(`   Found menu button with selector: ${selector}`);
          await menuBtn.click();
          await page.waitForTimeout(1000);
          menuOpened = true;
          break;
        }
      } catch (e) {
        // Continue trying
      }
    }
    
    if (!menuOpened) {
      console.log('   Trying to find visible menu items...');
    }
    
    await page.screenshot({ path: 'tmp/02-after-menu-attempt.png', fullPage: true });
    
    // Step 3: Look for "Devices" or "Network Devices" navigation item
    console.log('4. Looking for Network Devices navigation...');
    
    // Try multiple approaches to find and click the devices menu
    const deviceNavSelectors = [
      'text=/.*Network Devices.*/i',
      'text=/.*Devices.*/i',
      '[href*="devices"]',
      'a:has-text("Network Devices")',
      'span:has-text("Network Devices")',
      '[aria-label*="Devices"]'
    ];
    
    let navigatedToDevices = false;
    for (const selector of deviceNavSelectors) {
      try {
        console.log(`   Trying selector: ${selector}`);
        const element = await page.$(selector);
        if (element) {
          // Check if visible
          const isVisible = await element.isVisible();
          console.log(`   Found element, visible: ${isVisible}`);
          
          if (isVisible) {
            await element.click({ timeout: 5000 });
            await page.waitForTimeout(3000);
            navigatedToDevices = true;
            console.log('   Clicked on devices navigation');
            break;
          } else {
            // Try to scroll into view or find parent
            console.log('   Element not visible, trying parent...');
            const parent = await element.evaluateHandle(el => el.parentElement);
            if (parent) {
              await parent.asElement().click({ timeout: 5000 });
              await page.waitForTimeout(2000);
              navigatedToDevices = true;
              break;
            }
          }
        }
      } catch (e) {
        console.log(`   Failed with selector ${selector}: ${e.message}`);
      }
    }
    
    console.log('5. Current URL after navigation attempt:', page.url());
    await page.screenshot({ path: 'tmp/03-after-device-nav.png', fullPage: true });
    
    // Step 4: Look for Add/Onboard button
    console.log('6. Looking for Add/Onboard device button...');
    
    const addButtonSelectors = [
      'button:has-text("Add")',
      'button:has-text("Onboard")',
      'button:has-text("Quick Add")',
      '[aria-label*="Add"]',
      '[data-testid*="add"]',
      'button.add-device',
      'text=/.*Add Device.*/i'
    ];
    
    let addButtonFound = false;
    for (const selector of addButtonSelectors) {
      try {
        const addBtn = await page.$(selector);
        if (addBtn && await addBtn.isVisible()) {
          console.log(`   Found Add button with selector: ${selector}`);
          await addBtn.click();
          await page.waitForTimeout(3000);
          addButtonFound = true;
          break;
        }
      } catch (e) {
        // Continue
      }
    }
    
    await page.screenshot({ path: 'tmp/04-after-add-click.png', fullPage: true });
    
    if (!addButtonFound) {
      console.log('   Add button not found, trying to locate onboarding form directly...');
    }
    
    // Step 5: Look for serial number input field
    console.log('7. Looking for serial number input field...');
    
    const serialInputSelectors = [
      'input[placeholder*="serial" i]',
      'input[name*="serial" i]',
      'textarea[placeholder*="serial" i]',
      'input[placeholder*="Serial" i]',
      'textarea',
      'input[type="text"]'
    ];
    
    let serialInput = null;
    for (const selector of serialInputSelectors) {
      try {
        const inputs = await page.$$(selector);
        for (const input of inputs) {
          if (await input.isVisible()) {
            console.log(`   Found visible input with selector: ${selector}`);
            serialInput = input;
            break;
          }
        }
        if (serialInput) break;
      } catch (e) {
        // Continue
      }
    }
    
    if (serialInput) {
      console.log('8. Entering serial numbers...');
      // Try entering serials separated by newlines or commas
      const serialText = SERIALS.join('\n');
      await serialInput.fill(serialText);
      await page.waitForTimeout(1000);
      
      console.log('9. Serial numbers entered:', SERIALS);
      await page.screenshot({ path: 'tmp/05-serials-entered.png', fullPage: true });
      
      // Step 6: Look for Submit/Add/Onboard button
      console.log('10. Looking for submit button...');
      
      const submitSelectors = [
        'button:has-text("Add")',
        'button:has-text("Onboard")',
        'button:has-text("Submit")',
        'button[type="submit"]',
        'button.primary',
        'button.en-c-button--primary'
      ];
      
      let submitButton = null;
      for (const selector of submitSelectors) {
        try {
          const btns = await page.$$(selector);
          for (const btn of btns) {
            if (await btn.isVisible()) {
              submitButton = btn;
              console.log(`   Found submit button: ${selector}`);
              break;
            }
          }
          if (submitButton) break;
        } catch (e) {
          // Continue
        }
      }
      
      if (submitButton) {
        console.log('11. Clicking submit to onboard devices...');
        await submitButton.click();
        await page.waitForTimeout(5000);
        
        console.log('12. After submit, URL:', page.url());
        await page.screenshot({ path: 'tmp/06-after-submit.png', fullPage: true });
        
        // Check for success/error messages
        const pageText = await page.textContent('body');
        if (pageText.includes('success') || pageText.includes('Success')) {
          console.log('✅ Success message detected!');
        } else if (pageText.includes('error') || pageText.includes('Error') || pageText.includes('invalid')) {
          console.log('⚠️  Error message detected');
          console.log('   Page text preview:', pageText.substring(0, 500));
        } else {
          console.log('   No clear success/error message found');
        }
        
        await page.waitForTimeout(3000);
        await page.screenshot({ path: 'tmp/07-final-state.png', fullPage: true });
        
      } else {
        console.log('   Submit button not found');
        await page.screenshot({ path: 'tmp/06-no-submit.png', fullPage: true });
      }
      
    } else {
      console.log('   Serial input field not found');
      console.log('   Current page may not be the onboarding form');
      
      // Get page content for debugging
      const bodyText = await page.textContent('body');
      console.log('\n   Page text preview:');
      console.log(bodyText.substring(0, 800));
    }
    
    console.log('\n=== Onboarding attempt complete ===');
    console.log('Check screenshots in tmp/ directory for details');
    
  } catch (error) {
    console.error('Error:', error.message);
    console.error(error.stack);
    await page.screenshot({ path: 'tmp/error.png', fullPage: true });
  }
  
  await browser.close();
})();
