


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
sensor_MM   equ	0x0D	      ; Middle Middle Diode
sensor_MR   equ	0x0E	      ; Middle Middle Diode	    
sensor_ML   equ	0x0F	      ; Middle Middle Diode	    
sensor_LL   equ	0x10	      ; Middle Middle Diode	    
sensor_RR   equ	0x11	      ; Middle Middle Diode	       
ADCResult   equ	0x20	      ; Rsult from reading the ADC
White_Temp  equ	0x21  
   
BlackVal_Max_X2		EQU	0x28			; Register to store upper black value X2
BlackVal_Average	EQU     0x29			; Register to store average value of the LeftLeft sensor
BlackVal_Average_X2	EQU	0x30			; Register to store average value of both LeftLeft and RightRight sensor 
     
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
       //BSF     TRISC, 3 ,0            ; Set RC3 as input (analog)
        //BSF     ANSELC, 3, 0           ; Set RC3 as analog
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
    
	MOVLB   0x0F
	
	CLRF    PORTA  ,0 	  ; Clear PORTA register           
	CLRF    LATA   ,0	  ; Clear PORTA data latches
	CLRF    ANSELA ,1    ; Set all PORTA pins to digital
	CLRF    TRISA  ,0    ; Set all PORTA pins to outputs
    
        MOVLB   0xF                   ; Switch to Bank F for ADC registers
	CLRF	PORTC
	CLRF	LATC
	MOVLW	0xFF
	MOVWF	TRISC			; Make entire PORTC input pins
	MOVLW	0b11111000
	MOVWF	ANSELC
        CLRF    ADRESH, 0              ; Clear ADC result high byte
	
	; Configure ADCON2: Left justify result (ADRESH contains 8 MSBs)
        MOVLW   0x2F                   ; Left justify, ADC clock = Frc, acquisition time = 12 TAD
        MOVWF   ADCON2, 0
	
        ; Configure ADCON1: Use Vref+ = Vdd and Vref- = Vss
        MOVLW   0x00            
        MOVWF   ADCON1, 0

        //BSF	ADON			;Enable AN0 of ADC
	
        ; Configure ADCON0: Select channel AN15 (RC3) and enable ADC
	; WIll do this in the mian to toggle between teh 5 different ADC pins
        ;MOVLW   0x3F                   ; CHS = 1111 (AN15), ADON = 1
        ;MOVWF   ADCON0, 0
	MOVLW	0xC8
	MOVWF	White_Temp
	
    
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
    MOVLW   0b00111011
    MOVWF   INTCON2
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
    ;ADC Readings
    ;MOVLW   0xFF
    ;MOVWF   PORTD
    CALL    ADC_Loop
   ;	  CALL    Set_Val    ues for testing
    CALL    ADC_read
    
    CALL    Display_Delay
    
    GOTO    LLI
    
    CALL	Interupt_Handler
    ; CALL Line Location Interpreter     
    GOTO	Main
    
Interupt_Handler:
    MOVLW	0x00
    CPFSGT	IntExt0
    GOTO	Main		    ; if not equal, means the interupt has not happened, IntExt0 is 0x00
    MOVLW	0x1F
    CPFSGT	IntExt0
    GOTO	Reg_Dump
    CALL	Calibrate	    ; If equal, call the subroutine
    GOTO	Main
    
Display_Delay:
    
    BSF	    PORTA, 5				; Turn port RA4 on to indicate lost led   
    CALL    Delay3Hz
    CALL    Delay3Hz
    CLRF    PORTA
    return
   
