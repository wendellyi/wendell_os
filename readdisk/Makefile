all: readdisk.asm msg
	nasm readdisk.asm -o readdisk.bin
	dd of=readdisk.img if=readdisk.bin bs=512 count=1
	dd of=readdisk.img if=msg bs=512 seek=1
