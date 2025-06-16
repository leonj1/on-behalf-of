#!/usr/bin/env node

/**
 * Enhanced debug script for consent grant process
 * Focuses specifically on the GRANT button interaction
 */

const puppeteer = require('puppeteer');

async function debugConsentGrant() {
    console.log('🔍 Debugging Consent Grant Process');
    console.log('=' .repeat(50));
    
    let browser;
    
    try {
        browser = await puppeteer.launch({
            headless: false,  // Visual debugging
            args: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage'
            ],
            devtools: true  // Open DevTools for debugging
        });
        
        const page = await browser.newPage();
        await page.setViewport({ width: 1280, height: 720 });
        
        // Capture ALL network activity
        let networkLog = [];
        let responseLog = [];
        
        page.on('request', request => {
            networkLog.push({
                type: 'REQUEST',
                method: request.method(),
                url: request.url(),
                headers: request.headers(),
                postData: request.postData(),
                timestamp: new Date().toISOString()
            });
            console.log(`🔄 ${request.method()} ${request.url()}`);
        });
        
        page.on('response', response => {
            responseLog.push({
                type: 'RESPONSE',
                status: response.status(),
                url: response.url(),
                headers: response.headers(),
                timestamp: new Date().toISOString()
            });
            console.log(`📡 ${response.status()} ${response.url()}`);
            
            // Log response body for consent-related calls
            if (response.url().includes('consent') || response.url().includes('banking-api')) {
                response.text().then(text => {
                    console.log(`   Response body: ${text.substring(0, 200)}${text.length > 200 ? '...' : ''}`);
                }).catch(() => {});
            }
        });
        
        page.on('console', msg => {
            console.log(`🖥️  Console [${msg.type()}]: ${msg.text()}`);
        });
        
        // Intercept and log all errors
        page.on('pageerror', error => {
            console.log(`❌ Page Error: ${error.message}`);
        });
        
        page.on('requestfailed', request => {
            console.log(`🚫 Request Failed: ${request.method()} ${request.url()} - ${request.failure().errorText}`);
        });
        
        console.log('1. Logging in and navigating to banking consent...');
        
        // Go directly to a consent URL to simulate the flow
        // First, let's get a proper user token by logging in
        await page.goto('https://consent.joseserver.com', { waitUntil: 'networkidle0' });
        
        // Login if needed
        const content = await page.content();
        if (content.includes('Sign in')) {
            console.log('   Logging in...');
            const loginButton = await page.$('button');
            if (loginButton) {
                await loginButton.click();
                await page.waitForNavigation({ waitUntil: 'networkidle0' });
                
                await page.waitForSelector('#username', { timeout: 10000 });
                await page.type('#username', 'admin');
                await page.type('#password', 'admin');
                await page.keyboard.press('Enter');
                await page.waitForNavigation({ waitUntil: 'networkidle0' });
            }
        }
        
        console.log('2. Triggering withdrawal to get consent page...');
        
        // Click withdrawal button to trigger consent flow
        const clicked = await page.evaluate(() => {
            const buttons = Array.from(document.querySelectorAll('button'));
            const withdrawBtn = buttons.find(btn => {
                const text = btn.textContent || btn.innerText || '';
                return text.includes('Bank') || text.includes('💰') || text.includes('withdraw') || text.includes('Empty');
            });
            if (withdrawBtn) {
                withdrawBtn.click();
                return true;
            }
            return false;
        });
        
        if (!clicked) {
            throw new Error('Could not find withdrawal button');
        }
        
        // Wait for consent page to load
        console.log('3. Waiting for consent page...');
        await page.waitForFunction(
            () => window.location.href.includes('consent') || document.body.textContent.includes('Consent Request'),
            { timeout: 10000 }
        );
        
        const consentUrl = page.url();
        console.log(`   Consent page URL: ${consentUrl}`);
        
        // Take screenshot of consent page
        await page.screenshot({ path: '/tmp/consent-page-debug.png' });
        
        console.log('4. Analyzing consent page...');
        
        // Check if page has loaded properly
        const pageInfo = await page.evaluate(() => {
            return {
                title: document.title,
                url: window.location.href,
                hasGrantButton: !!document.querySelector('button:contains("GRANT"), button[onclick*="grant"], .grant-btn, #grant-btn'),
                allButtons: Array.from(document.querySelectorAll('button')).map(btn => ({
                    text: btn.textContent || btn.innerText,
                    id: btn.id,
                    className: btn.className,
                    onclick: btn.onclick ? btn.onclick.toString() : null
                })),
                variables: {
                    userToken: typeof userToken !== 'undefined' ? '***' + userToken.slice(-10) : 'undefined',
                    redirectUri: typeof redirectUri !== 'undefined' ? redirectUri : 'undefined',
                    state: typeof state !== 'undefined' ? state : 'undefined',
                    operations: typeof operations !== 'undefined' ? operations : 'undefined'
                }
            };
        });
        
        console.log('   Page analysis:', JSON.stringify(pageInfo, null, 2));
        
        console.log('5. Attempting to click GRANT button...');
        
        // Try multiple approaches to click the GRANT button
        let grantClicked = false;
        
        // Approach 1: Direct click on GRANT button text
        try {
            await page.waitForSelector('button', { timeout: 5000 });
            const grantButton = await page.evaluateHandle(() => {
                const buttons = Array.from(document.querySelectorAll('button'));
                return buttons.find(btn => {
                    const text = (btn.textContent || btn.innerText || '').trim().toLowerCase();
                    return text === 'grant' || text.includes('grant');
                });
            });
            
            if (grantButton.asElement()) {
                console.log('   Found GRANT button via text search');
                await grantButton.asElement().click();
                grantClicked = true;
            }
        } catch (e) {
            console.log(`   Text search approach failed: ${e.message}`);
        }
        
        // Approach 2: Call the JavaScript function directly
        if (!grantClicked) {
            try {
                console.log('   Trying to call grantConsent() function directly...');
                await page.evaluate(() => {
                    if (typeof grantConsent === 'function') {
                        grantConsent();
                        return true;
                    }
                    return false;
                });
                grantClicked = true;
            } catch (e) {
                console.log(`   Direct function call failed: ${e.message}`);
            }
        }
        
        // Approach 3: Simulate form submission
        if (!grantClicked) {
            try {
                console.log('   Trying form submission approach...');
                await page.evaluate(() => {
                    const forms = document.querySelectorAll('form');
                    for (const form of forms) {
                        const grantInput = form.querySelector('input[value="grant"], button[value="grant"]');
                        if (grantInput) {
                            grantInput.click();
                            return true;
                        }
                    }
                    return false;
                });
                grantClicked = true;
            } catch (e) {
                console.log(`   Form submission approach failed: ${e.message}`);
            }
        }
        
        if (grantClicked) {
            console.log('6. GRANT button clicked, waiting for response...');
            
            // Wait for either a redirect or an error
            await new Promise(resolve => setTimeout(resolve, 5000));
            
            const finalUrl = page.url();
            const finalContent = await page.evaluate(() => document.body.textContent);
            
            console.log(`   Final URL: ${finalUrl}`);
            console.log(`   Still on consent page: ${finalUrl.includes('consent')}`);
            
            await page.screenshot({ path: '/tmp/after-grant-click.png' });
            
            // Check if we got redirected back to the main app
            if (finalUrl.includes('consent-callback') || finalUrl.includes('consent.joseserver.com')) {
                console.log('   ✅ Successfully redirected after consent grant');
            } else if (finalUrl.includes('consent')) {
                console.log('   ❌ Still on consent page - grant may have failed');
            } else {
                console.log('   ⚠️  Unexpected final URL');
            }
        } else {
            console.log('   ❌ Could not click GRANT button');
        }
        
        console.log('\n7. Network activity summary:');
        
        const consentDecisionCalls = networkLog.filter(entry => 
            entry.url.includes('/consent/decision') && entry.type === 'REQUEST'
        );
        
        console.log(`   Consent decision API calls: ${consentDecisionCalls.length}`);
        consentDecisionCalls.forEach(call => {
            console.log(`     ${call.method} ${call.url}`);
            if (call.postData) {
                console.log(`     Body: ${call.postData}`);
            }
        });
        
        const consentDecisionResponses = responseLog.filter(entry => 
            entry.url.includes('/consent/decision') && entry.type === 'RESPONSE'
        );
        
        console.log(`   Consent decision responses: ${consentDecisionResponses.length}`);
        consentDecisionResponses.forEach(resp => {
            console.log(`     ${resp.status} ${resp.url}`);
        });
        
        console.log('\n📋 Debug complete. Check screenshots:');
        console.log('   /tmp/consent-page-debug.png');
        console.log('   /tmp/after-grant-click.png');
        
        // Keep browser open for manual inspection
        console.log('\n⏳ Browser staying open for manual inspection...');
        console.log('Press Ctrl+C when done');
        await new Promise(() => {}); // Keep open indefinitely
        
    } catch (error) {
        console.log(`❌ Debug error: ${error.message}`);
        console.log(error.stack);
    } finally {
        if (browser) {
            // Don't close automatically - let user inspect
            // await browser.close();
        }
    }
}

if (require.main === module) {
    debugConsentGrant();
}