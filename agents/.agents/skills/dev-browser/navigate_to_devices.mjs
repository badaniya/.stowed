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
    // Login
    console.log('1. Logging in...');
    await page.goto('https://brianna-vmr1.qa.xcloudiq.com/', {  waitUntil: 'networkidle', timeout: 60000 });
    await page.waitForTimeout(3000);
    const usernameInput = await page.$('input[type="text"].en-c-text-field__input');
    const passwordInput = await page.$('input[type="password"].en-c-text-field__input');
    await usernameInput.fill(EMAIL);
    await passwordInput.fill(PASSWORD);
    const submitBtn = await page.$('button[type="submit"].en-c-button--full-width');
    await submitBtn.click();
    await page.waitForTimeout(10000);
    console.log('   Logged in:', page.url());
    
    // Click on Network Devices menu
    console.log('2. Clicking on "Network Devices" menu item...');
    try {
      // Use getByText which is more reliable for text matching
      await page.getByText('Network Devices', { exact: true }).click({ timeout: 10000, force: true });
      await page.waitForTimeout(5000);
      console.log('   After click, URL:', page.url());
      await page.screenshot({ path: 'tmp/01-devices-page.png', fullPage: true });
    } catch (e) {
      console.log('   Direct click failed, trying alternative...');
      // Try clicking any element containing "Network Devices"
      await page.click('text="Network Devices"', { force: true });
      await page.waitForTimeout(5000);
      console.log('   After alternative click, URL:', page.url());
      await page.screenshot({ path: 'tmp/01-devices-page-alt.png', fullPage: true });
    }
    
    // Look for onboarding/add button
    console.log('3. Looking for onboarding button on devices page...');
    
    // Wait for page to load
    await page.waitForTimeout(3000);
    
    // Look for various button patterns
    const buttonText = await page.textContent('body');
    console.log('   Page contains "Onboard":', buttonText.includes('Onboard'));
    console.log('   Page contains "Add Device":', buttonText.includes('Add Device'));
    console.log('   Page contains "Quick Add":', buttonText.includes('Quick Add'));
    
    // Try finding and clicking onboard button
    const onboardButtonSelectors = [
      'button:has-text("Onboard")',
      'button:has-text("Add Device")',
      'button:has-text("Quick Add")',
      'button:has-text("Add")',
      'a:has-text("Onboard")',
      '[data-automation-id*="onboard" i]',
      '[data-automation-id*="add" i]'
    ];
    
    let clickedOnboard = false;
    for (const selector of onboardButtonSelectors) {
      try {
        const btn = await page.$(selector);
        if (btn) {
          const isVisible = await btn.isVisible();
          console.log(`   Found "${selector}", visible: ${isVisible}`);
          if (isVisible) {
            await btn.click();
            await page.waitForTimeout(3000);
            console.log('   Clicked onboard button');
            clickedOnboard = true;
            break;
          }
        }
      } catch (e) {
        // Continue
      }
    }
    
    await page.screenshot({ path: 'tmp/02-after-onboard-click.png', fullPage: true });
    
    if (clickedOnboard) {
      // Look for serial input field in dialog
      console.log('4. Looking for serial input in onboarding dialog...');
      await page.waitForTimeout(2000);
      
      // Find input fields
      const inputs = await page.$$('input[type="text"]:visible, textarea:visible');
      console.log(`   Found ${inputs.length} visible inputs`);
      
      for (const input of inputs) {
        const placeholder = await input.getAttribute('placeholder');
        const label = await input.getAttribute('aria-label');
        console.log(`   Input: placeholder="${placeholder}", label="${label}"`);
        
        // Try entering serials in the first visible text input
        if (placeholder || label) {
          console.log('5. Entering serial numbers...');
          await input.fill(SERIALS.join(','));
          await page.waitForTimeout(1500);
          await page.screenshot({ path: 'tmp/03-serials-entered.png', fullPage: true });
          
          // Look for and click Add/Submit button
          console.log('6. Looking for submit button...');
          const submitButtons = await page.$$('button:visible');
          for (const btn of submitButtons) {
            const text = (await btn.textContent()).trim().toLowerCase();
            if (text.includes('add') || text.includes('onboard') || text.includes('submit')) {
              console.log(`   Clicking button: "${text}"`);
              await btn.click();
              await page.waitForTimeout(7000);
              await page.screenshot({ path: 'tmp/04-after-submit.png', fullPage: true });
              
              // Check for success/error
              const resultText = await page.textContent('body');
              console.log('\n7. Checking results...');
              
              if (resultText.toLowerCase().includes('success') || resultText.toLowerCase().includes('added')) {
                console.log('✅ SUCCESS: Devices appear to be onboarded!');
              } else if (resultText.toLowerCase().includes('error') || resultText.toLowerCase().includes('invalid') || resultText.toLowerCase().includes('not found')) {
                console.log('⚠️  ERROR: Onboarding may have failed');
                // Try to extract error message
                const lines = resultText.split('\n');
                for (const line of lines) {
                  if (line.toLowerCase().includes('error') || line.toLowerCase().includes('invalid')) {
                    console.log('   Error message:', line.trim());
                  }
                }
              } else {
                console.log('ℹ️  Result unclear, check screenshots');
              }
              
              break;
            }
          }
          
          break;
        }
      }
    } else {
      console.log('4. No onboard button found');
      console.log('   Current page may not have onboarding functionality');
    }
    
    await page.waitForTimeout(2000);
    await page.screenshot({ path: 'tmp/05-final-state.png', fullPage: true });
    
    console.log('\n=== Process Complete ===');
    console.log('Attempted to onboard serials:', SERIALS);
    console.log('Screenshots saved in tmp/ directory');
    
  } catch (error) {
    console.error('Error:', error.message);
    console.error(error.stack);
    await page.screenshot({ path: 'tmp/error.png', fullPage: true });
  }
  
  await browser.close();
})();
