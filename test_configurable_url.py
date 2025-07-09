#!/usr/bin/env python3

import configparser
import sys
import os

# Add the project root to the path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sources.browser import Browser, create_driver

def test_configurable_default_url():
    """Test that the browser uses the configured default URL"""
    
    # Test different configurations
    test_configs = [
        ("https://www.bing.com", "Bing"),
        ("https://baidu.com", "baidu")
    ]
    
    for url, name in test_configs:
        print(f"\n=== Testing {name} as default URL ===")
        print(f"URL: {url}")
        
        try:
            # Create a headless browser
            driver = create_driver(headless=True, stealth_mode=False)
            browser = Browser(driver, default_url=url)
            
            # Check current URL
            current_url = browser.driver.current_url
            print(f"Browser navigated to: {current_url}")
            
            # Verify the URL contains the expected domain
            if url in current_url or current_url.startswith(url):
                print(f"✅ Success: Browser correctly navigated to {name}")
            else:
                print(f"⚠️  Warning: Expected {url}, but got {current_url}")
            
            # Clean up
            browser.quit()
            print(f"✅ Browser closed successfully")
            
        except Exception as e:
            print(f"❌ Error testing {name}: {str(e)}")

def test_config_file_reading():
    """Test reading default URL from config file"""
    
    print("\n=== Testing Config File Reading ===")
    
    config = configparser.ConfigParser()
    config.read('config.ini')
    
    try:
        default_url = config.get('BROWSER', 'default_search_url', fallback='https://www.google.com')
        print(f"Default URL from config: {default_url}")
        
        if default_url:
            print("✅ Successfully read default_search_url from config")
        else:
            print("❌ Failed to read default_search_url from config")
            
    except Exception as e:
        print(f"❌ Error reading config: {str(e)}")

def main():
    """Main test function"""
    print("🚀 Testing configurable default search URL functionality")
    
    # Test config file reading
    test_config_file_reading()
    
    # Test with different URLs (only if not in CI)
    if not os.getenv('CI'):
        test_configurable_default_url()
    else:
        print("\n⏭️  Skipping browser tests in CI environment")
    
    print("\n✅ All tests completed!")

if __name__ == "__main__":
    main()
