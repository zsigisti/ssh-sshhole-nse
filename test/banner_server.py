import socket, sys, threading
port, banner = int(sys.argv[1]), sys.argv[2]
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", port)); s.listen(16)
def handle(c):
    try:
        c.sendall((banner + "\r\n").encode())
        c.settimeout(1.0)
        try: c.recv(64)
        except Exception: pass
    finally:
        try: c.close()
        except Exception: pass
import time
end = time.time() + 20
s.settimeout(1.0)
while time.time() < end:
    try:
        c,_ = s.accept()
    except socket.timeout:
        continue
    except Exception:
        break
    threading.Thread(target=handle, args=(c,), daemon=True).start()
s.close()
