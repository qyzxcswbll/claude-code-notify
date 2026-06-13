"""Claude Code Notify · 配置保存服务

使用方式：
  python3 ~/.claude/notify-config-server.py

然后在浏览器打开配置页，点击「保存」即可写入配置。
"""

import json, os, io, base64
from http.server import HTTPServer, BaseHTTPRequestHandler

CONFIG_PATH = os.path.expanduser("~/.claude/notify-config.json")
THEMES_DIR = os.path.expanduser("~/.claude/themes")
PORT = 18765


class Handler(BaseHTTPRequestHandler):

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        if self.path == "/config":
            data = {}
            if os.path.exists(CONFIG_PATH):
                with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                    data = json.load(f)
            self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(data, ensure_ascii=False).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == "/save":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length).decode("utf-8")
            data = json.loads(body)

            os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)

            # 保存配置
            config = {
                "mode": data.get("mode", "elegant"),
                "theme": data.get("theme", "holo"),
                "icons": data.get("icons", {"project": "⚙", "done": "✨", "wait": "⚙"}),
                "params": data.get("params", {"radius": 14, "duration": 5}),
                "hasImage": data.get("hasImage", False),
            }
            with open(CONFIG_PATH, "w", encoding="utf-8") as f:
                json.dump(config, f, ensure_ascii=False, indent=2)

            # 保存立绘图片（如果有 base64）
            image_data = data.get("imageData")
            if image_data:
                os.makedirs(THEMES_DIR, exist_ok=True)
                img_path = os.path.join(THEMES_DIR, "character.png")
                # 解析 base64 data URL
                if "," in image_data:
                    _, b64 = image_data.split(",", 1)
                else:
                    b64 = image_data
                with open(img_path, "wb") as f:
                    f.write(base64.b64decode(b64))

            self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode())

        elif self.path == "/mode":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length).decode("utf-8")
            data = json.loads(body)
            mode = data.get("mode", "elegant")
            mode_path = os.path.expanduser("~/.claude/notify-mode")
            os.makedirs(os.path.dirname(mode_path), exist_ok=True)
            with open(mode_path, "w", encoding="utf-8") as f:
                f.write(mode)
            self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"status": "ok"}).encode())

        else:
            self.send_response(404)
            self.end_headers()


if __name__ == "__main__":
    print(f"Config server running on http://localhost:{PORT}")
    print(f"Press Ctrl+C to stop")
    HTTPServer(("", PORT), Handler).serve_forever()
