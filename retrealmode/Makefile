all: retrealmode.asm
	nasm retrealmode.asm -o retrealmode.bin
	nasm bootsec.asm -o bootsec.bin
	dd of=retrealmode.img if=bootsec.bin bs=512 count=1
	dd of=retrealmode.img if=retrealmode.bin bs=512 seek=1