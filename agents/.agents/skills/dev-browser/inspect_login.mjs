import { chromium } from 'playwright';

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ 
    viewport: { width: 1920, height: 1080 },
    ignoreHTTPSErrors: true
  });
  const page = await context.newPage();
  
  try {
    console.log('Loading login page...');
    await page.goto('https://brianna-vmr1.qa.xcloudiq.com/', { 
      waitUntil: 'networkidle',
      timeout: 60000 
    });
    
    await page.waitForTimeout(3000);
    await page.screenshot({ path: 'tmp/login-page.png', fullPage: true });
    
    console.log('URL:', page.url());
    
    // Get all input fields
    const inputs = await page.$$eval('input', inputs => 
      inputs.map(input => ({
        type: input.type,
        name: input.name,
        id: input.id,
        placeholder: input.placeholder,
        className: input.className
      }))
    );
    
    console.log('\nInput fields found:');
    console.log(JSON.stringify(inputs, null, 2));
    
    // Get all buttons
    const buttons = await page.$$eval('button', buttons => 
      buttons.map(btn => ({
        type: btn.type,
        text: btn.textContent.trim(),
        className: btn.className
      }))
    );
    
    console.log('\nButtons found:');
    console.log(JSON.stringify(buttons, null, 2));
    
  } catch (error) {
    console.error('Error:', error.message);
  }
  
  await browser.close();
})();
