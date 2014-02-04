current_dir=$(shell pwd)

all: gotoring3.asm
	nasm gotoring3.asm -o gotoring3.bin
	cd ../bootloader && make && cp bootloader.bin $(current_dir)
	cd $(current_dir)
	dd of=os.img if=bootloader.bin bs=512 count=1
	dd of=os.img if=gotoring3.bin bs=512 seek=1
	yes | mv os.img ..