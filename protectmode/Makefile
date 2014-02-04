all: protectmode.asm
	nasm protectmode.asm -o protectmode.bin
	nasm bootsec.asm -o bootsec.bin
	dd of=protectmode.img if=bootsec.bin bs=512 count=1
	dd of=protectmode.img if=protectmode.bin bs=512 seek=1
