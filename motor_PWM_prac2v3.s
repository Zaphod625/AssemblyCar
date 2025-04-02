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
    D3    equ  0x25
    
    
    movlw   0b01010110 ; Set internal oscillator to 4 MHz
    movwf   OSCCON
    
    movlw   0x13         ; PWM period of 50 kHz
    movwf   PR2          ; 0001 0011
    
    clrf    TMR2          
    clrf    T2CON
    
    movlw   0b00000100  ; Configure Timer2 Enable Timer2 with 1:1 prescaler
    movwf   T2CON
    
    ;movlw  0x05          
    ;movwf  PWM1
    ;movf   PWM1          ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty cu
    ;movwf  CCPR1L        ; using ccp1 module 
    
;Fraction can be approximated in quarters, i.e. 0.25, 0.5, 0.75. We choose 0.5
;DC1B<1:0> in CCP1CON = 0b10  the 2 lsb in the pwm duty cycle
    bcf	CCP1CON,4
    bsf	CCP1CON,5
    
    clrf    PORTC      ;clear port c
    clrf    PORTB  
    bcf     TRISC,2    ; RC2/CCP1 as output  (PWM1)
    bcf     TRISC,1    ; RC1/CCP2 as output (PWM2)
    bcf     TRISB,6    ;gonna use these two for directional control 
    bcf     TRISB,7    ; both digital
    
    movlb   0xf 
    bcf     ANSELC,1    ;Set all PORT pins as digital
    bcf     ANSELC,2 
    bsf     ANSELB,6 
    bsf     ANSELB,7 
    movlb   0x0
   
    BCF     CCP1CON,0   ; confiure bits for ccp module for pwm mode (11xx)
    BCF     CCP1CON,1
    BSF     CCP1CON,2
    BSF     CCP1CON,3
    
    BCF     CCP2CON,0   ; Configure bits for PWM mode (11xx)
    BCF     CCP2CON,1
    BSF     CCP2CON,2
    BSF     CCP2CON,3
    
    ;movlw   0x05          ; Set duty cycle for CCP2 (25% like CCP1)
    ;movwf   PWM2
    ;movlw   PWM2   
    ;movwf   CCPR2L

    bcf     CCP2CON,4     ; Set the 2 LSBs for finer duty cycle control
    bsf     CCP2CON,5

  
Main:
    
    call  Forward 
    call  DELAY
    
    call  Fast_forward 
    call  DELAY
    
    call  Reverse
    call  DELAY
    
    call  Stop
    call  DELAY
    
    call  Left
    call  DELAY
    
    call  Right
    call  DELAY

    goto Main

Forward:
    bsf     LATB,6
    bsf     LATB,7
    
    movlw   0x05           ; left wheel only turns 
    movwf   PWM1
    movf    PWM1          ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty 
    movwf   CCPR1L   
    
    movlw   0x05           ; right wheel turns  very slowly
    movwf   PWM2
    movf    PWM2          ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty 
    movwf   CCPR2L
    
    return

Reverse:
    bcf     LATB,6
    bcf     LATB,7
    
    movlw   0x05           ; left wheel only turns 
    movwf   PWM1
    movf    PWM1          ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty 
    movwf   CCPR1L   
    
    movlw   0x05          ; right wheel turns  very slowly
    movwf   PWM2
    movf    PWM2          ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty 
    movwf   CCPR2L 
    
    return

Left:
    ; Left turn (Motor A Forward, Motor B Reverse)
    bsf     LATB,6
    bcf     LATB,7
    
    movlw   0x00           ; left wheel only turns 
    movwf   PWM1
    movf    PWM1          ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty 
    movwf   CCPR1L   
    
    movlw   0x05           ; right wheel turns  very slowly
    movwf   PWM2
    movf    PWM2          ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty 
    movwf   CCPR2L 
    
    return

Right:
    ; Right turn (Motor A Reverse, Motor B Forward)
    bcf     LATB,6
    bsf     LATB,7
    
    movlw   0x05           ; left wheel only turns 
    movwf   PWM1
    movf    PWM1          ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty
    movwf   CCPR1L   
    
    movlw   0x00           ; right wheel turns  very slowly
    movwf   PWM2
    movf    PWM2          ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty
    movwf   CCPR2L 
    
    return

Stop:
    ; Stop both motors
    bcf     LATB,6
    bcf     LATB,7
    
    movlw   0x00           ; left wheel only turns 
    movwf   PWM1
    movf    PWM1          ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty
    movwf   CCPR1L   
    bcf	    CCP1CON,4     ; two lsb in the duty cycle
    bcf	    CCP1CON,5
    
    movlw   0x00           ; right wheel turns  very slowly
    movwf   PWM2
    movf    PWM2          ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty cu
    movwf   CCPR2L 
    bcf	    CCP2CON,4     ; two lsb in the duty cycle
    bcf	    CCP2CON,5
    
    return

Hard_right:
    bcf     LATB,6
    bsf     LATB,7
    
    movlw   0x0F           ; left wheel only turns 
    movwf   PWM1
    movf    PWM1          ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty
    movwf   CCPR1L   
    bsf	    CCP1CON,4     ; two lsb in the duty cycle
    bsf	    CCP1CON,5
    
    movlw   0x00           ; right wheel turns  very slowly
    movwf   PWM2
    movf    PWM2          ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty cu
    movwf   CCPR2L 
    bcf	    CCP2CON,4     ; two lsb in the duty cycle
    bcf	    CCP2CON,5
    
    return
    
Hard_left:
    bcf     LATB,6
    bsf     LATB,7
    
    movlw   0x00           ; left wheel turns very slowly
    movwf   PWM1
    movf    PWM1          ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty cu
    movwf   CCPR1L 
    bcf     CCP1CON,4     ; two lsb in the duty cycle
    bcf	    CCP1CON,5
    
    movlw   0x0F           ; right wheel only turns 
    movwf   PWM2
    movf    PWM2           ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty cu
    movwf   CCPR2L   
    bsf	    CCP2CON,4      ; two lsb in the duty cycle
    bsf	    CCP2CON,5
    
    return
    
Fast_forward:
    bsf     LATB,6
    bsf     LATB,7
    
    movlw   0x0F           ; both wheels turn 
    movwf   PWM1
    movf    PWM1           ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty 
    movwf   CCPR1L   
    bsf	    CCP1CON,4      ; two lsb in the duty cycle
    bsf	    CCP1CON,5
    
    movlw   0x0F           ; right wheel turns
    movwf   PWM2
    movf    PWM2           ; Set duty cycle to 25% out of 20 15 for 75% the 8 msb in the pwm duty 
    movwf   CCPR2L
    bsf	    CCP2CON,4      ; two lsb in the duty cycle
    bsf	    CCP2CON,5
    
    return
    

    
DELAY:                        ; Extended delay for motor state transitions
    movlw   0xFF      
    movwf   D1         
DELAY_LOOP_1:
    movlw   0xFF      
    movwf   D2         
DELAY_LOOP_2:               
    movlw   0xFF      
    movwf   D3         
DELAY_LOOP_3:
    decfsz  D3, f      
    goto    DELAY_LOOP_3
    decfsz  D2, f      
    goto    DELAY_LOOP_2 
    decfsz  D1, f     
    goto    DELAY_LOOP_1 
    return
    
    end