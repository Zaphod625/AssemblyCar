; PIC18F45K22 Assembly code for pic-as v2.50
PROCESSOR 18F45K22    
    
#include <xc.inc>
#include "pic18f45k22.inc"   
    

; CONFIG directives
CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register)

;============================== Registers ==============================
RESULTHI	equ	0x00          ; Variable to store high byte of ADC result
Delay1		equ	0x01          ; Counter variable for delay loops
Delay2		equ	0x02          ; Counter variable for nested delay loops
Delay3		equ	0x03          ; Counter variable for longer delay loops
Delay4		equ	0x04          ; Counter variable for nested longer delay loops
Counter		equ	0x05          ; Counter for LED flashing repetitions
CS_Enable	equ	0x06          ; Colour Select Enable lag bit 0
sensor_MM	equ	0x07          ; Middle Middle Diode
sensor_MR	equ	0x08          ; Middle Right Diode
sensor_ML	equ	0x09          ; Middle Left Diode
sensor_RR	equ	0x0A          ; Right Right Diode
sensor_LL	equ	0x0B          ; Left Left Diode
follow_colour	equ	0x0C          ; Colour to follow	       
ADCResult	equ	0x0D	      ; Result of ADC
	
MM_red_max	equ	0x0E	      ; Calibrated Ranges for RED
MM_red_min	equ	0x0F
MR_red_max	equ	0x10
MR_red_min	equ	0x11
ML_red_max	equ	0x12
ML_red_min	equ	0x13
RR_red_max	equ	0x14
RR_red_min	equ	0x15
LL_red_max	equ	0x16
LL_red_min	equ	0x17

MM_green_max	equ	0x18	      ; Calibrated Ranges for GREEN
MM_green_min	equ	0x19
MR_green_max	equ	0x1A		    
MR_green_min	equ	0x1B	
ML_green_max	equ	0x1C		    
ML_green_min	equ	0x1D 
RR_green_max	equ	0x1E		    
RR_green_min	equ	0x1F
LL_green_max	equ	0x20		    
LL_green_min	equ	0x21
	
MM_blue_max	equ	0x22	      ; Calibrated Ranges for BLUE
MM_blue_min	equ	0x23	
MR_blue_max	equ	0x24
MR_blue_min	equ	0x25	
ML_blue_max	equ	0x26
ML_blue_min	equ	0x27	
RR_blue_max	equ	0x28
RR_blue_min	equ	0x29	
LL_blue_max	equ	0x2A
LL_blue_min	equ	0x2B
	
MM_black_max_red	equ	0x2C	      ; Calibrated Max for BLACK
MR_black_max_red	equ	0x2D
ML_black_max_red	equ	0x2E    
    
MM_black_max_green	equ	0x2F
MR_black_max_green	equ	0x30
ML_black_max_green	equ	0x31
    
MM_black_max_blue	equ	0x32
MR_black_max_blue	equ	0x33
ML_black_max_blue	equ	0x34   
	
MM_white_min_red	equ	0x35	      ; Calibrated Min for WHITE	
MM_white_min_green	equ	0x36	
MM_white_min_blue	equ	0x37
   
Test_start_bit		equ	0x38	      ; Temporary Test bit for Cap Touch Detect Enable -> uses INT2 -> RB2 to set the bit    	    	    
	    
Vread			equ	0x39	      ; Voltage reading register
switchState		equ	0x3A	      ; Switch State (PRESSED = 1, UNPRESSED = 0)

PWM1			equ	0x3B
PWM2			equ	0x3C
state			equ	0x3D
		
		
; NOTE BSR GOES TO 59h UNTIL SFR IN USE		
		
;============================== Variables ==============================		
		
THRESHOLD		equ	0xFE		//THRESHOLD value
	
Range_Cal_Value_1	equ	0b00001010	//  195mV 
Range_Cal_Value_2	equ	0b00010100	//  390mV (bottom value = (2* Range_Cal_Value_2 ) - top value)
Range_Cal_Value_3	equ	0b00010000	//  312mV
Range_Cal_Value_4	equ	0b00101000	//  624mV
    
;------------------------------------------------------------------------------------------------------------------        
	        
	    
PSECT code,abs //Start of main code.     
 
org	0x00
GOTO	Setup
     
org	0x08
GOTO	HP_ISR
     
org	0x18
GOTO	LP_ISR


; ========== Setup Ports and ADC ==========
Setup:

    MOVLB   0x0F	  ; Switch to Bank F for ADC registers
	
;	CLRF    PORTX	  ; Clear PORTX register           
;	CLRF    LATX	  ; Clear PORTX data latches
;	CLRF    ANSELX    ; Set all PORTX pins to digital (digital = 0 / analog = 1)
;	CLRF    TRISX     ; Set all PORTX pins to outputs (output = 0 / input = 1)
    
	CLRF    PORTA,0		    ; PORTA: <7:3> (Colour LED (7=Black,6=Blue,5=Green,4=Red,3=White)) <2:0> (RGB Array (2=blue,1=green,0=red))     
	CLRF    LATA,0	  
	CLRF    ANSELA,1    
	CLRF    TRISA,0 
	
	CLRF    PORTB,0		    ; PORTB    
	CLRF    LATB,0
	CLRF    ANSELB,1
	CLRF    TRISB,0
    
	CLRF    PORTC,0		    ; PORTC
	CLRF    LATC,0
	CLRF    ANSELC,1
	CLRF    TRISC,0
	
	CLRF    PORTD,0		    ; PORTD 
	CLRF    LATD,0
	CLRF    ANSELD,1
	CLRF    TRISD,0
	
	CLRF    PORTE,0		    ; PORTE
	CLRF    LATE,0
	CLRF    ANSELE,1
	CLRF    TRISE,0 
	
; ADC SETUP:
	
    ; ADCON2:  ----TAD 16 & FOSC/32 FOR TESTING---------
        ;MOVLW   0b00111110			    ; <7> Left justify = 0, <6> Unimplemented = 0 ,<5:3> Acquisition Time = 20 T_AD = 111, <2:0> ADC clock = FOSC/64 = 110.
	MOVLW	0b00111110
        MOVWF   ADCON2,0
	
    ; ADCON1:
	MOVLW	0b00000000			    ; MOVLW	0b00000000 - Use Vref+ = Vdd and Vref- = Vss (old)
        MOVWF   ADCON1,0			    ; <--------- ATTENTION, MUST CHANGE 0b0000 01 00 <3:2> Vref+ = ext pin <1:0> Vref- + int pin
	
	; Clear ADC result high byte
	CLRF    ADRESH,0 
	
; PORT SETUP:
	
    ;PORTA Setup:
	MOVLW	0b00000111  
	MOVWF	PORTA,0				    ; Output (digital) on RA0, RA1, RA2 -> Keeps RGB Array Off
	
    ;PORTB Setup:
	MOVLW   0b11001000
	MOVWF   ANSELB,1			    ; PORTB <7:4> & <2:0>  Digital <3> analogue
	MOVLW	0b00111111			    ; PORTB <7:6>  Outputs. <5:0> Inputs
	MOVWF   TRISB
	
	BSF	LATB, 4    ; Set RB4 high (VDD)	    ; Part of CAP TOUCH - secondary channel (RB4) to VDD as digital output
	
	
    ;PORTC Setup:
	MOVLW	0b11111000
	MOVWF	ANSELC,1			    ; Make PORTC <7:2> analog. <1:0> digital.
	MOVLW	0b11111000
	MOVWF	TRISC				    ; Make PORTC <7:2> inputs. <1:0> outputs.
	
    ;PORTD Setup:
  	
    ;PORTE Setup:
    
    
    
