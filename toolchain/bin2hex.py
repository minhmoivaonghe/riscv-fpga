import os
import sys

src, out_dir = sys.argv[1], sys.argv[2]
data = open(src, "rb").read()
data += b"\0" * (-len(data) % 4)                      # căn đủ bội số của 4 byte

words = [int.from_bytes(data[i:i + 4], "little") for i in range(0, len(data), 4)]
EBREAK = 0x00100073
JAL_SELF = 0x0000006f
words = [EBREAK if w == JAL_SELF else w for w in words]
if EBREAK not in words:
    words.append(EBREAK)

os.makedirs(out_dir, exist_ok=True)

with open(os.path.join(out_dir, "input.txt"), "w") as f:
    f.write("".join("%08x\n" % w for w in words))

ram = os.path.join(out_dir, "ram_init.txt")
if not os.path.exists(ram):
    with open(ram, "w") as f:
        f.write("00000000\n" * 256)

print("OK: %d lenh -> %s" % (len(words), os.path.join(out_dir, "input.txt")))
