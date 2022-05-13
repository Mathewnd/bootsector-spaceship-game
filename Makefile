all: diskimage

bootsector.bin: bootsector.asm
	nasm -fbin -o bootsector.bin bootsector.asm




diskimage: bootsector.bin
	dd if=/dev/zero of=diskimage bs=512 count=2880
	dd if=bootsector.bin of=diskimage bs=512 count=1 conv=notrunc


test: diskimage
	qemu-system-i386 -fda diskimage -d int -monitor stdio
