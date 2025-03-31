; PIC18F45K22 Assembly code for pic-as v2.50
#include <xc.inc>

; CONFIG directives
CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register)

;========== Definition of variables ==========
RESULTHI	equ	0x00          ; Variable to store high byte of ADC result
Delay1		equ	0x01          ; Counter variable for delay loops
Delay2		equ	0x02          ; Counter variable for nested delay loops
Delay3		equ	0x03          ; Counter variable for longer delay loops
Delay4		equ	0x04          ; Counter variable for nested longer delay loops
Counter		equ	0x05          ; Counter for LED flashing repetitions
Temp_Value	equ	0x06          ; Temporary storage
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
	
MM_black_max_red    equ 0x2C	      ; Calibrated Max for BLACK	
MM_black_max_green  equ 0x2D	
MM_black_max_blue   equ 0x2E
	
MM_white_min_red    equ 0x2F	      ; Calibrated Min for WHITE	
MM_white_min_green  equ 0x30	
MM_white_min_blue   equ 0x31	
   
Test_start_bit	    equ 0x32	      ; Temporary Test bit for Cap Touch Start -> uses INT2 -> RB2 to set the bit    
   
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
;	CLRF    ANSELX    ; Set all PORTX pins to digital (digital = 0 / input = 1)
;	CLRF    TRISX     ; Set all PORTX pins to outputs (output = 0 / input = 1)
    
       ;CLRF    PORTA,0		    ; PORTA Taken: <7:0> digital outputs. <7:3> calibration colour (7=Black,6=Blue,5=Green,4=Red,3=White , <2:0> RGB Array (2=blue,1=green,0=red)         
       ;CLRF    LATA,0	  
	CLRF    ANSELA,1    
	CLRF    TRISA,0     
	
	CLRF    PORTB,0		    ; PORTB <7:6> and <3:0> digital inputs. <5:4> analog inputs
	CLRF    LATB,0
	CLRF    ANSELB,1
	CLRF    TRISB,0
    
	CLRF    PORTC,0		    ; PORTC <7:2> analog inputs , <1;:0> digital inputs.      -----------------------> RC2 and RC1 to be used for PWM (consult Johan)
	CLRF    LATC,0
	CLRF    ANSELC,1
	CLRF    TRISC,0
	
	CLRF    PORTD,0		    ; PORTD Taken - Intended Setup: <7:0> digital outputs. 
	CLRF    LATD,0
	CLRF    ANSELD,1
	CLRF    TRISD,0
	
	CLRF    PORTE,0		    ; PORTE
	CLRF    LATE,0
	CLRF    ANSELE,1
	CLRF    TRISE,0 
	
; ADC SETUP:
	
    ; ADCON2:
        MOVLW   0b00111110			    ; <7> Left justify = 0, <6> Unimplemented = 0 ,<5:3> Acquisition Time = 20 T_AD = 111, <2:0> ADC clock = FOSC/64 = 110.
        MOVWF   ADCON2,0
	
    ; ADCON1:           
        CLRF   ADCON1,0				    ; Use Vref+ = Vdd and Vref- = Vss
	
	; Clear ADC result high byte
	CLRF    ADRESH,0 
	
; PORT SETUP:
	
    ;PORTA Setup:
	MOVLW	0b00000111  
	MOVWF	PORTA,0				    ; Output (digital) on RA0, RA1, RA2 -> Keeps RGB Array Off
	
    ;PORTB Setup:
	MOVLW   0b00000000
	MOVWF   ANSELB,1			    ; PORTB <7:6> RB7, RB6 unimplemented, <5:4> RB5-RB4 digital, <3:0> RB0-RB3 digital.
	MOVLW	0b11101111			    ; Make RB4 output and rest input
	MOVWF   TRISB
	
	BSF	LATB, 4    ; Set RB4 high (VDD)	    ; Part of CAP TOUCH - secondary channel (RB4) to VDD as digital output
	
	
    ;PORTC Setup:
	MOVLW	0b11111100
	MOVWF	ANSELC,1			    ; Make PORTC <7:2> analog.
	SETF	TRISC,0				    ; Make entire PORTC input pins.
	
    ;PORTD Setup:
    ;The setup that was needed was done when clearing everything in D registers above
		
    ;PORTE Setup:
	;Not used atm
    
	       
    MOVLB   0x0					    ; Return to Bank 0 for normal operation
    
; OSCILLATOR SETUP:
    
    BSF	    OSCCON, 6				    ;IRCF2	    ;Oscillator Speed is 4MHz OSCON <6:4> / IRCF <2:0> 
    BCF	    OSCCON, 5				    ;IRCF1
    BSF	    OSCCON, 4				    ;IRCF0
    
    
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

;======================================================================================================================================================================================    
    
Main:
    
    CALL    ADC_Loop				    ; used to continually strobe/poll sensors and store a value so that sensor register
    CALL    ADC_Read				    ; used to show what colour we on (uses sensor_MM strobed value)
    ;GOTO    CAP_Touch_Sense			    ; used to continuously check if touch sensed
    GOTO    Cap_Touch_Start			    ; starts cap touch if bit set
    
    ;Interrupts handled in HP_ISR
    ;Interrupt on RB0 -> INT0 -> Calibrate_ver_RGB
    ;Interrupt on RB1 -> INT1 -> Follower_Colour_Select
    ;Interrupt on RB2 -> INT2 -> Test for Cap Touch Start for now 
   
    ;GOTO	Main   
  
;======================================================================================================================================================================================    
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  CAP TOUCH - Sensing Steps  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;	    
;1. Drive secondary channel to VDD as digital output.				- Done in Setup
;2. Point ADC to the secondary VDD pin (charges CHOLD to VDD).			-   
;3. Ground sensor line.								-
;4. Turn sensor line as input (TRISx = 1).					-
;5. Point ADC to sensor channel (voltage divider from sensor to CHOLD).		-
;6. Begin ADC conversion.							-
;7. Reading is in ADRESH:ADRESL.						-
;	    
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	
;
;CAP_Touch_Sense:
;    
;    ; STEP 1:
;	; Port RB4 already setup
;	
;    ; STEP 2: Point ADC to the secondary VDD pin
;	MOVLW 0b00111101	    ; Select AN15 (RB4) as the secondary ADC channel
;	MOVWF ADCON0
;   
;    ; STEP 3: Ground sensor line
;	BCF TRISB, 5		  ; RB5 as output
;	BCF LATB, 5		  ; Drive RB5 low (GND)
;    
;    ; STEP 4: Turn sensor pin to input
;	BSF TRISB, 5		  ; Set RB5 as input (floating touch sensor)
;    
;    ; STEP 5: Point ADC to sensor channel
;	MOVLW 0b00110101          ; Select AN13 (RB5) as sensor ADC channel
;	MOVWF ADCON0
;    
;    ; STEP 6: Start ADC Conversion
;	CALL	ADC_Start	    
;    
;    ; STEP 7:
;	MOVF	ADRESH, W	    ; Read high byte of ADC result
;	MOVWF	RESULTHI	    ; Store result

    
    ; Repeat or Process the Sensor Value    <--------------------------------------------------------------------------- TEST MULTIPLE TIMES
    
    
Cap_Touch_Start:   
; Checks if CAP Start Touch Enabled    
    
    BTFSC   Test_start_bit,0			    ; Test with a set bit for now on external interrupt INT2 - RB2
    GOTO    LLI			       
    GOTO    Main
  
LLI:
    
    BTFSC   follow_colour, 4			    ; Follow RED
    GOTO    follow_red
    
    BTFSC   follow_colour, 5			    ; Follow GREEN
    GOTO    follow_green
    
    BTFSC   follow_colour, 6			    ; Follow BLUE
    GOTO    follow_blue
    
    BTFSC   follow_colour, 7			    ; Follow BLACK
    GOTO    follow_black
    
    GOTO    Main		
    
    
    follow_red:
	
	MOVLW	0b00000000
	MOVWF	PORTD				    ; Turns direction LEDs OFF
	BCF	PORTA, 0			    ; Turns RED RGB Array ON
	CALL	Delay3Hz
	CALL	ADC_Loop			    ; Get sensor values for RED
	
    
	red_straight:
    		      
	    MOVF	sensor_MM,0		    ; Fetch sensor_MM value to compare
	    CPFSLT	MM_red_min,0		    ; Compare MM_red_min with sensor_MM, skip if MM_red_min < sensor_MM
	    GOTO	red_right		    ; Checks MR sensor		
	    CPFSGT	MM_red_max,0		    ; Compare MM_red_max with sensor_MM, skip if MM_red_max > sensor_MM
	    GOTO	red_right		    ; Checks MR sensor
	    BSF		PORTD, 0		    ; Indicates STRAIGHT
	    
	    ; EXECUTE MOTOR STRAIGHT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			    
	    GOTO	follow_red		    ; Repeats Check after motor moved
	
	red_right:
		       
	    MOVF	sensor_MR,0		    ; Fetch sensor_MR value to compare
	    CPFSLT	MR_red_min,0		
	    GOTO	red_left				
	    CPFSGT	MR_red_max,0		
	    GOTO	red_left		
	    BSF		PORTD, 1		    ; Indicates RIGHT
	    
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_red		
	
	red_left:
		       
	    MOVF	sensor_ML,0		    ; Fetch sensor_ML value to compare
	    CPFSLT	ML_red_min,0		
	    GOTO	red_right_right				
	    CPFSGT	ML_red_max,0		
	    GOTO	red_right_right		
	    BSF		PORTD, 2		    ; Indicates LEFT
	    
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_red
    
	red_right_right:   
		       
	    MOVF	sensor_RR,0		    ; Fetch sensor_RR value to compare
	    CPFSLT	RR_red_min,0		
	    GOTO	red_left_left				
	    CPFSGT	RR_red_max,0		
	    GOTO	red_left_left		
	    BSF		PORTD, 1		    ; Indicates RIGHT
	    
	    ; EXECUTE MOTOR HARD RIGHT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_red    
	  
	red_left_left:
		       
	    MOVF	sensor_LL,0		    ; Fetch sensor_LL value to compare
	    CPFSLT	LL_red_min,0		
	    GOTO	red_stop				
	    CPFSGT	LL_red_max,0		
	    GOTO	red_stop		
	    BSF		PORTD, 2		    ; Indicates LEFT
	    
	    ; EXECUTE MOTOR HARD LEFT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_red
	    
	red_stop:
	; Checks if at end line
    
	    MOVF	sensor_MM,0		    ; Check if Middle Sensor on BLACK
	    CPFSGT	MM_black_max_red,0	      
	    GOTO	LOST
	    
	    MOVF	sensor_RR,0		    ; Check if Right Right Sensor on Black
	    CPFSGT	MM_black_max_red,0	      
	    GOTO	LOST
	    
	    MOVF	sensor_LL,0		    ; Check if Left Left Sensor on Black    
	    CPFSGT	MM_black_max_red,0	     
	    GOTO	LOST
	
	    GOTO IDLE    
	    
    GOTO follow_red				    ; Safety Net
    
    
    
    follow_green:
    
	MOVLW	0b00000000
	MOVWF	PORTD				    ; Turns direction LEDs OFF
	BCF	PORTA, 1			    ; Turns GREEN RGB Array ON
	CALL	Delay3Hz			    
	CALL	ADC_Loop			    ; Get sensor values for GREEN
	
    
	green_straight:
    		      
	    MOVF	sensor_MM,0		    
	    CPFSLT	MM_green_min,0		    
	    GOTO	green_right		   	
	    CPFSGT	MM_green_max,0		    
	    GOTO	green_right		    
	    BSF		PORTD, 0		    ; Indicates STRAIGHT
	    
	    ; EXECUTE MOTOR STRAIGHT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			    
	    GOTO	follow_green		    
	
	green_right:
		       
	    MOVF	sensor_MR,0		    
	    CPFSLT	MR_green_min,0		
	    GOTO	green_left				
	    CPFSGT	MR_green_max,0		
	    GOTO	green_left		
	    BSF		PORTD, 1		    ; Indicates RIGHT
	    
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_green		
	
	green_left:
		       
	    MOVF	sensor_ML,0		    
	    CPFSLT	ML_green_min,0		
	    GOTO	green_right_right				
	    CPFSGT	ML_green_max,0		
	    GOTO	green_right_right		
	    BSF		PORTD, 2		    ; Indicates LEFT
	    
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_green
    
	green_right_right:   
		       
	    MOVF	sensor_RR,0		   
	    CPFSLT	RR_green_min,0		
	    GOTO	green_left_left				
	    CPFSGT	RR_green_max,0		
	    GOTO	green_left_left		
	    BSF		PORTD, 1		    ; Indicates RIGHT
	    
	    ; EXECUTE MOTOR HARD RIGHT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_green    
	  
	green_left_left:
		       
	    MOVF	sensor_LL,0		    
	    CPFSLT	LL_green_min,0		
	    GOTO	green_stop				
	    CPFSGT	LL_green_max,0		
	    GOTO	green_stop		
	    BSF		PORTD, 2		    ; Indicates LEFT
	    
	    ; EXECUTE MOTOR HARD LEFT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_green
	    
	green_stop:
	; Checks if at end line
    
	    MOVF	sensor_MM,0		    ; Check if Middle Sensor on BLACK
	    CPFSGT	MM_black_max_green,0	      
	    GOTO	LOST
	    
	    MOVF	sensor_RR,0		    ; Check if Right Right Sensor on Black
	    CPFSGT	MM_black_max_green,0	      
	    GOTO	LOST
	    
	    MOVF	sensor_LL,0		    ; Check if Left Left Sensor on Black    
	    CPFSGT	MM_black_max_green,0	     
	    GOTO	LOST
	
	    GOTO IDLE    
	    
    GOTO follow_green				    ; Safety Net
    
    
    
    follow_blue:
    
	MOVLW	0b00000000
	MOVWF	PORTD				    ; Turns direction LEDs OFF
	BCF	PORTA, 2			    ; Turns BLUE RGB Array ON
	CALL	Delay3Hz			    
	CALL	ADC_Loop			    ; Get sensor values for GREEN
	
    
	blue_straight:
    		      
	    MOVF	sensor_MM,0		    
	    CPFSLT	MM_blue_min,0		    
	    GOTO	blue_right		   	
	    CPFSGT	MM_blue_max,0		    
	    GOTO	blue_right		    
	    BSF		PORTD, 0		    ; Indicates STRAIGHT
	    
	    ; EXECUTE MOTOR STRAIGHT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			    
	    GOTO	follow_blue		    
	
	blue_right:
		       
	    MOVF	sensor_MR,0		    
	    CPFSLT	MR_blue_min,0		
	    GOTO	blue_left				
	    CPFSGT	MR_blue_max,0		
	    GOTO	blue_left		
	    BSF		PORTD, 1		    ; Indicates RIGHT
	    
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_blue		
	
	blue_left:
		       
	    MOVF	sensor_ML,0		    
	    CPFSLT	ML_blue_min,0		
	    GOTO	blue_right_right				
	    CPFSGT	ML_blue_max,0		
	    GOTO	blue_right_right		
	    BSF		PORTD, 2		    ; Indicates LEFT
	    
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_blue
    
	blue_right_right:   
		       
	    MOVF	sensor_RR,0		   
	    CPFSLT	RR_blue_min,0		
	    GOTO	blue_left_left				
	    CPFSGT	RR_blue_max,0		
	    GOTO	blue_left_left		
	    BSF		PORTD, 1		    ; Indicates RIGHT
	    
	    ; EXECUTE MOTOR HARD RIGHT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_blue    
	  
	blue_left_left:
		       
	    MOVF	sensor_LL,0		    
	    CPFSLT	LL_blue_min,0		
	    GOTO	blue_stop				
	    CPFSGT	LL_blue_max,0		
	    GOTO	blue_stop		
	    BSF		PORTD, 2		    ; Indicates LEFT
	    
	    ; EXECUTE MOTOR HARD LEFT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_blue
	    
	blue_stop:
	; Checks if at end line
    
	    MOVF	sensor_MM,0		    ; Check if Middle Sensor on BLACK
	    CPFSGT	MM_black_max_blue,0	      
	    GOTO	LOST
	    
	    MOVF	sensor_RR,0		    ; Check if Right Right Sensor on Black
	    CPFSGT	MM_black_max_blue,0	      
	    GOTO	LOST
	    
	    MOVF	sensor_LL,0		    ; Check if Left Left Sensor on Black    
	    CPFSGT	MM_black_max_blue,0	     
	    GOTO	LOST
	
	    GOTO IDLE	    
	    
    GOTO follow_green				    ; Safety Net
    
    
    
    follow_black:
    ;Needs to check STOP first, but only after a certain number of motor movements to get past start line
    ; maybe just go straight or a set time?									<----------------------------------------------------- ATTENTION!
    
    
	MOVLW	0b00000000
	MOVWF	PORTD				    ; Turns direction LEDs OFF
	BCF	PORTA, 0			    ; Turns RED RGB Array ON
	CALL	Delay3Hz			    
	CALL	ADC_Loop			    ; Get sensor values
    
	black_stop:
	; Checks if at end line
    
	    MOVF	sensor_MM,0		    ; Check if Middle Sensor on BLACK
	    CPFSGT	MM_black_max_red,0	    ; Compare MM_black_max_blue with sensor_MM, skip if MM_black_max_blue > sensor_MM  
	    GOTO	black_straight
	    
	    MOVF	sensor_RR,0		    ; Check if Right Right Sensor on Black
	    CPFSGT	MM_black_max_red,0	      
	    GOTO	black_straight
	    
	    MOVF	sensor_LL,0		    ; Check if Left Left Sensor on Black    
	    CPFSGT	MM_black_max_red,0	     
	    GOTO	black_straight
	    
	    GOTO IDLE
    
	black_straight:
		      
	    MOVF	sensor_MM,0		    		   	
	    CPFSGT	MM_black_max_red,0		    
	    GOTO	black_right		    
	    BSF		PORTD, 0		    ; Indicates STRAIGHT
	
	    ; EXECUTE MOTOR STRAIGHT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_black    
	
	black_right:
		      
	    MOVF	sensor_MR,0		    		   	
	    CPFSGT	MM_black_max_red,0		    
	    GOTO	black_left		    
	    BSF		PORTD, 1		    ; Indicates RIGHT
	
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_black    
    
	black_left:
		      
	    MOVF	sensor_ML,0		    		   	
	    CPFSGT	MM_black_max_red,0		    
	    GOTO	black_right_right		    
	    BSF		PORTD, 2		    ; Indicates RIGHT
	
	    ; EXECUTE MOTOR SOFT LEFT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_black
    
	black_right_right:
		      
	    MOVF	sensor_RR,0		    		   	
	    CPFSGT	MM_black_max_red,0		    
	    GOTO	black_left_left		    
	    BSF		PORTD, 1		    ; Indicates RIGHT
	
	    ; EXECUTE MOTOR HARD RIGHT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_black
	    
	black_left_left:
		      
	    MOVF	sensor_LL,0		    		   	
	    CPFSGT	MM_black_max_red,0		    
	    GOTO	LOST		    
	    BSF		PORTD, 2		    ; Indicates RIGHT
	
	    ; EXECUTE MOTOR HARD LEFT FUNCTION											<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay2s			
	    GOTO	follow_black
      
	    
    LOST:
	BSF PORTD, 3				    ; Indicate LOST
	
	    ; EXECUTE A MOTOR FUNCTION	(STRAIGHT?)										<------------------------------------- MOTOR FUNC
	
	GOTO	LLI
	
	
	
    IDLE:
	BSF	PORTD, 4				    ; Indicate STOP
	MOVLW	0b00000111				    ; Turn OFF RBG Arrays and Colour LEDs
	MOVWF	PORTA
	BCF	Test_start_bit, 0			    ; Refreshes the Capacitive Touch Start Bit
	CALL	Delay2s
	GOTO	Main					    ; Loop at main until start
	    
;------------------------------------------------------------------------     ADC     ------------------------------------------------------------------------   
    
ADC_Loop:
    
    BTFSS   Test_start_bit, 0			; Check if Started
    BSF	    PORTA, 0				; Use RED LED Array when IDLE, else will use whatever array set in other functions
    
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
	
	
ADC_Read:
    ; used to show what colour we on (uses last known sensor_MM strobed value)    -------------------------------------    ONLY USED WHEN NOT STARTED
    
    MOVF	sensor_MM,0			; Fetch sensor_MM value to compare (Stored in WREG)
    CALL	Check_Red
    BCF		PORTA, 0			; Turn off RED LED Array set in ADC Loop if start was not set --- Safety Net
    RETURN
    
    Check_Red:		       
	CPFSLT	MM_red_min,0			; Compare MM_red_min with sensor_MM, skip if MM_red_min < sensor_MM
	GOTO	Check_Green			; Checks if green		
	CPFSGT	MM_red_max,0			; Compare MM_red_max with sensor_MM, skip if MM_red_max > sensor_MM
	GOTO	Check_Green			; Checks if green
	BSF	PORTA, 4
	CALL    Delay2s
	return
    Check_Green:		     
	CPFSLT	MM_green_min,0		
	GOTO	Check_Blue				
	CPFSGT	MM_green_max,0		
	GOTO	Check_Blue		
	BSF	PORTA, 5
	CALL    Delay2s
	return
    Check_Blue:		     
	CPFSLT	MM_blue_min,0		
	GOTO	Check_Black				
	CPFSGT	MM_blue_max,0		
	GOTO	Check_Black		
	BSF	PORTA, 6
	CALL    Delay2s
	return
    Check_Black:				
	CPFSGT	MM_black_max_red,0		
	GOTO	Check_White		
	BSF	PORTA, 7
	CALL    Delay2s
	return
    Check_White:			  
	BSF	PORTA, 3
	CALL    Delay2s
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
    ;CALL   
;    
    RETFIE  1 
    
LP_ISR:
    RETFIE  1

;--------------------------	    --------------------------	    --------------------------	    --------------------------	    --------------------------    
Calibrate_ver_RGB:
    ;Calibrates each sensor for each colour for each RGB value.
    
    MOVLW 0b00000111				    ; Ensures that all LEDs are off
    MOVWF PORTA
    
    ;CALL Red_Calibrate
    ;CALL Green_Calibrate
    ;CALL Blue_Calibrate
    ;CALL Black_Calibrate
    ;Call White_Calibrate
    
    Red_Calibrate:
    
	BCF	PORTA, 0			    ; Turns RED RGB Array ON
    
	BSF	PORTA, 4			    ; Indicates that RED is to be sampled
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	
	;sensor_MM
	MOVLW   0b00111101                          ; Select ADC Channel AN15 -> RC3 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    ; Store current ADC reading in WREG
	MOVWF	Temp_Value			    ; Store ADC reading in temporary register
	ADDLW   0b00000101			    ; add a 97.65mV on top of the Measured ADC reading
	MOVWF   MM_red_max			    ; Store max value
	MOVLW	0b00001010			    ; 195.3mV -> max - 195.3mV = base - 97.65mV
	SUBWF	MM_red_max, 0			    ; Subtract WREG from MM_red_Max, result stored in WREG
	MOVWF	MM_red_min			    ; Store min value
	;sensor_MR
	MOVLW   0b01000001                          ; Select ADC Channel AN16 -> RC4 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    
	MOVWF	Temp_Value			    
	ADDLW   0b00001010			    
	MOVWF   MR_red_max			    
	MOVLW	0b00010100			    
	SUBWF	MR_red_max, 0			    
	MOVWF	MR_red_min
	;sensor_ML
	MOVLW   0b01000101                          ; Select ADC Channel AN17 -> RC5 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    
	MOVWF	Temp_Value			    
	ADDLW   0b00001010			    
	MOVWF   ML_red_max			    
	MOVLW	0b00010100			    
	SUBWF	ML_red_max, 0			    
	MOVWF	ML_red_min
	;sensor_RR
	MOVLW   0b01001001                          ; Select ADC Channel AN18 -> RC6 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    
	MOVWF	Temp_Value			    
	ADDLW   0b00001010			    
	MOVWF   RR_red_max			    
	MOVLW	0b00010100			    
	SUBWF	RR_red_max, 0			    
	MOVWF	RR_red_min
	;sensor_LL
	MOVLW   0b01001101                          ; Select ADC Channel AN19 -> RC7 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    
	MOVWF	Temp_Value			    
	ADDLW   0b00001010			    
	MOVWF   LL_red_max			    
	MOVLW	0b00010100			    
	SUBWF	LL_red_max, 0			    
	MOVWF	LL_red_min
	
	BSF	PORTA, 0			    ; Turns RED RGB Array OFF 
				    
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
	;RETURN

    Green_Calibrate:
    
	BCF	PORTA, 1			    ; Turns GREEN RGB Array ON
    
	BSF	PORTA, 5			    ; Indicates that GREEN is to be sampled
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	
	;sensor_MM
	MOVLW   0b00111101                          ; Select ADC Channel AN15 -> RC3 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    
	MOVWF	Temp_Value			    
	ADDLW   0b00000101			    
	MOVWF   MM_green_max			    
	MOVLW	0b00001010			    
	SUBWF	MM_green_max, 0			    
	MOVWF	MM_green_min			    
	;sensor_MR
	MOVLW   0b01000001                          ; Select ADC Channel AN16 -> RC4 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    
	MOVWF	Temp_Value			    
	ADDLW   0b00001010			    
	MOVWF   MR_green_max			    
	MOVLW	0b00010100			    
	SUBWF	MR_green_max, 0			    
	MOVWF	MR_green_min
	;sensor_ML
	MOVLW   0b01000101                          ; Select ADC Channel AN17 -> RC5 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    
	MOVWF	Temp_Value			    
	ADDLW   0b00001010			    
	MOVWF   ML_green_max			    
	MOVLW	0b00010100			    
	SUBWF	ML_green_max, 0			    
	MOVWF	ML_green_min
	;sensor_RR
	MOVLW   0b01001001                          ; Select ADC Channel AN18 -> RC6 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    
	MOVWF	Temp_Value			    
	ADDLW   0b00001010			    
	MOVWF   RR_green_max			    
	MOVLW	0b00010100			    
	SUBWF	RR_green_max, 0			    
	MOVWF	RR_green_min
	;sensor_LL
	MOVLW   0b01001101                          ; Select ADC Channel AN19 -> RC7 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    
	MOVWF	Temp_Value			    
	ADDLW   0b00001010			    
	MOVWF   LL_green_max			    
	MOVLW	0b00010100			    
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
	;RETURN
	
    Blue_Calibrate:
    
	BCF	PORTA, 2			    ; Turns BLUE RGB Array ON
    
	BSF	PORTA, 6			    ; Indicates that BLUE is to be sampled
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	
	;sensor_MM
	MOVLW   0b00111101                          ; Select ADC Channel AN15 -> RC3 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    
	MOVWF	Temp_Value			    
	ADDLW   0b00000101			    
	MOVWF   MM_blue_max			    
	MOVLW	0b00001010			    
	SUBWF	MM_blue_max, 0			    
	MOVWF	MM_blue_min			    
	;sensor_MR
	MOVLW   0b01000001                          ; Select ADC Channel AN16 -> RC4 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    
	MOVWF	Temp_Value			    
	ADDLW   0b00001010			    
	MOVWF   MR_blue_max			    
	MOVLW	0b00010100			    
	SUBWF	MR_blue_max, 0			    
	MOVWF	MR_blue_min
	;sensor_ML
	MOVLW   0b01000101                          ; Select ADC Channel AN17 -> RC5 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    
	MOVWF	Temp_Value			    
	ADDLW   0b00001010			    
	MOVWF   ML_blue_max			    
	MOVLW	0b00010100			    
	SUBWF	ML_blue_max, 0			    
	MOVWF	ML_blue_min
	;sensor_RR
	MOVLW   0b01001001                          ; Select ADC Channel AN18 -> RC6 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    
	MOVWF	Temp_Value			    
	ADDLW   0b00001010			    
	MOVWF   RR_blue_max			    
	MOVLW	0b00010100			    
	SUBWF	RR_blue_max, 0			    
	MOVWF	RR_blue_min
	;sensor_LL
	MOVLW   0b01001101                          ; Select ADC Channel AN19 -> RC7 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    
	MOVWF	Temp_Value			    
	ADDLW   0b00001010			    
	MOVWF   LL_blue_max			    
	MOVLW	0b00010100			    
	SUBWF	LL_blue_max, 0			    
	MOVWF	LL_blue_min
	
	BSF	PORTA, 1			    ; Turns BLUE RGB Array OFF 
				    
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
	;RETURN
	
    Black_Calibrate:
   
	BSF	PORTA, 7			    ; Indicates that BLACK is to be sampled
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	
	;sensor_MM
	MOVLW   0b00111101                          ; Select ADC Channel AN15 -> RC3 (sensor_MM)
	MOVWF   ADCON0
	
	BCF	PORTA, 0			    ; Turns RED RGB Array ON
	
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	ADDLW   0b00000101			    ; Add 97.65mV		    
	MOVWF   MM_black_max_red	
	BSF	PORTA, 0			    ; Turns RED RGB Array OFF
	BCF	PORTA, 1			    ; Turns GREEN RGB Array ON
	CALL    ADC_Start
	MOVF    ADRESH, W			    	    			    
	ADDLW   0b00000101			   		    
	MOVWF   MM_black_max_green	
	BSF	PORTA, 1			    ; Turns GREEN RGB Array OFF
	BCF	PORTA, 2			    ; Turns BLUE RGB Array ON
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	ADDLW   0b00000101			    		    
	MOVWF   MM_black_max_blue	
	BSF	PORTA, 2			    ; Turns BLUE RGB Array OFF
	
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
	;RETURN
	
White_Calibrate:
   
	BSF	PORTA, 3			    ; Indicates that WHITE is to be sampled
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	
	;sensor_MM
	MOVLW   0b00111101                          ; Select ADC Channel AN15 -> RC3 (sensor_MM)
	MOVWF   ADCON0
	
	BCF	PORTA, 0			    ; Turns RED RGB Array ON
	
	CALL    ADC_Start
	MOVF    ADRESH, W
	MOVWF	MM_white_min_red		    ; Store ADC value in White_min_red
	MOVLW   0b00000101			    ; Load 97.65mV
	SUBWF	MM_white_min_red,1		    ; Subtract and store back in register White_min_red	
	BSF	PORTA, 0			    ; Turns RED RGB Array OFF
	
	BCF	PORTA, 1			    ; Turns GREEN RGB Array ON
	CALL    ADC_Start
	MOVF    ADRESH, W			    	    			    
	MOVWF	MM_white_min_green			    
	MOVLW   0b00000101			    
	SUBWF	MM_white_min_green,1		    
	BSF	PORTA, 1			    ; Turns GREEN RGB Array OFF
	
	BCF	PORTA, 2			    ; Turns BLUE RGB Array ON
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	MOVWF	MM_white_min_blue			    
	MOVLW   0b00000101			    
	SUBWF	MM_white_min_blue,1,0		    	
	BSF	PORTA, 2			    ; Turns BLUE RGB Array OFF
	
	BCF	PORTA, 3			    ; Indicate that Black_Calibrate is completed
	CALL    Delay3Hz
	BSF	PORTA, 3
	CALL    Delay3Hz
	BCF	PORTA, 3
	CALL    Delay3Hz
	BSF	PORTA, 3
	CALL    Delay3Hz
	BCF	PORTA, 3
	CALL    Delay3Hz
	BSF	PORTA, 3
	CALL    Delay3Hz
	BCF	PORTA, 3
	CALL    Delay3Hz
	;RETURN
	
    MOVLW   0b00000111
    MOVWF   PORTA				    ; Ensures that all LEDs are off
    
    BSF	    INTCON, 4				    ; Sets INT0 External Interrupt Enable bit (Interrupt can be used again)
    BCF	    INTCON, 1				    ; Clears interrupt flag: INT0 -> RB0
	
    RETURN					    ; Return to HP_ISR:
    
;--------------------------	    --------------------------	    --------------------------	    --------------------------	    --------------------------
Follower_Colour_Select:
; Sets the colour we want to follow    
    
	MOVLW   0b00111101			    ; Using sensor_MM (AN15 -> RC3) to select colour
	MOVWF   ADCON0
	
	MOVLW   0b11111111			    ; Indicate we are to sample
	MOVWF   PORTA  
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	MOVLW   0b00000111
	MOVWF   PORTA 
	
	CALL    ADC_Start			    ; Start ADC reading
	MOVF    ADRESH, W			    ; Store ADC reading in WREG			    
    
	CALL	Red				    ; Starts colour select check
	
	BSF	INTCON3, 3			    ; Sets INT1 External Interrupt Enable bit (Interrupt can be used again)
	BCF	INTCON3, 0			    ; Clears interrupt flag: INT1 -> RB1
    
	RETURN					    ; Return to HP_ISR:
	
    Red:		       
	CPFSLT	MM_red_min,0			    ; Compare MM_red_min with sensor_MM (WREG) , skip if MM_red_min < sensor_MM (WREG)
	GOTO	Green				    ; Checks if green		
	CPFSGT	MM_red_max,0			    ; Compare MM_red_max with sensor_MM, skip if MM_red_max > sensor_MM (WREG)
	GOTO	Green				    ; Checks if green
	BSF	PORTA, 4
	BSF	follow_colour, 4
	CALL    Delay2s
	return
    Green:		     
	CPFSLT	MM_green_min,0		
	GOTO	Blue				
	CPFSGT	MM_green_max,0		
	GOTO	Blue		
	BSF	PORTA, 5
	BSF	follow_colour, 5
	CALL    Delay2s
	return
    Blue:		     
	CPFSLT	MM_blue_min,0		
	GOTO	Black				
	CPFSGT	MM_blue_max,0		
	GOTO	Black		
	BSF	PORTA, 6
	BSF	follow_colour, 6
	CALL    Delay2s
	return
    Black:				
	CPFSGT	MM_black_max_red,0		
	GOTO	White		
	BSF	PORTA, 7
	BSF	follow_colour, 7
	CALL    Delay2s
	return
    White:
	MOVLW   0b11111111
	MOVWF	PORTA
	BSF	follow_colour, 7		    ; Follow BLACK as last alternative
	CALL    Delay2s
	return

;------------------------------------------------------------------------    INTERRUPTS  END   ------------------------------------------------------------------------      
    
  
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
      
    
END                          ; End of program file
    