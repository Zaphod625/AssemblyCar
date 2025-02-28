; PIC18F45K22 Assembly code for pic-as v2.50
#include <xc.inc>

; CONFIG directives
CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register)

;========== Definition of variables ==========
RESULTHI    equ 0x00          ; Variable to store high byte of ADC result
Delay1      equ 0x01          ; Counter variable for delay loops
Delay2      equ 0x02          ; Counter variable for nested delay loops
Delay3      equ 0x03          ; Counter variable for longer delay loops
Delay4      equ 0x04          ; Counter variable for nested longer delay loops
Counter     equ 0x05          ; Counter for LED flashing repetitions
TempC       equ 0x06          ; Temporary storage for PORTC LED pattern
WhiteVal    equ 0x07          ; Storage for white calibration ADC value
RedVal      equ 0x08          ; Storage for red calibration ADC value
GreenVal    equ 0x09          ; Storage for green calibration ADC value
BlueVal     equ 0x0A          ; Storage for blue calibration ADC value
BlackVal    equ 0x0B          ; Storage for black calibration ADC value
IntExt0	    equ 0x0C          ; Flag for interrupt state (0=proceed, 1=wait)
ADCResult   equ	0x20	      ; Rsult from reading the ADC
     
PSECT code,abs //Start of main code.     
org	0x00
GOTO	Setup
     
org	0x08
GOTO	HP_ISR
     
org	0x18
GOTO	LP_ISR



; Interrupt Vector
//PSECT intVec,class=CODE,reloc=2
//intVec:
//    BTFSC   INTCON3, 1        ; Check INT2IF bit - was INT2 triggered?
//    goto    ISRDump           ; If INT2IF set (bit=1), go to ISRDump (color detection routine)
//    goto    ISRCali           ; Otherwise handle INT1 (calibration trigger)
    
; Main program

 
; ========== Setup ADC and Port A for LEDs on RA<7:4> on Curiosity ==========
Setup:

    ; --- Set up I/O ---
        BSF     TRISC, 3 ,0            ; Set RC3 as input (analog)
        BSF     ANSELC, 3, 0           ; Set RC3 as analog
;	MOVLB   0x0F
;	CLRF    PORTB
;	CLRF    LATB
;	MOVLW   0xF0
;	MOVWF   ANSELB
;	MOVLW   0xFF
;	MOVWF   TRISB
 ;   SETF   TRISB           ; Set all PORTC pins as outputs
   ; MOVLW   0x00              ; Load 0 into W register
  ;  CLRF   ANSELB            ; Set all PORTC pins as outputs
 
	

    ; --- Set up ADC ---
        ;MOVLB   0xF                   ; Switch to Bank F for ADC registers
        CLRF    ADRESH, 0              ; Clear ADC result high byte
	
	; Configure ADCON2: Left justify result (ADRESH contains 8 MSBs)
        MOVLW   0x2F                   ; Left justify, ADC clock = Frc, acquisition time = 12 TAD
        MOVWF   ADCON2, 0
	
        ; Configure ADCON1: Use Vref+ = Vdd and Vref- = Vss
        MOVLW   0x00            
        MOVWF   ADCON1, 0

        BSF	ADON			;Enable AN0 of ADC
	
        ; Configure ADCON0: Select channel AN15 (RC3) and enable ADC
        MOVLW   0x3F                   ; CHS = 1111 (AN15), ADON = 1
        MOVWF   ADCON0, 0
	
    
    CLRF    PORTD             ; Initialize PORTC by clearing outputs (all pins low)
    MOVLW   0x00              ; Load 0 into W register
    MOVWF   ANSELD            ; Set all PORTC pins as digital I/O
    MOVLW   0x00              ; Load 0 into W register
    MOVWF   TRISD             ; Set all PORTC pins as outputs
    
    ; Set up Port B pin B.0 for external interrupt
    ;BSF     TRISB, 0          ; Set RB0 as input (1=input)
    ;BCF     ANSELB,0
    ;CLRF    ANSELB,0            ; Configure all PORTB pins as digital
	MOVLB   0x0F
	CLRF    PORTB
	CLRF    LATB
	MOVLW   0xF0
	MOVWF   ANSELB		;sets RB4-RB7 as analog inputs and RB0-RB3 as digital pins.
	MOVLW   0xFF
	MOVWF   TRISB
     
    MOVLB   0x0               ; Return to Bank 0 for normal operation
    
    ; Set up external interrupt
    CLRF    INTCON3           ; Clear all interrupt flags and enable bits
    MOVLW   0b01001000
    MOVWF   INTCON3
    CLRF    INTCON2
   // MOVLW   0b11011000        ; Configure INT2: enable INT2 interrupt, high priority, falling edge_BAN just focusing on the 1 pin for now
   // MOVWF   INTCON3           ; Write to INT control register
    CLRF    INTCON            ; Clear all interrupt control flags
    MOVLW   0b01010000
    MOVWF   INTCON
    BSF	    GIE		      ; enable interrupts
    MOVLW   0x00              ; Load 0 into W
    MOVWF   IntExt0
    //MOVWF   RCON              ; Reset control register - clear all bits
    
    GOTO    Main
    
