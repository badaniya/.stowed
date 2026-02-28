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
    // Step 1: Go directly to Original XIQ devices page
    console.log('1. Navigating to Original XIQ devices page...');
    await page.goto('https://brianna-vmr1.qa.xcloudiq.com/devices', { 
      waitUntil: 'networkidle',
      timeout: 60000 
    });
    
    await page.waitForTimeout(3000);
    
    // Check if we're on login page
    const currentUrl = page.url();
    console.log('   Current URL:', currentUrl);
    
    if (currentUrl.includes('login') || currentUrl.includes('sso')) {
      console.log('2. On login page, logging in...');
      await page.waitForTimeout(2000);
      const usernameInput = await page.$('input[type="text"].en-c-text-field__input');
      const passwordInput = await page.$('input[type="password"].en-c-text-field__input');
      
      if (usernameInput && passwordInput) {
        await usernameInput.fill(EMAIL);
        await passwordInput.fill(PASSWORD);
        const submitBtn = await page.$('button[type="submit"].en-c-button--full-width');
        await submitBtn.click();
        await page.waitForTimeout(10000);
        console.log('   Logged in, URL:', page.url());
      }
    }
    
    await page.screenshot({ path: 'tmp/01-original-xiq.png', fullPage: true });
    
    // Step 2: Look for "Add Devices" or "+" button
    console.log('3. Looking for Add Devices button...');
    
    // Original XIQ uses different button patterns
    const addDevicePatterns = [
      { selector: 'button', text: 'Add Devices' },
      { selector: 'button', text: 'ADD DEVICES' },
      { selector: 'button', text: '+' },
      { selector: 'button[title*="Add"]', text: null },
      { selector: '.add-device-button', text: null },
      { selector: 'button.primary', text: 'Add' }
    ];
    
    let addButton = null;
    for (const pattern of addDevicePatterns) {
      try {
        if (pattern.text) {
          const buttons = await page.$$(`${pattern.selector}:has-text("${pattern.text}")`);
          for (const btn of buttons) {
            if (await btn.isVisible()) {
              console.log(`   Found button: ${pattern.selector} with text "${pattern.text}"`);
              addButton = btn;
              break;
            }
          }
        } else {
          const btn = await page.$(pattern.selector);
          if (btn && await btn.isVisible()) {
            console.log(`   Found button: ${pattern.selector}`);
            addButton = btn;
            break;
          }
        }
        if (addButton) break;
      } catch (e) {
        // Continue
      }
    }
    
    if (addButton) {
      console.log('4. Clicking Add Devices button...');
      await addButton.click();
      await page.waitForTimeout(3000);
      await page.screenshot({ path: 'tmp/02-add-dialog.png', fullPage: true });
    } else {
      console.log('4. Add button not found, checking page content...');
      const bodyText = await page.textContent('body');
      console.log('   Page contains "Add":', bodyText.includes('Add'));
      console.log('   Page contains "Quick Add":', bodyText.includes('Quick Add'));
      
      // Try clicking on text "Add" or "Quick Add"
      try {
        await page.click('text="Quick Add"', { timeout: 5000 });
        console.log('   Clicked "Quick Add"');
        await page.waitForTimeout(2000);
      } catch (e) {
        console.log('   "Quick Add" not found');
      }
      
      await page.screenshot({ path: 'tmp/02-no-add-button.png', fullPage: true });
    }
    
    // Step 3: Look for serial number input in dialog
    console.log('5. Looking for serial number input in dialog...');
    await page.waitForTimeout(1000);
    
    const dialogInputs = await page.$$('input[type="text"], textarea');
    console.log(`   Found ${dialogInputs.length} text inputs`);
    
    let serialInputFound = false;
    for (let i = 0; i < dialogInputs.length; i++) {
      const input = dialogInputs[i];
      if (await input.isVisible()) {
        // Check placeholder or label
        const placeholder = await input.getAttribute('placeholder');
        const name = await input.getAttribute('name');
        console.log(`   Input ${i}: placeholder="${placeholder}", name="${name}"`);
        
        if (placeholder && (placeholder.toLowerCase().includes('serial') || placeholder.toLowerCase().includes('device'))) {
          console.log('6. Found serial input field, entering serials...');
          
          // Enter serials (comma or newline separated)
          await input.fill(SERIALS.join(','));
          await page.waitForTimeout(1000);
          
          await page.screenshot({ path: 'tmp/03-serials-entered.png', fullPage: true });
          serialInputFound = true;
          
          // Look for submit button
          console.log('7. Looking for submit/add button in dialog...');
          const dialogButtons = await page.$$('button:visible');
          
          for (const btn of dialogButtons) {
            const btnText = await btn.textContent();
            console.log(`   Button text: "${btnText.trim()}"`);
            
            if (btnText && (btnText.toLowerCase().includes('add') || btnText.toLowerCase().includes('onboard') || btnText.toLowerCase().includes('submit'))) {
              console.log('8. Clicking submit button...');
              await btn.click();
              await page.waitForTimeout(5000);
              
              console.log('9. After submit, checking for results...');
              await page.screenshot({ path: 'tmp/04-after-submit.png', fullPage: true });
              
              const resultText = await page.textContent('body');
              if (resultText.includes('success') || resultText.includes('Success') || resultText.includes('added')) {
                console.log('✅ Success message detected!');
              } else if (resultText.includes('error') || resultText.includes('Error') || resultText.includes('fail') || resultText.includes('invalid')) {
                console.log('⚠️  Error/failure detected');
                console.log('   Message preview:', resultText.substring(resultText.indexOf('error') - 50, resultText.indexOf('error') + 200));
              }
              
              break;
            }
          }
          
          break;
        }
      }
    }
    
    if (!serialInputFound) {
      console.log('   Serial input not found in dialog');
      console.log('   Page may not be showing the onboarding dialog');
      
      // Debug: get all visible text
      const visibleText = await page.textContent('body');
      console.log('\n   Visible page text preview:');
      console.log(visibleText.substring(0, 1000));
    }
    
    await page.waitForTimeout(2000);
    await page.screenshot({ path: 'tmp/05-final.png', fullPage: true });
    
    console.log('\n=== Onboarding attempt complete ===');
    console.log('Device serials attempted:', SERIALS);
    console.log('Check screenshots in tmp/ for visual confirmation');
    
  } catch (error) {
    console.error('Error:', error.message);
    await page.screenshot({ path: 'tmp/error.png', fullPage: true });
  }
  
  await browser.close();
})();
