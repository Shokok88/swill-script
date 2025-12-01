# swill_controller.py
import asyncio
import websockets
import json

class SWILLController:
    def __init__(self, port=51948):
        self.port = port
        self.clients = set()
        
    async def handler(self, websocket):
        self.clients.add(websocket)
        print(f"[SWILL Controller] Новое подключение: {websocket.remote_address}")
        
        try:
            async for message in websocket:
                print(f"[SWILL Controller] Получено: {message}")
                
                # Реле сообщения всем клиентам
                if message.startswith("broadcast:"):
                    broadcast_msg = message[10:]
                    await self.broadcast(broadcast_msg)
                else:
                    await websocket.send(f"ACK: {message}")
                    
        except websockets.exceptions.ConnectionClosed:
            print(f"[SWILL Controller] Соединение закрыто: {websocket.remote_address}")
        finally:
            self.clients.remove(websocket)
    
    async def broadcast(self, message):
        if self.clients:
            await asyncio.gather(
                *[client.send(message) for client in self.clients]
            )
    
    async def send_command(self, job_id):
        command = f"join {job_id}"
        await self.broadcast(command)
    
    async def start(self):
        print(f"[SWILL Controller] Запуск сервера на ws://localhost:{self.port}")
        async with websockets.serve(self.handler, "localhost", self.port):
            await asyncio.Future()  # run forever
    
    def run(self):
        asyncio.run(self.start())

# Интерфейс командной строки
if __name__ == "__main__":
    import threading
    
    controller = SWILLController(51948)
    
    # Запуск сервера в отдельном потоке
    server_thread = threading.Thread(target=controller.run, daemon=True)
    server_thread.start()
    
    print("[SWILL Controller] Сервер запущен. Команды:")
    print("  join <JobID> - присоединиться к серверу")
    print("  teleport <PlaceID> <JobID> - прямой телепорт")
    print("  broadcast:message - отправить всем клиентам")
    print("  exit - выход")
    
    try:
        while True:
            cmd = input("SWILL> ").strip()
            if cmd.lower() == 'exit':
                break
            elif cmd.startswith('join '):
                job_id = cmd[5:].strip()
                asyncio.run(controller.send_command(job_id))
            else:
                print("Неизвестная команда")
    except KeyboardInterrupt:
        print("\n[SWILL Controller] Остановка...")