Main:
    CALL	ADC_Start
   // CALL	ADC_read
    MOVLW	0x00
    CPFSGT	IntExt0
    GOTO	Main		    ; if not equal, means the interupt has not happened, IntExt0 is 0x00
    MOVLW	0x1F
    CPFSGT	IntExt0
    GOTO	Reg_Dump
    CALL	Calibrate	    ; If equal, call the subroutine
    GOTO	Main
   
    
HP_ISR:
    BTFSC   INTCON,1
    CALL    IntExt0_RB0
    BTFSC   INTCON3,0
    CALL    IntExt1_RB1
    RETFIE  1

IntExt0_RB0:
    MOVLW   0b01000000
    MOVWF   INTCON
    MOVLW   0xFF
    MOVWF   IntExt0
    return
IntExt1_RB1:
    MOVLW   0b01000000
    MOVWF   INTCON
    MOVLW   0x00
    MOVWF   INTCON3
    MOVLW   0xF
    MOVWF   IntExt0
    return
LP_ISR:
    RETFIE  1

Reg_Dump:
    MOVFF   ADRESH, PORTD
    CAll    Delay2s
    MOVLW   0x00
    MOVWF   IntExt0
    MOVLW   0b01001000
    MOVWF   INTCON3
    MOVLW   0b11010000
    MOVWF   INTCON
    
    GOTO    Main
    
Calibrate:
    Call CaliWhite
    Call CaliRed
    Call CaliGreen
    Call CaliBlue
    Call CaliBlack
    
    MOVLW   0x00
    MOVWF   IntExt0
    MOVLW   0b11010000
    MOVWF   INTCON
    GOTO    Main   
    
CaliWhite:
    MOVLW   0b00000001
    MOVWF   PORTD;
    CALL    Delay2s
    CALL    ADC_Start
    movff   ADRESH, WhiteVal  ; Store current ADC reading in BlackVal
    CALL    Delay3Hz
    return

CaliRed:
    MOVLW   0b00001010
    MOVWF   PORTD;
    CALL    Delay2s
    CALL    ADC_Start
    movff   ADRESH, RedVal  ; Store current ADC reading in BlackVal
    CALL    Delay3Hz
    return
   
CaliGreen:
    MOVLW   0b10001000
    MOVWF   PORTD;
    CALL    Delay2s
    CALL    ADC_Start
    movff   ADRESH, GreenVal  ; Store current ADC reading in BlackVal
    CALL    Delay3Hz
    return
    
CaliBlue:
    MOVLW   0b01000100
    MOVWF   PORTD;
    CALL    Delay2s
    CALL    ADC_Start
    movff   ADRESH, BlueVal  ; Store current ADC reading in BlackVal
    CALL    Delay3Hz
    return
    
CaliBlack:
    movlw   0xFF
    MOVWF   PORTD;
    CALL    Delay2s
    CALL    ADC_Start
    movff   ADRESH, BlackVal  ; Store current ADC reading in BlackVal
    CALL    Delay3Hz
    return                    ; Return from subroutine
    
