#!/bin/bash
TOKEN=$(cat /Users/vincent/Desktop/ILoveWork/macosApp/token.txt)
URL="https://oa.jinuotec.com/mcp/admin"

# 1. Initialize and capture cookies
echo "=== 1. Initialize ==="
curl -s -X POST "$URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -c cookies.txt \
  -d '{"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{"roots":{},"elicitation":{}},"clientInfo":{"name":"test","version":"1.0"}},"jsonrpc":"2.0","id":0}' > /dev/null

# 2. Tools/Call
echo "=== 2. Tools/Call ==="
curl -s -X POST "$URL" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "mcp-protocol-version: 2025-11-25" \
  -b cookies.txt \
  -d '{"method":"tools/call","jsonrpc":"2.0","id":1,"params":{"name":"oa_service_attendance_getDailyReport","arguments":{"userName":"vincent","dateStart":"2026-05-17","dateEnd":"2026-05-24","page":1,"count":10}}}' > call_response.json

cat call_response.json
echo
