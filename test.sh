#!/bin/bash
set -e

# Direktori kerja
WORKDIR=~/winiso
ISO_URL="http://download.microsoft.com/download/6/2/A/62A76ABB-9990-4EFC-A4FE-C7D698DAEB96/9600.17050.WINBLUE_REFRESH.140317-1640_X64FRE_SERVER_EVAL_EN-US-IR3_SSS_X64FREE_EN-US_DV9.ISO"
ISO_NAME="WindowsServer2012R2.iso"
VIRTIO_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
VIRTIO_NAME="virtio-win.iso"

# 1️⃣ Install dependencies
echo "🔧 Menginstal dependensi..."
sudo apt update && sudo apt install -y genisoimage wimtools cabextract wget rsync

# 2️⃣ Download Windows Server 2012 R2 ISO
if [ ! -f "$ISO_NAME" ]; then
    echo "📥 Mengunduh Windows Server 2012 R2 ISO..."
    wget -O "$ISO_NAME" "$ISO_URL"
fi

# 3️⃣ Download VirtIO Drivers
if [ ! -f "$VIRTIO_NAME" ]; then
    echo "📥 Mengunduh VirtIO Drivers..."
    wget -O "$VIRTIO_NAME" "$VIRTIO_URL"
fi

# 4️⃣ Ekstrak ISO
echo "📂 Mengekstrak ISO Windows..."
mkdir -p $WORKDIR/extracted
sudo mount -o loop "$ISO_NAME" /mnt
rsync -av /mnt/ $WORKDIR/extracted
sudo umount /mnt

# 5️⃣ Ekstrak dan tambahkan driver VirtIO
echo "🖥️ Menambahkan driver VirtIO..."
mkdir -p $WORKDIR/virtio
sudo mount -o loop "$VIRTIO_NAME" /mnt
rsync -av /mnt/ $WORKDIR/virtio
sudo umount /mnt

# Tambahkan driver ke boot.wim
sudo mount -o loop $WORKDIR/extracted/sources/boot.wim /mnt
wimapply /mnt/2 /tmp/bootwim
wimadd /tmp/bootwim $WORKDIR/virtio
wimcapture /tmp/bootwim $WORKDIR/extracted/sources/boot.wim
sudo umount /mnt

# Tambahkan driver ke install.wim
sudo mount -o loop $WORKDIR/extracted/sources/install.wim /mnt
wimapply /mnt/1 /tmp/installwim
wimadd /tmp/installwim $WORKDIR/virtio
wimcapture /tmp/installwim $WORKDIR/extracted/sources/install.wim
sudo umount /mnt

# 6️⃣ Buat file Unattended Installation
echo "⚙️ Membuat file autounattend.xml..."
cat <<EOF > $WORKDIR/extracted/autounattend.xml
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64">
            <UserData>
                <AcceptEula>true</AcceptEula>
                <FullName>Administrator</FullName>
                <Organization>Company</Organization>
            </UserData>
            <ImageInstall>
                <OSImage>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>1</PartitionID>
                    </InstallTo>
                </OSImage>
            </ImageInstall>
        </component>
    </settings>
</unattend>
EOF

# 7️⃣ Aktifkan RDP dengan SetupComplete.cmd
echo "💻 Mengaktifkan RDP..."
mkdir -p $WORKDIR/extracted/setup/scripts
cat <<EOF > $WORKDIR/extracted/setup/scripts/SetupComplete.cmd
@echo off
reg add "HKLM\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
netsh advfirewall firewall set rule group="Remote Desktop" new enable=yes
EOF

# 8️⃣ Buat ulang ISO
echo "📀 Membuat ulang ISO Windows..."
cd $WORKDIR/extracted
genisoimage -m -o ~/WindowsServer2012R2_Custom.iso -b boot/etfsboot.com -no-emul-boot -boot-load-size 8 -boot-info-table .

echo "✅ ISO baru telah dibuat: ~/WindowsServer2012R2_Custom.iso"
