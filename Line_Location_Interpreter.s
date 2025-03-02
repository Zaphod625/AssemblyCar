PROCESSOR 18F45K22

;========================================================== Configuration bits ==============================================================================

    CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
    CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register)
    
    #include    <xc.inc>
    #include    "pic18f45k22.inc"
    
;======================================================== Definition of variables ===========================================================================
    
; symbol EQU value   -> Variable CANNOT be changed later
; symbol SET value   -> Variable CAN    be changed later    
    
	
ADCResult		equ	0x20			; Register Address of Latest ADC Result Reading

Colour EQU 0b01100110	; Average value of colour we looking for (eg 2V = 0b01100110) --> Use variable/register of calibrated colour when linking code
    
Max_Colour_Value	EQU	0x31			; Register Address of Max value accepted in range (GPR -> BSR = 0, a = 0)
Min_Colour_Value	EQU	0x32			; Register Address of Min value accepted in range (GPR -> BSR = 0, a = 0) 	
		
		
; If method 1 on 'Call Straight/Left/Right/LeftLeft/RightRight used		
		
;Straight_Colour	EQU	0x21			; Register for Straight Sensor Colour Value
;Left_Colour		EQU	0x22			; Register for Left Sensor Colour Value
;Right_Colour		EQU	0x23			; Register for Right Sensor Colour Value
;LeftLeft_Colour	EQU	0x24			; Register for LeftLeft Sensor Colour Value
;RightRight_Colour	EQU	0x25			; Register for RightRight Sensor Colour Value
	
	
WhiteVal_Min		EQU     0x26			; Register to store lowwer white value during calibration
		
BlackVal_Max		EQU	0x27			; Register to store upper black value during calibration
BlackVal_Max_X2		EQU	0x28			; Register to store upper black value X2
BlackVal_Average	EQU     0x29			; Register to store average value of the LeftLeft sensor
BlackVal_Average_X2	EQU	0x30			; Register to store average value of both LeftLeft and RightRight sensor
		
	
;----------------------------------------------------------------------------------------------------------------------------------------------------------
    
PSECT code,abs					//Start of main code.
 
        org 0x00				; Reset vector
	    goto    Setup       
	org 0x8					; Interrupt vector
	    goto    ISR				; Interrupt Service Routine
	
	    
;================================================================== Setup ===================================================================================

Setup:	    
    
	MOVLB   0x0F
	
	CLRF    PORTA  ,0 	  ; Clear PORTA register           
	CLRF    LATA   ,0	  ; Clear PORTA data latches
	CLRF    ANSELA ,1    ; Set all PORTA pins to digital
	CLRF    TRISA  ,0    ; Set all PORTA pins to outputs
	
	CLRF    PORTB  ,0 
	CLRF    LATB   ,0
	CLRF    ANSELB ,1
	CLRF    TRISB  ,0
    
	CLRF    PORTC  ,0 
	CLRF    LATC   ,0
	CLRF    ANSELC ,1
	CLRF    TRISC  ,0
	
	CLRF    PORTD  ,0 
	CLRF    LATD   ,0
	CLRF    ANSELD ,1
	CLRF    TRISD  ,0
	
	CLRF    PORTE  ,0 
	CLRF    LATE   ,0
	CLRF    ANSELE ,1
	CLRF    TRISE  ,0
	
	MOVLB	0x0
    
;	CALL Average				; Establishes an average value to work with -> stored in register 'Colour' -> for test 'Colour is a value
	
;	CALL Range				; Establishes a range to work with -> stored in registers: 'Max_Colour_Value' and 'Min_Colour_Value' 

	
;============================================================== Main program =================================================================================
	