; ========== PWM SETUP ==========
; Using Timer4 for PWM (like working example) instead of Timer2

    MOVLB   0x0F                  ; Switch to Bank F for PWM registers
    
    ; Set PWM period: 50kHz (20us period)
    ; PR4 = ((Period x Fosc) / (4 * TMR4 Prescaler)) - 1
    ; = ((20e-6 * 4MHz) / 4) - 1 = 19
    movlw   19
    movwf   PR4
    
    ; Initial duty cycles (will be changed in motor control functions)
    movlw   0
    movwf   CCPR1L
    movwf   CCPR2L
    bcf     CCP1CON,4             ; Clear LSBs initially
    bcf     CCP1CON,5
    bcf     CCP2CON,4
    bcf     CCP2CON,5
    
    ; Set CCP1 and CCP2 to use TMR4 (CCPTMRS0)
    ; CCP1TSEL = 01 (bits 1:0)
    ; CCP2TSEL = 01 (bits 3:2)
    movlw   0b00001001           ; CCP2TSEL=01, CCP1TSEL=01
    movwf   CCPTMRS0
    
    ; Configure CCPxCON registers for PWM (CCPxM = 1100)
    movlw   0b00001100
    movwf   CCP1CON
    movwf   CCP2CON
    
    ; Setup RB6 and RB7 as outputs for motor control
    bcf     TRISB, 6             ; RB6 = Motor A direction
    bcf     TRISB, 7             ; RB7 = Motor B direction
    
    ; Setup and start Timer4 (Prescaler = 1)
    clrf    TMR4
    movlw   0b00000100           ; T4CON: TMR4ON=1, Prescaler=1
    movwf   T4CON
    
    MOVLB   0x00                  ; Return to Bank 0    
; OSCILLATOR SETUP:
    
    BSF	    OSCCON, 6			    ;IRCF2	    ;Oscillator Speed is 4MHz OSCON <6:4> / IRCF <2:0> 
    BSF	    OSCCON, 5			    ;IRCF1
    BSF	    OSCCON, 4			    ;IRCF0
    
; CTMU SETUP: (CAP Touch)
    
    MOVLW   0b00000011
    MOVWF   CTMUICON,1				    ; ITRIM<5:0>: Current Source Trim bits / IRNG<1:0>: Current Source Range Select bits
    
    MOVLW   0b11011100				    ; positive edge response, RB2 - EDGE1 - CTED1 / RB3 - EDGE2 - CTED2, Events Not Occured 
    MOVWF   CTMUCONL,1
    
    CLRF    CTMUCONH,1
    
    MOVLB   0x0				    ; Return to Bank 0 for normal operation
    
; CLEAR VARIABLES:
    BCF	    CS_Enable, 0
    BCF	    Test_start_bit, 0
    CLRF    follow_colour
    
; EXTERNAL INTERRUPTS:
    
    CLRF    INTCON3,0			
    			
    MOVLW   0b11011000				    ; INT1 -> RB1 external interrupt pin turned on (+high priority) [Ensure pin set as digital input - YES]	
    MOVWF   INTCON3,0				    ; INT2 -> RB2 external interrupt pin turned on (+high priority) [Ensure pin set as digital input - YES]
    			
    
    CLRF    INTCON2,0				    ; Interrupts INT0, INT1, INT2 are on falling_edge, TMR0 Overflow ignored (Pull-Ups enabled if corresponding  WPUB bit set)
   
    CLRF    INTCON,0				    ; Enables global interrupts, enables peripheral interrupts, disables TMR0 Overflow interrupt
    MOVLW   0b11010000				    ; Enables INT0 - RBO external interrupt pin
						    ; Disables Port B Interrupt-On-Change (IOCx) Interrupt Enable bit, Clears: TMR0, INT0, RB_IOCx interrupt flag bits (interrupts have not occured)
    MOVWF   INTCON,0
    
    GOTO    Main

;==================================================================================================================  
    
Main:
    
    BTFSS   CS_Enable, 0
    CALL    Colour_Read				    ; used to show what colour we on (uses sensor_MM strobed value)
    
     BTFSC   Test_start_bit, 0			    ; Test with a set bit for now on external interrupt INT2 - RB2
     GOTO    Cap_Touch_Detect			    ; used to continuously check if touch sensed
    
    ;Interrupts handled in HP_ISR
    ;Interrupt on RB0 -> INT0 -> Calibrate_ver_RGB
    ;Interrupt on RB1 -> INT1 -> Follower_Colour_Select
    ;Interrupt on RB2 -> INT2 -> Enables CAP_TOUCH_DETECT
   
    GOTO	Main   
  
;=================================================================================================================

  Cap_Touch_Detect:
    //Taking out the cap touch
    //GOTO    LLI
    //This is what I have added taking out if it doesn't work
    
    MOVLW   0b00100101			// Select ADC Channel AN9 -> RB3 ( CTED2 - CTMU )
    MOVWF   ADCON0,0
    
MOVLB   0x0F					; Switch to Bank F
    
BSF CTMUCONH, 7,1				// Enable the CTMU
BCF CTMUCONL, 0,1				// Clear Edge1 status bit
BCF CTMUCONL, 1,1				// Clear Edge2 status bit
BSF CTMUCONH, 1,1				// Drain charge on the circuit
    
MOVLB   0x00			
  
CALL	Delay2s
Call Delay2s
    
MOVLB   0x0F    
    
BCF CTMUCONH, 1,1				// End drain of circuit
BSF CTMUCONL, 1,1				// Begin charging the circuit ( EDG1STAT = 1 ) using CTMU current source

MOVLB   0x00			
  
CALL	Delay2s  
 
    
MOVLB   0x0F    
    
BCF CTMUCONL, 1,1				// Stop charging circuit
    
MOVLB   0x00
    			
	CALL    ADC_Start			// Begin ADC conv and Wait for ADC conv complete
	MOVF    ADRESH, W			// Get the value from the ADC
	
	MOVWF	Vread,0				// Move the value from WREG to Vread
	MOVLW	THRESHOLD	 
	CPFSGT	Vread,0				// skip if f > W (Vread > THRESHOLD) & execute if THRESHOLD > Vread
	GOTO	LLI
	
	GOTO Cap_Touch_Detect       
   
