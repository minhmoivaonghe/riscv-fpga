# RISC-V Multi-cycle Core on FPGA

CPU RISC-V multi-cycle (SystemVerilog) kèm toolchain C++ -> HEX nạp qua UART, hiển thị kết quả lên máy tính.

## Cấu trúc
- `rtl/`       : mã nguồn core, UART, FIFO, LCD
- `sim/`       : testbench
- `quartus/`   : project Quartus II (Cyclone IV EP4CE6)
- `toolchain/` : main.cpp, crt0, link.ld, build, bin2hex.py, send.py
- `docs/`      : mô tả thiết kế, ảnh chạy thực tế

## Phần cứng / công cụ
- Board: Intel/Altera Cyclone IV EP4CE6, nạp bằng USB-Blaster
- Mạch chuyển USB-UART (để gửi chương trình vào core)
- Quartus II, RISC-V GCC toolchain, Python 3, thư viện `pyserial`

## Sinh lệnh và chạy trên FPGA

### 1. Biên dịch C++ sang mã máy RISC-V
Viết chương trình trong `toolchain/main.cpp`, rồi chạy script `build`. Script dùng `crt0` (khởi tạo stack, gọi `main`) và `link.ld` (sơ đồ bộ nhớ) để tạo `a.elf`, `a.dump` (mã dịch ngược để kiểm tra), `a.bin` (mã máy thô).

### 2. Chuyển BIN sang file hex
    python bin2hex.py a.bin .

Tạo ra `input.txt`: mỗi dòng là một lệnh 32-bit dạng hex. Script tự căn đủ bội số 4 byte và đổi vòng lặp vô hạn `jal x0, 0` thành `ebreak` để core biết khi nào dừng.

### 3. Nạp phần cứng
1. Mở project trong `quartus/`, biên dịch bằng Quartus II
2. Nạp file `.sof` xuống board qua USB-Blaster

### 4. Gửi chương trình vào core qua UART

**Yêu cầu:**
- File hex (`input.txt`) phải nằm **cùng thư mục với `send.py`**
- Cài thư viện: `pip install pyserial`
- Xác định cổng COM của mạch USB-UART: cắm mạch vào máy, mở **Device Manager -> Ports (COM & LPT)**, tìm tên dạng `USB Serial Port (COM5)`. Số COM có thể đổi khi cắm sang cổng USB khác.

**Chạy:**
    python send.py COM9 input.txt

Thay `COM9` bằng cổng COM bạn vừa tìm được. Kiểm tra trước khi gửi (chỉ in byte, không gửi):

    python send.py COM9 input.txt

**Giao thức:**
- Baudrate 19200
- Chương trình dài 1 đến 256 lệnh
- Byte đầu của mỗi lệnh không được là `0x47` ('G'), vì 'G' là ký tự báo CPU bắt đầu chạy
- `send.py` gửi chương trình + 'G', sau đó đọc 4 byte kết quả (32-bit, little-endian) và in ra màn hình

### Luồng tổng quát
`main.cpp` -> `build` -> `a.elf` -> `a.bin` -> `bin2hex.py` -> `input.txt` -> `send.py COMx` (UART) -> RISC-V core -> kết quả (terminal + LCD)

## Kết quả
(video chạy thật trên board ở `https://youtube.com/shorts/jBch4MloWBQ`)
