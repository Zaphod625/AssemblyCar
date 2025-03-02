

; RGB LED with 2 Second Constant Display for PIC18F45K22 on Curiosity Board
; For MPLAB X with pic-as assembler
    PROCESSOR 18F45K22
    #include <xc.inc>
    
; Configuration bits
CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block)
CONFIG  WDTEN = OFF           ; Watchdog Timer disabled
; Variables
    PSECT udata
Delay1:     DS 1
Delay2:     DS 1
Delay3:     DS 1              ; Added for longer delay
    PSECT code
    
    ORG 0x0000
    GOTO Main
    
Main:
    ; Initialize Port C for RGB LED control
    CLRF    PORTC
    MOVLW   0x00
    MOVWF   ANSELC
    MOVLW   0x00
    MOVWF   TRISC
    ; Main loop for LED display
ColorLoop:
    ; Red LED
    MOVLW   0x40        ; RGB Red pin on Port C
    MOVWF   PORTC
    CALL    Delay2Sec   ; Keep LED on for 2 seconds
    
    ; Green LED
    MOVLW   0x20        ; RGB Green pin on Port C
    MOVWF   PORTC
    CALL    Delay2Sec   ; Keep LED on for 2 seconds
    
    ; Blue LED
    MOVLW   0x10        ; RGB Blue pin on Port C
    MOVWF   PORTC
    CALL    Delay2Sec   ; Keep LED on for 2 seconds
    
    ; White (all LEDs)
    MOVLW   0x70        ; All RGB pins on Port C
    MOVWF   PORTC
    CALL    Delay2Sec   ; Keep LED on for 2 seconds
    
    GOTO    ColorLoop   ; Repeat the sequence

; Delay for approximately 2 seconds
Delay2Sec:
    MOVLW   0x0A        ; Outer loop counter for longer delay
    MOVWF   Delay3
Delay_outermost:
    MOVLW   0xFF
    MOVWF   Delay2
Delay_outer:
    MOVLW   0xFF
    MOVWF   Delay1
Delay_inner:
    DECFSZ  Delay1, F
    GOTO    Delay_inner
    DECFSZ  Delay2, F
    GOTO    Delay_outer
    DECFSZ  Delay3, F
    GOTO    Delay_outermost
    RETURN
    END
