#!/usr/bin/env python3

import time
import asyncio
import requests
import sys
import os
import logging
import subprocess
import signal
import multiprocessing
from threading import Thread

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class APITester:
    def __init__(self):
        self.api_process = None
        self.base_url = "http://localhost:7777"
        
    def start_api_server(self):
        """Start the API server in a subprocess"""
        try:
            logger.info("Starting API server...")
            self.api_process = subprocess.Popen(
                [sys.executable, "api.py"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            # Give the server time to start
            time.sleep(10)
            
            # Check if process is still running
            if self.api_process.poll() is not None:
                stdout, stderr = self.api_process.communicate()
                logger.error(f"API server failed to start. Stdout: {stdout}, Stderr: {stderr}")
                return False
                
            logger.info("API server started successfully")
            return True
            
        except Exception as e:
            logger.error(f"Error starting API server: {e}")
            return False
    
    def stop_api_server(self):
        """Stop the API server"""
        if self.api_process:
            logger.info("Stopping API server...")
            self.api_process.terminate()
            try:
                self.api_process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.api_process.kill()
                self.api_process.wait()
            logger.info("API server stopped")
    
    def test_health_check(self):
        """Test the health endpoint"""
        try:
            logger.info("Testing health check endpoint...")
            response = requests.get(f"{self.base_url}/health", timeout=30)
            
            if response.status_code == 200:
                logger.info("✅ Health check passed")
                return True
            else:
                logger.error(f"❌ Health check failed: {response.status_code}")
                return False
                
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ Health check request failed: {e}")
            return False
    
    def test_is_active(self):
        """Test the is_active endpoint"""
        try:
            logger.info("Testing is_active endpoint...")
            response = requests.get(f"{self.base_url}/is_active", timeout=30)
            
            if response.status_code == 200:
                logger.info("✅ is_active endpoint passed")
                return True
            else:
                logger.error(f"❌ is_active endpoint failed: {response.status_code}")
                return False
                
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ is_active request failed: {e}")
            return False
    
    def test_screenshot(self):
        """Test the screenshot endpoint"""
        try:
            logger.info("Testing screenshot endpoint...")
            response = requests.get(f"{self.base_url}/screenshot", timeout=30)
            
            # Screenshot might not be available initially, so both 200 and 404 are acceptable
            if response.status_code in [200, 404]:
                logger.info("✅ Screenshot endpoint accessible")
                return True
            else:
                logger.error(f"❌ Screenshot endpoint failed: {response.status_code}")
                return False
                
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ Screenshot request failed: {e}")
            return False
    
    def test_simple_query(self):
        """Test a simple query to check browser functionality"""
        try:
            logger.info("Testing simple query...")
            
            query_data = {
                "query": "What is the weather like today?",
                "stream": False
            }
            
            response = requests.post(
                f"{self.base_url}/query",
                json=query_data,
                timeout=60
            )
            
            if response.status_code == 200:
                data = response.json()
                logger.info(f"✅ Simple query successful")
                logger.info(f"Response: {data.get('message', 'No message')[:100]}...")
                return True
            else:
                logger.error(f"❌ Simple query failed: {response.status_code}")
                if response.text:
                    logger.error(f"Response: {response.text[:200]}...")
                return False
                
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ Simple query request failed: {e}")
            return False
    
    def test_browser_search_query(self):
        """Test a query that should trigger browser search"""
        try:
            logger.info("Testing browser search query...")
            
            query_data = {
                "query": "Search for the latest news about Python programming",
                "stream": False
            }
            
            response = requests.post(
                f"{self.base_url}/query",
                json=query_data,
                timeout=90
            )
            
            if response.status_code == 200:
                data = response.json()
                logger.info(f"✅ Browser search query successful")
                logger.info(f"Response: {data.get('message', 'No message')[:100]}...")
                return True
            else:
                logger.error(f"❌ Browser search query failed: {response.status_code}")
                if response.text:
                    logger.error(f"Response: {response.text[:200]}...")
                return False
                
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ Browser search query request failed: {e}")
            return False
    
    def run_all_tests(self):
        """Run all tests"""
        logger.info("🚀 Starting comprehensive API tests")
        
        if not self.start_api_server():
            logger.error("❌ Failed to start API server")
            return False
        
        try:
            # Wait for server to be fully ready
            logger.info("Waiting for API server to be fully ready...")
            time.sleep(15)
            
            tests = [
                ("Health Check", self.test_health_check),
                ("Is Active", self.test_is_active), 
                ("Screenshot", self.test_screenshot),
                ("Simple Query", self.test_simple_query),
                ("Browser Search Query", self.test_browser_search_query)
            ]
            
            results = []
            for test_name, test_func in tests:
                logger.info(f"\n--- Running {test_name} Test ---")
                try:
                    result = test_func()
                    results.append((test_name, result))
                except Exception as e:
                    logger.error(f"❌ {test_name} test crashed: {e}")
                    results.append((test_name, False))
                
                # Wait between tests
                time.sleep(2)
            
            # Summary
            logger.info("\n" + "="*50)
            logger.info("TEST SUMMARY")
            logger.info("="*50)
            
            passed = 0
            total = len(results)
            
            for test_name, result in results:
                status = "✅ PASSED" if result else "❌ FAILED"
                logger.info(f"{test_name}: {status}")
                if result:
                    passed += 1
            
            logger.info(f"\nOverall: {passed}/{total} tests passed")
            
            if passed == total:
                logger.info("🎉 All tests passed! The fix appears to be working correctly.")
                return True
            else:
                logger.warning(f"⚠️  {total - passed} test(s) failed. Some issues may remain.")
                return False
                
        finally:
            self.stop_api_server()

def main():
    """Main test function"""
    tester = APITester()
    success = tester.run_all_tests()
    
    if success:
        logger.info("\n✅ API testing completed successfully")
        sys.exit(0)
    else:
        logger.error("\n❌ API testing completed with failures")
        sys.exit(1)

if __name__ == "__main__":
    main()
