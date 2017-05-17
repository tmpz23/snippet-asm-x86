; masm32

include		C:\masm32\include\msvcrt.inc
includelib	C:\masm32\lib\msvcrt.lib

; use : invoke HexDump32, lpData, 32
; use : invoke HexDump32, lpData, 123

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