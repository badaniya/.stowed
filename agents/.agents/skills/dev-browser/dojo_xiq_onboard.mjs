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
    // According to nvo-device-onboarding skill, Original XIQ (Dojo) is at:
    // https://<cluster>.qa.xcloudiq.com/sso?sso=true
    
    console.log('1. Navigating to Original XIQ (Dojo) with sso=true...');
    await page.goto('https://brianna-vmr1.qa.xcloudiq.com/sso?sso=true', { 
      waitUntil: 'domcontentloaded',
      timeout: 60000 
    });
    
    await page.waitForTimeout(3000);
    
    // Login
    console.log('2. Logging in...');
    const usernameInput = await page.$('input[type="text"].en-c-text-field__input');
    const passwordInput = await page.$('input[type="password"].en-c-text-field__input');
    
    if (usernameInput && passwordInput) {
      await usernameInput.fill(EMAIL);
      await passwordInput.fill(PASSWORD);
      const submitBtn = await page.$('button[type="submit"].en-c-button--full-width');
      await submitBtn.click();
      await page.waitForTimeout(10000);
    }
    
    console.log('3. After login, URL:', page.url());
    await page.screenshot({ path: 'tmp/01-after-sso-login.png', fullPage: true });
    
    const bodyText = await page.textContent('body');
    
    // Check if we're on Dojo XIQ (look for specific Dojo/Dijit patterns)
    const isDojoXIQ = bodyText.includes('dijit') || 
                      bodyText.includes('Manage') && bodyText.includes('Monitor') && bodyText.includes('Configure');
    
    console.log('   Is Dojo XIQ:', isDojoXIQ);
    console.log('   Page contains "Manage":', bodyText.includes('Manage'));
    console.log('   Page contains "Monitor":', bodyText.includes('Monitor'));
    console.log('   Page contains "Configure":', bodyText.includes('Configure'));
    
    // Try to navigate directly to devices page URL
    console.log('4. Trying direct navigation to devices page...');
    
    const devicesUrls = [
      'https://brianna-vmr1.qa.xcloudiq.com/#/manage/devices',
      'https://brianna-vmr1.qa.xcloudiq.com/devices',
      'https://brianna-vmr1.qa.xcloudiq.com/#/devices'
    ];
    
    for (const url of devicesUrls) {
      console.log(`   Trying: ${url}`);
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
      await page.waitForTimeout(5000);
      
      const currentUrl = page.url();
      const pageContent = await page.textContent('body');
      
      console.log(`   Result URL: ${currentUrl}`);
      await page.screenshot({ path: `tmp/02-attempt-${devicesUrls.indexOf(url)}.png`, fullPage: true });
      
      // Check if we're on a devices page
      if (pageContent.includes('Serial Number') || 
          pageContent.includes('Device') && pageContent.includes('Add') ||
          pageContent.includes('Quick Add')) {
        console.log('   ✓ Found devices page!');
        break;
      }
    }
    
    // Look for the page structure
    console.log('5. Analyzing page structure...');
    const finalUrl = page.url();
    const finalContent = await page.textContent('body');
    
    await page.screenshot({ path: 'tmp/03-current-page.png', fullPage: true });
    
    // Check if there's a "Devices" link/tab anywhere
    if (finalContent.includes('Device')) {
      console.log('   Page contains "Device" text');
      
      // Try clicking any "Devices" link
      try {
        await page.click('text="Devices"', { timeout: 5000 });
        await page.waitForTimeout(3000);
        console.log('   Clicked "Devices" link');
        console.log('   New URL:', page.url());
        await page.screenshot({ path: 'tmp/04-after-devices-click.png', fullPage: true });
      } catch (e) {
        console.log('   Could not click "Devices" link');
      }
    }
    
    // Now look for Add/Onboard functionality
    console.log('6. Looking for device onboarding UI...');
    
    const currentContent = await page.textContent('body');
    
    // Look for Quick Add Devices dialog/button (Dojo pattern)
    // In Original XIQ, there's usually a button or link with "Quick Add Devices"
    const quickAddPatterns = [
      'Quick Add Devices',
      'Add Devices',
      'quick add devices',
      'add devices'
    ];
    
    for (const pattern of quickAddPatterns) {
      if (currentContent.toLowerCase().includes(pattern.toLowerCase())) {
        console.log(`   Found "${pattern}" in page content`);
        
        try {
          // Try to click it
          await page.click(`text="${pattern}"`, { timeout: 5000 });
          await page.waitForTimeout(3000);
          console.log(`   Clicked "${pattern}"`);
          await page.screenshot({ path: 'tmp/05-quick-add-dialog.png', fullPage: true });
          
          // Now look for the serial input
          console.log('7. Looking for serial number input...');
          
          // Get all textareas and inputs
          const allInputs = await page.$$('textarea, input[type="text"]');
          console.log(`   Found ${allInputs.length} text inputs/textareas`);
          
          for (let i = 0; i < allInputs.length; i++) {
            const input = allInputs[i];
            if (await input.isVisible()) {
              const name = await input.getAttribute('name');
              const id = await input.getAttribute('id');
              const placeholder = await input.getAttribute('placeholder');
              
              console.log(`   Input ${i}: name="${name}", id="${id}", placeholder="${placeholder}"`);
              
              // If this looks like a serial number field or is the first visible textarea
              if (i === 0 || (name && name.includes('serial')) || (placeholder && placeholder.includes('serial'))) {
                console.log('8. Entering serial numbers...');
                
                // Enter serials (one per line for Original XIQ)
                await input.fill(SERIALS.join('\n'));
                await page.waitForTimeout(1500);
                
                console.log('   Entered serials:', SERIALS);
                await page.screenshot({ path: 'tmp/06-serials-entered.png', fullPage: true });
                
                // Look for Add button
                console.log('9. Looking for Add button...');
                const buttons = await page.$$('button, .dijitButton');
                
                for (const btn of buttons) {
                  if (await btn.isVisible()) {
                    const btnText = await btn.textContent();
                    
                    if (btnText && btnText.toLowerCase().trim() === 'add') {
                      console.log('   Clicking Add button...');
                      await btn.click();
                      await page.waitForTimeout(10000); // Wait for processing
                      
                      console.log('10. Checking results...');
                      await page.screenshot({ path: 'tmp/07-after-submit.png', fullPage: true });
                      
                      const resultText = await page.textContent('body');
                      
                      // Check for success or error
                      if (resultText.toLowerCase().includes('success') || 
                          resultText.toLowerCase().includes('added')) {
                        console.log('\n✅ SUCCESS: Devices successfully onboarded!');
                        console.log('   SIM serial numbers were ACCEPTED');
                      } else if (resultText.toLowerCase().includes('error') || 
                                 resultText.toLowerCase().includes('invalid') ||
                                 resultText.toLowerCase().includes('not found')) {
                        console.log('\n⚠️  ERROR: Devices NOT accepted');
                        console.log('   SIM serial numbers were REJECTED or INVALID');
                        
                        // Extract error details
                        const errorPatterns = ['error', 'invalid', 'not found', 'fail'];
                        for (const pattern of errorPatterns) {
                          const idx = resultText.toLowerCase().indexOf(pattern);
                          if (idx >= 0) {
                            console.log('   Error context:', resultText.substring(Math.max(0, idx - 50), idx + 150));
                            break;
                          }
                        }
                      } else {
                        console.log('\nℹ️  Result unclear - check screenshots');
                      }
                      
                      await page.waitForTimeout(3000);
                      await page.screenshot({ path: 'tmp/08-final.png', fullPage: true });
                      
                      break; // Exit button loop
                    }
                  }
                }
                
                break; // Exit input loop
              }
            }
          }
          
          break; // Exit pattern loop if we clicked Quick Add
        } catch (e) {
          console.log(`   Failed to interact with "${pattern}": ${e.message}`);
        }
      }
    }
    
    console.log('\n=== ONBOARDING ATTEMPT COMPLETE ===');
    console.log('Device serials tested:', SERIALS);
    console.log('Screenshots saved in tmp/ directory');
    console.log('\nIf serials were entered, check tmp/07-after-submit.png and tmp/08-final.png for results');
    
  } catch (error) {
    console.error('\nError:', error.message);
    await page.screenshot({ path: 'tmp/error.png', fullPage: true });
  }
  
  await browser.close();
})();
