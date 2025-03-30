; Example 1: Set duty cycle at 25%
    ; See HoPE p. 566
    ; CCPRL1 = 0.25 x (PR2+1) = 0.25 x 20 = 5
    
    ;Pulse Width = CCPRxL:CCP1CON<5:4>. TOSC . (TMRx Prescale Value)
    
    ;Duty Cycle= (CCPR1L+CCP1CON<5:4>)/(PR2+1)4
    
    PROCESSOR 18F45K22

    CONFIG  FOSC = INTIO67        ; Internal oscillator
    CONFIG  WDTEN = OFF           ; Disable Watchdog Timer

    #include <xc.inc>
    #include "pic18f45k22.inc"

PSECT code, abs
    org  00h
    goto INIT

INIT:      
   
    PWM1  equ  0x20
    PWM2  equ  0x21
    state equ  0x22
    D1    equ  0x23
    D2    equ  0x24
    
    
    movlw   0b01010110 ; Set internal oscillator to 4 MHz
    movwf   OSCCON
    
    movlw   0x13         ; PWM period of 50 kHz
    movwf   PR2        ; 0001 0011
    
    clrf    TMR2          
    clrf    T2CON
    
    movlw   0b00000100  ; Configure Timer2 Enable Timer2 with 1:1 prescaler
    movwf   T2CON
    
    movlw  0x05          
    movwf  PWM1
    
    movf    PWM1          ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty cu
    movwf   CCPR1L       ; using ccp1 module 
    
;Fraction can be approximated in quarters, i.e. 0.25, 0.5, 0.75. We choose 0.5
;DC1B<1:0> in CCP1CON = 0b10  the 2 lsb in the pwm duty cycle
    bcf	CCP1CON,4
    bsf	CCP1CON,5
    
    clrf    PORTC      ;clear port c
    clrf    LATC   
    bcf     TRISC,2    ; RC2/CCP1 as output
    bcf     TRISC,1    ; RC1/CCP2 as output (PWM2)
    
    movlb   0xf 
    clrf    ANSELC     ;Set all PORTC pins as digital
    bcf     TRISC,4    ;gonna use these two for directional control 
    bcf     TRISC,5    ;outputs motor a
    
    bcf     TRISC,6    ;gonna use these two for directional control 
    bcf     TRISC,7    ;outputs  motor b
    movlb   0x0
   
    BCF     CCP1CON,0   ; confiure bits for ccp module for pwm mode (11xx)
    BCF     CCP1CON,1
    BSF     CCP1CON,2
    BSF     CCP1CON,3
    
    BCF     CCP2CON,0   ; Configure bits for PWM mode (11xx)
    BCF     CCP2CON,1
    BSF     CCP2CON,2
    BSF     CCP2CON,3
    
    movlw  0x05          
    movwf  PWM2

    movlw   PWM2          ; Set duty cycle for CCP2 (25% like CCP1)
    movwf   CCPR2L

    bcf     CCP2CON,4     ; Set the 2 LSBs for finer duty cycle control
    bsf     CCP2CON,5
    
switch_block:
    bsf  state, 0   ; forward
    ;bsf  state, 1   ; reverse
    ;bsf  state, 2   ; left
    ;bsf  state, 3   ; right
    ;bsf  state, 4   ; stop 
    
Main:
    btfss   state,0         
    goto    Reverse           

    bsf     LATC,4             ; Set RC4 HIGH (Motor A Forward)
    bcf     LATC,5             ; Set RC5 LOW (Motor A Forward)
    bsf     LATC,6             ; Set RC6 HIGH (Motor B Forward)
    bcf     LATC,7             ; Set RC7 LOW (Motor B Forward)
    goto    Main               ; Keep looping to check state

Reverse:
    btfss   state,1         
    goto    Left               
    
    bcf     LATC,4             ; Set RC4 LOW (Motor A Reverse)
    bsf     LATC,5             ; Set RC5 HIGH (Motor A Reverse)
    bcf     LATC,6             ; Set RC6 LOW (Motor B Reverse)
    bsf     LATC,7             ; Set RC7 HIGH (Motor B Reverse)
    goto    Main               ; Keep looping to check state

Left:
    btfss   state,2           
    goto    Right           
    
    bsf     LATC,4             ; Set RC4 HIGH (Motor A Forward)
    bcf     LATC,5             ; Set RC5 LOW (Motor A Forward)
    bcf     LATC,6             ; Set RC6 LOW (Motor B Reverse)
    bsf     LATC,7             ; Set RC7 HIGH (Motor B Reverse)
    goto    Main               ; Keep looping to check state

Right:
    btfss   state,3           
    goto    Stop 
    
    bcf     LATC,4             ; Set RC4 LOW (Motor A Reverse)
    bsf     LATC,5             ; Set RC5 HIGH (Motor A Reverse)
    bsf     LATC,6             ; Set RC6 HIGH (Motor B Forward)
    bcf     LATC,7             ; Set RC7 LOW (Motor B Forward)
    goto    Main               ; Keep looping to check state

Stop:
    btfss   state,4          
    goto    Main
    
    bcf     LATC,4             ; Set RC4 LOW (Motor A Stop)
    bcf     LATC,5             ; Set RC5 LOW (Motor A Stop)
    bcf     LATC,6             ; Set RC6 LOW (Motor B Stop)
    bcf     LATC,7             ; Set RC7 LOW (Motor B Stop)
    goto    Main               ; Keep looping to check state

DELAY:                        ; delay if needed for the motor states 
    movlw   0xFF      
    movwf   D1         
DELAY_LOOP_1:
    movlw   0xFF      
    movwf   D2         
DELAY_LOOP_2:               
    decfsz  D2, f      
    goto    DELAY_LOOP_2 

    decfsz  D1, f     
    goto    DELAY_LOOP_1 
    return
    
    end