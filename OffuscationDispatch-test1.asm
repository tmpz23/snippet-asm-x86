; Offuscation, méthodo :
; 
; 1. Convertir les arguments de la fonction à offusquer en adresses relatives à ebp : [ebp], [ebp-4], [ebp-8] etc.
; 2. Séparer en blocks de 3 instructions
; 3. Réorganiser les instructions par blocks de sorte à faire apparaître pour chaque label et pour chaque branchement :
;   [*] le label doit être la première instructions du block
;   [*] le branchement en dernière instructions du block
; 4. On asigne un label global à chaque début de block et un saut à chaque fin de block que l'on numérote de 0 à n :
;   SEG0::
;       SWITCH_CONTEXT32 ; Ceci permet d'inverser les registres ebp et eax pour le bon fonctionnement du dispatcher et du programme
;           ... ; Les instructions du block
;       jmp DEBUT_Dispatcher ; jmp FIN_Dispatcher pour le dernier block
; 5. Pour chaque branchement en fin de block, on va reconfigurer le saut pour passer par le dispatcheur. 
;    Pour sauter au block n, il faut simplement modifier l'indice à (n-2)
;    Exemple :
;       ### CODE A PRENDRE ###
;           jbe mon_label_debut_du_seg9 ; dernière instruction du segment 2
; 
;       ### A MODIFIER PAR ### 
;       ja SEG2_suite
;           mov [indice], 7 ; aller au block 9
;       SEG2_suite::
;
; 6. Créer le tableau d'indices et de pointers de fonctions de la sorte :
;   dispatcher_ind_arr dd 0,1,[...],n
;   dispatcher_labels_arr dd FTO_SEG0, FTO_SEG1, [...] FTO_SEGN
; 
;   dispatcher_ind_arr doit indexer en ordre croissant les fonctions de dispatcher_labels_arr en commençant par 0
;   Exemple : 
;       dispatcher_labels_arr   dd SEG2, SEG0, SEG1 
;       dispatcher_ind_arr      dd       1,    2,    0 ; dernier block (2) en position 0
; 7. Adapter l'appel du Dispatcher avec les arguments : invoke Dispatcher arg1,arg2,arg3,argn
; 8. Mélanger les blocks 


.586
.model flat, stdcall
option casemap: none
ASSUME FS:NOTHING

include     C:\masm32\include\windows.inc 
include     C:\masm32\include\kernel32.inc
includelib  C:\masm32\lib\kernel32.lib
include     C:\masm32\include\msvcrt.inc
includelib  C:\masm32\lib\msvcrt.lib
include     C:\masm32\include\user32.inc
includelib  C:\masm32\lib\user32.lib
include     C:\masm32\include\ntdll.inc
includelib  C:\masm32\lib\ntdll.lib

.data
    data1 dd 2, 5, 6, 3, 7, 1, 2, 8
    size_array dd 32

    str_intro       db "Dump :",0
    str_crlf        db 13,10,0
    format_2x       db " %.02x",0
    format_dwAddr   db 10,13,"%.08x :",0

    context_ebp     dd 0
    context_eax     dd 0

    indice dd -1 ; indice du prochain block
    dispatcher_ind_arr dd 3,5,1,6,4,7,2,8,0
    dispatcher_labels_arr dd FTO_SEG8, FTO_SEG2, FTO_SEG6, FTO_SEG0, FTO_SEG4, FTO_SEG1, FTO_SEG3, FTO_SEG5, FTO_SEG7
    ;                           0,1,2,3,4,5,6,7,8
    ;                           8,2,6,0,4,1,3,5,7

.code
HexDump32 PROTO :DWORD, :DWORD

; changement de contexte pour EAX, EBP
SWITCH_CONTEXT32 MACRO
    push edx ; variable de transition

    mov edx, [context_ebp]
    mov [context_ebp], ebp
    mov ebp, edx

    mov edx, [context_eax]
    mov [context_eax], eax
    mov eax, edx

    pop edx
ENDM


FTO_SEG0::
    SWITCH_CONTEXT32
    push esi
    push edi
    xor eax,eax
    mov edi,dword ptr [ebp+8+4] ; taille en octet du tableau de donnée
    jmp DEBUT_Dispatcher

