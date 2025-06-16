#!/usr/bin/env node

/**
 * Test script to verify banking service CORS is working
 * Tests the complete flow: login + click banking service button
 */

const puppeteer = require('puppeteer');

async function testBankingCORS() {
    console.log('🏦 Testing Banking Service CORS');
    console.log('=' .repeat(40));
    
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
        
        console.log('2. Navigating and logging in...');
        await page.goto('https://consent.joseserver.com', { 
            waitUntil: 'networkidle0',
            timeout: 30000 
        });
        
        // Check if already logged in
        const content = await page.content();
        if (content.includes('Sign in')) {
            // Need to log in
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
        
        console.log('3. Looking for banking service button...');
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        // Look for the banking service button  
        const bankingButton = await page.evaluate(() => {
            const buttons = Array.from(document.querySelectorAll('button'));
            const btn = buttons.find(btn => {
                const text = btn.textContent || btn.innerText || '';
                return text.includes('Bank') || text.includes('💰') || text.includes('withdraw') || text.includes('Empty');
            });
            return btn ? true : false;  // Return boolean since we can't return DOM elements
        });
        
        if (!bankingButton) {
            console.log('   Could not find banking button, checking page content...');
            const pageText = await page.evaluate(() => document.body.textContent);
            console.log('   Page content preview:', pageText.substring(0, 300));
            
            // Try to find any button that might be the banking service
            const allButtons = await page.$$eval('button', buttons => 
                buttons.map(btn => btn.textContent || btn.innerText).filter(text => text.trim())
            );
            console.log('   Available buttons:', allButtons);
            
            throw new Error('Could not find banking service button');
        }
        
        console.log('   Found banking service button');
        
        // Listen for network requests to catch CORS errors
        let corsError = false;
        let networkError = null;
        
        page.on('response', response => {
            if (response.url().includes('service-a-api.joseserver.com')) {
                console.log(`   API Response: ${response.status()} ${response.url()}`);
            }
        });
        
        page.on('console', msg => {
            if (msg.type() === 'error' && msg.text().includes('CORS')) {
                corsError = true;
                networkError = msg.text();
                console.log(`   ❌ CORS Error detected: ${msg.text()}`);
            }
        });
        
        console.log('4. Clicking banking service button...');
        await page.evaluate(() => {
            const buttons = Array.from(document.querySelectorAll('button'));
            const bankingBtn = buttons.find(btn => {
                const text = btn.textContent || btn.innerText || '';
                return text.includes('Bank') || text.includes('💰') || text.includes('withdraw') || text.includes('Empty');
            });
            if (bankingBtn) bankingBtn.click();
        });
        
        // Wait a bit for the request to complete
        await new Promise(resolve => setTimeout(resolve, 3000));
        
        if (corsError) {
            console.log('   ❌ CORS error detected in browser console');
            success = false;
        } else {
            console.log('   ✅ No CORS errors detected');
            success = true;
        }
        
        await page.screenshot({ path: '/tmp/banking-test.png' });
        
    } catch (error) {
        console.log(`❌ Error during banking test: ${error.message}`);
        if (browser) {
            const pages = await browser.pages();
            if (pages.length > 0) {
                await pages[0].screenshot({ path: '/tmp/banking-error.png' });
            }
        }
    } finally {
        if (browser) {
            await browser.close();
        }
    }
    
    console.log('\n' + '='.repeat(40));
    console.log('BANKING CORS TEST SUMMARY');
    console.log('='.repeat(40));
    
    if (success) {
        console.log('✅ BANKING CORS TEST PASSED');
        console.log('   Banking service requests work without CORS errors');
    } else {
        console.log('❌ BANKING CORS TEST FAILED');
        console.log('   CORS errors detected or other issues occurred');
    }
    
    return success;
}

if (require.main === module) {
    testBankingCORS().then(success => {
        process.exit(success ? 0 : 1);
    });
}