bits 16; 16 bit mode
org 0x7c00; |0x7c00|memory adresas nuo kur prasides mano kodas - memory
xor bx,bx
mov ds,bx
mov word [seed],ax
mov [boot_drive], dl
mov ah,0
mov al,13h
int 0x10

xor ax,ax; Loadina grafikas is hard drive y ram [kas yra nuo 512 byte]
mov es, ax      ; ES:BX, sektorius rame kur
mov ah, 02h     ; BIOS: skaityti sektorius is hard drive
mov al, 63       ; Kiek sekturiu skaityti
mov ch, 0       ; cylinder
mov cl, 2       ; sectorius  kuris, nuo 1?
mov dh, 0       ; head ?
mov dl, [boot_drive]     ; drive 80h = first hard disk| boot
mov bx, 0x7E00     ; ES:BX = kur data rame atsiras, sektorius 0x7c00 ir nuo jo 512 byto
int 13h

mov al, 34h; PIT intterupts hlt at 1,193,182 Hz
out 43h, al
mov ax, 31930; we give 1193 so it would slow down speed of pit by 1193 times
out 40h, al          
mov al, ah
out 40h, al  

mov ax,0xA000
mov es,ax;

; mov word [es:di],257
; jmp Stop
.wait:
    in   al, 64h ; gauna informacija is I/O port 64h | in -> skaityti byte is tam tinkamos vietos
    test al, 10b ; jeigu byte 1 yra, tada laukia | 1 byte reiskia, kad eile informacijos yra eileja ir nepriima daugau       
    jnz  .wait

mov al, 0D4h ; komanda kontroleriui reiskia kad sekantis byte bus pelei nusiustas
out 64h, al ; out -> nusiuncia "al" y 64h

.wait2:
    in   al, 64h ; vel tikrina ar gali priimti informacija
    test al, 10b
    jnz  .wait2


mov al, 0F4h           ; Leidiza pelei siusti informacija
out 60h, al

call LoadMapSides
call SpawnCar
xor di,di
start:

    ; skaito peles info, button|x|y
    .waitMI: ; left click | right click | middle button | always on | pos/neg x change | pos/neg y change | x of | y of
        in   al, 64h
        test al, 01h
        jz   Idle
        test al,100000b ; 
        jz  Idle
        in   al,60h
        test al,1000b  ; if byte 3 is 1 | aligns packets     
        jz   .waitMI
        mov [mouse_b0],al
    .waitMX:; x
        in   al, 64h
        test al, 01h
        jz   .waitMX

    in   al, 60h
    mov cl,al

    .waitMY:; y
        in   al, 64h
        test al, 01h
        jz   .waitMY
    in   al, 60h

    push ax
    push cx
        call ClearPrevPos
    pop cx
    pop ax
    test al,al
    jz NoYChange
        cmp al,0
        jg Yinc
            add word [PlaneIn],320
            jmp NoYChange
        Yinc:
            sub word [PlaneIn],320
    NoYChange:
    mov word [Wheel],0
    test cl,cl
    jz NoXChange
        cmp cl,0
        jg Xinc
            mov word [Wheel],1
            dec word [PlaneIn]
            jmp NoXChange
        Xinc:
            mov word [Wheel],2
            inc word [PlaneIn]
    NoXChange:

    inc word [Time]
    test word [Time],11b
    jnz NoSideXOR2
        call SidesXOR
    NoSideXOR2:        
    test word [Time],1111b
    jnz NoSpawn2
        call SpawnCar
        call ScoreUpdate
    NoSpawn2: 
    call UpdateOtherCars
    call DrawCar
    call DrawSteerWheel
    sti
    hlt
    jmp start
Idle:
    mov word [Wheel],0
    inc word [Time]
    test word [Time],11b
    jnz NoSideXOR
        call SidesXOR
    NoSideXOR:  
    test word [Time],1111b
    jnz NoSpawn1
        call SpawnCar
        call ScoreUpdate
    NoSpawn1:    
    
    call ClearPrevPos
    call UpdateOtherCars
    call DrawCar
    call DrawSteerWheel
    sti
    hlt
    jmp start
