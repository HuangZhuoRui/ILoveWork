#!/bin/bash
TOKEN=$(cat /Users/vincent/Desktop/ILoveWork/macosApp/token.txt)
URL="https://oa.jinuotec.com/mcp/admin"

# 1. Initialize and capture cookies
echo "=== 1. Initialize ==="
curl -s -v -X POST "$URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -c cookies.txt \
  -d '{"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{"roots":{},"elicitation":{}},"clientInfo":{"name":"test","version":"1.0"}},"jsonrpc":"2.0","id":0}' > init_response.json

echo
cat init_response.json
echo

# 2. Send notifications/initialized
echo "=== 2. Notifications/Initialized ==="
curl -s -v -X POST "$URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "mcp-protocol-version: 2025-11-25" \
  -b cookies.txt \
  -c cookies.txt \
  -d '{"method":"notifications/initialized","jsonrpc":"2.0"}' > notif_response.json

echo
cat notif_response.json
echo

# 3. Tools/List
echo "=== 3. Tools/List ==="
curl -s -v -X POST "$URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "mcp-protocol-version: 2025-11-25" \
  -b cookies.txt \
  -d '{"method":"tools/list","jsonrpc":"2.0","id":1}' > list_response.json

echo
cat list_response.json
echo
