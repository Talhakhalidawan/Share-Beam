import asyncio
import json
import time
import websockets

CONNECTED_CLIENTS = set()

async def relay_message(sender, message):
    """Send message to all clients except the sender."""
    if not CONNECTED_CLIENTS:
        return
    # Copy the set because we might modify it during iteration
    for client in list(CONNECTED_CLIENTS):
        if client is sender:
            continue
        try:
            await client.send(message)
        except websockets.exceptions.ConnectionClosed:
            CONNECTED_CLIENTS.remove(client)

async def handler(websocket):
    # Only accept connections on /ws
    if websocket.request.path != "/ws":
        await websocket.close(1008, "Only /ws is accepted")
        return

    CONNECTED_CLIENTS.add(websocket)
    addr = websocket.remote_address
    print(f"\n[+] Client connected from {addr}")

    try:
        async for raw_message in websocket:
            try:
                data = json.loads(raw_message)
                sender_name = data.get('senderName', 'Unknown')
                content = data.get('data', '')
                payload_type = data.get('type', -1)  # 0 = text, 1 = file, 2 = announcement
                
                print(f"\n[Received from {sender_name}] Type: {payload_type} | Content: {content}")

                # Relay to all other clients (keep the message exactly as received)
                await relay_message(websocket, raw_message)

            except json.JSONDecodeError:
                print(f"\n[Error] Invalid JSON from {addr}: {raw_message[:100]}")
            except Exception as e:
                print(f"\n[Error] Processing message: {e}")
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        CONNECTED_CLIENTS.remove(websocket)
        print(f"\n[-] Client disconnected from {addr}")


async def broadcast_cli_input():
    """Broadcast manually typed messages (as text payloads) to all clients."""
    print("\n--- Share-Beam Python Test Hub ---")
    print("1. Open your Flutter Web app")
    print("2. Go to Settings -> Join Server")
    print("3. Enter your Local IP (or 127.0.0.1) and Port 9876")
    print("4. Type messages here to send them to ALL connected apps")
    print("5. Messages sent from the app will appear here and be relayed to other apps\n")

    while True:
        text = await asyncio.get_event_loop().run_in_executor(
            None, input, "> "
        )
        if not text:
            continue

        payload = {
            "id": str(int(time.time() * 1000)),
            "type": 0,                # FileTransferType.text
            "fileName": "Python Metadata",
            "size": len(text),
            "data": text,
            "senderName": "Python"
        }

        message = json.dumps(payload)
        if CONNECTED_CLIENTS:
            print(f"Broadcasting to {len(CONNECTED_CLIENTS)} clients...")
            await relay_message(None, message)  # None sender = send to all
        else:
            print("No clients connected.")


async def main():
    # Start WebSocket server
    async with websockets.serve(handler, "0.0.0.0", 1234):
        # Run the CLI input loop concurrently
        await broadcast_cli_input()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[!] Server stopped.")