LLI:
  
    BTFSC   follow_colour, 4			    ; Follow RED
    BCF	    PORTA, 0
    BTFSC   follow_colour, 4			    
    CALL    Delay_125us
    BTFSC   follow_colour, 4			    
    GOTO    follow_red
    
    BTFSC   follow_colour, 5			    ; Follow GREEN
    BCF	    PORTA, 1
    BTFSC   follow_colour, 5			    
    CALL    Delay_125us
    BTFSC   follow_colour, 5			    
    GOTO    follow_green
    
    BTFSC   follow_colour, 6			    ; Follow BLUE
    BCF	    PORTA, 2
    BTFSC   follow_colour, 6			    
    CALL    Delay_125us
    BTFSC   follow_colour, 6			    
    GOTO    follow_blue
    
    BTFSC   follow_colour, 7			    ; Follow BLACK
    BCF	    PORTA, 0
    BTFSC   follow_colour, 7			    
    CALL    Delay_125us
    BTFSC   follow_colour, 7			    
    GOTO    follow_black
    
    BCF	PORTA, 4				    ; Indicates that No colour was selected
    CALL    Delay3Hz
    BSF	PORTA, 4
    CALL    Delay3Hz
    BCF	PORTA, 4
    CALL    Delay3Hz
    BSF	PORTA, 4
    CALL    Delay3Hz
    BCF	PORTA, 4
    CALL    Delay3Hz
    BSF	PORTA, 4
    CALL    Delay3Hz
    BCF	PORTA, 4
    CALL    Delay3Hz
    
    BCF	   Test_start_bit, 0
    
    GOTO    Main		
    
    
    follow_red:
	
	MOVLW	0b00000000
	MOVWF	PORTD				    ; Turns direction LEDs OFF
	CALL	ADC_Loop			    ; Get sensor values for RED
	
    
	red_straight:
    		      
	    MOVF	sensor_MM,0		    ; Fetch sensor_MM value to compare
	    CPFSLT	MM_red_min,0		    ; Compare MM_red_min with sensor_MM, skip if MM_red_min < sensor_MM
	    GOTO	red_right		    ; Checks MR sensor		
	    CPFSGT	MM_red_max,0		    ; Compare MM_red_max with sensor_MM, skip if MM_red_max > sensor_MM
	    GOTO	red_right		    ; Checks MR sensor
	    BSF		PORTD, 0		    ; Indicates STRAIGHT
	    
	    ; EXECUTE MOTOR STRAIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    Call	GO_Straight
	    
	    CALL	Delay_125us			    
	    GOTO	follow_red		    
	
	red_right:
		       
	    MOVF	sensor_MR,0		    
	    CPFSLT	MR_red_min,0		
	    GOTO	red_left				
	    CPFSGT	MR_red_max,0		
	    GOTO	red_left		
	    BSF		PORTD, 1		    ; Indicates RIGHT
	    
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION		    <------------------------------------- MOTOR FUNC
	    CALL	Right
	    CALL	Delay_125us			
	    GOTO	follow_red		
	
	red_left:
		       
	    MOVF	sensor_ML,0		    
	    CPFSLT	ML_red_min,0		
	    GOTO	red_stop				
	    CPFSGT	ML_red_max,0		
	    GOTO	red_stop		
	    BSF		PORTD, 2		    ; Indicates LEFT
	    
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	Left
	    CALL	Delay_125us			
	    GOTO	follow_red
    
	red_right_right:   
		       
	    MOVF	sensor_RR,0		    
	    CPFSLT	RR_red_min,0		
	    GOTO	red_left_left				
	    CPFSGT	RR_red_max,0		
	    GOTO	red_left_left		
	    BSF		PORTD, 1		    ; Indicates RIGHT
	    
	    ; EXECUTE MOTOR HARD RIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	Right
	    CALL	Delay_125us			
	    GOTO	follow_red    
	  
	red_left_left:
		       
	    MOVF	sensor_LL,0		    
	    CPFSLT	LL_red_min,0		
	    GOTO	red_stop				
	    CPFSGT	LL_red_max,0		
	    GOTO	red_stop		
	    BSF		PORTD, 2		    ; Indicates LEFT
	    
	    ; EXECUTE MOTOR HARD LEFT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	Left
	    CALL	Delay_125us			
	    GOTO	follow_red
	    
	red_stop:
	; Checks if at end line
    
	    MOVF	sensor_MM,0		    ; Check if Middle Sensor on BLACK
	    CPFSGT	MM_black_max_red,0	      
	    GOTO	LOST
	    
	    MOVF	sensor_MR,0		    ; Check if Right Right Sensor on BLACK
	    CPFSGT	MR_black_max_red,0	      
	    GOTO	LOST
	    
	    MOVF	sensor_ML,0		    ; Check if Left Left Sensor on BLACK   
	    CPFSGT	ML_black_max_red,0	     
	    GOTO	LOST
	
	    CALL Stop_Car
	    
	    GOTO IDLE    
	    
    GOTO follow_red				    ; Safety Net
    
    
    
    follow_green:
    
	MOVLW	0b00000000
	MOVWF	PORTD				    ; Turns direction LEDs OFF
	CALL	ADC_Loop			    ; Get sensor values for GREEN
    
	green_straight:
    		      
	    MOVF	sensor_MM,0		    
	    CPFSLT	MM_green_min,0		    
	    GOTO	green_right		   	
	    CPFSGT	MM_green_max,0		    
	    GOTO	green_right		    
	    BSF		PORTD, 0		    ; Indicates STRAIGHT
	    
	    ; EXECUTE MOTOR STRAIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	GO_Straight
	    CALL	Delay_125us
	    GOTO	follow_green		    
	
	green_right:
		       
	    MOVF	sensor_MR,0		    
	    CPFSLT	MR_green_min,0		
	    GOTO	green_left				
	    CPFSGT	MR_green_max,0		
	    GOTO	green_left		
	    BSF		PORTD, 1		    ; Indicates RIGHT
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	Right
	    CALL	Delay_125us			
	    GOTO	follow_green		
	
	green_left:
		       
	    MOVF	sensor_ML,0		    
	    CPFSLT	ML_green_min,0		
	    GOTO	green_stop				
	    CPFSGT	ML_green_max,0		
	    GOTO	green_stop		
	    BSF		PORTD, 2		    ; Indicates LEFT
	    
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	Left
	    CALL	Delay_125us		
	    GOTO	follow_green
    
	green_right_right:   
		       
	    MOVF	sensor_RR,0		   
	    CPFSLT	RR_green_min,0		
	    GOTO	green_left_left				
	    CPFSGT	RR_green_max,0		
	    GOTO	green_left_left		
	    BSF		PORTD, 1		    ; Indicates RIGHT
	    
	    ; EXECUTE MOTOR HARD RIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	Right
	    CALL	Delay_125us			
	    GOTO	follow_green    
	  
	green_left_left:
		       
	    MOVF	sensor_LL,0		    
	    CPFSLT	LL_green_min,0		
	    GOTO	green_stop				
	    CPFSGT	LL_green_max,0		
	    GOTO	green_stop		
	    BSF		PORTD, 2		    ; Indicates LEFT
	    
	    ; EXECUTE MOTOR HARD LEFT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	Left
	    CALL	Delay_125us			
	    GOTO	follow_green
	    
	green_stop:
	; Checks if at end line
    
	    MOVF	sensor_MM,0		    ; Check if Middle Sensor on BLACK
	    CPFSGT	MM_black_max_green,0	      
	    GOTO	LOST
	    
	    MOVF	sensor_MR,0		    ; Check if Right Right Sensor on Black
	    CPFSGT	MR_black_max_green,0	      
	    GOTO	LOST
	    
	    MOVF	sensor_ML,0		    ; Check if Left Left Sensor on Black    
	    CPFSGT	ML_black_max_green,0	     
	    GOTO	LOST
	    
	    
	    CALL Stop_Car
	    
	    
	    GOTO IDLE    
	    
    GOTO follow_green				    ; Safety Net
    
    
    
    follow_blue:
    
	MOVLW	0b00000000
	MOVWF	PORTD				    ; Turns direction LEDs OFF		    
	CALL	ADC_Loop			    ; Get sensor values for BLUE
	
	blue_straight:
    		      
	    MOVF	sensor_MM,0		    
	    CPFSLT	MM_blue_min,0		    
	    GOTO	blue_right		   	
	    CPFSGT	MM_blue_max,0		    
	    GOTO	blue_right		    
	    BSF		PORTD, 0		    ; Indicates STRAIGHT
	    
	    ; EXECUTE MOTOR STRAIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	GO_Straight
	    
	    ;CALL	Delay_125us
	    GOTO	follow_blue		    
	
	blue_right:
		       
	    MOVF	sensor_MR,0		    
	    CPFSLT	MR_blue_min,0		
	    GOTO	blue_left				
	    CPFSGT	MR_blue_max,0		
	    GOTO	blue_left		
	    BSF		PORTD, 1		    ; Indicates RIGHT
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION						<------------------------------------- MOTOR FUNC	
	    Call	Right
	    ;CALL	Delay_125us
	    GOTO	follow_blue		
	
	blue_left:
		       
	    MOVF	sensor_ML,0		    
	    CPFSLT	ML_blue_min,0		
	    GOTO	blue_right_right		       
	    CPFSGT	ML_blue_max,0		
	    GOTO	blue_right_right		        
	    BSF		PORTD, 2		    ; Indicates LEFT
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION						<------------------------------------- MOTOR FUNC			
	    CALL	Left
	    ;CALL	Delay_125us
	    GOTO	follow_blue
    
	blue_right_right:   
		       
	    MOVF	sensor_RR,0		   
	    CPFSLT	RR_blue_min,0		
	    GOTO	blue_left_left				
	    CPFSGT	RR_blue_max,0		
	    GOTO	blue_left_left		
	    BSF		PORTD, 1		    ; Indicates RIGHT
	    
	    ; EXECUTE MOTOR HARD RIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	Right_Right
	    ;CALL	Delay_125us			
	    GOTO	follow_blue    
	  
	blue_left_left:
		       
	    MOVF	sensor_LL,0		    
	    CPFSLT	LL_blue_min,0		
	    GOTO	blue_stop				
	    CPFSGT	LL_blue_max,0		
	    GOTO	blue_stop		
	    BSF		PORTD, 2		    ; Indicates LEFT
	    
	    ; EXECUTE MOTOR HARD LEFT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	Left_Left
	    ;CALL	Delay_125us			
	    GOTO	follow_blue
	    
	blue_stop:
	; Checks if at end line
    
	    MOVF	sensor_MM,0		    ; Check if Middle Sensor on BLACK
	    CPFSGT	MM_black_max_blue,0	      
	    GOTO	LOST
	    
	    MOVF	sensor_MR,0		    ; Check if Right Right Sensor on Black
	    CPFSGT	MR_black_max_blue,0	      
	    GOTO	LOST
	    
	    MOVF	sensor_ML,0		    ; Check if Left Left Sensor on Black    
	    CPFSGT	ML_black_max_blue,0	     
	    GOTO	LOST
	    
	    CALL Stop_Car

	    GOTO IDLE

	    
    GOTO follow_blue				    ; Safety Net
    
    
    
    follow_black:
 
	MOVLW	0b00000000
	MOVWF	PORTD				    ; Turns direction LEDs OFF
	CALL	ADC_Loop			    ; Get sensor values
    
	black_stop:
	; Checks if at end line
    
	    ; EXECUTE MOTOR STRAIGHT FUNCTION						<------------------------------------- MOTOR FUNC											<------------------------------------- MOTOR FUNC
	    
	    
	    MOVF	sensor_MM,0		    ; Check if Middle Sensor on BLACK
	    CPFSGT	MM_black_max_red,0	    ; Compare MM_black_max_blue with sensor_MM, skip if MM_black_max_blue > sensor_MM  
	    GOTO	black_straight
	    
	    MOVF	sensor_MR,0		    ; Check if Right Right Sensor on Black
	    CPFSGT	MR_black_max_red,0	      
	    GOTO	black_straight
	    
	    MOVF	sensor_ML,0		    ; Check if Left Left Sensor on Black    
	    CPFSGT	ML_black_max_red,0	     
	    GOTO	black_straight
	    
	    CALL	Stop_Car
	    
	    GOTO IDLE
    
	black_straight:
		      
	    MOVF	sensor_MM,0		    		   	
	    CPFSGT	MM_black_max_red,0		    
	    GOTO	black_right		    
	    BSF		PORTD, 0		    ; Indicates STRAIGHT
	
	    ; EXECUTE MOTOR STRAIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	GO_Straight
	    GOTO	follow_black    
	
	black_right:
		      
	    MOVF	sensor_MR,0		    		   	
	    CPFSGT	MR_black_max_red,0		    
	    GOTO	black_left		    
	    BSF		PORTD, 1		    ; Indicates RIGHT
	
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	Right
	    GOTO	follow_black    
    
	black_left:
		      
	    MOVF	sensor_ML,0		    		   	
	    CPFSGT	ML_black_max_red,0		    
	    GOTO	LOST
	    BSF		PORTD, 2		    ; Indicates LEFT
	
	    ; EXECUTE MOTOR SOFT LEFT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	Left
	    GOTO	follow_black
    
	black_right_right:
		      
	    MOVF	sensor_RR,0		    		   	
	    CPFSGT	MM_black_max_red,0		    
	    GOTO	black_left_left		    
	    BSF		PORTD, 1		    ; Indicates RIGHT
	
	    ; EXECUTE MOTOR HARD RIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	Right_Right
	    GOTO	follow_black
	    
	black_left_left:
		      
	    MOVF	sensor_LL,0		    		   	
	    CPFSGT	MM_black_max_red,0		    
	    GOTO	LOST		    
	    BSF		PORTD, 2		    ; Indicates RIGHT
	
	    ; EXECUTE MOTOR HARD LEFT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	Left_Left
	    GOTO	follow_black
      
	    
    LOST:
	BSF	PORTD, 3				    ; Indicate LOST
	CALL	Delay_125us
	
	    ; EXECUTE A MOTOR FUNCTION	(STRAIGHT?)					<------------------------------------- MOTOR FUNC
	    
	GOTO	LLI
	
	
    IDLE:
	MOVLW	0b00000111				    ; Turn OFF RBG Arrays and Colour LEDs
	MOVWF	PORTA
	BSF	PORTD, 4				    ; Indicate STOP
	CALL	Delay2s
	CALL	Delay2s
	CALL	Delay2s
	BCF	CS_Enable, 0				    ; Revert back to what colour we are on in main loop	
	BCF	Test_start_bit, 0			    ; Refreshes the Capacitive Touch Start Bit
	CLRF    follow_colour
	BCF	PORTD, 4				    ; Clear STOP LED
	GOTO	Main					    ; Loop at main until start
	    
