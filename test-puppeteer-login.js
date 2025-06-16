#!/usr/bin/env node

/**
 * Puppeteer script to test login with hardcoded admin/admin credentials
 * Tests the complete browser-based authentication flow
 */

const puppeteer = require('puppeteer');

async function testKeycloakLogin() {
    console.log('🤖 Starting Puppeteer Login Test');
    console.log('=' .repeat(50));
    
    let browser;
    let success = false;
    
    try {
        // Launch browser
        console.log('1. Launching browser...');
        browser = await puppeteer.launch({
            headless: true,
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-accelerated-2d-canvas',
                '--no-first-run',
                '--no-zygote',
                '--disable-gpu'
            ]
        });
        
        const page = await browser.newPage();
        
        // Set viewport and user agent
        await page.setViewport({ width: 1280, height: 720 });
        await page.setUserAgent('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36');
        
        console.log('   ✅ Browser launched successfully');
        
        // Navigate to the application
        console.log('2. Navigating to frontend...');
        await page.goto('https://consent.joseserver.com', { 
            waitUntil: 'networkidle0',
            timeout: 30000 
        });
        console.log('   ✅ Frontend page loaded');
        
        // Take screenshot of initial page
        await page.screenshot({ path: '/tmp/01-initial-page.png' });
        
        // Wait for and click the login button
        console.log('3. Looking for login button...');
        
        // Wait a bit for the page to fully load
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        // Try to find login button with various selectors
        let loginButton = null;
        
        // Check for common login button patterns
        const selectors = [
            'button[onclick*="signIn"]',
            'button:contains("Sign in")',
            'button:contains("🔐")',
            'button[type="submit"]',
            'a[href*="signin"]',
            'button',
            '[role="button"]'
        ];
        
        for (const selector of selectors) {
            try {
                await page.waitForSelector(selector, { timeout: 2000 });
                loginButton = await page.$(selector);
                if (loginButton) {
                    const buttonText = await page.evaluate(el => el.textContent || el.value || el.getAttribute('aria-label'), loginButton);
                    console.log(`   Found button: "${buttonText}" with selector: ${selector}`);
                    break;
                }
            } catch (e) {
                // Continue to next selector
            }
        }
        
        if (!loginButton) {
            // Debug: log page content to understand what's there
            const pageText = await page.evaluate(() => document.body.textContent);
            console.log('   Page content preview:', pageText.substring(0, 500));
            
            const buttons = await page.$$eval('button, [role="button"], input[type="submit"]', elements => 
                elements.map(el => ({
                    tag: el.tagName,
                    text: el.textContent || el.value,
                    onclick: el.onclick ? 'has onclick' : 'no onclick',
                    type: el.type
                }))
            );
            console.log('   Available buttons:', buttons);
            
            throw new Error('Could not find login button');
        }
        
        console.log('   ✅ Login button found');
        await page.screenshot({ path: '/tmp/02-before-login-click.png' });
        
        // Click login button
        console.log('4. Clicking login button...');
        await loginButton.click();
        
        // Wait for redirect to Keycloak
        console.log('5. Waiting for Keycloak redirect...');
        await page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 15000 });
        
        const currentUrl = page.url();
        console.log(`   Current URL: ${currentUrl}`);
        
        if (!currentUrl.includes('keycloak-api.joseserver.com')) {
            throw new Error(`Expected Keycloak URL, got: ${currentUrl}`);
        }
        
        console.log('   ✅ Successfully redirected to Keycloak');
        await page.screenshot({ path: '/tmp/03-keycloak-page.png' });
        
        // Fill in login credentials
        console.log('6. Filling in credentials...');
        
        // Wait for username field
        await page.waitForSelector('#username, input[name="username"], input[type="text"]', { timeout: 10000 });
        await page.type('#username, input[name="username"], input[type="text"]', 'admin');
        
        // Wait for password field  
        await page.waitForSelector('#password, input[name="password"], input[type="password"]', { timeout: 5000 });
        await page.type('#password, input[name="password"], input[type="password"]', 'admin');
        
        console.log('   ✅ Credentials entered');
        await page.screenshot({ path: '/tmp/04-credentials-entered.png' });
        
        // Submit the form
        console.log('7. Submitting login form...');
        const submitButton = await page.$('#kc-login, input[type="submit"], button[type="submit"]');
        if (submitButton) {
            await submitButton.click();
        } else {
            // Fallback: press Enter
            await page.keyboard.press('Enter');
        }
        
        // Wait for authentication to complete
        console.log('8. Waiting for authentication...');
        await page.waitForNavigation({ 
            waitUntil: 'networkidle0', 
            timeout: 20000 
        });
        
        const finalUrl = page.url();
        console.log(`   Final URL: ${finalUrl}`);
        await page.screenshot({ path: '/tmp/05-after-login.png' });
        
        // Check if we're back at the consent app and logged in
        if (finalUrl.includes('consent.joseserver.com')) {
            console.log('9. Checking login status...');
            
            // Look for indicators of successful login
            const pageContent = await page.content();
            
            if (pageContent.includes('Welcome') || 
                pageContent.includes('admin') || 
                pageContent.includes('Sign out') ||
                pageContent.includes('Manage Consents')) {
                console.log('   ✅ Login appears successful!');
                success = true;
            } else if (pageContent.includes('Sign in') || 
                      pageContent.includes('different account') ||
                      pageContent.includes('error')) {
                console.log('   ❌ Login appears to have failed');
                console.log('   Page content includes signin/error indicators');
            } else {
                console.log('   ❓ Login status unclear');
                console.log('   Taking final screenshot for manual review');
            }
        } else {
            console.log(`   ❓ Unexpected final URL: ${finalUrl}`);
        }
        
        await page.screenshot({ path: '/tmp/06-final-state.png' });
        
    } catch (error) {
        console.log(`❌ Error during login test: ${error.message}`);
        
        if (browser) {
            const pages = await browser.pages();
            if (pages.length > 0) {
                await pages[0].screenshot({ path: '/tmp/error-state.png' });
                console.log('   Screenshot saved to /tmp/error-state.png');
            }
        }
    } finally {
        if (browser) {
            await browser.close();
        }
    }
    
    console.log('\n' + '='.repeat(50));
    console.log('PUPPETEER TEST SUMMARY');
    console.log('='.repeat(50));
    
    if (success) {
        console.log('🎉 LOGIN TEST PASSED');
        console.log('   The admin/admin credentials work correctly');
        console.log('   Users can successfully log in via the browser');
    } else {
        console.log('❌ LOGIN TEST FAILED OR UNCLEAR');
        console.log('   Please check screenshots in /tmp/ for details');
        console.log('   Screenshots: 01-initial-page.png through 06-final-state.png');
    }
    
    console.log('\nCredentials tested: admin / admin');
    console.log('Application URL: https://consent.joseserver.com');
    console.log('Keycloak URL: https://keycloak-api.joseserver.com');
    
    return success;
}

// Check if puppeteer is available
async function checkPuppeteerAvailability() {
    try {
        require('puppeteer');
        return true;
    } catch (error) {
        console.log('❌ Puppeteer not found. Installing...');
        console.log('   Run: npm install puppeteer');
        return false;
    }
}

async function main() {
    const available = await checkPuppeteerAvailability();
    if (!available) {
        console.log('Please install Puppeteer first:');
        console.log('  npm install puppeteer');
        process.exit(1);
    }
    
    const success = await testKeycloakLogin();
    process.exit(success ? 0 : 1);
}

if (require.main === module) {
    main();
}