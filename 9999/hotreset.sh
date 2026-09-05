#!/bin/bash
D=/sys/bus/pci/devices/0000:81:00.0
echo "1111" | sudo -S -p "" bash -c "
echo 1 > $D/remove; sleep 3
echo 1 > /sys/bus/pci/rescan; sleep 10
ls $D >/dev/null 2>&1 && echo PCI_BACK || echo PCI_FAIL
sleep 5; nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>&1 | head -1"
