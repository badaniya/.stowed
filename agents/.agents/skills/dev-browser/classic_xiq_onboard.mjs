import { chromium } from 'playwright';

const EMAIL = 'badaniya+user1@extremenetworks.com';
const PASSWORD = 'Extreme@123';
const SERIALS = ['SIM51200-19291', 'SIM51200-19281'];

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ 
    viewport: { width: 1920, height: 1080 },
    ignoreHTTPSErrors: true
  });
  const page = await context.newPage();
  
  try {
    // Step 1: Try to access classic XIQ directly
    console.log('1. Attempting to access Classic XIQ interface...');
    
    // Common paths for classic/legacy XIQ
    const classicPaths = [
      'https://brianna-vmr1.qa.xcloudiq.com/home',
      'https://brianna-vmr1.qa.xcloudiq.com/legacy',
      'https://brianna-vmr1.qa.xcloudiq.com/classic',
      'https://brianna-vmr1.qa.xcloudiq.com/#/manage/devices',
      'https://brianna-vmr1.qa.xcloudiq.com/manage/devices'
    ];
    
    let loggedIn = false;
    
    for (const url of classicPaths) {
      try {
        console.log(`   Trying: ${url}`);
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
        await page.waitForTimeout(3000);
        
        const currentUrl = page.url();
        console.log(`   Current URL: ${currentUrl}`);
        
        // Check if we need to login
        if (currentUrl.includes('login') || currentUrl.includes('sso')) {
          if (!loggedIn) {
            console.log('2. Logging in...');
            await page.waitForTimeout(2000);
            const usernameInput = await page.$('input[type="text"].en-c-text-field__input');
            const passwordInput = await page.$('input[type="password"].en-c-text-field__input');
            
            if (usernameInput && passwordInput) {
              await usernameInput.fill(EMAIL);
              await passwordInput.fill(PASSWORD);
              const submitBtn = await page.$('button[type="submit"].en-c-button--full-width');
              await submitBtn.click();
              await page.waitForTimeout(10000);
              loggedIn = true;
              console.log('   Logged in, URL:', page.url());
            }
          }
        }
        
        // Check if this looks like classic XIQ
        const pageText = await page.textContent('body');
        const isClassic = pageText.includes('Manage') || pageText.includes('Monitor') || 
                         pageText.includes('Configure') || currentUrl.includes('manage');
        
        if (isClassic) {
          console.log('   ✓ This appears to be classic XIQ interface');
          await page.screenshot({ path: 'tmp/01-classic-xiq.png', fullPage: true });
          break;
        }
        
      } catch (e) {
        console.log(`   Failed: ${e.message}`);
      }
    }
    
    // Step 2: Look for the main navigation
    console.log('3. Looking for Manage/Devices navigation...');
    
    const currentUrl = page.url();
    await page.screenshot({ path: 'tmp/02-after-navigation-attempts.png', fullPage: true });
    
    // If we're on EP1, try to find a link to switch to classic
    const bodyText = await page.textContent('body');
    if (currentUrl.includes('ep1test.com') || bodyText.includes('Workspace')) {
      console.log('   Currently on EP1, looking for classic/legacy switch...');
      
      // Look for profile menu or settings
      const profileSelectors = [
        'button[aria-label*="profile" i]',
        'button[aria-label*="account" i]',
        'button[aria-label*="user" i]',
        '[data-testid*="profile"]',
        '[data-testid*="user"]',
        'text="BA"', // User initials
        'text="Brian Adaniya"'
      ];
      
      for (const selector of profileSelectors) {
        try {
          await page.click(selector, { timeout: 5000 });
          await page.waitForTimeout(2000);
          console.log(`   Clicked profile menu: ${selector}`);
          await page.screenshot({ path: 'tmp/03-profile-menu.png', fullPage: true });
          
          // Look for "Classic" or "Legacy" option
          const menuText = await page.textContent('body');
          if (menuText.includes('Classic') || menuText.includes('Legacy') || menuText.includes('Switch to')) {
            console.log('   Found switch option in menu');
            await page.click('text=/.*Classic.*/i', { timeout: 3000 });
            await page.waitForTimeout(5000);
            console.log('   Switched to classic, URL:', page.url());
            await page.screenshot({ path: 'tmp/04-after-classic-switch.png', fullPage: true });
          }
          break;
        } catch (e) {
          // Continue
        }
      }
    }
    
    // Step 3: Navigate to Devices page in classic XIQ
    console.log('4. Navigating to Devices page...');
    
    // Try clicking on Manage > Devices
    const manageNavSelectors = [
      'text="Manage"',
      'a:has-text("Manage")',
      '[href*="manage"]',
      'text=/Manage/i'
    ];
    
    for (const selector of manageNavSelectors) {
      try {
        const element = await page.$(selector);
        if (element && await element.isVisible()) {
          console.log(`   Found Manage menu: ${selector}`);
          await element.click();
          await page.waitForTimeout(2000);
          await page.screenshot({ path: 'tmp/05-manage-menu.png', fullPage: true });
          
          // Now click Devices
          await page.click('text="Devices"', { timeout: 5000 });
          await page.waitForTimeout(3000);
          console.log('   Clicked Devices, URL:', page.url());
          await page.screenshot({ path: 'tmp/06-devices-page.png', fullPage: true });
          break;
        }
      } catch (e) {
        console.log(`   Failed to navigate via ${selector}`);
      }
    }
    
    // Step 4: Look for "Add Devices" or "+" button
    console.log('5. Looking for Add Devices button...');
    
    const addButtonSelectors = [
      'button:has-text("Add Devices")',
      'button:has-text("ADD DEVICES")',
      'a:has-text("Add Devices")',
      '.addDeviceButton',
      '#addDeviceButton',
      'text="+ Add Devices"',
      'button.primary:has-text("Add")',
      '[title="Add Devices"]',
      '[aria-label="Add Devices"]'
    ];
    
    let addButton = null;
    for (const selector of addButtonSelectors) {
      try {
        const btn = await page.$(selector);
        if (btn && await btn.isVisible()) {
          console.log(`   Found Add button: ${selector}`);
          addButton = btn;
          break;
        }
      } catch (e) {
        // Continue
      }
    }
    
    if (addButton) {
      console.log('6. Clicking Add Devices...');
      await addButton.click();
      await page.waitForTimeout(3000);
      await page.screenshot({ path: 'tmp/07-add-dialog.png', fullPage: true });
      
      // Step 5: Look for "Quick Add Devices" option
      console.log('7. Looking for Quick Add Devices option...');
      
      const quickAddSelectors = [
        'text="Quick Add Devices"',
        'text=/.*Quick.*Add.*/i',
        '[title*="Quick Add"]',
        'button:has-text("Quick")'
      ];
      
      for (const selector of quickAddSelectors) {
        try {
          await page.click(selector, { timeout: 5000 });
          await page.waitForTimeout(2000);
          console.log('   Clicked Quick Add Devices');
          await page.screenshot({ path: 'tmp/08-quick-add-dialog.png', fullPage: true });
          break;
        } catch (e) {
          // Continue
        }
      }
      
      // Step 6: Find serial number input field
      console.log('8. Looking for serial number input...');
      
      // In classic XIQ, the Quick Add dialog has a specific structure
      // Look for textarea or input with id/name containing "serial" or "device"
      const serialInputSelectors = [
        'textarea[name*="serial" i]',
        'textarea[id*="serial" i]',
        'input[name*="serial" i]',
        'textarea.dijitTextArea',
        'textarea',
        'input[type="text"]'
      ];
      
      let serialInput = null;
      for (const selector of serialInputSelectors) {
        try {
          const inputs = await page.$$(selector);
          for (const input of inputs) {
            if (await input.isVisible()) {
              console.log(`   Found input: ${selector}`);
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
        console.log('9. Entering serial numbers...');
        
        // For classic XIQ, serials should be entered one per line
        const serialText = SERIALS.join('\n');
        await serialInput.fill(serialText);
        await page.waitForTimeout(1500);
        
        console.log(`   Entered serials: ${SERIALS.join(', ')}`);
        await page.screenshot({ path: 'tmp/09-serials-entered.png', fullPage: true });
        
        // Step 7: Click Add/Submit button
        console.log('10. Looking for Add/Submit button...');
        
        const submitSelectors = [
          'button:has-text("Add")',
          'button:has-text("Submit")',
          'button[type="submit"]',
          '.dijitButton:has-text("Add")',
          'button.primary'
        ];
        
        for (const selector of submitSelectors) {
          try {
            const buttons = await page.$$(selector);
            for (const btn of buttons) {
              if (await btn.isVisible()) {
                const btnText = await btn.textContent();
                if (btnText.toLowerCase().includes('add') || btnText.toLowerCase().includes('submit')) {
                  console.log(`   Clicking submit button: "${btnText.trim()}"`);
                  await btn.click();
                  await page.waitForTimeout(8000); // Wait for processing
                  
                  console.log('11. Checking results...');
                  await page.screenshot({ path: 'tmp/10-after-submit.png', fullPage: true });
                  
                  // Check for success or error messages
                  const resultText = await page.textContent('body');
                  
                  if (resultText.toLowerCase().includes('success') || 
                      resultText.toLowerCase().includes('successfully') ||
                      resultText.toLowerCase().includes('added')) {
                    console.log('✅ SUCCESS: Devices appear to be added!');
                  } else if (resultText.toLowerCase().includes('error') || 
                             resultText.toLowerCase().includes('invalid') ||
                             resultText.toLowerCase().includes('not found') ||
                             resultText.toLowerCase().includes('failed')) {
                    console.log('⚠️  ERROR: Onboarding failed or rejected');
                    
                    // Try to extract error message
                    const lines = resultText.split('\n').filter(l => l.trim().length > 0);
                    for (const line of lines) {
                      const lowerLine = line.toLowerCase();
                      if (lowerLine.includes('error') || lowerLine.includes('invalid') || 
                          lowerLine.includes('fail') || lowerLine.includes('not')) {
                        console.log(`   Message: ${line.trim()}`);
                      }
                    }
                  } else {
                    console.log('ℹ️  No clear success/error message found');
                  }
                  
                  // Wait a bit more and take final screenshot
                  await page.waitForTimeout(3000);
                  await page.screenshot({ path: 'tmp/11-final-result.png', fullPage: true });
                  
                  break;
                }
              }
            }
            break;
          } catch (e) {
            console.log(`   Failed to click submit: ${e.message}`);
          }
        }
      } else {
        console.log('   Serial input field not found');
      }
      
    } else {
      console.log('   Add Devices button not found');
      console.log('   Page may not be the devices management page');
    }
    
    console.log('\n=== Onboarding Attempt Complete ===');
    console.log('Device serials:', SERIALS);
    console.log('Check tmp/ directory for screenshots');
    
  } catch (error) {
    console.error('Error:', error.message);
    console.error(error.stack);
    await page.screenshot({ path: 'tmp/error.png', fullPage: true });
  }
  
  await browser.close();
})();
