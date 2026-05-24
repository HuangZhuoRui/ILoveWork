import http.server
import urllib.request
import sys

class Proxy(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        self.handle_req("POST")
    def do_GET(self):
        self.handle_req("GET")
        
    def handle_req(self, method):
        print(f"\n--- INTERCEPTED {method} REQUEST ---")
        print(f"Path: {self.path}")
        for header, value in self.headers.items():
            print(f"Header: {header}: {value}")
            
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)
        if body:
            print("Body:", body.decode('utf-8', errors='replace'))
            
        # Stop proxy after 1 request for safety
        def kill_me():
            import os
            os._exit(0)
        import threading
        threading.Timer(1, kill_me).start()

        self.send_response(200)
        self.end_headers()

if __name__ == '__main__':
    http.server.HTTPServer(('', 8080), Proxy).serve_forever()
