# Cach dung:  python send.py COM5 prog.hex      (COM5 = cong USB-UART)
#             python send.py dry prog.hex       (chi in cac byte, khong gui)
# Cai thu vien:  pip install pyserial
import sys

port = sys.argv[1]
path = sys.argv[2] if len(sys.argv) > 2 else 'prog.hex'
BAUD = 19200

words = []
for line in open(path):
    line = line.split('//')[0].split('#')[0].strip()
    if line:
        words.append(int(line, 16))

assert 0 < len(words) <= 256, 'chuong trinh phai tu 1 den 256 lenh'
data = b''.join(w.to_bytes(4, 'little') for w in words)   # byte thap truoc
assert all(data[i] != 0x47 for i in range(0, len(data), 4)), "byte dau cua lenh khong duoc la 'G'"

if port == 'dry':
    print(data.hex(' '))
    sys.exit()

import serial
s = serial.Serial(port, BAUD, timeout=3)
s.reset_input_buffer()
s.write(data + b'G')                  # chuong trinh + 'G' de cho CPU chay
r = s.read(4)                         # dap an 32 bit = 4 byte
if len(r) < 4:
    print('Khong nhan du 4 byte, nhan duoc:', r.hex(' '))
else:
    print('Dap an:', int.from_bytes(r, 'little', signed=True))
