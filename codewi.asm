ASSUME DS:DATA, CS:CODE, SS:STK

; SUM I=1..N OF (I^J - 5), J IS A PARAMETER

CODE SEGMENT
JMP START
	START:
	MOV AX, DATA
		MOV DS, AX
	
		MOV AX, STK
		MOV SS, AX
		
		CALL INPUT
		MOV N,AX
		CALL INPUT
		MOV J,AX
	
		;СОХРАНИМ АДРЕС Ф-ИИ ДОС 60H В ПЕРЕМЕННОЙ
		;ПАРА BX:ES ПОСЛЕ ВЫПОЛНЕНИЯ 21H БУДЕТ СОДЕРЖАТЬ СЕГМЕНТ:СМЕЩЕНИЕ
		PUSH DS	
		PUSH DX
		MOV AH,35H  ;Ф-Я ПОЛУЧЕНИЯ ВЕКТОРА
		MOV AL,60H	;НОМЕР ВЕКТОРА
		INT 21H
		MOV WORD PTR OLD_60H, BX
		MOV WORD PTR OLD_60H + 2, ES
		POP DX
		POP DS
		;ТЕПЕРM OLD_60H СОДЕРЖИТ АДРЕС
	
		;УСТАНОВИМ ПРОЦЕДУРУ CYCLE В КАЧЕСТВЕ НОВОГО ОБРАБОТЧИКА 60H
		PUSH DS			
		PUSH DX
		MOV AH,25H	;Ф-Я ЗАПОЛНЕНИЯ В-РА
		MOV AL, 60H	;ЕГО НОМЕР
		MOV DX, OFFSET CYCLE	;СМЕЩЕНИЕ ОБРАБОТЧИКА
		PUSH DS	;СОХРАНИМ DS=DATA
		PUSH CS	;ПЕРЕСЫЛАЕМ CS В DS
		POP DS	;DS:DX -> CYCLE
		INT 21H
		POP DS	;ВОССТАНОВИМ DS=DATA
		POP DX
		POP DS

		;ВЫЗОВЕМ ПОДПРОГРАММУ ПОДСЧЕТА		
		INT 60H
		
		
		;ВОССТАНОВИМ СТАРЫЙ ОБРАБОТЧИК 60H
		PUSH DS			
		PUSH DX
		LDS DX, OLD_60H ;ЗАПОЛНИМ DS:DX ИЗ OLD_60H
		MOV AH, 25H	
		MOV AL, 60H
		INT 21H	
		POP DX
		POP DS
		
		MOV AX, RES
		
		CALL OUTPUT
		MOV AX, 4C00H
		INT 21H ;КОНЕЦ
	
	
	CYCLE PROC
	
		MOV AX, 0
		MOV DI, J
		MOV CX, 1
	
		M1:
			SUB DI, 5
			MOV BX, CX
			XOR BX, DI
			ADD AX, BX	
			INC CX
			CMP CX, N
			JG M2
			JMP M1
	
		M2:
			MOV BX, AX
	
		MOV RES, BX
		IRET
	CYCLE ENDP
	
	
	INPUT PROC 
	;Ф-Я ВВОДА СТРОКИ В БУФЕР
    MOV AH,0AH
    XOR DI,DI
    MOV DX,OFFSET BUFF ; АДРЕС БУФЕРА
    INT 21H ; ПРИНИМАЕМ СТРОКУ
	;DL - СИМВОЛ ДЛЯ ВЫВОДА В КОНСОЛЬ
	;ДАЛЬШЕ ДЛЯ ОТОБРАЖЕНИЯ В КОНСОЛИ БЕЗ ЭХА
    MOV DL,0AH
    MOV AH,02H
    INT 21H
    
	; ОБРАБАТЫВАЕМ СОДЕРЖИМОЕ БУФЕРА
    MOV SI,OFFSET BUFF + 2 ; БЕРЕМ АДРЕС НАЧАЛА СТРОКИ
    CMP BYTE PTR [SI],"-" ; ЕСЛИ ПЕРВЫЙ СИМВОЛ МИНУС
    JNZ II1
    MOV DI,1  ; УСТАНАВЛИВАЕМ ФЛАГ
    INC SI    ; И ПРОПУСКАЕМ МИНУС
	
	II1:
		XOR AX,AX
		MOV BX,10  ;ОСНОВАНИЕ СИСТ.СЧИСЛ
	II2:
		MOV CL,[SI] ;БЕРЕМ СИМВОЛ ИЗ БУФЕРА
		CMP CL,0DH  ;ПРОВЕРЯЕМ НЕ ПОСЛЕДНИЙ ЛИ ОН
		JZ ENDINP
    
		;ЕСЛИ СИМВОЛ НЕ ПОСЛЕДНИЙ, ТО ПРОВЕРЯЕМ ЕГО НА ПРАВИЛЬНОСТЬ
		CMP CL,'0'  ;ЕСЛИ ВВЕДЕН НЕВЕРНЫЙ СИМВОЛ <0
		JL ER
		CMP CL,'9'  ;ЕСЛИ ВВЕДЕН НЕВЕРНЫЙ СИМВОЛ >9
		JA ER
		SUB CL,'0' ;ДЕЛАЕМ ИЗ СИМВОЛА ЧИСЛО 
		MUL BX     ;УМНОЖАЕМ НА 10
		ADD AX,CX  ;ПРИБАВЛЯЕМ К ОСТАЛЬНЫМ
		INC SI     ;УКАЗАТЕЛЬ НА СЛЕДУЮЩИЙ СИМВОЛ
		JMP II2     ;ПОВТОРЯЕМ
 
	ER:   ;ЕСЛИ БЫЛА ОШИБКА, ТО ВЫВОДИМ СООБЩЕНИЕ ОБ ЭТОМ И ВЫХОДИМ
		MOV DX, OFFSET msg
		MOV AH,09
		INT 21H
		MOV AX, 4C00H
		INT 21H
 
	;ВСЕ СИМВОЛЫ ИЗ БУФЕРА ОБРАБОТАНЫ, ЧИСЛО НАХОДИТСЯ В AX
	ENDINP:
		CMP DI,1 ;ЕСЛИ БЫЛА УСТАНОВЛЕНА 1, ТО НЕ ПРЫГАЕМ
		JNZ II3
		NEG AX   ;И ДЕЛАЕМ ЧИСЛО ОТРИЦАТЕЛЬНЫМ
		
	II3:
		RET
	INPUT ENDP
	
	
	OUTPUT PROC	
	;ПРОВЕРЯЕМ ЧИСЛО НА ЗНАК
	;ПОСЛЕ ЭТОЙ ОПЕРАЦИИ УСТАНАВЛИВАЕТСЯ ФЛАГ ЗНАКА .
	   TEST    AX, AX
	   JNS     OI1
	;ЕСЛИ ОНО ОТРИЦАТЕЛЬНОЕ, ТО ПРОДОЛЖИМ ВЫПОЛНЕНИЕ:
	;ВЫВЕДЕМ МИНУС И ОСТАВИМ ЛИШЬ МОДУЛЬ ЧИСЛА.
	;ЕСЛИ ПОЛОЖИТЕЛЬНОЕ – ПРЫЖОК НА OI1
	   MOV  CX, AX
	   MOV     AH, 02H
	   MOV     DL, '-'
	   INT     21H
	   MOV  AX, CX
	   NEG     AX
	;КОЛИЧЕСТВО ЦИФР ДЕРЖИМ В CX
	OI1:  
		XOR     CX, CX
		MOV     BX, 10 ;ОСНОВАНИЕ СИСТ.СЧИСЛ
	OI2:
		XOR     DX,DX
		DIV     BX
	;ДЕЛИМ ЧИСЛО НА ОСНОВАНИЕ СС, В ОСТАТКЕ ПОЛУЧАЕТСЯ ПОСЛЕДНЯЯ ЦИФРА.
	;ВЫВОДИМ В ОБРАТНОМ ПОРЯДКЕ, ПОЭТОМУ ТОЛКАЕМ В СТЭКЕ.
		PUSH    DX
		INC     CX
	;С ЧАСТНЫМ ПОВТОРЯЕМ ТО ЖЕ САМОЕ, ОТДЕЛЯЯ ОТ НЕГО ОЧЕРЕДНУЮ
	;ЦИФРУ СПРАВА, ПОКА НЕ ОСТАНЕТСЯ НОЛЬ (TEST AX, AX)
		TEST    AX, AX
		JNZ     OI2
	;ТЕПЕРЬ ПРИСТУПИМ К ВЫВОДУ.
		MOV     AH, 02H
	OI3:
		POP     DX
	;ИЗВЛЕКАЕМ ОЧЕРЕДНУЮ ЦИФРУ, ПЕРЕВОДИМ ЕЁ В СИМВОЛ И ВЫВОДИМ.
		ADD     DL, '0'
		INT     21H
	;ПОВТОРИМ РОВНО СТОЛЬКО РАЗ, СКОЛЬКО ЦИФР НАСЧИТАЛИ.
		LOOP    OI3	
		RET
	OUTPUT ENDP
	
CODE ENDS

DATA SEGMENT
	msg DB "INCORRECT NUMBER$"
	BUFF DB 6,7 DUP(?)
	
	OLD_60H DD ? ;ХРАНИТ АДРЕС ОБРАБОТЧИКА ПО УМОЛЧАНИЮ
	N DW 0
	J DW 0
	RES DW 0	
DATA ENDS

STK SEGMENT STACK
	DB 256 DUP (?)
STK ENDS
	
	END START