;------------------------------------------------------------------------     ADC     ------------------------------------------------------------------------   
    
ADC_Loop:
    
    //Read pin RC3, channel AN15 
    CALL    Delay3Hz
    MOVLW   0b00111101
    MOVWF   ADCON0,0
    CALL    ADC_Start
    MOVF    ADRESH, 0				; Move ADRESH to W (contains 8 MSBs of ADCResult)
    MOVWF   sensor_MM,0
    
    //Read pin RC4, channel AN16
    CALL    Delay3Hz
    MOVLW   0b1000001
    MOVWF   ADCON0,0
    CALL    ADC_Start
    MOVF    ADRESH, 0				; Move ADRESH to W (contains 8 MSBs of ADCResult)
    MOVWF   sensor_MR
    
    //Read pin RC5, channel AN17 
    CALL    Delay3Hz
    MOVLW   0b01000101
    MOVWF   ADCON0,0
    CALL    ADC_Start
    MOVF    ADRESH, 0				; Move ADRESH to W (contains 8 MSBs of ADCResult)
    MOVWF   sensor_ML
    
    //Read pin RC6, channel AN18
    CALL    Delay3Hz
    MOVLW   0b01001001
    MOVWF   ADCON0,0
    CALL    ADC_Start
    MOVF    ADRESH, 0				; Move ADRESH to W (contains 8 MSBs of ADCResult)
    MOVWF   sensor_LL
    
    //Read pin RC7, channel AN19
    CALL    Delay3Hz
    MOVLW   0b01001101
    MOVWF   ADCON0,0
    CALL    ADC_Start
    MOVF    ADRESH, 0				; Move ADRESH to W (contains 8 MSBs of ADCResult)
    MOVWF   sensor_RR
    
    RETURN
    