Main:
    
    ;------------------------------------------------------------------------ Can be removed later, Just a setup for test -> Using PORT A - part of setup
	MOVLB	0xF
	
	CLRF	ADRESH,1	; ADC initialize result register
	
        MOVLW 	0b00101111 	; ADC: left justify, FRC - 600Hz
        MOVWF 	ADCON2,1 	; ADC: & 12 TAD ACQ time
        
        CLRF 	ADCON1,1 	; ADC: ref = Vdd,Vss -> 00000000B
	
	SETF	ANSELA,1	; All Port A now 1 = analog -> All ports RA0 - RA7
	
        SETF	TRISA,1		; All Port A now 1 = inputs -> All ports RA0 - RA7
	
	MOVLB	0x0
    ;------------------------------------------------------------------------ Can be removed later, Just a setup for test -> Using PORT D
    
    ;   CALL	WhiteVal_Min			; This value will be used to compare if the sensor being tested is on white
						; Can Add into Calibrate function -> does not have to run through this step for the LLI everytime then	
						;				  -> Just a slightly lowwer value as everything above is inherently white  - 1 check
    					
	; Done here for test					
		MOVLW 	0b11011110	    ; Can be swapped for WhiteVal ---> Calibrated white value	
		MOVWF   WhiteVal_Min, 0	; Test For on line  -> Made it a value for test -> 4.54V - 200mV = 4.34V -> 1101 1110 01 *Based off measured oscilliscope value 
		
;		MOVLW	0b00001010		;Going to subtr 41 steps -> 200mV from WhiteVal_Min   -----> Use if 'MOVLW 0b11011110' above swapped for WhiteVal
		
;		SUBWF	WhiteVal, 0		; Subtract WREG from WhiteVal   -> 0 indicates that value is stored in WREG 		
;		MOVWF	WhiteVal_Min            ; Contains WhiteVal - 200mV value
				
	;Done here for test   ----> Commented out part will be uncommented and 'MOVLW 0b11011110' and command below it will be removed when integrating code.
	

	
	
    ;   CALL	BlackVal_Max			; This value will be used to get an upper black value
						; Can Add into Calibrate function -> does not have to run through this step for the LLI everytime then			
						
	; Done here for test					
		MOVLW 	0b01000010	    ; Can be swapped for BlackVal ---> Calibrated black value
		MOVWF   BlackVal_Max, 0	; Test For on line  -> Made it a value for test -> 1.2V + 100mV = 1.3V -> 0100 0010 11 *Based off measured oscilliscope value
		
;		MOVLW	0b00000101		;Going to add 21 steps -> 102.5mV to BlackVal_Max   -----> Use if 'MOVLW 0b01000010' above swapped for BlackVal
		
;		ADDWF	BlackVal, 0		; Add WREG to BlackVal_Max   -> 0 indicates that value is stored in WREG
;		MOVWF	BlackVal_Max		; Contains BlackVal + 102.5mV value		
		
		; Below in place to account for a division later in (Call Black_End)
		
		MOVF	BlackVal_Max, W		        ; Load BlackVal_Max into WREG 
		ADDWF   BlackVal_Max, 0, 0		; Add WREG to BlackVal_Max   -> 0 indicates that value is stored in WREG
		
		MOVWF	BlackVal_Max_X2, 0		; This is BlackVal_Max multiplied by 2 
			
	;Done here for test   ----> Commented out part will be uncommented and 'MOVLW 0b01000010' and command below it will be removed when integrating code.
	
	
	CLRF	PORTC				; Turn Off previous direction LED  ---> Delay before returning to main func??
	 
	CALL	Black_End			; Check if all Black (END)  --> Can get an average an it will be very low  --> Sample all sensors & average ----> Outer two?
    
	CALL	Straight			; Check Middle Sensor
	
	CALL	Left				; Check Inner Left Sensor
	
	CALL	Right				; Check Inner Right Sensor
	
	CALL	LeftLeft			; Check Outer Left Sensor
	
	CALL	RightRight			; Check Outer Right Sensor
	
	CALL	White_Lost			; Check if all white (LOST) ---> By default the last outcome so could even assume and not check?
	
	GOTO 	Main				; Loop Main

;============================================================== Functions ===================================================================================
;_________________________________________________________________________________________
; ADCON0: A/D CONTROL REGISTER 0  ->  RD0 - RD7 -> AN20 - AN27
;
; bit 7: Unimplemented = 0	
; bit 6-2: CHS<4:0>: Analog Channel Select bits  ->  10100 = AN20  -  11011 = AN27
; bit 1: GO	
; bit 0: ADC Enable = 1
;	
; 	0b  0   '00000'	0   1	-> Change '' to select channel, keep others fixed
;_________________________________________________________________________________________	
	