ClearPrevPos:
    mov di,[PlaneIn]
    mov ch,14
    ClearY:
        mov cl,9
        ClearX:
            mov word [es:di],5654
            add di,1
            dec cl
            jnz ClearX
        add di,311
        dec ch
        jnz ClearY
    ret
DrawCar:
    mov di,[PlaneIn]
    lea si,[CarFrames]
    mov ch,14
    DrawPY:
        mov cl,9
        DrawPX:
            mov al,[si]
            test al,al
            jz SkipD    
                test al,al
                jz Permat2
                    mov bl,[es:di]
                    cmp bl,22
                    jne Stop
                Permat2:
                mov byte [es:di],al
            SkipD:
            inc si
            inc di
            dec cl
            jnz DrawPX
        add di,311
        dec ch
        jnz DrawPY
    ret
Stop:
jmp Stop
boot_drive dw 0
times 510-($-$$) db 0; fill (512 bytes - ending pos of the code) with 0's. 
dw 0xaa55; hard drive marking   
SpawnCar:
    cmp word [CarA],20
    jne NotLimit
        ret
    NotLimit:
    mov ax,[seed]
    imul ax,109
    add ax,1021
    mov word [seed],ax
    push ax
    shr ax,8
    xor dx,dx
    mov bx,12
    div bx

    imul dx,13
    add dx,4564
    mov di,dx
    mov al,[es:di]
    cmp al,22
    je Continue
        ret
    Continue:
    sub dx,4480

    lea si,[CarBuffer]
    
    mov ax,[CarA]
    imul ax,3
    add si,ax
    mov word [si],dx
    add si,2
    pop ax
    shr ax,12
    test ax,1111b
    jnz NormalCar
        mov byte [si],4
        inc word [CarA]
        ret
    NormalCar:
    shr ax,2
    mov byte [si],al
    inc word [CarA]
    ret
UpdateOtherCars:
    lea si,[CarBuffer]
    mov ax,[CarA]
    test ax,ax
    jnz Forward
        ret
    Forward:
        mov di,[si]
        mov cl,9
        ClearPrevPosB:
            mov byte [es:di],22
            inc di
            dec cl
            jnz ClearPrevPosB
        add di,311
        mov word [si],di
        lea bp,[OtherCars]
        dec bp
        add si,2
        xor ah,ah
        mov al,[si]
        imul ax,126
        sub bp,ax
        mov cl,14
        DrawA:
            mov ch,9
            DrawB:
                mov al,[bp]
                test al,al
                jz Permat
                    mov byte [es:di],al
                Permat:
                dec bp
                inc di
                dec ch
                jnz DrawB
            add di,311
            jnc InBound
                cmp cl,14
                jne SkipOOB
                    jmp OOB
            InBound:

            dec cl
            jnz DrawA
            jmp SkipOOB
        OOB: ; kai masina paliecia limita, kordinates naujas pastato
            ; jmp Stop
            lea bp,[CarBuffer]; KAZKODEL jeugi 2 masinos toje pacioje y asyje, tik viena pasalinta, bet kai 3 veikia??
            mov ax,[CarA]; 1 masinos
            mov cx, ax; 1 ciklai
            ; dec ax
            imul ax,3; 1x3 = 3 byte
            add bp,ax; buffer + 1 word, nuo galo ciklas
            xor ax,ax; ax = 0
            xor bx,bx
            ShuffleCarBuf:
                mov dl,[bp-1]; dl = paskutinis el
                mov dh,[bp-2]
                mov bh,[bp-3]
                dec bp
                mov byte [bp],al; paskutinis el =0
                dec bp
                mov byte [bp],ah
                dec bp
                mov byte [bp],bl
                mov ax,dx; al = dl ah = dh
                shr bx,8; ah => al

                ; mov ax,dx; paskutinis elementas bus yrasytas a;acioje esantiem elementam
                ; sub bp,2
                dec cx
                jnz ShuffleCarBuf
            dec word [CarA]
            jnz SkipOOB
            ret


        SkipOOB:

        inc si
        mov ax,[si]
        test ax,ax
        jnz Forward
    
    ret
