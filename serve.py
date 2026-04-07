import http.server
import socketserver
import os

os.chdir(os.path.dirname(os.path.abspath(__file__)))
PORT = 8899

class Handler(http.server.SimpleHTTPRequestHandler):
    pass

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"Serving on http://localhost:{PORT}")
    httpd.serve_forever()
