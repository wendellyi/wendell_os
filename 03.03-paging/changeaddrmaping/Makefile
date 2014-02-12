current_dir=$(shell pwd)
obj_name=changeaddrmaping

all: $(obj_name).asm
	nasm $(obj_name).asm -o $(obj_name).bin
	cd ../bootloader && make && cp bootloader.bin $(current_dir)
	cd $(current_dir)
	dd of=os.img if=bootloader.bin bs=512 count=1
	dd of=os.img if=$(obj_name).bin bs=512 seek=1
	yes | mv os.img ..