FTO_SEG1::
    SWITCH_CONTEXT32
    xor esi,esi
    cmp edi,3 ; edi doit être supérieur à 3 donc au moins 4 octets pour travailler (une donnée est sur 32 bits)
    ja FTO_SEG1_suite
        mov [indice], 7 ; aller au block 9
    FTO_SEG1_suite::
    jmp DEBUT_Dispatcher
    
FTO_SEG2::
    SWITCH_CONTEXT32
    mov edx,dword ptr [ebp+8] ; @ du tableau de données
    add edi,0fffffffch
    push ebx
    jmp DEBUT_Dispatcher

FTO_SEG3::
    SWITCH_CONTEXT32
    mov ebx,dword ptr [ebp+8+8] ; masque du XOR
    shr edi,2
    push ebp
    add edi,1
    jmp DEBUT_Dispatcher

FTO_SEG4::
    SWITCH_CONTEXT32
    mov ecx,dword ptr [edx] ; ecx = donnée du tableau
    mov ebp,ecx
    xor ebp,esi ; xor avec la valeur précédante du tableau
    jmp DEBUT_Dispatcher

FTO_SEG5::
    SWITCH_CONTEXT32
    xor ebp,ebx ; xor avec le masque
    mov dword ptr [edx],ebp ; stockage du résultat
    xor eax,ecx
    add edx,4
    jmp DEBUT_Dispatcher

FTO_SEG6::
    SWITCH_CONTEXT32
    sub edi,1
    mov esi,ecx ; esi prend la valeur précédente du tableau
    je FTO_SEG6_suite
        mov [indice], 3 ; aller au block 5
    FTO_SEG6_suite::
    jmp DEBUT_Dispatcher

FTO_SEG7::
    SWITCH_CONTEXT32
    pop ebp
    pop ebx
    jmp DEBUT_Dispatcher

FTO_SEG8::
    SWITCH_CONTEXT32
    pop edi
    pop esi
    jmp FIN_Dispatcher


Dispatcher PROC lpData:DWORD,dwLen:DWORD,dwMask:DWORD
    mov [context_ebp], ebp
    DEBUT_Dispatcher::
        SWITCH_CONTEXT32
        pushf

        lea eax, dispatcher_labels_arr
        push ecx
        push edx

        mov ecx, [indice]
        inc ecx
        mov [indice], ecx

        xor edx, edx
        
        cmp ecx,0
        jz Dispatcher_EndLoop2

        Dispatcher_Loop2 :
            add edx, 4
            loop Dispatcher_Loop2
        Dispatcher_EndLoop2:
        
        add edx, offset dispatcher_ind_arr
        mov ecx, [edx]

        cmp ecx,0
        jz Dispatcher_EndLoop

        Dispatcher_Loop :
            add eax, 4
            loop Dispatcher_Loop
        
        Dispatcher_EndLoop:
        pop edx
        pop ecx
        popf

        jmp dword ptr [eax]
    FIN_Dispatcher::
    ret
Dispatcher ENDP

HexDump32 PROC USES ecx esi ebx edx lpData:DWORD, dwLen:DWORD
    invoke crt_printf, ADDR str_intro ; Affiche le titre du dump
    
    mov esi, lpData
    invoke crt_printf, ADDR format_dwAddr, esi
    
    mov ecx, dwLen
    xor edx,edx
    
    HD_loop :
        push ecx
        push edx

        movzx ebx, BYTE PTR [esi]
        invoke crt_printf, ADDR format_2x, ebx

        pop edx
        pop ecx

        inc edx
        inc esi
        
        cmp edx,16

        jb HD_continuerLigne
        cmp ecx,1
        jz HD_continuerLigne
        
        push ecx
        invoke crt_printf, ADDR format_dwAddr, esi ; On affiche l'adresse de dump actuelle
        pop ecx
        xor edx,edx

        HD_continuerLigne:
        loop HD_loop

    invoke crt_printf, ADDR str_crlf ; Saut de ligne final

    ret
HexDump32 ENDP

start:
    ;dump initial
    invoke HexDump32, ADDR data1, 32

    ; adresse du tableau, taille du tableau de donnée en octet, masque XOR
    invoke Dispatcher, ADDR data1, size_array, 0ffffffffh

    ;dump final
    invoke HexDump32, ADDR data1, 32

    ; on quitte le programme
    end_program:
    invoke ExitProcess, 0
end start