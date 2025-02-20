#!/bin/bash
echo "SCRIPT AUTO INSTALL WINDOWS by HIDESSH"
echo
echo "Pilih OS yang ingin anda install"
echo "[1] Windows 2019(Default)"
echo "[2] Windows 2016"
echo "[3] Windows 2012"
echo "[4] Windows 10"
echo "[5] Masukkan Link GZ manual"

read -p "Pilih [1]: " PILIHOS

case "$PILIHOS" in
    1|"") PILIHOS="https://file.nixpoin.com/windows2019DO.gz";;
    2) PILIHOS="https://file.nixpoin.com/windows2016.gz";;
    3) PILIHOS="http://52.221.195.212/w12.gz";;
    4) PILIHOS="https://file.nixpoin.com/win10.gz";;
    5) read -p "[?] Masukkan Link GZ mu: " PILIHOS;;
    *) echo "[!] Pilihan salah"; exit 1;;
esac

cat >/tmp/net.bat <<EOF
@ECHO OFF
net user Administrator $PASSADMIN
for /f "tokens=3*" %%i in ('netsh interface show interface ^|findstr /I /R "Local.* Ethernet Ins*"') do (set InterfaceName=%%j)
netsh -c interface ip set address name="Ethernet Instance 0" source=static address=$IP4 mask=255.255.240.0 gateway=$GW
netsh -c interface ip add dnsservers name="Ethernet Instance 0" address=8.8.8.8 index=1 validate=no
netsh -c interface ip add dnsservers name="Ethernet Instance 0" address=8.8.4.4 index=2 validate=no
exit
EOF

cat >/tmp/dpart.bat <<EOF
@ECHO OFF
echo HideSSH - Jangan tutup jendela ini
set PORT=5000
netsh advfirewall firewall add rule name="Open Port 5000" dir=in action=allow protocol=TCP localport=5000
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v PortNumber /t REG_DWORD /d 5000 /f
net stop TermService
net start TermService
ECHO SELECT VOLUME=%%SystemDrive%% > "%SystemDrive%\diskpart.extend"
ECHO EXTEND >> "%SystemDrive%\diskpart.extend"
START /WAIT DISKPART /S "%SystemDrive%\diskpart.extend"
del /f /q "%SystemDrive%\diskpart.extend"
exit
EOF


echo "[*] Mengunduh file Windows..."
wget --no-check-certificate -O /tmp/windows.gz "$PILIHOS"
if [ $? -ne 0 ]; then
    echo "[!] Gagal mengunduh file!"
    exit 1
fi

echo "[*] Mengekstrak file Windows..."
gunzip /tmp/windows.gz
if [ $? -ne 0 ]; then
    echo "[!] Gagal mengekstrak file!"
    exit 1
fi

echo "[*] Menulis image ke disk..."
dd if=/tmp/windows of=/dev/vda bs=3M status=progress
if [ $? -ne 0 ]; then
    echo "[!] Gagal menulis ke disk!"
    exit 1
fi

echo "[*] Mounting Windows partition..."
mount.ntfs-3g /dev/vda2 /mnt || echo "[!] Gagal mount /dev/vda2"

cd "/mnt/ProgramData/Microsoft/Windows/Start Menu/Programs/" || exit
cp -f /tmp/net.bat net.bat
cp -f /tmp/dpart.bat dpart.bat

echo "[*] Instalasi selesai, reboot VPS untuk memulai Windows."