ADC_Start:
    BSF	    GO					; Start conversion
    BTFSC   ADCON0, 1				; Wait until conversion complete
    BRA	    $-2
    RETURN
	
	
Colour_Read:
    ;shows colour we are on
    
    ;sensor_MM
    MOVLW   0b00111101				; Select ADC Channel AN15 -> RC3 (sensor_MM)
    MOVWF   ADCON0
    
    CALL	Check_Red
    
    BSF		PORTA, 0			; Turn off RED LED Array set in ADC Loop if start was not set 
    BSF		PORTA, 1			; Turn off GREEN LED Array set in ADC Loop if start was not set   ---   Safety Net		
    BSF		PORTA, 2			; Turn off BLUE LED Array set in ADC Loop if start was not set 
    RETURN
    
    Check_Red:		   
    
	BCF	PORTA, 0			; Turn on RED RGB Array
	CALL	Delay2s
	CALL    ADC_Start
	MOVF    ADRESH, W			; Store current ADC reading in WREG
	BSF	PORTA, 0			; Turn off RED RGB Array
    
	CPFSLT	MM_red_min,0			; Compare MM_red_min with sensor_MM, skip if MM_red_min < sensor_MM (WREG)
	GOTO	Check_Green			; Checks if green		
	CPFSGT	MM_red_max,0			; Compare MM_red_max with sensor_MM, skip if MM_red_max > sensor_MM (WREG)
	GOTO	Check_Green			; Checks if green
	BSF	PORTA, 4
	CALL    Delay2s
	BCF	PORTA, 4
	return
	
    Check_Green:
    
	BCF	PORTA, 1			; Turn on GREEN RGB Array
	CALL	Delay2s
	CALL    ADC_Start
	MOVF    ADRESH, W			
	BSF	PORTA, 1
    
	CPFSLT	MM_green_min,0		
	GOTO	Check_Blue				
	CPFSGT	MM_green_max,0		
	GOTO	Check_Blue		
	BSF	PORTA, 5
	CALL    Delay2s
	BCF	PORTA, 5
	return
	
    Check_Blue:	
    
	BCF	PORTA, 2			; Turn on BLUE RGB Array
	CALL	Delay2s
	CALL    ADC_Start
	MOVF    ADRESH, W			
	BSF	PORTA, 2
    
	CPFSLT	MM_blue_min,0		
	GOTO	Check_Black				
	CPFSGT	MM_blue_max,0		
	GOTO	Check_Black		
	BSF	PORTA, 6
	CALL    Delay2s
	BCF	PORTA, 6
	return
	
    Check_Black:				
	CPFSGT	MM_black_max_blue,0		
	GOTO	Check_White		
	BSF	PORTA, 7
	CALL    Delay2s
	BCF	PORTA, 7
	return
	
    Check_White:			  
	BSF	PORTD, 5
	CALL    Delay2s
	BCF	PORTD, 5
	return
	    
;------------------------------------------------------------------------    INTERRUPTS  START  ------------------------------------------------------------------------	    
	    
HP_ISR:
    BTFSC    INTCON,1				    ; Checks if INT0 -> RB0 flag has been set (triggered?) -> Skips if not set
    CALL     Calibrate_ver_RGB
    BTFSC    INTCON3,0				    ; Checks if INT1 -> RB1 flag has been set (triggered?) -> Skips if not set
    CALL     Follower_Colour_Select
    BTFSC    INTCON3,1				    ; Checks if INT2 -> RB2 flag has been set (triggered?) -> Skips if not set 
    BSF	     Test_start_bit,0
    BCF	     INTCON3, 1				    ; Clears interrupt flag: INT2 -> RB2
        
    RETFIE  1 
    
LP_ISR:
    RETFIE  1

