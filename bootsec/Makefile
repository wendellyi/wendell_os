all: bootsec.asm
	nasm bootsec.asm -o bootsec.bin
	dd of=bootsec.img if=bootsec.bin bs=512 count=1 2> /dev/null