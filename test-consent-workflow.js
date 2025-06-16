#!/usr/bin/env node

/**
 * Test script to debug the complete consent workflow
 * Tests: Login -> Click Withdraw -> Grant Consent -> Verify Withdrawal Success
 */

const puppeteer = require('puppeteer');

async function testConsentWorkflow() {
    console.log('🔐 Testing Complete Consent Workflow');
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
        await page.setViewport({ width: 1280, height: 720 });
        
        // Enable console and network monitoring
        let apiResponses = [];
        let consoleMessages = [];
        let corsErrors = [];
        
        page.on('response', response => {
            if (response.url().includes('service-a-api.joseserver.com') || 
                response.url().includes('consent-api.joseserver.com') ||
                response.url().includes('keycloak-api.joseserver.com')) {
                apiResponses.push({
                    url: response.url(),
                    status: response.status(),
                    timestamp: new Date().toISOString()
                });
                console.log(`   📡 API: ${response.status()} ${response.url()}`);
            }
        });
        
        page.on('console', msg => {
            consoleMessages.push(`${msg.type()}: ${msg.text()}`);
            if (msg.type() === 'error') {
                console.log(`   ❌ Console Error: ${msg.text()}`);
                if (msg.text().includes('CORS')) {
                    corsErrors.push(msg.text());
                }
            }
        });
        
        console.log('2. Navigating to frontend and logging in...');
        await page.goto('https://consent.joseserver.com', { 
            waitUntil: 'networkidle0',
            timeout: 30000 
        });
        
        // Check if already logged in
        const content = await page.content();
        if (content.includes('Sign in')) {
            console.log('   Logging in with admin/admin...');
            
            const loginButton = await page.$('button[type="submit"], button');
            if (loginButton) {
                await loginButton.click();
                await page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 15000 });
                
                // Fill credentials
                await page.waitForSelector('#username, input[name="username"], input[type="text"]', { timeout: 10000 });
                await page.type('#username, input[name="username"], input[type="text"]', 'admin');
                await page.type('#password, input[name="password"], input[type="password"]', 'admin');
                
                const submitButton = await page.$('#kc-login, input[type="submit"], button[type="submit"]');
                if (submitButton) {
                    await submitButton.click();
                } else {
                    await page.keyboard.press('Enter');
                }
                
                await page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 20000 });
            }
        }
        
        console.log('3. Looking for withdrawal/banking button...');
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        // Take screenshot of main page
        await page.screenshot({ path: '/tmp/01-main-page.png' });
        
        console.log('4. Clicking withdrawal button...');
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
        
        // Wait for potential redirect to consent page
        console.log('5. Waiting for response (consent redirect or direct result)...');
        await new Promise(resolve => setTimeout(resolve, 3000));
        
        // Check current URL and page content
        const currentUrl = page.url();
        const pageContent = await page.evaluate(() => document.body.textContent);
        
        console.log(`   Current URL: ${currentUrl}`);
        console.log(`   Page content preview: ${pageContent.substring(0, 200)}...`);
        
        // Take screenshot after withdrawal click
        await page.screenshot({ path: '/tmp/02-after-withdrawal-click.png' });
        
        if (currentUrl.includes('consent') || pageContent.includes('consent') || pageContent.includes('grant') || pageContent.includes('allow')) {
            console.log('6. Consent page detected - granting consent...');
            
            // Look for consent grant buttons
            const consentGranted = await page.evaluate(() => {
                // Look for various consent buttons
                const buttons = Array.from(document.querySelectorAll('button, input[type="submit"], a'));
                const grantBtn = buttons.find(btn => {
                    const text = (btn.textContent || btn.innerText || btn.value || '').toLowerCase();
                    return text.includes('allow') || text.includes('grant') || text.includes('approve') || text.includes('yes') || text.includes('accept');
                });
                
                if (grantBtn) {
                    console.log('Found consent grant button:', grantBtn.textContent || grantBtn.value);
                    grantBtn.click();
                    return true;
                }
                
                // Also check for forms with hidden inputs
                const forms = Array.from(document.querySelectorAll('form'));
                for (const form of forms) {
                    const allowInput = form.querySelector('input[name="allow"], input[value="allow"], input[value="yes"]');
                    if (allowInput) {
                        console.log('Found consent form with allow input');
                        allowInput.click();
                        form.submit();
                        return true;
                    }
                }
                
                return false;
            });
            
            if (!consentGranted) {
                console.log('   ❌ Could not find consent grant button');
                
                // Debug: show available buttons
                const availableButtons = await page.$$eval('button, input[type="submit"], a', elements => 
                    elements.map(el => ({
                        tag: el.tagName,
                        text: el.textContent || el.innerText || el.value || '',
                        type: el.type || 'N/A'
                    })).filter(item => item.text.trim())
                );
                console.log('   Available interactive elements:', availableButtons);
            } else {
                console.log('   ✅ Consent granted, waiting for redirect...');
                
                // Wait for redirect back to main app
                await page.waitForNavigation({ waitUntil: 'networkidle0', timeout: 15000 });
                await new Promise(resolve => setTimeout(resolve, 2000));
                
                // Take screenshot after consent grant
                await page.screenshot({ path: '/tmp/03-after-consent-grant.png' });
                
                console.log('7. Testing withdrawal again after consent...');
                
                // Try withdrawal again
                const secondWithdrawal = await page.evaluate(() => {
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
                
                if (secondWithdrawal) {
                    console.log('   Second withdrawal attempt initiated...');
                    await new Promise(resolve => setTimeout(resolve, 3000));
                    
                    // Take final screenshot
                    await page.screenshot({ path: '/tmp/04-final-result.png' });
                } else {
                    console.log('   ❌ Could not find withdrawal button for second attempt');
                }
            }
        } else {
            console.log('6. No consent page detected - checking for direct result...');
        }
        
        // Analyze the results
        console.log('\n8. Analyzing API responses...');
        
        const withdrawalRequests = apiResponses.filter(resp => 
            resp.url.includes('/withdraw') || resp.url.includes('service-a-api')
        );
        
        const consentRequests = apiResponses.filter(resp => 
            resp.url.includes('consent') || resp.url.includes('consent-api')
        );
        
        console.log(`   Withdrawal API calls: ${withdrawalRequests.length}`);
        withdrawalRequests.forEach(req => {
            console.log(`     ${req.status} ${req.url} at ${req.timestamp}`);
        });
        
        console.log(`   Consent API calls: ${consentRequests.length}`);
        consentRequests.forEach(req => {
            console.log(`     ${req.status} ${req.url} at ${req.timestamp}`);
        });
        
        // Check for success indicators
        const hasSuccessResponse = withdrawalRequests.some(req => req.status === 200);
        const hasForbiddenResponse = withdrawalRequests.some(req => req.status === 403);
        
        if (hasSuccessResponse) {
            console.log('   ✅ Found successful withdrawal response (200)');
            success = true;
        } else if (hasForbiddenResponse) {
            console.log('   ❌ Withdrawal still forbidden (403) after consent process');
            success = false;
        } else {
            console.log('   ⚠️  No clear withdrawal response detected');
            success = false;
        }
        
    } catch (error) {
        console.log(`❌ Error during consent workflow test: ${error.message}`);
        if (browser) {
            const pages = await browser.pages();
            if (pages.length > 0) {
                await pages[0].screenshot({ path: '/tmp/error-consent-workflow.png' });
            }
        }
    } finally {
        if (browser) {
            await browser.close();
        }
    }
    
    console.log('\n' + '='.repeat(50));
    console.log('CONSENT WORKFLOW TEST SUMMARY');
    console.log('='.repeat(50));
    
    if (success) {
        console.log('✅ CONSENT WORKFLOW TEST PASSED');
        console.log('   Withdrawal succeeded after consent grant');
    } else {
        console.log('❌ CONSENT WORKFLOW TEST FAILED');
        console.log('   Withdrawal denied even after consent process');
        console.log('\n🔍 TROUBLESHOOTING STEPS:');
        console.log('   1. Check consent store API for stored consent records');
        console.log('   2. Verify service-a is checking consent correctly');
        console.log('   3. Check token exchange and user ID consistency');
        console.log('   4. Verify consent grant parameters match check parameters');
    }
    
    console.log('\n📸 Screenshots saved:');
    console.log('   /tmp/01-main-page.png - Main page after login');
    console.log('   /tmp/02-after-withdrawal-click.png - After clicking withdrawal');
    console.log('   /tmp/03-after-consent-grant.png - After granting consent');
    console.log('   /tmp/04-final-result.png - Final withdrawal attempt');
    
    return success;
}

if (require.main === module) {
    testConsentWorkflow().then(success => {
        process.exit(success ? 0 : 1);
    });
}