;--------------------------	    --------------------------	    --------------------------	    --------------------------	    --------------------------    
Calibrate_ver_RGB:
    ;Calibrates each sensor for each colour for each RGB value.
    
    MOVLW 0b00000111				    ; Ensures that all LEDs are off
    MOVWF PORTA
    
    CALL Red_Calibrate
    CALL Black_Calibrate
    CALL Blue_Calibrate
    CALL Green_Calibrate
    Call White_Calibrate
    
    MOVLW   0b00000111
    MOVWF   PORTA				    ; Ensures that all LEDs are off
    
    BCF	    INTCON, 1				    ; Clears interrupt flag: INT0 -> RB0
    BSF	    INTCON, 4				    ; Sets INT0 External Interrupt Enable bit (Interrupt can be used again)

    
    Return
    
    Red_Calibrate:
	
	BCF	PORTA, 0			    ; Turns RED RGB Array ON
	BSF	PORTA, 4			    ; Indicates that RED is to be sampled
	
	CALL	Cal_Delay
	
	
	;sensor_MM
	MOVLW   0b00111101                          ; Select ADC Channel AN15 -> RC3 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    ; Store current ADC reading in WREG
	;ADDLW   0b00000101			    ; add a 97.65mV on top of the Measured ADC reading - for VREF+ = VDD (old)
	ADDLW   Range_Cal_Value_1		    ; add a 40mV on top of the Measured ADC reading - for VREF+ = EXT PIN 
	MOVWF   MM_red_max			    ; Store max value
	;MOVLW	 0b00001010			    ; 195.3mV -> max - 195.3mV = base - 97.65mV (old)
	MOVLW	Range_Cal_Value_2		    ; 80mV -> max - 80mV = base - 80mV
	SUBWF	MM_red_max, 0			    ; Subtract WREG from MM_red_Max, result stored in WREG
	MOVWF	MM_red_min			    ; Store min value
	
	;sensor_MR
	MOVLW   0b01000001                          ; Select ADC Channel AN16 -> RC4 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    			    
	;ADDLW   0b00001010
	ADDLW   0b00000101		    ; ----------------------------------------------------- hard code VALUE
	MOVWF   MR_red_max			    
	;MOVLW	 0b00010100
	MOVLW	0b00001010		    ; ----------------------------------------------------- hard code VALUE
	SUBWF	MR_red_max, 0			    
	MOVWF	MR_red_min
	
	;sensor_ML
	MOVLW   0b01000101                          ; Select ADC Channel AN17 -> RC5 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    			    
	;ADDLW   0b00001010
	ADDLW   Range_Cal_Value_1
	MOVWF   ML_red_max			    
	;MOVLW	0b00010100
	MOVLW	Range_Cal_Value_2
	SUBWF	ML_red_max, 0			    
	MOVWF	ML_red_min
	
	;sensor_RR
	MOVLW   0b01001001                          ; Select ADC Channel AN18 -> RC6 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    			    
	;ADDLW   0b00001010
	ADDLW   Range_Cal_Value_1
	MOVWF   RR_red_max			    
	;MOVLW	0b00010100
	MOVLW	Range_Cal_Value_2
	SUBWF	RR_red_max, 0			    
	MOVWF	RR_red_min
	
	;sensor_LL
	MOVLW   0b01001101                          ; Select ADC Channel AN19 -> RC7 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    			    
	;ADDLW   0b00001010
	ADDLW   Range_Cal_Value_1
	MOVWF   LL_red_max			    
	;MOVLW	0b00010100
	MOVLW	Range_Cal_Value_2
	SUBWF	LL_red_max, 0			    
	MOVWF	LL_red_min
	
	BSF	PORTA, 0			    ; Turns RED RGB Array OFF 
	
	CALL Delay_125us
	
	BCF	PORTA, 4			    ; Indicate that Red_Calibrate is completed
	CALL    Delay3Hz
	BSF	PORTA, 4
	CALL    Delay3Hz
	BCF	PORTA, 4
	CALL    Delay3Hz
	BSF	PORTA, 4
	CALL    Delay3Hz
	BCF	PORTA, 4
	CALL    Delay3Hz
	BSF	PORTA, 4
	CALL    Delay3Hz
	BCF	PORTA, 4
	CALL    Delay3Hz
	RETURN

    Green_Calibrate:
    
	BCF	PORTA, 1			    ; Turns GREEN RGB Array ON
    
	BSF	PORTA, 5			    ; Indicates that GREEN is to be sampled
	CALL	Cal_Delay
	
	
	;sensor_MM
	MOVLW   0b00111101                          ; Select ADC Channel AN15 -> RC3 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    			    
	;ADDLW  0b00000101
	ADDLW   Range_Cal_Value_1
	MOVWF   MM_green_max			    
	;MOVLW	0b00001010
	MOVLW	Range_Cal_Value_2
	SUBWF	MM_green_max, 0			    
	MOVWF	MM_green_min
	
	;sensor_MR
	MOVLW   0b01000001                          ; Select ADC Channel AN16 -> RC4 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    			    
	;ADDLW   0b00001010
	ADDLW   Range_Cal_Value_1
	MOVWF   MR_green_max			    
	;MOVLW	0b00010100
	MOVLW	Range_Cal_Value_2
	SUBWF	MR_green_max, 0			    
	MOVWF	MR_green_min
	
	;sensor_ML
	MOVLW   0b01000101                          ; Select ADC Channel AN17 -> RC5 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    			    
	;ADDLW   0b00001010
	ADDLW   Range_Cal_Value_1
	MOVWF   ML_green_max			    
	;MOVLW	0b00010100
	MOVLW	Range_Cal_Value_2
	SUBWF	ML_green_max, 0			    
	MOVWF	ML_green_min
	
	;sensor_RR
	MOVLW   0b01001001                          ; Select ADC Channel AN18 -> RC6 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    			    
	;ADDLW   0b00001010
	ADDLW   Range_Cal_Value_1
	MOVWF   RR_green_max			    
	;MOVLW	0b00010100
	MOVLW	Range_Cal_Value_2
	SUBWF	RR_green_max, 0			    
	MOVWF	RR_green_min
	
	;sensor_LL
	MOVLW   0b01001101                          ; Select ADC Channel AN19 -> RC7 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    			    
	;ADDLW   0b00001010
	ADDLW   Range_Cal_Value_1
	MOVWF   LL_green_max			    
	;MOVLW	0b00010100
	MOVLW	Range_Cal_Value_2
	SUBWF	LL_green_max, 0			    
	MOVWF	LL_green_min
	
	BSF	PORTA, 1			    ; Turns GREEN RGB Array OFF 
				    
	BCF	PORTA, 5			    ; Indicate that Green_Calibrate is completed
	CALL    Delay3Hz
	BSF	PORTA, 5
	CALL    Delay3Hz
	BCF	PORTA, 5
	CALL    Delay3Hz
	BSF	PORTA, 5
	CALL    Delay3Hz
	BCF	PORTA, 5
	CALL    Delay3Hz
	BSF	PORTA, 5
	CALL    Delay3Hz
	BCF	PORTA, 5
	CALL    Delay3Hz
	RETURN
	
    Blue_Calibrate:
    
	BCF	PORTA, 2			    ; Turns BLUE RGB Array ON
    
	BSF	PORTA, 6			    ; Indicates that BLUE is to be sampled
	CALL	Cal_Delay
	
	
	;sensor_MM
	MOVLW   0b00111101                          ; Select ADC Channel AN15 -> RC3 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    			    
	;ADDLW   0b00000101
	ADDLW   Range_Cal_Value_1
	MOVWF   MM_blue_max			    
	;MOVLW	0b00001010
	MOVLW	Range_Cal_Value_2
	SUBWF	MM_blue_max, 0			    
	MOVWF	MM_blue_min
	
	;sensor_MR
	MOVLW   0b01000001                          ; Select ADC Channel AN16 -> RC4 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    			    
	;ADDLW   0b00001010
	ADDLW   Range_Cal_Value_1
	MOVWF   MR_blue_max			    
	;MOVLW	0b00010100
	MOVLW	Range_Cal_Value_2
	SUBWF	MR_blue_max, 0			    
	MOVWF	MR_blue_min
	
	;sensor_ML
	MOVLW   0b01000101                          ; Select ADC Channel AN17 -> RC5 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    			    
	;ADDLW   0b00001010
	ADDLW   Range_Cal_Value_1
	MOVWF   ML_blue_max			    
	;MOVLW	0b00010100
	MOVLW	Range_Cal_Value_2
	SUBWF	ML_blue_max, 0			    
	MOVWF	ML_blue_min
	
	;sensor_RR
	MOVLW   0b01001001                          ; Select ADC Channel AN18 -> RC6 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    		    
	;ADDLW   0b00001010
	ADDLW   Range_Cal_Value_1
	MOVWF   RR_blue_max			    
	;MOVLW	0b00010100
	MOVLW	Range_Cal_Value_2
	SUBWF	RR_blue_max, 0			    
	MOVWF	RR_blue_min
	
	;sensor_LL
	MOVLW   0b01001101                          ; Select ADC Channel AN19 -> RC7 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    		    
	;ADDLW   0b00001010
	ADDLW   Range_Cal_Value_1
	MOVWF   LL_blue_max			    
	;MOVLW	0b00010100
	MOVLW	Range_Cal_Value_2
	SUBWF	LL_blue_max, 0			    
	MOVWF	LL_blue_min
	
	BSF	PORTA, 2			    ; Turns BLUE RGB Array OFF 
				    
	BCF	PORTA, 6			    ; Indicate that Blue_Calibrate is completed
	CALL    Delay3Hz
	BSF	PORTA, 6
	CALL    Delay3Hz
	BCF	PORTA, 6
	CALL    Delay3Hz
	BSF	PORTA, 6
	CALL    Delay3Hz
	BCF	PORTA, 6
	CALL    Delay3Hz
	BSF	PORTA, 6
	CALL    Delay3Hz
	BCF	PORTA, 6
	CALL    Delay3Hz
	RETURN
	
    Black_Calibrate:
   
	BCF	PORTA, 0			    ; Turns RED RGB Array ON
    
	BSF	PORTA, 7			    ; Indicates that BLACK is to be sampled
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	
	
	;sensor_MM
	MOVLW   0b00111101                          ; Select ADC Channel AN15 -> RC3 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W
	ADDLW   Range_Cal_Value_4			   
	MOVWF   MM_black_max_red	
	
	;sensor_MR
	MOVLW   0b01000001                          ; Select ADC Channel AN16 -> RC4 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	ADDLW   Range_Cal_Value_4			    
	MOVWF   MR_black_max_red	
	
	;sensor_ML
	MOVLW   0b01000101                          ; Select ADC Channel AN17 -> RC5 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	ADDLW   Range_Cal_Value_4			   
	MOVWF   ML_black_max_red	
	
	BSF	PORTA, 0			    ; Turns RED RGB Array OFF
	CALL    Delay_125us
	
	
	
	BCF	PORTA, 1			    ; Turns GREEN RGB Array ON
	CALL    Delay2s
	
	;sensor_MM
	MOVLW   0b00111101                          ; Select ADC Channel AN15 -> RC3 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    	    			    
	ADDLW   Range_Cal_Value_1			    ; Add Range_Cal_Value_1		    
	MOVWF   MM_black_max_green
	
	;sensor_MR
	MOVLW   0b01000001                          ; Select ADC Channel AN16 -> RC4 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	ADDLW   Range_Cal_Value_1			    
	MOVWF   MR_black_max_green	
	
	;sensor_ML
	MOVLW   0b01000101                          ; Select ADC Channel AN17 -> RC5 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	ADDLW   Range_Cal_Value_1			    
	MOVWF   ML_black_max_green	
	
	BSF	PORTA, 1			    ; Turns GREEN RGB Array OFF
	CALL    Delay_125us
	
	
	
	BCF	PORTA, 2			    ; Turns BLUE RGB Array ON
	CALL    Delay2s
	
	
	;sensor_MM
	MOVLW   0b00111101                          ; Select ADC Channel AN15 -> RC3 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	ADDLW   Range_Cal_Value_1			    
	MOVWF   MM_black_max_blue
	
	;sensor_MR
	MOVLW   0b01000001                          ; Select ADC Channel AN16 -> RC4 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	ADDLW   Range_Cal_Value_1			      
	MOVWF   MR_black_max_blue	
	
	;sensor_ML
	MOVLW   0b01000101                          ; Select ADC Channel AN17 -> RC5 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	ADDLW   Range_Cal_Value_1			   
	MOVWF   ML_black_max_blue	
	
	BSF	PORTA, 2			    ; Turns BLUE RGB Array OFF
	CALL    Delay_125us
	
	BCF	PORTA, 7			    ; Indicate that Black_Calibrate is completed
	CALL    Delay3Hz
	BSF	PORTA, 7
	CALL    Delay3Hz
	BCF	PORTA, 7
	CALL    Delay3Hz
	BSF	PORTA, 7
	CALL    Delay3Hz
	BCF	PORTA, 7
	CALL    Delay3Hz
	BSF	PORTA, 7
	CALL    Delay3Hz
	BCF	PORTA, 7
	CALL    Delay3Hz
	RETURN
	
