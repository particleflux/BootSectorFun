Some tiny little 512-byte bootsector programs.
Should be able to start from any bootsector, whether it is floppy or hdd or USB.

# Clock

A big fullscreen digital clock. Can be switched between 24 and 12 hour format, and has 
adjustable foreground and background colors.

Compile with: 
>nasm -f bin clock.asm

Then try it out for example on Qemu:
>qemu-system-i386 -fda clock -boot a