Straight:
    
	CLRF	ADCON0, 1       ;------------------> ; Probably dont need as overwritten ---> but byrons problem so clear good?
	MOVLW	0b00000001	; Selecting Analog Channel AN0 (RA0) and ADC enable (BSF ADCON0,0,1 / ADON = 1)
	MOVWF	ADCON0, 1
	
	CALL	ADC_Start		; Call a sample and store the value in 'ADCResult' register
	
; Compare that value with range value -- x2 -> max and min ----------- OR ----------- Compare levels ------------------> For DEMO Check if not white (easiest option)
	
	; Method 1
	
;	MOVFF ADCResult, Straight_Colour
;	MOVF Straight_Colour, W
;	CPFSGT WhiteVal_Min	        ; -> skip if f > W
;	Return
;	BSF PORTC, 0			; Turn port RC0 on to indicate straight
;	GOTO Main
	
	; Method 2
	
	MOVF ADCResult, W		; Move captured ADC value to WREG
	
	CPFSGT WhiteVal_Min, 0	        ; -> skip if f > W
	RETURN				; Return to Main to continue next function (next sensor check) as sensor is on white
	
	BSF PORTC, 0			; Turn port RC0 on to indicate straight
	
	GOTO Main			; Restarts main and goes through checks from start
	 
	
Left:
    
	CLRF	ADCON0, 1	
	MOVLW	0b00000101	; Selecting Analog Channel AN1 (RA1) and ADC enable (BSF ADCON0,0,1 / ADON = 1)
	MOVWF	ADCON0, 1
	
	CALL	ADC_Start
	
	MOVF ADCResult, W
	CPFSGT WhiteVal_Min, 0	        ; -> skip if f > W
	RETURN
	BSF PORTC, 1			; Turn port RC1 on to indicate left
	
	GOTO Main
	
	
	
Right:

	CLRF	ADCON0, 1
	MOVLW	0b00001001	; Selecting Analog Channel AN2 (RA2) and ADC enable (BSF ADCON0,0,1 / ADON = 1)
	MOVWF	ADCON0, 1    
      
	CALL	ADC_Start
	
	MOVF ADCResult, W
	
	CPFSGT WhiteVal_Min, 0	        ; -> skip if f > W
	RETURN
	
	BSF PORTC, 2			; Turn port RC2 on to indicate straight
	
	GOTO Main
	
LeftLeft:
    
	CLRF	ADCON0, 1
	MOVLW	0b00001101	; Selecting Analog Channel AN3 (RA3) and ADC enable (BSF ADCON0,0,1 / ADON = 1)
	MOVWF	ADCON0, 1    
    
	CALL	ADC_Start
	
	MOVF ADCResult, W
	CPFSGT WhiteVal_Min, 0	        ; -> skip if f > W
	RETURN
	BSF PORTC, 1			; Turn port RC1 on to indicate left
	
RightRight:
   
	CLRF	ADCON0, 1
	MOVLW	0b00010001	; Selecting Analog Channel AN4 (RA4) and ADC enable (BSF ADCON0,0,1 / ADON = 1)
	MOVWF	ADCON0, 1    
    
	CALL	ADC_Start
	
	MOVF ADCResult, W
	CPFSGT WhiteVal_Min, 0	        ; -> skip if f > W
	RETURN
	BSF PORTC, 2			; Turn port RC0 on to indicate right
	