White_Calibrate:
   
	BSF	PORTD, 5			    ; Indicates that WHITE is to be sampled
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	
	
	;sensor_MM
	MOVLW   0b00111101                          ; Select ADC Channel AN15 -> RC3 (sensor_MM)
	MOVWF   ADCON0
	
	BCF	PORTA, 0			    ; Turns RED RGB Array ON
	CALL    Delay2s
	
	CALL    ADC_Start
	MOVF    ADRESH, W
	MOVWF	MM_white_min_red		    ; Store ADC value in White_min_red
	;MOVLW   0b00000101			    ; Load 97.65mV
	;MOVLW	Range_Cal_Value_1		    ; Load 40mV
	MOVLW	0b00000101
	SUBWF	MM_white_min_red,1		    ; Subtract and store back in register White_min_red	
	
	BSF	PORTA, 0			    ; Turns RED RGB Array OFF
	CALL    Delay_125us
	
	BCF	PORTA, 1			    ; Turns GREEN RGB Array ON
	CALL    Delay2s
	
	CALL    ADC_Start
	MOVF    ADRESH, W			    	    			    
	MOVWF	MM_white_min_green			    
	;MOVLW   0b00000101
	MOVLW	Range_Cal_Value_1
	SUBWF	MM_white_min_green,1
	
	BSF	PORTA, 1			    ; Turns GREEN RGB Array OFF
	CALL    Delay_125us
	
	BCF	PORTA, 2			    ; Turns BLUE RGB Array ON
	CALL    Delay2s
	
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	MOVWF	MM_white_min_blue			    
	;MOVLW   0b00000101
	MOVLW	Range_Cal_Value_1
	SUBWF	MM_white_min_blue,1,0		    	
	BSF	PORTA, 2			    ; Turns BLUE RGB Array OFF
	
	BCF	PORTD, 5			    ; Indicate that White_Calibrate is completed
	CALL    Delay3Hz
	BSF	PORTD, 5
	CALL    Delay3Hz
	BCF	PORTD, 5
	CALL    Delay3Hz
	BSF	PORTD, 5
	CALL    Delay3Hz
	BCF	PORTD, 5
	CALL    Delay3Hz
	BSF	PORTD, 5
	CALL    Delay3Hz
	BCF	PORTD, 5
	CALL    Delay3Hz
	RETURN
	