ADC_Loop:
    //Read pin RC3, channel AN15 
    CALL    Delay3Hz
    MOVLW   0b00111101
    MOVWF   ADCON0
    CALL    ADC_Start
    MOVF    ADRESH, 0           ; Move ADRESH to W (contains 8 MSBs of ADCResult)
    MOVWF   ADCResult           ; Store ADC result in variable
    MOVWF   sensor_RR
    
    //Read pin RC4, channel AN16
    CALL    Delay3Hz
    MOVLW   0b1000001
    MOVWF   ADCON0
    CALL    ADC_Start
    MOVF    ADRESH, 0           ; Move ADRESH to W (contains 8 MSBs of ADCResult)
    MOVWF   ADCResult           ; Store ADC result in variable
    MOVWF   sensor_MM
    
    //Read pin RC5, channel AN17 
    CALL    Delay3Hz
    MOVLW   0b01000101
    MOVWF   ADCON0
    CALL    ADC_Start
    MOVF    ADRESH, 0           ; Move ADRESH to W (contains 8 MSBs of ADCResult)
    MOVWF   ADCResult           ; Store ADC result in variable
    MOVWF   sensor_LL
    
    //Read pin RC6, channel AN18
    CALL    Delay3Hz
    MOVLW   0b01001001
    MOVWF   ADCON0
    CALL    ADC_Start
    MOVF    ADRESH, 0           ; Move ADRESH to W (contains 8 MSBs of ADCResult)
    MOVWF   ADCResult           ; Store ADC result in variable
    MOVWF   sensor_ML
    
    //Read pin RC7, channel AN19
    CALL    Delay3Hz
    MOVLW   0b01001101
    MOVWF   ADCON0
    CALL    ADC_Start
    MOVF    ADRESH, 0           ; Move ADRESH to W (contains 8 MSBs of ADCResult)
    MOVWF   ADCResult           ; Store ADC result in variable
    MOVWF   sensor_MR
    
    return
    
 
    
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
    CAll    Delay2s
    CAll    Delay2s
    MOVLW   0x00
    MOVWF   IntExt0
    MOVLW   0b01001000
    MOVWF   INTCON3
    MOVLW   0b11010000
    MOVWF   INTCON
    
    GOTO    Main
    
Calibrate:
    // Set to use sensor_MM as the callibrated number
    MOVLW   0b00111101
    MOVWF   ADCON0
    
    Call CaliWhite
    Call CaliRed
    Call CaliGreen
    Call CaliBlue
    Call CaliBlack
    
     
    MOVLW   0x00
    MOVWF   PORTD  
    MOVWF   IntExt0
    MOVLW   0b11010000
    MOVWF   INTCON
    GOTO    Main   
    
CaliWhite:
    MOVLW   0b00000001
    MOVWF   PORTD;
    CALL    Delay2s
    CALL    Delay2s
    CALL    Delay2s
    CALL    Delay2s
    CALL    ADC_Start
    CALL    Delay2s
    MOVF    ADRESH, W  ; Store current ADC reading in BlackVal
    //MOVLW   0xE1	; used for testing logic
    ADDLW   0x50
    MOVWF   WhiteVal    
    MOVLW   0b00000001
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b0000000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b00000001
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b0000000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b00000001
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b0000000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b00000001
    MOVWF   PORTD;
    CALL    Delay3Hz
    return

CaliRed:
    MOVLW   0b00010010
    MOVWF   PORTD;
    CALL    Delay2s
    CALL    Delay2s
    CALL    Delay2s
    CALL    Delay2s
    CALL    ADC_Start
    CALL    Delay2s
    MOVF    ADRESH, W  ; Store current ADC reading in BlackVal
    //MOVLW   0x9F
    ADDLW   0x34	; add a 100mV on top of the Measured ADC reading for the logic to see whta colour we are reading
    MOVWF   RedVal    
    CALL    Delay3Hz
    MOVLW   0b00010010
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b0000000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b00010010
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b0000000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b00010010
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b0000000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b00010010
    MOVWF   PORTD;
    CALL    Delay3Hz
    return
   
CaliGreen:
    MOVLW   0b10001000
    MOVWF   PORTD;
    CALL    Delay2s
    CALL    Delay2s
    CALL    Delay2s
    CALL    Delay2s
    CALL    ADC_Start
    CALL    Delay2s
    MOVF    ADRESH, W  ; Store current ADC reading in BlackVal
    //MOVLW   0xC2
    ADDLW   0x32	; add a 100mV on top of the Measured ADC reading for the logic to see whta colour we are reading
    MOVWF   GreenVal    
    CALL    Delay3Hz
    MOVLW   0b10001000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b0000000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b10001000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b0000000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b10001000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b0000000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b10001000
    MOVWF   PORTD;
    CALL    Delay3Hz
    return
    