Black_End:
    
    
    ; The idea is to add the two outer most sensor values and compare it to (X2) the max black value plus itself again because dividing is complex
    ;
    ; (Value 1 + Value 2) / 2 = BlackVal_Average   ------------>   Average < WREG  then in end zone   -------------> WREG =  BlackVal_Max
    ;
    ; So (Value 1 + Value 2) = 2 BlackVal_Average  ------------> 2 Average < 2 WREG then in end zone  -------------> WREG = 2 BlackVal_Max = BlackVal_Max_X2   **(Multiply both sides by 2)
    ;
    ; As we can see above the logic should work.
    
	CLRF	BlackVal_Average, 0
    
    ; Checking LeftLeft
	CLRF	ADCON0, 1
	MOVLW	0b00001101	; Selecting Analog Channel AN3 (RA3) and ADC enable (BSF ADCON0,0,1 / ADON = 1)
	MOVWF	ADCON0, 1    
    
	CALL	ADC_Start
	
	MOVFF	ADCResult, BlackVal_Average	            ; Store first ADC value in BlackVal_Average
	
    ; Checking RightRight
	CLRF	ADCON0, 1
	MOVLW	0b00010001				    ; Selecting Analog Channel AN4 (RA4) and ADC enable (BSF ADCON0,0,1 / ADON = 1)
	MOVWF	ADCON0, 1    
    
	CALL	ADC_Start
	
	MOVF	ADCResult, W				    ; Load ADC value into WREG 
	
	ADDWF	BlackVal_Average, W			    ; Add WREG to Black_Average and keep added value in WREG
	
	CPFSLT	BlackVal_Max_X2, 0				    ; Compare BlackVal_Average_X2 with WREG, skip if BlackVal_Average < WREG
	GOTO Stop				    
	
	Return						    ; Continue with sensor location search
    
White_Lost:
	
    ; Signals that we are lost
    
    ; Lucky for use PORTC RC0 - RC4 is set up in initialization --------> RC3 initialised for analog input but we can change it for RC5 as it also has analog input
    
    ; Output to an LED_Lost
    
	BSF PORTC, 4  ; Turn port RC4 on to indicate lost led   
	
	GOTO Stop
    
Stop: 
    
    ; Can make more complex to confirm if really on black end of track
    
	BSF	PORTC, 3				    ; Turn port RC3 on to indicate end of track  -------> Ask Byron to Move RC3 to RC5? Then can use PORTC RC0 to RC 4 for Direction LEDs
    
	BRA	Stop					    ; Will repeat check indefinitly 
    
;--------------------------------------------------- Start an ADC conversion on selected channel ------------------------------------------------------------
ADC_Start:

	BSF 	GO 		    ; Start conversion
; OR	BSF     ADCON0, 1           ; Start ADC conversion
        BTFSC   ADCON0, 1           ; Wait until conversion complete 
	BRA 	$-2 
	
	MOVF    ADRESH, W           ; Move ADRESH to W (contains 8 MSBs of ADCResult) 
        MOVWF   ADCResult, 0        ; Store ADC result in register 'ADCResult' 
	
	RETURN
    
;-------------------------------------------------------------------------------------------------------------------------------------------------------------   
Range:
    
;	-------------------------------------------------  Setup Max / Min values for colour  ----------------------------------------------------------------
	
	CLRF	Max_Colour_Value, 1		; Set Max register to 0
	CLRF	Min_Colour_Value, 1		; Set Min register to 0
	
;	-----------	-----------	-----------	-----------	-----------	-----------	-----------	-----------	-----------	-----
	
	MOVLW	Colour				; Loading value of calibrated colour  
	
	ADDLW	0b00001011			; Adding decimal = 11 -> 214.83mV; since each step (resolution) is 19.53mV for an 8-bit register
					    
	MOVWF	Max_Colour_Value, 1		; Store the upper/max value, a = 1 -> GPR			 
	
;	-----------	-----------	-----------	-----------	-----------	-----------	-----------	-----------	-----------	-----  

	MOVLW	0b00001011			; Loading value of calibrated colour  
	
	SUBLW	Colour				; Subtracting decimal = 11 -> 214.83mV; since each step (resolution) is 19.53mV for an 8-bit register				    
	
	MOVWF	Min_Colour_Value, 1		; Store the lowwer/min value, a = 1 -> GPR
	
;	------------------------------------------------------------------------------------------------------------------------------------------------------    
    
	
;========================================================= Interrupt service routine ========================================================================
	
ISR:						; GIE automatically cleared upon branching to interrupt vector	
    
;    	BCF 	INTCON,1 / INT0IF		; clear external interrupt flag (RB0)
;	BCF     INTCON,0 / RBIF			; clear internal interrupct flag (RB4)
    
	RETFIE					; GIE automatically set upon return from interrupt vector (ISR)
	
	
	
end						; Stop Program -> Safeguard, but loop preffered			