;--------------------------	    --------------------------	    --------------------------	    --------------------------	    --------------------------
Follower_Colour_Select:
; Sets the colour we want to follow    
    
	MOVLW   0b00111101			    ; Using sensor_MM (AN15 -> RC3) to select colour
	MOVWF   ADCON0
	
	BSF	CS_Enable, 0			    ; set the Colour Select Flag bit 0 
	
	MOVLW   0b11111111			    ; Indicate we are to sample
	MOVWF   PORTA  
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	MOVLW   0b00000111
	MOVWF   PORTA 
    
	CALL	Red
	
	BSF	PORTA, 0			; Turn off RED LED Array set in ADC Loop if start was not set 
	BSF	PORTA, 1			; Turn off GREEN LED Array set in ADC Loop if start was not set   ---   Safety Net		
	BSF	PORTA, 2			; Turn off BLUE LED Array set in ADC Loop if start was not set 
	
	BCF	INTCON3, 0			; Clears interrupt flag: INT1 -> RB1
	BSF	INTCON3, 3			; Sets INT1 External Interrupt Enable bit (Interrupt can be used again)
	
	RETURN
    
    Red:		   
    
	BCF	PORTA, 0			; Turn on RED RGB Array
	CALL	Delay2s
	CALL    ADC_Start
	MOVF    ADRESH, W			; Store current ADC reading in WREG
	BSF	PORTA, 0			; Turn off RED RGB Array
    
	CPFSLT	MM_red_min,0			; Compare MM_red_min with sensor_MM, skip if MM_red_min < sensor_MM (WREG)
	GOTO	Green				; Checks if green		
	CPFSGT	MM_red_max,0			; Compare MM_red_max with sensor_MM, skip if MM_red_max > sensor_MM (WREG)
	GOTO	Green				; Checks if green
	BSF	PORTA, 4
	BSF	follow_colour, 4
	return
	
    Green:
    
	BCF	PORTA, 1			; Turn on GREEN RGB Array
	CALL	Delay2s
	CALL    ADC_Start
	MOVF    ADRESH, W			
	BSF	PORTA, 1
    
	CPFSLT	MM_green_min,0		
	GOTO	Blue				
	CPFSGT	MM_green_max,0		
	GOTO	Blue		
	BSF	PORTA, 5
	BSF	follow_colour, 5
	return
	
    Blue:	
    
	BCF	PORTA, 2			; Turn on BLUE RGB Array
	CALL	Delay2s
	CALL    ADC_Start
	MOVF    ADRESH, W			
	BSF	PORTA, 2
    
	CPFSLT	MM_blue_min,0		
	GOTO	Black				
	CPFSGT	MM_blue_max,0		
	GOTO	Black		
	BSF	PORTA, 6
	BSF	follow_colour, 6
	return
	
    Black:						
	BSF	PORTA, 7
	BSF	follow_colour, 7		    ; Follow BLACK as last alternative
	return

	
  

;------------------------------------------------------------------------    INTERRUPTS  END   ------------------------------------------------------------------------      
    
Delay_125us:   
	movlw   0x04		; Load 4 into W (N = 4)
	movwf   Delay1		; Set inner loop counter 
    OuterLoop:
	movlw   0x05		; Load 5 into W (M = 5)
	movwf   Delay2		; Set outer loop counter
    InnerLoop:
	decfsz  Delay1, f	; Decrement inner counter
	goto    InnerLoop	; Repeat if not zero
	decfsz  Delay2, f	; Decrement outer counter
	goto    InnerLoop	; Repeat if not zero
	nop			; Adjust delay slightly
	return			; Return after delay complete  
	
	
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

    
GO_Straight:
    bsf     LATB,6               ; Set motor directions
    bsf     LATB,7
    
    movlw   5                    ; 25% duty cycle (5/20)
    movwf   PWM1
    movf    PWM1, W              
    movwf   CCPR1L   
    bcf     CCP1CON,4            ; Set LSBs for 5 (0101)
    bsf     CCP1CON,5
    
    movlw   5                    ; 25% duty cycle
    movwf   PWM2
    movf    PWM2, W              
    movwf   CCPR2L
    bcf     CCP2CON,4
    bsf     CCP2CON,5
    
    return

Stop_Car:
    ; Stop both motors
    bcf     LATB,6
    bcf     LATB,7
    
    movlw   0                    ; 0% duty cycle
    movwf   CCPR1L   
    bcf     CCP1CON,4
    bcf     CCP1CON,5
    
    movlw   0                    ; 0% duty cycle
    movwf   CCPR2L 
    bcf     CCP2CON,4
    bcf     CCP2CON,5
    
    return
Right:
    ; Controlled right turn - Left motor forward, Right motor reverse (slower)
    bsf     LATB,6               ; Left motor forward
    bcf     LATB,7               ; Right motor reverse
    
    movlw   8                    ; 40% duty cycle left motor (forward)
    movwf   CCPR1L   
    bcf     CCP1CON,4
    bcf     CCP1CON,5
    
    movlw   6                    ; 30% duty cycle right motor (reverse)
    movwf   CCPR2L 
    bcf     CCP2CON,4
    bcf     CCP2CON,5
    
    return

Left:
    ; Controlled left turn - Right motor forward, Left motor reverse (slower)
    bcf     LATB,6               ; Left motor reverse
    bsf     LATB,7               ; Right motor forward
    
    movlw   6                    ; 30% duty cycle left motor (reverse)
    movwf   CCPR1L   
    bcf     CCP1CON,4
    bcf     CCP1CON,5
    
    movlw   8                    ; 40% duty cycle right motor (forward)
    movwf   CCPR2L 
    bcf     CCP2CON,4
    bcf     CCP2CON,5
    
    return
        
Right_Right:
    ; 90-degree right turn - Left motor forward, right motor reverse at maximum differential
    bsf     LATB,6               ; Left motor forward  
    bcf     LATB,7               ; Right motor reverse
    
    movlw   12                   ; 75% duty cycle left motor (forward) - maximum power
    movwf   CCPR1L   
    bsf     CCP1CON,4            ; Set 1111 (15) for precise control
    bsf     CCP1CON,5
    
    movlw   15                   ; 75% duty cycle right motor but in reverse direction
    movwf   CCPR2L 
    bsf     CCP2CON,4            ; Set 1111 (15) for precise control
    bsf     CCP2CON,5
    
    return
    
Left_Left:
    ; 90-degree left turn - Right motor forward, left motor reverse at maximum differential
    bcf     LATB,6               ; Left motor reverse
    bsf     LATB,7               ; Right motor forward
    
    movlw   15                   ; 75% duty cycle left motor (reverse) - maximum power
    movwf   CCPR1L   
    bsf     CCP1CON,4            ; Set 1111 (15) for precise control
    bsf     CCP1CON,5
    
    movlw   12                   ; 75% duty cycle right motor (forward) - maximum power
    movwf   CCPR2L 
    bsf     CCP2CON,4            ; Set 1111 (15) for precise control
    bsf     CCP2CON,5
    
    return

    Cal_Delay:
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	return
    
    
END                          ; End of program file
    


