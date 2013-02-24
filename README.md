Some tiny little 512-byte bootsector programs.
Should be able to start from any bootsector, whether it is floppy or hdd or USB.

"clock" instructions:
Compile with 
>nasm -f bin clock.asm

Then try it out for example on Qemu, with
>qemu-system-i386 -fda clock -boot a

