@echo off

echo Building Project... > err

sjasmplus --lst=source.asm --zxnext --nologo ASM\MAIN.ASM

type err
