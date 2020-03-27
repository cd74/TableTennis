data  segment
ls244        equ 2a0h   
io8253a        equ 280h
io8253b        equ 281h
io8253k        equ 283h
io8255a        equ 288h
io8255b        equ 289h
io8255k        equ 28bh
io8255c        equ 28ah   ; a:led, b:dig   it, c0~3:in,c4~8:out
led      db     3fh,06h,5bh,4fh,66h,6dh,7dh,07h,7fh,6fh  ;数码管段码
score   dw   0,0  ;得分
hit db 0,0    ; 球被击标志
mishit db 0,0  ;球被误击标志
smode db 0  ;智能模式标志
string1  db     '08117101 TABLE TENNIS 2019-06-04 Press to start...$'
string2  db     'started ...$'
string3  db    'Press any key to continue$'
string4  db     'WINNER:LEFT PLAYER    $'
string5  db    'WINNER:RIGHT PLAYER    $'
data ends
stacks segment stack
      db 100 dup (?)
stacks ends
code segment
      assume cs:code,ds:data,ss:stacks
main proc far
start:    mov ax,stacks
        mov ss,ax
        mov ax,data
        mov ds,ax
        mov dx,offset string1
        mov ah,09h
        int 21h
       mov dx,io8253k  ;写控制字
       mov al,00110100b       ;使0通道为工作方式2,out端接另一个clk
       out dx,al
       mov dx,io8253k
       mov al,01010100b       ;设8253通道1工作方式2
       out dx,al
       mov dx,io8255k
       mov al,10000001b
       out dx,al
       
fq: mov dx,io8255c           
    in al,dx
    test al,00000010b   ;检测开局
    jz fq
    mov dx,offset string2
    mov ah,09h
    int 21h
    
    mov ax,1000     ;写入循环计数初值
    mov dx,io8253a
    out dx,al        ;先写入低字节
    mov al,ah
    out dx,al        ;后写入高字节
    mov ax,250    ;写入循环计数初值
    mov dx,io8253b
    out dx,al 

    mov bh,1 ;bh=1:灯右移，bh=0:灯左移
    mov bl,01000000b  ;bl存灯状态
    mov ch,4  ;ch存计数次数

lp: mov cl,ch  ;更新新一轮需要的计数次数
    cmp bh,0
    je rotr
    shl bl,1  ;改变灯
    mov dx,io8255a
    mov al,bl
    out dx,al   
    jmp slp
rotr:   
    shr bl,1
    mov dx,io8255a
    mov al,bl
    out dx,al
   
slp:
    mov dx,ls244
    in al,dx
    test al,00001000b  ;智能模式判断
    jne smd
    and al,00000011b   ;球速控制按键判断
    mov ch,al
    inc ch   ;利用计数次数控制每个灯亮的时间
smd:mov [smode],1      
    
    mov dx,io8255c
    in al,dx
    cmp bl,10000000b   ;球是否在最左侧
    jne notl
    test al, 00000001b  ;判断击球按键状态
    jz n1 
    cmp mishit[1],0   ;在此次大循环中是否已经误击过（一个大循环只计一次误击）
    jne n1
    inc score 
    mov mishit[1],1   ;表明在此次大循环中已经误击过
n1: test al, 00000010b
    jz tck
    mov hit,1  ;表明已经回球
    cmp [smode],1    ;智能模式判断
    jne tck
    cmp cl,2         ;判断时间
    ja tck
    mov ch,0         ;改变速度
    jmp tck

notl:
    cmp bl,00000001b   ;球是否在最右侧
    jne notr
    test al, 00000001b   
    jz n2
    mov hit[1],1;接球
    cmp [smode],1
    jne tck
    cmp cl,2
    ja tck
    mov ch,0 
n2: test al, 00000010b
    jz tck
    cmp mishit,0
    jne tck
    inc score[2]
    mov mishit,1
    jmp tck
    
relay:
    jmp slp   ;距离太长，需要跳转两次
    
notr:      ;球在中间
    test al, 00000001b   
    jz n3
    cmp mishit[1],0
    jne n3
    inc score 
    mov mishit[1],1
   ; call digit
n3: test al, 00000010b
    jz tck
    cmp mishit,0
    jne tck
    mov mishit,1
    inc score[2]
    
tck: 
    call digit
    mov dx,io8253b   
    in al,dx   ;读入计数值
    cmp al,1
    ja relay

wt: mov dx,io8253b
    in al,dx
    cmp al,1
    je wt    ;防止1被重复检测到    
    cmp cl,0  ;剩余计数次数是否为0
    je ov
    dec cl   ;剩余计数次数减1
    jmp relay   ;剩余计数次数不为0，仍然进入小循环

ov: cmp bl,10000000b  ;球是否在最左侧
    jne j1
    mov bh,0    ;改变灯移动方向
    cmp hit,0   ;是否回球
    jne w
    inc score[2]    ;没有回球，对方得分
    mov ch,4    ;重设剩余计数次数
    jmp w
j1: cmp bl,00000001b
    jne w
    mov bh,1
    cmp hit[1],0
    jne w 
    inc score
    mov ch,4
    
w:  mov hit,0
    mov hit[1],0
    mov mishit,0
    mov mishit[1],0   ;标志变量清零
    jmp lp      ;进入下一个大循环

exit:         mov ah,09h
                mov dx,offset string3
                int 21h
                mov ah,01h
                int 21h
                mov ah,4ch               ;返回DOS
    int 21h
main endp

digit proc near ;
    cmp word ptr score,9   ;得分是否大于9
    jna cont    
    mov ah,09h
    mov dx,offset string4
    int 21h                                 
    jmp exit   ;退出
cont:
    cmp word ptr score[2],9
    jna cont1
    mov ah,09h
    mov dx,offset string5
    int 21h    
    jmp exit

cont1:   mov dx,io8255b
    mov al,0
    out dx,al   ;送全灭段码

    mov dx,io8255c
    mov al,01000000b
    out dx,al   ;位选
    mov si,[score]
    mov dx,io8255b
    mov al,led[si]
    out dx,al   ;送左侧玩家得分

    mov dx,io8255b
    mov al,0
    out dx,al   ;送全灭段码

    mov dx,io8255c
    mov al,00010000b
    out dx,al
    mov dx,io8255b
    mov si, score[2]
    mov al,led[si]
    out dx,al   ;送右侧玩家得分
    ret
digit endp
code ends
end start