CaliBlue:
    MOVLW   0b01000100
    MOVWF   PORTD;
    CALL    Delay2s
    CALL    Delay2s
    CALL    Delay2s
    CALL    Delay2s
    CALL    ADC_Start
    CALL    Delay2s
    MOVF    ADRESH, W  ; Store current ADC reading in BlackVal
    //MOVLW   0x87
    ADDLW   0x13	; add a 100mV on top of the Measured ADC reading for the logic to see whta colour we are reading
    MOVWF   BlueVal    
    CALL    Delay3Hz
    MOVLW   0b01000100
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b0000000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b01000100
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b0000000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b01000100
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b0000000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b01000100
    MOVWF   PORTD;
    CALL    Delay3Hz
    return
    
CaliBlack:
    movlw   0xFF
    MOVWF   PORTD;
    CALL    Delay2s
    CALL    Delay2s
    CALL    Delay2s
    CALL    Delay2s
    CALL    ADC_Start
    CALL    Delay2s
    MOVF    ADRESH, W  ; Store current ADC reading in BlackVal
    //MOVLW   0x50
    ADDLW   0x05	; add a 100mV on top of the Measured ADC reading for the logic to see whta colour we are reading
    MOVWF   BlackVal    
    CALL    Delay3Hz
    MOVLW   0xFF
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b0000000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0xFF
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b0000000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0xFF
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0b0000000
    MOVWF   PORTD;
    CALL    Delay3Hz
    MOVLW   0xFF
    MOVWF   PORTD;
    CALL    Delay3Hz
    return                    ; Return from subroutine
    
  
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
        ;MOVF    ADRESH, 0           ; Move ADRESH to W (contains 8 MSBs of ADCResult)
        ;MOVWF   ADCResult           ; Store ADC result in variable
	CALL	Check_Black
	return
	
Set_Val:
    ; this function is purely for tetsing logic of the check values to displasy the result from one phototransisitor
    MOVLW   0x05
    MOVWF  sensor_MM
    
    MOVLW   0x46
    MOVWF  BlackVal
    
    MOVLW   0x5F
    MOVWF  RedVal
    
    MOVLW   0x98
    MOVWF  BlueVal
    
    MOVLW   0xC8
    MOVWF  GreenVal
    return
    

	
Check_Black:
        ; Check if ADCResult < 51 (0-1V range)
        MOVF	BlackVal,0                  ; This needs to be updated to Black, and the same logic to the rest
	CPFSLT	sensor_MM
        GOTO    Check_Blue
        MOVLW   0xFF                ; Output "00000001" for 0-1V
	MOVWF   PORTD
	CALL    Delay2s
	return
Check_Blue:
        MOVF   BlueVal,0
        CPFSLT	sensor_MM
        GOTO    Check_Red
        MOVLW   0b01000100                ; Output "00000011" for 1-2V
        MOVWF   PORTD
        CALL    Delay2s
        return

Check_Red:
        MOVF   RedVal,0                 
        CPFSLT	sensor_MM
        GOTO    Check_Green          
        MOVLW   0b00010010                ; Output "00000111" for 2-3V
        MOVWF   PORTD
        CALL    Delay2s
        return
Check_Green:
        MOVF   GreenVal,0
        CPFSLT	sensor_MM
        GOTO    Check_White          
        MOVLW   0b10001000                ; Output "00001111" for 3-4V
        MOVWF   PORTD
        CALL    Delay2s
        return

Check_White:
        MOVLW   0x01                ; Output "00011111" for 4-5V
        MOVWF   PORTD
        CALL    Delay2s
        return

;-------------------------------------------------------------------------------------------------------------------------------  	
LLI:	  
   	
		; Below in place to account for a division later in (Call Black_End)
		
;	MOVF	BlackVal, W		        ; Load BlackVal_Max into WREG 
;	ADDWF   BlackVal, 0, 0			; Add WREG to BlackVal   -> 0 indicates that value is stored in WREG -> 0 indicates access memory
		
;	MOVWF	BlackVal_Max_X2, 0		; This is BlackVal multiplied by 2 *Note BlackVal already has 100mV added to it from Calibrate
			
	
		; Functions to execute LLI
	
	CLRF	PORTA				; Turn Off previous direction LED  ---> Delay before returning to main func??
	 
