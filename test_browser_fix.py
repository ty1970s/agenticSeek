#!/usr/bin/env python3
"""
Test script to verify the browser fixes work correctly.
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sources.browser import create_driver

def test_browser_creation():
    """Test creating a browser with headless mode."""
    print("Testing browser creation with headless mode...")
    
    driver = None
    try:
        # Test with headless mode (should be more stable)
        driver = create_driver(headless=True, stealth_mode=False)
        print("✅ Successfully created headless browser!")
        
        # Test basic navigation with timeout
        driver.set_page_load_timeout(30)
        driver.get("https://httpbin.org/get")
        print("✅ Successfully navigated to test page!")
        
        # Check if page loaded
        try:
            title = driver.title
            print(f"✅ Page title: '{title}' (empty is normal for JSON response)")
        except Exception as e:
            print(f"⚠️  Could not get title: {e}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False
    finally:
        if driver:
            try:
                driver.quit()
                print("✅ Browser closed successfully!")
            except Exception as e:
                print(f"⚠️  Warning during cleanup: {e}")

def test_stealth_browser():
    """Test creating a browser with stealth mode."""
    print("\nTesting browser creation with stealth mode...")
    
    driver = None
    try:
        # Test with stealth mode
        driver = create_driver(headless=True, stealth_mode=True)
        print("✅ Successfully created stealth browser!")
        
        # Test basic navigation with timeout
        driver.set_page_load_timeout(30)
        driver.get("https://httpbin.org/get")
        print("✅ Successfully navigated to test page!")
        
        return True
        
    except Exception as e:
        print(f"❌ Stealth mode error: {str(e)}")
        return False
    finally:
        if driver:
            try:
                driver.quit()
                print("✅ Stealth browser closed successfully!")
            except Exception as e:
                print(f"⚠️  Warning during stealth cleanup: {e}")

if __name__ == "__main__":
    print("Testing browser fixes...")
    print("=" * 50)
    
    success1 = test_browser_creation()
    success2 = test_stealth_browser()
    
    print("\n" + "=" * 50)
    if success1 and success2:
        print("✅ All tests passed! Browser fix successful.")
        sys.exit(0)
    else:
        print("❌ Some tests failed. Please check the error messages above.")
        sys.exit(1)