FlashLED:
    movff   TempC, PORTD      ; Display LED pattern from TempC
    call    Delay3Hz          ; Wait for 0.333 seconds
    movlw   0x00              ; Load 00000000b (all LEDs off)
    movwf   PORTD             ; Turn off all LEDs
    call    Delay3Hz          ; Wait for 0.333 seconds
    DCFSNZ  Counter, f        ; Decrement Counter, skip next if not zero
    return                    ; If Counter = 0, return from subroutine
    goto    FlashLED          ; Otherwise continue flashing
    
Delay3Hz:                     ; Delay of approximately 0.333 seconds (3Hz)
    movlw   0x76              ; Load 118 decimal into W
    movwf   Delay2            ; Set outer loop counter
Go_on1:            
    movlw   0x76              ; Load 118 decimal into W
    movwf   Delay1            ; Set inner loop counter
Go_on2:
    decfsz  Delay1, f         ; Decrement inner counter, skip next if zero
    goto    Go_on2            ; If not zero, continue inner loop
    decfsz  Delay2, f         ; Decrement outer counter, skip next if zero
    goto    Go_on1            ; If not zero, continue outer loop
    return                    ; Return after delay complete
    
Delay2s:                      ; Delay of approximately 2 seconds
    movlw   0xFF              ; Load 255 decimal into W
    movwf   Delay4            ; Set outer loop counter
Go_on3:            
    movlw   0xFF              ; Load 255 decimal into W
    movwf   Delay3            ; Set inner loop counter
Go_on4:
     decfsz  Delay3, f         ; Decrement inner counter, skip next if zero
    goto    Go_on4            ; If not zero, continue inner loop
    decfsz  Delay4, f         ; Decrement outer counter, skip next if zero
    goto    Go_on3            ; If not zero, continue outer loop
    return                    ; Return after delay complete
    
    
ADC_Start:
        ; --- Start an ADC conversion on RC3 ---
	BSF 	GO 		; Start conversion
	;BSF     ADCON0, 1           ; Start ADC conversion
        BTFSC   ADCON0, 1           ; Wait until conversion complete
	BRA 	$-2 
	RETURN
ADC_read:
        ; --- Retrieve ADC Result ---
        MOVF    ADRESH, 0           ; Move ADRESH to W (contains 8 MSBs of ADCResult)
        MOVWF   ADCResult           ; Store ADC result in variable
	GOTO	Check_0_1V
	GOTO	Main

	
Check_0_1V:
        ; Check if ADCResult < 51 (0-1V range)
        MOVLW   51                  ; This needs to be updated to Black, and the same logic to the rest
        SUBWF   ADCResult,W         ; W = ADCResult - 51
        BTFSC   STATUS, 0           ; If ADCResult < 51 (C is set), go to 0-1V range
        GOTO    Check_1_2V          
        MOVLW   0x01                ; Output "00000001" for 0-1V
	MOVWF   PORTD
	CALL    Delay2s
	return
Check_1_2V:
        MOVLW   102                 
        SUBWF   ADCResult,W         ; W = ADCResult - 102
        BTFSC   STATUS, 0           
        GOTO    Check_2_3V          
        MOVLW   0x03                ; Output "00000011" for 1-2V
        MOVWF   PORTD
        CALL    Delay2s
        return

Check_2_3V:
        MOVLW   153                 
        SUBWF   ADCResult,W         ; W = ADCResult - 153
        BTFSC   STATUS, 0           
        GOTO    Check_3_4V          
        MOVLW   0x07                ; Output "00000111" for 2-3V
        MOVWF   PORTD
        CALL    Delay2s
        return

Check_3_4V:
        MOVLW   204                 
        SUBWF   ADCResult,W         ; W = ADCResult - 204
        BTFSC   STATUS, 0           
        GOTO    Check_4_5V          
        MOVLW   0x0F                ; Output "00001111" for 3-4V
        MOVWF   PORTD
        CALL    Delay2s
        return

Check_4_5V:
        MOVLW   0x1F                ; Output "00011111" for 4-5V
        MOVWF   PORTD
        CALL    Delay2s
        return

    GOTO    Main                ; Repeat process
END                          ; End of program file