;	CALL	Black_End			; Check if all Black (END)  --> Can get an average an it will be very low  --> Sample all sensors & average ----> Outer two?
	
    
	GOTO	Straight			; Check Middle Sensor
	
;	CALL	Right				; Check Inner Right Sensor
	//GOTO	Left				; Check Inner Left Sensor
	
	//GOTO	RightRight			; Check Outer Right Sensor
	
	
	
	

	
	//CALL	LeftLeft			; Check Outer Left Sensor
	

	
	
	
	
	//GOTO	White_Lost			; Check if all white (LOST) ---> By default the last outcome so could even assume and not check?
	
;	CALL	Delay2s
	
	GOTO	Interupt_Handler				; Loop Main    
 
    
Straight:
	
	MOVF sensor_MR, W			; Move captured ADC value to WREG
	
	CPFSGT White_Temp, 0			; -> skip if White > sensor_MM
	GOTO Left					; Return to Main to continue next function (next sensor check) as sensor is on white
	
	BSF PORTA, 1; Turn port RA1 on to indicate straight
	
		
	GOTO	Interupt_Handler				; Loop Main    
	 

Left:
	
	MOVF sensor_MM, W
	
	CPFSGT White_Temp, 0	        //WhiteVal > sensor_ML
	GOTO	RightRight
	
	BSF PORTA, 2				; Turn port RA2 on to indicate left
	
	GOTO	Interupt_Handler
	
RightRight:
   
	MOVF sensor_RR, W
	
	
	CPFSGT White_Temp, 0	       
	GOTO	White_Lost
	
	BSF PORTA, 3				; Turn port RA3 on to indicate right
	GOTO	Interupt_Handler
	
	
Right:

	MOVF sensor_RR, W
	
	CPFSGT White_Temp, 0	       
	RETURN
	
	BSF PORTA, 3				; Turn port RA3 on to indicate straight
	
	GOTO	Interupt_Handler
	
	
LeftLeft:
	
	MOVF sensor_LL, W
	
	CPFSGT White_Temp, 0	      
	GOTO Interupt_Handler
	
	BSF PORTA, 2				; Turn port RA2 on to indicate left
	
	GOTO Interupt_Handler
	


White_Lost:
	
; Signals that we are lost and outputs to an LED_Lost
    
	BSF PORTA, 4				; Turn port RA4 on to indicate lost led   
	
	//GOTO Search	
	GOTO Interupt_Handler

Search: 
    
	CALL    Delay2s	
	return
	
Black_End:
    
    
    ; The idea is to add the two outer most sensor values and compare it to (X2) the max black value plus itself again because dividing is complex
    ;
    ; (Value 1 + Value 2) / 2 = BlackVal_Average   ------------>   Average < WREG  then in end zone   -------------> WREG =  BlackVal_Max
    ;
    ; So (Value 1 + Value 2) = 2 BlackVal_Average  ------------> 2 Average < 2 WREG then in end zone  -------------> WREG = 2 BlackVal_Max = BlackVal_Max_X2   **(Multiply both sides by 2)
    ;
    ; As we can see above the logic should work.
    
    ; Adding sensor_LL
    
	CLRF	BlackVal_Average, 0
	
	MOVFF	sensor_LL, BlackVal_Average	            ; Store first ADC value in BlackVal_Average
	
    ; Adding sensor_RR
	
	MOVF	sensor_RR, W				    ; Load ADC value into WREG 
	
	ADDWF	BlackVal_Average, W			    ; Add WREG to Black_Average and keep added value in WREG
	
	CPFSLT	BlackVal_Max_X2, 0			    ; Compare BlackVal_Average_X2 with WREG, skip if BlackVal_Average < WREG
	CALL	Stop				    
	
	return
	GOTO Interupt_Handler						    ; Continue with sensor location search
    
Stop: 
    
; Can make more complex to confirm if really on black end of track
    
	BSF	PORTA, 0				    ; Turn port RA0 on to indicate end of track
    
	CALL    Delay2s

	GOTO Interupt_Handler
	
;	BRA	Stop					    ; Will repeat check indefinitly     
;--------------------------------------------------------------------------------------------------------------------------------- 	
    GOTO Main
    
END                          ; End of program file