import urllib.parse
import urllib.request
import json
import hashlib
import base64
import os
import secrets
from http.server import BaseHTTPRequestHandler, HTTPServer
import webbrowser
import ssl

ssl._create_default_https_context = ssl._create_unverified_context

# Generate PKCE verifier and challenge
verifier = secrets.token_urlsafe(64)
digest = hashlib.sha256(verifier.encode('ascii')).digest()
challenge = base64.urlsafe_b64encode(digest).decode('ascii').rstrip('=')
state = secrets.token_urlsafe(16)

client_id = "74"
redirect_uri = "http://localhost:10010/callback"
auth_url = (f"https://fuzzid.com/oauth?response_type=code&client_id={client_id}"
            f"&code_challenge={challenge}&code_challenge_method=S256"
            f"&redirect_uri={urllib.parse.quote(redirect_uri)}&state={state}&scope=openid"
            f"&resource={urllib.parse.quote('https://oa.jinuotec.com/mcp/admin')}")

class RequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        query = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(query)
        
        if 'code' in params:
            code = params['code'][0]
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(b"<html><body><h1>Success! You can close this window and go back to the terminal.</h1></body></html>")
            
            # Exchange code for token
            token_url = "https://fuzzid.com/api/oauth/token"
            data = urllib.parse.urlencode({
                "grant_type": "authorization_code",
                "client_id": client_id,
                "code": code,
                "redirect_uri": redirect_uri,
                "code_verifier": verifier
            }).encode('utf-8')
            
            req = urllib.request.Request(token_url, data=data)
            try:
                with urllib.request.urlopen(req) as response:
                    res = json.loads(response.read().decode())
                    token = res['access_token']
                    print(f"Token acquired, length: {len(token)}")
                    with open("token.txt", "w") as f:
                        f.write(token)
                    
                    # Fetch tools/list from MCP server
                    mcp_url = "https://oa.jinuotec.com/mcp/admin"
                    mcp_req = urllib.request.Request(mcp_url, data=json.dumps({
                        "jsonrpc": "2.0",
                        "id": 1,
                        "method": "tools/list",
                        "params": {}
                    }).encode('utf-8'), headers={
                        "Authorization": f"Bearer {token}",
                        "Content-Type": "application/json",
                        "Accept": "application/json"
                    })
                    try:
                        with urllib.request.urlopen(mcp_req) as mcp_res:
                            print("MCP tools/list Response:")
                            print(mcp_res.read().decode())
                    except Exception as e2:
                        print("MCP request failed:", e2)
                        if hasattr(e2, 'read'):
                            body = e2.read().decode(errors='replace')
                            print("MCP Error Body:", body)
            except Exception as e:
                print("Error exchanging token:", e)
                if hasattr(e, 'read'):
                    print(e.read().decode(errors='replace'))
            
            # Stop the server
            def kill_me_please():
                self.server.server_close()
                os._exit(0)
            import threading
            threading.Timer(1, kill_me_please).start()
            
        else:
            self.send_response(400)
            self.end_headers()

if __name__ == "__main__":
    print("Opening browser for authorization...")
    print(auth_url)
    # webbrowser.open(auth_url)
    server = HTTPServer(('localhost', 10010), RequestHandler)
    print("Waiting for callback on port 10010...")
    server.serve_forever()