LoadMapSides:
    xor di,di
    mov cl,200
    ModYSide:
        mov ch,80
        ModXside1:
            mov al,cl
            and al,1
            add al,90
            mov byte [es:di],al
            inc di
            dec ch
            jnz ModXside1
        mov word [es:di],4882
        add di,2

        mov ch,78
        FillCenter:
            mov word [es:di],5654
            add di,2
            dec ch
            jnz FillCenter

        mov word [es:di],4882
        add di,2
        mov ch,80
        ModXSide2:
            mov al,cl
            and al,1
            xor al,1
            add al,90
            mov byte [es:di],al
            inc di
            dec ch
            jnz ModXSide2
        dec cl
        jnz ModYSide
    
    xor di,di
    mov cl,8
    InitializeScorePlaceY:
        mov ch,14
        InitializeScorePlaceX:
            mov word [es:di],4369
            add di,2
            dec ch
            jnz InitializeScorePlaceX
        add di,292
        dec cl
        jnz InitializeScorePlaceY
    ret 
SidesXOR:
    xor di,di
    mov cl,200
    ModYSideB:
        mov ch,80
        ModXsideB1:
            mov ax,[es:di]
            xor ax,1
            mov word [es:di],ax
            inc di
            dec ch
            jnz ModXsideB1

        add di,160

        mov ch,80
        ModXSideB2:
            mov ax,[es:di]
            xor ax,1
            mov word [es:di],ax
            inc di
            dec ch
            jnz ModXSideB2
        dec cl
        jnz ModYSideB
    ret 
DrawSteerWheel:
    mov di,40960
    lea si,[SteerWheel]
    mov ax,[Wheel]
    mov bx,7200
    mul bx
    add si,ax
    ; add si,7200
    ; xor si,si
    ; mov ax,4096
    ; mov ds,ax
    mov ch,72
    DrawY:
        mov cl,50
        DrawX:
            mov ax,[si]
            test ax,ax
            jz Permat3
                mov word [es:di],ax
            Permat3: 
            add di,2
            add si,2
            jnc NoLoadOverflow
                mov ax,ds
                add ax,4096
                mov ds,ax
            NoLoadOverflow: 
                      
            dec cl
            jnz DrawX
        add di,220
        dec ch
        jnz DrawY 
        xor ax,ax
        mov ds,ax
    ret
ScoreUpdate:
    inc word [Score]
    mov di,341

    mov ax,[Score]
    mov bx,10
    mov ch,5
    DrawNS:
        xor dx,dx
        div bx; liekana * 6*4
        imul dx,24
        lea bp,[Numbers]
        add bp,dx
        mov cl,6
        DrawN:
            mov dx,[bp]
            mov word [es:di],dx
            add di,2
            add bp,2
            
            mov dx,[bp]
            mov word [es:di],dx
            add di,2
            add bp,2

            add di,316
            dec cl
            jnz DrawN
        sub di,1925
        dec ch
        jnz DrawNS
    ret
CarFrames:
incbin "CarGame/CarRed9x14.raw"
incbin "CarGame/RedbullCar9x14.raw"
incbin "CarGame/CarGreen9x14.raw"
incbin "CarGame/CarPink9x14.raw"
incbin "CarGame/CarBlue9x14.raw"
incbin "CarGame/CarOrange9x14.raw"
OtherCars:

Numbers:
incbin "CarGame/Numbers/0.raw"
incbin "CarGame/Numbers/1.raw"
incbin "CarGame/Numbers/2.raw"
incbin "CarGame/Numbers/3.raw"
incbin "CarGame/Numbers/4.raw"
incbin "CarGame/Numbers/5.raw"
incbin "CarGame/Numbers/6.raw"
incbin "CarGame/Numbers/7.raw"
incbin "CarGame/Numbers/8.raw"
incbin "CarGame/Numbers/9.raw"
CarBuffer:
dw 156; index
db 0; car type
db 63*3 dup(0)
CarA dw 1
Time dw 0
seed dw 0
Wheel dw 0
mouse_b0 db 0
PlaneIn dw 31840
PFrame dw 0
Score dw 0
SteerWheel:
incbin "CarGame/SteerWheel100x72.raw"
incbin "CarGame/SteerWheel100x72C.raw"
incbin "CarGame/SteerWheel100x72B.raw"
