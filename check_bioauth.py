import os
import re
import asyncio
from telegram import Bot
import requests

BOT_TOKEN = os.environ.get("BOT_TOKEN")
CHAT_ID = os.environ.get("CHAT_ID")
NODE_IP = os.environ.get("NODE_IP")

async def send_message(message):
    bot = Bot(token=BOT_TOKEN)
    await bot.send_message(chat_id=CHAT_ID, text=message)

def get_tunnel_link():
    log_file = "/root/.humanode/workspaces/default/tunnel/logs.txt"
    if not os.path.exists(log_file):
        return None
    with open(log_file, "rb") as f:
        f.seek(0, os.SEEK_END)
        end = f.tell()
        size = 1024
        if end < size:
            size = end
        f.seek(-size, os.SEEK_END)
        lines = f.readlines()
    for line in reversed(lines):
        line = line.decode('utf-8', errors='ignore')
        match = re.search(r"wss://[^\s]+", line)
        if match:
            return match.group(0)
    return None

async def check_status():
    payload = {
        "jsonrpc": "2.0",
        "method": "bioauth_status",
        "params": [],
        "id": 1
    }
    response = requests.post(f'http://{NODE_IP}:9933', json=payload)
    result_json = response.json()
    result = result_json.get('result', '')
    if isinstance(result, dict):
        status = result.get('status', '').strip()
    elif isinstance(result, str):
        status = result.strip()
    else:
        status = ''

    if status.lower() == "inactive":
        link = get_tunnel_link()
        if link:
            message = f"❌ Bioauth inaktif! Tarama yapılması gerekiyor.\nLink: https://webapp.mainnet.stages.humanode.io/open?url={link}"
        else:
            message = "❌ Bioauth inaktif! Ancak log dosyasından tunnel linki alınamadı."
        await send_message(message)

async def main():
    while True:
        try:
            await check_status()
            await asyncio.sleep(600)
        except Exception as e:
            await send_message(f"⚠️ Hata: {e}")
            await asyncio.sleep(600)

if __name__ == "__main__":
    asyncio.run(main())
