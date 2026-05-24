import http.server
import urllib.request
import sys
import threading

request_count = 0

class Proxy(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        self.handle_req("POST")
    def do_GET(self):
        self.handle_req("GET")
        
    def handle_req(self, method):
        global request_count
        request_count += 1
        
        print(f"\n--- INTERCEPTED {method} REQUEST {request_count} ---")
        print(f"Path: {self.path}")
        for header, value in self.headers.items():
            print(f"Header: {header}: {value}")
            
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)
        if body:
            print("Body:", body.decode('utf-8', errors='replace'))
            
        # Send a dummy valid MCP response so Claude keeps talking
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        
        # Simple mock responses based on request_count or body content
        if b"initialize" in body:
            resp = '{"jsonrpc":"2.0","id":0,"result":{"protocolVersion":"2025-11-25","capabilities":{"tools":{"listChanged":false}},"serverInfo":{"name":"athena-admin","version":"1.0"}}}'
        elif b"tools/list" in body:
            resp = '{"jsonrpc":"2.0","id":1,"result":{"tools":[]}}'
        else:
            resp = '{"jsonrpc":"2.0","id":2,"result":{}}'
            
        self.wfile.write(resp.encode('utf-8'))
        
        if request_count >= 3:
            def kill_me():
                import os
                os._exit(0)
            threading.Timer(1, kill_me).start()

if __name__ == '__main__':
    http.server.HTTPServer(('', 8080), Proxy).serve_forever()
