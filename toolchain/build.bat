@echo off
REM Biên dịch main.cpp -> ghi thẳng input.txt vào thư mục dữ liệu của core
set "OUT=C:\Users\user\Music\risc v\data\c++"

cd /d "%~dp0"

riscv-none-elf-g++ -march=rv32i -mabi=ilp32 -O1 -ffreestanding -nostdlib -nostartfiles -fno-exceptions -fno-rtti -mno-relax -T link.ld crt0.S main.cpp -o a.elf
if errorlevel 1 goto err

riscv-none-elf-objcopy -O binary a.elf a.bin
if errorlevel 1 goto err

python bin2hex.py a.bin "%OUT%"
if errorlevel 1 goto err

REM In ra assembly để đối chiếu với input.txt
riscv-none-elf-objdump -d a.elf > a.dump.txt
echo Xong. Assembly nam trong a.dump.txt
goto end

:err
echo LOI: xem thong bao phia tren.

:end
pause
