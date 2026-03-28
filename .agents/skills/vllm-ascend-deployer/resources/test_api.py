#!/usr/bin/env python3
"""
vLLM-Ascend API Testing Script
Usage: python test_api.py <server-ip> <port> [model-path]
"""

import sys
import json
import time
import requests
from typing import Optional, Dict, Any

class VLLMAPITester:
    def __init__(self, base_url: str, model: str):
        self.base_url = base_url.rstrip('/')
        self.model = model
        self.session = requests.Session()
    
    def test_health(self) -> bool:
        """Test health endpoint"""
        try:
            response = self.session.get(f"{self.base_url}/health", timeout=10)
            if response.status_code == 200:
                print("[OK] Health check passed")
                return True
            else:
                print(f"[FAIL] Health check failed: {response.status_code}")
                return False
        except Exception as e:
            print(f"[ERROR] Health check error: {e}")
            return False
    
    def test_models(self) -> Optional[Dict[str, Any]]:
        """Test models endpoint"""
        try:
            response = self.session.get(f"{self.base_url}/v1/models", timeout=10)
            if response.status_code == 200:
                data = response.json()
                print("[OK] Models endpoint working")
                print(f"     Available models: {[m['id'] for m in data.get('data', [])]}")
                return data
            else:
                print(f"[FAIL] Models endpoint failed: {response.status_code}")
                return None
        except Exception as e:
            print(f"[ERROR] Models endpoint error: {e}")
            return None
    
    def test_chat_completion(self, message: str = "Hello, who are you?", max_tokens: int = 50) -> Optional[Dict[str, Any]]:
        """Test chat completions endpoint"""
        try:
            payload = {
                "model": self.model,
                "messages": [{"role": "user", "content": message}],
                "max_tokens": max_tokens
            }
            
            print(f"\n[TEST] Sending chat completion request...")
            print(f"       Message: {message}")
            
            start_time = time.time()
            response = self.session.post(
                f"{self.base_url}/v1/chat/completions",
                json=payload,
                timeout=60
            )
            elapsed = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                content = data.get('choices', [{}])[0].get('message', {}).get('content', '')
                usage = data.get('usage', {})
                
                print(f"[OK] Chat completion successful ({elapsed:.2f}s)")
                print(f"     Response: {content[:100]}..." if len(content) > 100 else f"     Response: {content}")
                print(f"     Tokens: prompt={usage.get('prompt_tokens')}, completion={usage.get('completion_tokens')}")
                return data
            else:
                print(f"[FAIL] Chat completion failed: {response.status_code}")
                print(f"       Error: {response.text}")
                return None
        except Exception as e:
            print(f"[ERROR] Chat completion error: {e}")
            return None
    
    def test_completion(self, prompt: str = "Once upon a time", max_tokens: int = 50) -> Optional[Dict[str, Any]]:
        """Test text completions endpoint"""
        try:
            payload = {
                "model": self.model,
                "prompt": prompt,
                "max_tokens": max_tokens
            }
            
            print(f"\n[TEST] Sending completion request...")
            print(f"       Prompt: {prompt}")
            
            start_time = time.time()
            response = self.session.post(
                f"{self.base_url}/v1/completions",
                json=payload,
                timeout=60
            )
            elapsed = time.time() - start_time
            
            if response.status_code == 200:
                data = response.json()
                text = data.get('choices', [{}])[0].get('text', '')
                usage = data.get('usage', {})
                
                print(f"[OK] Completion successful ({elapsed:.2f}s)")
                print(f"     Response: {text[:100]}..." if len(text) > 100 else f"     Response: {text}")
                print(f"     Tokens: prompt={usage.get('prompt_tokens')}, completion={usage.get('completion_tokens')}")
                return data
            else:
                print(f"[FAIL] Completion failed: {response.status_code}")
                print(f"       Error: {response.text}")
                return None
        except Exception as e:
            print(f"[ERROR] Completion error: {e}")
            return None
    
    def run_all_tests(self):
        """Run all API tests"""
        print("=" * 50)
        print("vLLM-Ascend API Test Suite")
        print("=" * 50)
        print(f"Base URL: {self.base_url}")
        print(f"Model: {self.model}")
        print("=" * 50)
        
        results = {
            "health": self.test_health(),
            "models": self.test_models() is not None,
            "chat": self.test_chat_completion() is not None,
            "completion": self.test_completion() is not None
        }
        
        print("\n" + "=" * 50)
        print("Test Results Summary")
        print("=" * 50)
        for test, passed in results.items():
            status = "[PASS]" if passed else "[FAIL]"
            print(f"  {test}: {status}")
        
        all_passed = all(results.values())
        print("=" * 50)
        if all_passed:
            print("All tests passed!")
        else:
            print("Some tests failed!")
        return all_passed


def main():
    if len(sys.argv) < 3:
        print("Usage: python test_api.py <server-ip> <port> [model-path]")
        print("Example: python test_api.py 175.100.2.5 8002 /home/weights/Qwen3-4B")
        sys.exit(1)
    
    server_ip = sys.argv[1]
    port = sys.argv[2]
    model = sys.argv[3] if len(sys.argv) > 3 else "default"
    
    base_url = f"http://{server_ip}:{port}"
    
    tester = VLLMAPITester(base_url, model)
    success = tester.run_all_tests()
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
