# Bootsector spaceship game
Bootsector game where you go pewpew on spaceships and have to also dodge shots

Controls are

W and A -> move up and down

K -> shoot

# Building

you need NASM to build this.

run ``make`` to build the disk image

# Testing

Throw the disk image into a VM. The makefile has a target named "test" which runs QEMU with the disk image
