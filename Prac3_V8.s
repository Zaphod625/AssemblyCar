; PIC18F45K22 Assembly code for pic-as v2.50
PROCESSOR 18F45K22    
    
#include <xc.inc>
#include "pic18f45k22.inc"   
    

; CONFIG directives
CONFIG  FOSC = INTIO67        ; Oscillator Selection bits (Internal oscillator block, port function on RA6 and RA7)
CONFIG  WDTEN = OFF           ; Watchdog Timer Enable bit (WDT is controlled by SWDTEN bit of the WDTCON register)

;============================== Registers ==============================
RESULTHI	equ	0x00          ; Variable to store high byte of ADC result
DelayA		equ	0x01          ; Counter variable for delay loops
DelayB		equ	0x02          ; Counter variable for nested delay loops
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
RR_black_max_red	equ	0x2F
LL_black_max_red	equ	0x30
    
MM_black_max_green	equ	0x31
MR_black_max_green	equ	0x32
ML_black_max_green	equ	0x33
RR_black_max_green	equ	0x34
LL_black_max_green	equ	0x35
    
MM_black_max_blue	equ	0x36
MR_black_max_blue	equ	0x37
ML_black_max_blue	equ	0x38
RR_black_max_blue	equ	0x39
LL_black_max_blue	equ	0x3A
	
MM_white_min_red	equ	0x3B	      ; Calibrated Min for WHITE	
MM_white_min_green	equ	0x3C	
MM_white_min_blue	equ	0x3D
   
Test_start_bit		equ	0x3E	      ; Temporary Test bit for Cap Touch Detect Enable -> uses INT2 -> RB2 to set the bit    	    	    
	    
Vread			equ	0x3F	      ; Voltage reading register
switchState		equ	0x40	      ; Switch State (PRESSED = 1, UNPRESSED = 0)

PWM1			equ	0x41
PWM2			equ	0x42
state			equ	0x43
			
;========== UART RAM Variables ==========
RXIndex			equ	0x44  ; Index for received characters
Temp			equ	0x45  ; Temporary variable
;Counter		equ	0x46  ; Counter for loops
RXBuffSize		equ	0x47  ; Size of receive buffer
CurrentMode		equ	0x48  ; Current MARV mode (0=Menu, 1=Select, 2=Calibrate, 3=Race, etc.)
SelectedColor		equ	0x49  ; Selected color (0=None, 1=Red, 2=Green, 3=Blue, 4=Black)
DisplayValue		equ	0x4A  ; Value to display on 7-segment display
ProgramIndex		equ	0x4B  ; Index for program mode (editing slogan)
EditMode		equ	0x4C  ; Flag to indicate we are in edit mode
	
;--- I2C Variables (Adjusted to avoid conflicts with UART code)
TX_BYTE			EQU	0x4D
POLL_COUNTER		EQU	0x4E
Delay1			EQU	0x4F
Delay2			EQU	0x50
EEPROM_ADDRESS		EQU	0x51
BYTE_COUNT		EQU	0x52
TEMP_COUNTER		EQU	0x53
    
; Parameters for functions
SRC_PTR_L		EQU	0x54
SRC_PTR_H		EQU	0x55
DEST_PTR_L		EQU	0x56
DEST_PTR_H		EQU	0x57
START_ADDR		EQU	0x58
    
WRITE_CONTROL		EQU	10100000B  ; Control byte for write operations (A0h)
READ_CONTROL		EQU	10100001B  ; Control byte for read operations (A1h)
			
			
movlw   0x13         ; PWM period of 50 kHz
movwf   PR2          ; 0001 0011
    
clrf    TMR2          
clrf    T2CON
    
movlw   0b00000100  ; Configure Timer2 Enable Timer2 with 1:1 prescaler
movwf   T2CON		
			
bcf	CCP1CON,4
bsf	CCP1CON,5
		
		
; NOTE BSR GOES TO 59h UNTIL SFR IN USE		
		
;============= Variables ================================	
		
THRESHOLD		equ	0xFF		//THRESHOLD value
	
Range_Cal_Value_1	equ	0b00001010	//  195mV 
Range_Cal_Value_2	equ	0b00010100	//  390mV (bottom value = (2* Range_Cal_Value_2 ) - top value)
Range_Cal_Value_3	equ	0b00010000	//  312mV
Range_Cal_Value_4	equ	0b00100000	//  624mV
    
;------------------------------------------------------------------------------------------------------------------        
	        
	    
PSECT code,abs //Start of main code.     
 
org	0x00
GOTO	Setup
     
org	0x08
GOTO	HP_ISR
     
org	0x18
GOTO	LP_ISR


; ========== Setup Ports and ADC =======================
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
	
; ========== ADC SETUP: ==============================
	
    ; ADCON2:  ----TAD 16 & FOSC/32 FOR TESTING---------
        ;MOVLW   0b00111110			    ; <7> Left justify = 0, <6> Unimplemented = 0 ,<5:3> Acquisition Time = 20 T_AD = 111, <2:0> ADC clock = FOSC/64 = 110.
	MOVLW	0b00110101
        MOVWF   ADCON2,0
	
    ; ADCON1:
	MOVLW	0b00000000			    ; MOVLW	0b00000000 - Use Vref+ = Vdd and Vref- = Vss (old)
        MOVWF   ADCON1,0			    ; <--------- ATTENTION, MUST CHANGE 0b0000 01 00 <3:2> Vref+ = ext pin <1:0> Vref- + int pin
	
	; Clear ADC result high byte
	CLRF    ADRESH,0 
	
; ========== PORT SETUP: ============================
	
    ;PORTA Setup:
	MOVLW	0b00000111  
	MOVWF	PORTA,0				    ; Output (digital) on RA0, RA1, RA2 -> Keeps RGB Array Off
	
    ;PORTB Setup:
	MOVLW   0b11111000
	MOVWF   ANSELB,1			    ; PORTB <2:0> & <7:6> Digital <5:3> Analogue
	MOVLW	0b00111111			    ; PORTB <7:6>  Outputs <5:0> Inputs
	MOVWF   TRISB
	
	;BSF	LATB, 4    ; Set RB4 high (VDD)	    ; Part of CAP TOUCH - secondary channel (RB4) to VDD as digital output
	
	
    ;PORTC Setup:
	MOVLW	0b11111000
	MOVWF	ANSELC,1			    ; Make PORTC <7:3> analog. <2:0> digital.
	MOVLW	0b11111000
	MOVWF	TRISC				    ; Make PORTC <7:3> inputs. <2:0> outputs.
	
    ;PORTD Setup:
  	
    ;PORTE Setup:
    
    ; Configure RB2 as digital input
BSF     TRISB, 2         ; Set RB2 as input
BCF     ANSELB, 2        ; Make RB2 digital (not analog)

; Configure INT2 interrupt
BCF     INTCON3, 1       ; Clear INT2 interrupt flag first
BSF     INTCON3, 4       ; Enable INT2 interrupt (INT2IE)
BSF     INTCON3, 7       ; Set INT2 as high priority (INT2IP)

; For falling edge trigger on INT2
BCF     INTCON2, 1       ; Clear INTEDG2 bit for falling edge

; Enable global and peripheral interrupts
BSF     INTCON, 7        ; Enable global interrupts (GIE)
BSF     INTCON, 6        ; Enable peripheral interrupts (PEIE)
; ========== PWM SETUP ==============================
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
    
; ========== OSCILLATOR SETUP: =====================
    
    BSF	    OSCCON, 6			    ;IRCF2	    ;Oscillator Speed is 4MHz OSCON <6:4> / IRCF <2:0> 
    BCF	    OSCCON, 5			    ;IRCF1
    BSF	    OSCCON, 4			    ;IRCF0
    
; ========== CTMU SETUP: (CAP Touch) ===============
    
    MOVLW   0b00000011
    MOVWF   CTMUICON,1				    ; ITRIM<5:0>: Current Source Trim bits / IRNG<1:0>: Current Source Range Select bits
    
    MOVLW   0b11011100				    ; positive edge response, RB2 - EDGE1 - CTED1 / RB3 - EDGE2 - CTED2, Events Not Occured 
    MOVWF   CTMUCONL,1
    
    CLRF    CTMUCONH,1
    
    MOVLB   0x0				    ; Return to Bank 0 for normal operation
    
; ========== CLEAR VARIABLES: =====================
    BCF	    CS_Enable, 0
    BCF	    Test_start_bit, 0
    CLRF    follow_colour
    
; ========== EXTERNAL INTERRUPTS: =================
    
    CLRF    INTCON3,0			
    			
    MOVLW   0b11011000				    ; INT1 -> RB1 external interrupt pin turned on (+high priority) [Ensure pin set as digital input - YES]	
    MOVWF   INTCON3,0				    ; INT2 -> RB2 external interrupt pin turned on (+high priority) [Ensure pin set as digital input - YES]
    			
    
    CLRF    INTCON2,0				    ; Interrupts INT0, INT1, INT2 are on falling_edge, TMR0 Overflow ignored (Pull-Ups enabled if corresponding  WPUB bit set)
   
    CLRF    INTCON,0				    ; Enables global interrupts, enables peripheral interrupts, disables TMR0 Overflow interrupt
    MOVLW   0b11010000				    ; Enables INT0 - RBO external interrupt pin
						    ; Disables Port B Interrupt-On-Change (IOCx) Interrupt Enable bit, Clears: TMR0, INT0, RB_IOCx interrupt flag bits (interrupts have not occured)
    MOVWF   INTCON,0
    
; ========== EUSART SETUP ========================   
    ; Configure only the specific pins we're using
    movlb   0x0F        ; Select bank 15 for ANSEL registers
    
    ; Disable analog functions only on specific pins
    bcf     ANSELC, 6 ; Disable analog for RC6 (UART TX)
    bcf     ANSELC, 7 ; Disable analog for RC7 (UART RX)
    bcf     ANSELC, 3 ; Disable analog for RC3 (I2C SCL)
    bcf     ANSELC, 4 ; Disable analog for RC4 (I2C SDA)
    bcf     ANSELE, 0 ; Disable analog for RE0 (7-segment LSB)
    bcf     ANSELE, 1 ; Disable analog for RE1 (7-segment)
    bcf     ANSELE, 2 ; Disable analog for RE2 (7-segment MSB)
    
    ; Set pin directions - only the specific pins we're using
    movlb   0x01        ; Select bank 1 for TRIS registers
    
    ; UART pins directions
    bcf     TRISC, 6 ; RC6 (TX) as output
    bsf     TRISC, 7 ; RC7 (RX) as input
    
    ; I2C pins directions
    bsf     TRISC, 3 ; RC3 (SCL) as input (controlled by MSSP)
    bsf     TRISC, 4 ; RC4 (SDA) as input (controlled by MSSP)
    
    ; 7-segment display pins directions
    bcf     TRISE, 0, 0 ; RE0 as output (LSB)
    bcf     TRISE, 1, 0 ; RE1 as output
    bcf     TRISE, 2, 0 ; RE2 as output (MSB)
    
    ; Initialize only our specific output pins
    movlb   0           ; Select bank 0 for PORT registers
    bcf     LATE, 0  ; Clear RE0
    bcf     LATE, 1  ; Clear RE1
    bcf     LATE, 2  ; Clear RE2
    
    ; Configure UART
    movlb   0x03        ; Select bank 3
    bcf     TXSTA1, 4, 0 ; Asynchronous mode
    bsf     TXSTA1, 2, 0 ; High baud rate
    bcf     BAUDCON1, 3, 1 ; 8-bit baud rate generator
    movlw   12          ; 19200 baud rate at 16MHz (FOSC/16/(SPBRG+1))
    movwf   SPBRG1, 0
    bsf     RCSTA1, 7, 0 ; Enable serial port
    bsf     TXSTA1, 5, 0 ; Enable transmitter
    bsf     RCSTA1, 4, 0 ; Enable receiver
    
    ; Configure I2C
    movlb   0x03        ; Select bank 3
    clrf    SSP1STAT, 0 ; Clear status register
    movlw   0x28        ; Master mode, I2C with clock = FOSC/(4 * (SSPADD + 1))
    movwf   SSP1CON1, 0
    movlw   9          ; Set I2C clock to 100kHz at 16MHz Fosc (16MHz/4/(39+1))
    movwf   SSP1ADD, 0  
    bsf     SSP1CON1, 5, 0 ; Enable MSSP module
    
    ; Initialize variables
    clrf    RXIndex, 0
    movlw   20          ; Set buffer size to 20 bytes
    movwf   RXBuffSize, 0
    movlw   3           ; Start in Race mode (3)
    movwf   CurrentMode, 0
    movwf   DisplayValue, 0  ; Display "3" for Race mode
    clrf    SelectedColor, 0
    clrf    EditMode, 0
    
    ; Update 7-segment display
    call    UpdateDisplay
    
    ; Clear receive buffer - Use inline code instead of a loop with labels
    lfsr    0, RXTable
    movf    RXBuffSize, 0, 0
    movwf   Counter, 0
    
Setup_ClearBuffer_Loop:
    clrf    POSTINC0, 0
    decfsz  Counter, 1, 0
    bra     Setup_ClearBuffer_Loop
    
    ; Initialize custom slogan buffer with default
    call    InitializeSlogan
    
    ; Send startup message with team name
    call    SendStartupMsg
    goto    Main

    ; Initialize Slogan
InitializeSlogan:
    ; Copy default slogan to editable buffer
    lfsr    0, CustomSlogan
    lfsr    1, DefaultSlogan
CopySlogan:
    movf    POSTINC1, 0, 0
    movwf   POSTINC0, 0
    bnz     CopySlogan    ; Continue until null terminator
    return
    
    
    
    GOTO    Main

;==================================================================================================================  
    
Main:
    
    BTFSS   CS_Enable, 0
    CALL    Colour_Read                          ; Used to show what colour we on (uses sensor_MM strobed value)
    ; Start of UART processing loop
    ReceiveLoop:
	BTFSC   Test_start_bit, 0                    ; Test with a set bit for now on external interrupt INT2 - RB2
	GOTO    Cap_Touch_Detect                     ; Used to continuously check if touch sensed
	
        btfss   PIR1, 5, 0                      ; Check if data received
        bra     ReceiveLoop                     ; Loop until character received
        
        movff   RCREG1, Temp                    ; Get received character
        
        ; Echo typed character
        movf    Temp, 0, 0
        call    SendChar
        
        ; Check for <Enter>
        movf    Temp, 0, 0
        xorlw   0x0D
        bz      ProcessCompleteCommand          ; If Enter, process the complete command
        
        ; Check if we're in Program/Edit mode
        btfsc   EditMode, 0, 0
        goto    StoreInSloganBuffer
        
        ; Store in RXTable (up to buffer size limit)
        movf    RXBuffSize, 0, 0
        cpfslt  RXIndex, 0                      ; Skip if RXIndex < RXBuffSize
        bra     ReceiveLoop                     ; Buffer full, ignore character and continue receiving
        
        lfsr    0, RXTable                      ; Point to start of buffer
        movf    RXIndex, 0, 0
        addwf   FSR0L, 1, 0                     ; Adjust pointer to current position
        movf    Temp, 0, 0                      ; Get the received character
        movwf   POSTINC0, 0                     ; Store it in buffer
        incf    RXIndex, 1, 0                   ; Increment index
        
        bra     ReceiveLoop                     ; Continue receiving characters
    
ProcessCompleteCommand:
    call    ProcessInput                        ; Process the complete command
    goto    Main                                ; Return to main loop after processing 
  
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
Call	Delay2s
    
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
	    
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	   
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
	    
	    CALL	Delay_125us
	    GOTO	follow_blue		    
	
	blue_right:
		       
	    MOVF	sensor_MR,0		    
	    CPFSLT	MR_blue_min,0		
	    GOTO	blue_left				
	    CPFSGT	MR_blue_max,0		
	    GOTO	blue_left		
	    BSF		PORTD, 1		    ; Indicates RIGHT
	    
	    CALL	Delay_125us
	    
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    Call	Left	
	    GOTO	follow_blue		
	
	blue_left:
		       
	    MOVF	sensor_ML,0		    
	    CPFSLT	ML_blue_min,0		
	    GOTO	blue_stop		       
	    CPFSGT	ML_blue_max,0		
	    GOTO	blue_stop		        
	    BSF		PORTD, 2		    ; Indicates LEFT
	    
	    CALL	Delay_125us
	    
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL	Right			
	    GOTO	follow_blue
    
	blue_right_right:   
		       
	    MOVF	sensor_RR,0		   
	    CPFSLT	RR_blue_min,0		
	    GOTO	blue_left_left				
	    CPFSGT	RR_blue_max,0		
	    GOTO	blue_left_left		
	    BSF		PORTD, 1		    ; Indicates RIGHT
	    
	    ; EXECUTE MOTOR HARD RIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay_125us			
	    GOTO	follow_blue    
	  
	blue_left_left:
		       
	    MOVF	sensor_LL,0		    
	    CPFSLT	LL_blue_min,0		
	    GOTO	blue_stop				
	    CPFSGT	LL_blue_max,0		
	    GOTO	blue_stop		
	    BSF		PORTD, 2		    ; Indicates LEFT
	    
	    ; EXECUTE MOTOR HARD LEFT FUNCTION						<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay_125us			
	    GOTO	follow_blue
	    
	blue_stop:
	; Checks if at end line
    
	    MOVF	sensor_MM,0		    ; Check if Middle Sensor on BLACK
	    CPFSGT	MM_black_max_blue,0	      
	    GOTO	LOST
	    
	    MOVF	sensor_MR,0		    ; Check if Right Right Sensor on Black
	    CPFSGT	ML_black_max_blue,0	      
	    GOTO	LOST
	    
	    MOVF	sensor_ML,0		    ; Check if Left Left Sensor on Black    
	    CPFSGT	MR_black_max_blue,0	     
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
	    
	    CALL Stop_Car
	    
	    GOTO IDLE
    
	black_straight:
		      
	    MOVF	sensor_MM,0		    		   	
	    CPFSGT	MM_black_max_red,0		    
	    GOTO	black_right		    
	    BSF		PORTD, 0		    ; Indicates STRAIGHT
	
	    ; EXECUTE MOTOR STRAIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    CALL    GO_Straight
	    
	    CALL	Delay_125us			
	    GOTO	follow_black    
	
	black_right:
		      
	    MOVF	sensor_MR,0		    		   	
	    CPFSGT	MR_black_max_red,0		    
	    GOTO	black_left		    
	    BSF		PORTD, 1		    ; Indicates RIGHT
	
	    ; EXECUTE MOTOR SOFT RIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay_125us			
	    GOTO	follow_black    
    
	black_left:
		      
	    MOVF	sensor_ML,0		    		   	
	    CPFSGT	ML_black_max_red,0		    
	    GOTO	LOST
	    BSF		PORTD, 2		    ; Indicates LEFT
	
	    ; EXECUTE MOTOR SOFT LEFT FUNCTION						<------------------------------------- MOTOR FUNC

	    CALL	Delay_125us			
	    GOTO	follow_black
    
	black_right_right:
		      
	    MOVF	sensor_RR,0		    		   	
	    CPFSGT	MM_black_max_red,0		    
	    GOTO	black_left_left		    
	    BSF		PORTD, 1		    ; Indicates RIGHT
	
	    ; EXECUTE MOTOR HARD RIGHT FUNCTION						<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay_125us			
	    GOTO	follow_black
	    
	black_left_left:
		      
	    MOVF	sensor_LL,0		    		   	
	    CPFSGT	MM_black_max_red,0		    
	    GOTO	LOST		    
	    BSF		PORTD, 2		    ; Indicates RIGHT
	
	    ; EXECUTE MOTOR HARD LEFT FUNCTION						<------------------------------------- MOTOR FUNC
	    
	    CALL	Delay_125us			
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
    
    //Read pin RD6, channel AN26 
    CALL    Delay3Hz
    MOVLW   0b01101001
    MOVWF   ADCON0,0
    CALL    ADC_Start
    MOVF    ADRESH, 0				; Move ADRESH to W (contains 8 MSBs of ADCResult)
    MOVWF   sensor_MM,0
    
    //Read pin RD7, channel AN27
    CALL    Delay3Hz
    MOVLW   0b01101101
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
    
    //Read pin RB4, channel AN11
    CALL    Delay3Hz
    MOVLW   0b00101101
    MOVWF   ADCON0,0
    CALL    ADC_Start
    MOVF    ADRESH, 0				; Move ADRESH to W (contains 8 MSBs of ADCResult)
    MOVWF   sensor_LL
    
    //Read pin RB5, channel AN13
    CALL    Delay3Hz
    MOVLW   0b00110101
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
    MOVLW   0b01101001			; Select ADC Channel AN26 -> RD6 (sensor_MM)
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
    CALL     Stop_Car
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
    
    BSF	    INTCON, 4				    ; Sets INT0 External Interrupt Enable bit (Interrupt can be used again)
    BCF	    INTCON, 1				    ; Clears interrupt flag: INT0 -> RB0
    
    Return
    
    Red_Calibrate:
	
	BCF	PORTA, 0			    ; Turns RED RGB Array ON
	BSF	PORTA, 4			    ; Indicates that RED is to be sampled
	
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	
	;sensor_MM
	MOVLW   0b01101001                          ; Select ADC Channel AN26 -> RD6 (sensor_MM)
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
	MOVLW   0b01101101                         ; Select ADC Channel AN27 -> RD7 (sensor_MR)
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
	MOVLW   0b01000101                          ; Select ADC Channel AN17 -> RC5 (sensor_ML)
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
	MOVLW   0b00110101                          ; Select ADC Channel AN13 -> RB5 (sensor_RR)
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
	MOVLW   0b00101101                          ; Select ADC Channel AN11 -> RB4 (sensor_LL)
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
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	
	;sensor_MM
	MOVLW   0b01101001                          ; Select ADC Channel AN26 -> RD6 (sensor_MM)
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
	MOVLW   0b01101101                          ; Select ADC Channel AN27 -> RD7 (sensor_MR)
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
	MOVLW   0b01000101                          ; Select ADC Channel AN17 -> RC5 (sensor_ML)
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
	MOVLW   0b00110101                          ; Select ADC Channel AN13 -> RB5 (sensor_RR)
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
	MOVLW   0b00101101                          ; Select ADC Channel AN11 -> RB4 (sensor_LL)
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
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	CALL    Delay2s
	
	;sensor_MM
	MOVLW   0b01101001                          ; Select ADC Channel AN26 -> RD6 (sensor_MM)
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
	MOVLW   0b01101101                          ; Select ADC Channel AN27 -> RD7 (sensor_MR)
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
	MOVLW   0b01000101                          ; Select ADC Channel AN17 -> RC5 (sensor_ML)
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
	MOVLW   0b00110101                          ; Select ADC Channel AN13 -> RB5 (sensor_RR)
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
	MOVLW   0b00101101                          ; Select ADC Channel AN11 -> RB4 (sensor_LL)
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
	
	;sensor_MM
	MOVLW   0b01101001                          ; Select ADC Channel AN26 -> RD6 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W
	ADDLW   Range_Cal_Value_4			   
	MOVWF   MM_black_max_red	
	
	;sensor_MR
	MOVLW   0b01101101                          ; Select ADC Channel AN27 -> RD7 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	ADDLW   Range_Cal_Value_4			    
	MOVWF   MR_black_max_red	
	
	;sensor_ML
	MOVLW   0b01000101                          ; Select ADC Channel AN17 -> RC5 (sensor_ML)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	ADDLW   Range_Cal_Value_4			   
	MOVWF   ML_black_max_red	
	
	;sensor_RR
	MOVLW   0b00110101                         ; Select ADC Channel AN13 -> RB5 (sensor_RR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W
	ADDLW   Range_Cal_Value_4			   
	MOVWF   RR_black_max_red
	
	;sensor_LL
	MOVLW   0b00101101                          ; Select ADC Channel AN11 -> RB4 (sensor_LL)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W
	ADDLW   Range_Cal_Value_4			   
	MOVWF   LL_black_max_red
	
	BSF	PORTA, 0			    ; Turns RED RGB Array OFF
	CALL    Delay_125us
	
	
	
	BCF	PORTA, 1			    ; Turns GREEN RGB Array ON
	CALL    Delay2s
	
	;sensor_MM
	MOVLW   0b01101001                          ; Select ADC Channel AN26 -> RD6 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			    	    			    
	ADDLW   Range_Cal_Value_1			    ; Add Range_Cal_Value_1		    
	MOVWF   MM_black_max_green
	
	;sensor_MR
	MOVLW   0b01101101                          ; Select ADC Channel AN27 -> RD7 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	ADDLW   Range_Cal_Value_1			    
	MOVWF   MR_black_max_green	
	
	;sensor_ML
	MOVLW   0b01000101                          ; Select ADC Channel AN17 -> RC5 (sensor_ML)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	ADDLW   Range_Cal_Value_1			    
	MOVWF   ML_black_max_green	
	
	;sensor_RR
	MOVLW   0b00110101                          ; Select ADC Channel AN13 -> RB5 (sensor_RR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W
	ADDLW   Range_Cal_Value_1			   
	MOVWF   RR_black_max_green
	
	;sensor_LL
	MOVLW   0b00101101                          ; Select ADC Channel AN11 -> RB4 (sensor_LL)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W
	ADDLW   Range_Cal_Value_1			   
	MOVWF   LL_black_max_green
	
	BSF	PORTA, 1			    ; Turns GREEN RGB Array OFF
	CALL    Delay_125us
	
	
	
	BCF	PORTA, 2			    ; Turns BLUE RGB Array ON
	CALL    Delay2s
	
	;sensor_MM
	MOVLW   0b01101001                          ; Select ADC Channel AN26 -> RD6 (sensor_MM)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	ADDLW   Range_Cal_Value_1			    
	MOVWF   MM_black_max_blue
	
	;sensor_MR
	MOVLW   0b01101101                          ; Select ADC Channel AN27 -> RD7 (sensor_MR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	ADDLW   Range_Cal_Value_1			      
	MOVWF   MR_black_max_blue	
	
	;sensor_ML
	MOVLW   0b01000101                          ; Select ADC Channel AN17 -> RC5 (sensor_ML
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W			     	    			    
	ADDLW   Range_Cal_Value_1			   
	MOVWF   ML_black_max_blue
	
	;sensor_RR
	MOVLW   0b00110101                          ; Select ADC Channel AN11 -> RB5 (sensor_RR)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W
	ADDLW   Range_Cal_Value_1			   
	MOVWF   RR_black_max_blue
	
	;sensor_LL
	MOVLW   0b00101101                          ; Select ADC Channel AN11 -> RB4 (sensor_LL)
	MOVWF   ADCON0
	CALL    ADC_Start
	MOVF    ADRESH, W
	ADDLW   Range_Cal_Value_1			   
	MOVWF   LL_black_max_blue
	
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
	
	;sensor_MM
	MOVLW   0b01101001                          ; Select ADC Channel AN26 -> RD6 (sensor_MM)
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
    
	MOVLW   0b01101001                          ; Using sensor_MM (AN26 -> RD6) to select colour
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
	
	BSF	INTCON3, 3			; Sets INT1 External Interrupt Enable bit (Interrupt can be used again)
	BCF	INTCON3, 0			; Clears interrupt flag: INT1 -> RB1
	
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
	movwf   DelayA		; Set inner loop counter 
    OuterLoop:
	movlw   0x05		; Load 5 into W (M = 5)
	movwf   DelayB		; Set outer loop counter
    InnerLoop:
	decfsz  DelayA, f	; Decrement inner counter
	goto    InnerLoop	; Repeat if not zero
	decfsz  DelayB, f	; Decrement outer counter
	goto    InnerLoop	; Repeat if not zero
	nop			; Adjust delay slightly
	return			; Return after delay complete  
	
	
Delay3Hz:                     ; Delay of approximately 0.333 seconds (3Hz)
    movlw   0x76              ; Load 118 decimal into W
    movwf   DelayB            ; Set outer loop counter
Go_on1:            
    movlw   0x76              ; Load 118 decimal into W
    movwf   DelayA            ; Set inner loop counter
Go_on2:
    decfsz  DelayA, f         ; Decrement inner counter, skip next if zero
    goto    Go_on2            ; If not zero, continue inner loop
    decfsz  DelayB, f         ; Decrement outer counter, skip next if zero
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

    
;##################################################################################################################################3    
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
    
    
    StoreInSloganBuffer:
    ; Only store printable ASCII characters (32-126)
    movlw   32          ; Space character
    cpfslt  Temp, 0     ; Skip if Temp < 32
    goto    CheckUpperLimit
    goto    ReceiveLoop    ; Ignore control characters
    
CheckUpperLimit:
    movlw   127         ; Above printable ASCII
    cpfslt  Temp, 0     ; Skip if Temp < 127 
    goto    ReceiveLoop    ; Ignore high-ASCII characters
    
    ; Store in CustomSlogan (up to buffer size limit)
    movlw   48          ; Max slogan size (safe limit)
    cpfslt  ProgramIndex, 0  ; Skip if ProgramIndex < 48
    goto    ReceiveLoop   ; Buffer full, ignore character
    
    lfsr    0, CustomSlogan  ; Point to start of buffer
    movf    ProgramIndex, 0, 0
    addwf   FSR0L, 1, 0 ; Adjust pointer to current position
    movf    Temp, 0, 0  ; Get the received character
    movwf   POSTINC0, 0 ; Store it in buffer
    movlw   0           ; Add null terminator
    movwf   INDF0, 0    ; Store it
    incf    ProgramIndex, 1, 0 ; Increment index
    goto    ReceiveLoop

;========== Process Input Based on Current Mode ==========
ProcessInput:
    movlw   0x0A        ; Send line feed after carriage return
    call    SendChar
    
    ; Check if we're in Program/Edit mode
    btfsc   EditMode, 0, 0
    goto    FinishEditMode
    
    ; Check for "Howzit" command first - always returns to main menu
    call    CheckHowzit
    btfsc   STATUS, 0, 0 ; Skip if Z flag is clear (not matched)
    goto    SendMainMenu
    
    ; Otherwise, process according to current mode
    movf    CurrentMode, 0, 0
    
    ; Check which mode we're in
    xorlw   1           ; Check if in Select Color mode (1)
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    ProcessSelectColor
    
    movf    CurrentMode, 0, 0
    xorlw   4           ; Check if in Diagnostics mode (4)
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    ProcessDiagnostics
    
    ; If not in a submenu mode, process as main command
    goto    ProcessCommand

;========== Finish Edit Mode ==========
;========== Finish Edit Mode ==========
FinishEditMode:
    ; Turn off edit mode
    clrf    EditMode, 0
    
    ; Save slogan to EEPROM
    movlw   0x00                ; Start address in EEPROM
    movwf   START_ADDR
    movlw   LOW(CustomSlogan)   ; Source data in CustomSlogan
    movwf   SRC_PTR_L
    movlw   HIGH(CustomSlogan)
    movwf   SRC_PTR_H
    movlw   50                  ; Length of slogan buffer
    movwf   BYTE_COUNT
    call    Write_To_EEPROM
    
    ; Display confirmation message
    call    SendCRLF
    call    SendSloganUpdatedMsg
    
    ; Return to main menu
    goto    SendMainMenu

;========== Process Command on Enter ==========
ProcessCommand:
    ; Process single character commands from the main menu
    lfsr    0, RXTable
    movf    INDF0, 0, 0  ; Get first character
    
    ; Check for "S" command
    xorlw   'S'
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    SelectColor
    
    ; Check for "C" command
    movf    INDF0, 0, 0  ; Reload first character
    xorlw   'C'
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    Calibrate
    
    ; Check for "R" command
    movf    INDF0, 0, 0  ; Reload first character
    xorlw   'R'
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    RaceMode
    
    ; Check for "D" command
    movf    INDF0, 0, 0  ; Reload first character
    xorlw   'D'
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    Diagnostics
    
    ; Check for "P" command
    movf    INDF0, 0, 0  ; Reload first character
    xorlw   'P'
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    ProgramMode
    
    ; Check for "T" command
    movf    INDF0, 0, 0  ; Reload first character
    xorlw   'T'
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    TimeMode
    
    ; No valid command found, send error message
    call    SendError
    
    ; Clear buffer and return to main loop
FinalizeCommand:
    call    ClearBuffer
    goto    Main

;========== Process Select Color Submenu ==========
ProcessSelectColor:
    lfsr    0, RXTable
    movf    INDF0, 0, 0  ; Get first character
    
    ; Check for "R" (Red)
    xorlw   'R'
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    SelectRed
    
    ; Check for "G" (Green)
    movf    INDF0, 0, 0  ; Reload first character
    xorlw   'G'
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    SelectGreen
    
    ; Check for "B" (Blue)
    movf    INDF0, 0, 0  ; Reload first character
    xorlw   'B'
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    SelectBlue
    
    ; Check for "k" (Black)
    movf    INDF0, 0, 0  ; Reload first character
    xorlw   'k'
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    SelectBlack
    
    ; Invalid selection
    call    SendInvalidColorMsg
    call    ClearBuffer
    goto    Main

SelectRed:
    ; Set both color indicators
    movlw   1            ; Set color to Red (1)
    movwf   SelectedColor, 0
    
    ; Clear all follow_colour bits and set only Red
    clrf    follow_colour
    bsf     follow_colour, 4  ; Set bit 4 for RED
    
    ; Indicate selection visually
    MOVLW   0b00000111   ; Turn off RGB LEDs
    MOVWF   PORTA
    BSF     PORTA, 4     ; Turn on RED indicator LED
    
    ; Let the system know color is selected
    BSF     CS_Enable, 0 ; Flag that color is selected
    
    call    SendCRLF
    call    SendRedSelectedMsg
    call    ClearBuffer
    goto    Main

SelectGreen:
    ; Set both color indicators
    movlw   2            ; Set color to Green (2)
    movwf   SelectedColor, 0
    
    ; Clear all follow_colour bits and set only Green
    clrf    follow_colour
    bsf     follow_colour, 5  ; Set bit 5 for GREEN
    
    ; Indicate selection visually (same as hardware does)
    MOVLW   0b00000111   ; Turn off RGB LEDs
    MOVWF   PORTA
    BSF     PORTA, 5     ; Turn on GREEN indicator LED
    
    ; Let the system know color is selected
    BSF     CS_Enable, 0 ; Flag that color is selected - critical for hardware integration
    
    call    SendCRLF
    call    SendGreenSelectedMsg
    call    ClearBuffer
    goto    Main

SelectBlue:
    ; Set both color indicators
    movlw   3            ; Set color to Blue (3)
    movwf   SelectedColor, 0
    
    ; Clear all follow_colour bits and set only Blue
    clrf    follow_colour
    bsf     follow_colour, 6  ; Set bit 6 for BLUE
    
    ; Indicate selection visually (same as hardware does)
    MOVLW   0b00000111   ; Turn off RGB LEDs
    MOVWF   PORTA
    BSF     PORTA, 6     ; Turn on BLUE indicator LED
    
    ; Let the system know color is selected
    BSF     CS_Enable, 0 ; Flag that color is selected - critical for hardware integration
    
    call    SendCRLF
    call    SendBlueSelectedMsg
    call    ClearBuffer
    goto    Main

SelectBlack:
    ; Set both color indicators
    movlw   4            ; Set color to Black (4)
    movwf   SelectedColor, 0
    
    ; Clear all follow_colour bits and set only Black
    clrf    follow_colour
    bsf     follow_colour, 7  ; Set bit 7 for BLACK
    
    ; Indicate selection visually (same as hardware does)
    MOVLW   0b00000111   ; Turn off RGB LEDs
    MOVWF   PORTA
    BSF     PORTA, 7     ; Turn on BLACK indicator LED
    
    ; Let the system know color is selected
    BSF     CS_Enable, 0 ; Flag that color is selected - critical for hardware integration
    
    call    SendCRLF
    call    SendBlackSelectedMsg
    call    ClearBuffer
    goto    Main

;========== Process Diagnostics Submenu ==========
ProcessDiagnostics:
    lfsr    0, RXTable
    movf    INDF0, 0, 0  ; Get first character
    
    ; Check for "S" (Sensor test)
    xorlw   'S'
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    DiagSensorTest
    
    ; Check for "F" (Forward)
    movf    INDF0, 0, 0  ; Reload first character
    xorlw   'F'
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    DiagForward
    
    ; Check for "L" (Left)
    movf    INDF0, 0, 0  ; Reload first character
    xorlw   'L'
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    DiagLeft
    
    ; Check for "R" (Right)
    movf    INDF0, 0, 0  ; Reload first character
    xorlw   'R'
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    DiagRight
    
    ; Check for "T" (Stop)
    movf    INDF0, 0, 0  ; Reload first character
    xorlw   'T'
    btfsc   STATUS, 2, 0 ; Skip if Z flag is clear (not matched)
    goto    DiagStop
    
    ; Invalid diagnostics command
    call    SendInvalidDiagMsg
    call    ClearBuffer
    goto    Main
    
DiagSensorTest:
    call    SendCRLF
    call    SendSensorTestMsg
    
    ; First display numeric values of sensors
    call    ADC_Loop
    call    SendSensorValuesMsg
    
    ; Then show detected colors for each sensor
    call    SendCRLF
    call    DiagSensorColors
    
    call    ClearBuffer
    goto    Main

DiagForward:
    call    SendCRLF
    call    SendForwardMsg
    
    ; Call your forward motor function
    call    GO_Straight  ; This seems to be your function for moving straight
    
    call    ClearBuffer
    goto    Main

DiagLeft:
    call    SendCRLF
    call    SendLeftMsg
    
    ; Call your left turn motor function
    call    Left  ; This seems to be your function for turning left
    
    call    ClearBuffer
    goto    Main

DiagRight:
    call    SendCRLF
    call    SendRightMsg
    
    ; Call your right turn motor function
    call    Right  ; This seems to be your function for turning right
    
    call    ClearBuffer
    goto    Main
DiagStop:
    call    SendCRLF
    call    SendStopMsg  ; You'll need to create this message
    
    ; Call your stop motor function
    call    Stop_Car  ; This seems to be your function for stopping
    
    call    ClearBuffer
    goto    Main

;========== Sensor Color Detection for Diagnostics ==========
DiagSensorColors:
    ; First send a header
    movlw   high SensorColorStr
    movwf   TBLPTRH, 0
    movlw   low SensorColorStr
    movwf   TBLPTRL, 0
    call    SendString
    
    ; Check MM sensor color
    call    SendCRLF
    movlw   'M'
    call    SendChar
    movlw   'M'
    call    SendChar
    movlw   ':'
    call    SendChar
    movlw   ' '
    call    SendChar
    call    Check_MM_Color
    
    ; Check MR sensor color
    call    SendCRLF
    movlw   'M'
    call    SendChar
    movlw   'R'
    call    SendChar
    movlw   ':'
    call    SendChar
    movlw   ' '
    call    SendChar
    call    Check_MR_Color
    
    ; Check ML sensor color
    call    SendCRLF
    movlw   'M'
    call    SendChar
    movlw   'L'
    call    SendChar
    movlw   ':'
    call    SendChar
    movlw   ' '
    call    SendChar
    call    Check_ML_Color
    
    ; Check RR sensor color
    call    SendCRLF
    movlw   'R'
    call    SendChar
    movlw   'R'
    call    SendChar
    movlw   ':'
    call    SendChar
    movlw   ' '
    call    SendChar
    call    Check_RR_Color
    
    ; Check LL sensor color
    call    SendCRLF
    movlw   'L'
    call    SendChar
    movlw   'L'
    call    SendChar
    movlw   ':'
    call    SendChar
    movlw   ' '
    call    SendChar
    call    Check_LL_Color
    
    ; Final newline
    call    SendCRLF
    return

;----- Check MM Sensor Color -----
Check_MM_Color:
    ; Configure ADC for MM sensor
    MOVLW   0b01101001           ; Select ADC Channel AN26 -> RD6 (sensor_MM)
    MOVWF   ADCON0
    
    ; Check for Red
    BCF     PORTA, 0             ; Turn on RED RGB Array
    CALL    Delay_125us
    CALL    ADC_Start
    MOVF    ADRESH, W            ; Store current ADC reading in WREG
    BSF     PORTA, 0             ; Turn off RED RGB Array
    
    CPFSLT  MM_red_min,0         ; Compare MM_red_min with sensor_MM, skip if MM_red_min < sensor_MM (WREG)
    GOTO    Check_MM_Green       ; Checks if green      
    CPFSGT  MM_red_max,0         ; Compare MM_red_max with sensor_MM, skip if MM_red_max > sensor_MM (WREG)
    GOTO    Check_MM_Green       ; Checks if green
    
    ; It's RED - send 'R'
    MOVLW   'R'
    CALL    SendChar
    RETURN
    
Check_MM_Green:
    BCF     PORTA, 1             ; Turn on GREEN RGB Array
    CALL    Delay_125us
    CALL    ADC_Start
    MOVF    ADRESH, W            
    BSF     PORTA, 1             ; Turn off GREEN RGB Array
    
    CPFSLT  MM_green_min,0       
    GOTO    Check_MM_Blue                
    CPFSGT  MM_green_max,0       
    GOTO    Check_MM_Blue        
    
    ; It's GREEN - send 'G'
    MOVLW   'G'
    CALL    SendChar
    RETURN
    
Check_MM_Blue:
    BCF     PORTA, 2             ; Turn on BLUE RGB Array
    CALL    Delay_125us
    CALL    ADC_Start
    MOVF    ADRESH, W            
    BSF     PORTA, 2             ; Turn off BLUE RGB Array
    
    CPFSLT  MM_blue_min,0        
    GOTO    Check_MM_Black               
    CPFSGT  MM_blue_max,0        
    GOTO    Check_MM_Black       
    
    ; It's BLUE - send 'B'
    MOVLW   'B'
    CALL    SendChar
    RETURN
    
Check_MM_Black:                
    CPFSGT  MM_black_max_blue,0      
    GOTO    Check_MM_White       
    
    ; It's BLACK - send 'K'
    MOVLW   'K'
    CALL    SendChar
    RETURN
    
Check_MM_White:           
    ; Check if it meets white criteria
    MOVF    ADRESH, W
    CPFSLT  MM_white_min_red,0
    GOTO    Check_MM_Unknown
    
    ; It's WHITE - send 'W'  
    MOVLW   'W'
    CALL    SendChar
    RETURN
    
Check_MM_Unknown:
    ; If no color detected - send '?'
    MOVLW   '?'
    CALL    SendChar
    RETURN
    
;----- Check MR Sensor Color -----
Check_MR_Color:
    ; Configure ADC for MR sensor
    MOVLW   0b01101101           ; Select ADC Channel AN27 -> RD7 (sensor_MR)
    MOVWF   ADCON0
    
    ; Check for Red
    BCF     PORTA, 0             ; Turn on RED RGB Array
    CALL    Delay_125us
    CALL    ADC_Start
    MOVF    ADRESH, W            ; Store current ADC reading in WREG
    BSF     PORTA, 0             ; Turn off RED RGB Array
    
    CPFSLT  MR_red_min,0         ; Compare MR_red_min with sensor_MR, skip if MR_red_min < sensor_MR (WREG)
    GOTO    Check_MR_Green       ; Checks if green      
    CPFSGT  MR_red_max,0         ; Compare MR_red_max with sensor_MR, skip if MR_red_max > sensor_MR (WREG)
    GOTO    Check_MR_Green       ; Checks if green
    
    ; It's RED - send 'R'
    MOVLW   'R'
    CALL    SendChar
    RETURN
    
Check_MR_Green:
    BCF     PORTA, 1             ; Turn on GREEN RGB Array
    CALL    Delay_125us
    CALL    ADC_Start
    MOVF    ADRESH, W            
    BSF     PORTA, 1             ; Turn off GREEN RGB Array
    
    CPFSLT  MR_green_min,0       
    GOTO    Check_MR_Blue                
    CPFSGT  MR_green_max,0       
    GOTO    Check_MR_Blue        
    
    ; It's GREEN - send 'G'
    MOVLW   'G'
    CALL    SendChar
    RETURN
    
Check_MR_Blue:
    BCF     PORTA, 2             ; Turn on BLUE RGB Array
    CALL    Delay_125us
    CALL    ADC_Start
    MOVF    ADRESH, W            
    BSF     PORTA, 2             ; Turn off BLUE RGB Array
    
    CPFSLT  MR_blue_min,0        
    GOTO    Check_MR_Black               
    CPFSGT  MR_blue_max,0        
    GOTO    Check_MR_Black       
    
    ; It's BLUE - send 'B'
    MOVLW   'B'
    CALL    SendChar
    RETURN
    
Check_MR_Black:                
    CPFSGT  MR_black_max_blue,0      
    GOTO    Check_MR_Unknown    ; No specific white test for MR
    
    ; It's BLACK - send 'K'
    MOVLW   'K'
    CALL    SendChar
    RETURN
    
Check_MR_Unknown:
    ; If no color detected - send '?'
    MOVLW   '?'
    CALL    SendChar
    RETURN
    
;----- Check ML Sensor Color -----
Check_ML_Color:
    ; Configure ADC for ML sensor
    MOVLW   0b01000101           ; Select ADC Channel AN17 -> RC5 (sensor_ML)
    MOVWF   ADCON0
    
    ; Check for Red
    BCF     PORTA, 0             ; Turn on RED RGB Array
    CALL    Delay_125us
    CALL    ADC_Start
    MOVF    ADRESH, W            ; Store current ADC reading in WREG
    BSF     PORTA, 0             ; Turn off RED RGB Array
    
    CPFSLT  ML_red_min,0         ; Compare ML_red_min with sensor_ML, skip if ML_red_min < sensor_ML (WREG)
    GOTO    Check_ML_Green       ; Checks if green      
    CPFSGT  ML_red_max,0         ; Compare ML_red_max with sensor_ML, skip if ML_red_max > sensor_ML (WREG)
    GOTO    Check_ML_Green       ; Checks if green
    
    ; It's RED - send 'R'
    MOVLW   'R'
    CALL    SendChar
    RETURN
    
Check_ML_Green:
    BCF     PORTA, 1             ; Turn on GREEN RGB Array
    CALL    Delay_125us
    CALL    ADC_Start
    MOVF    ADRESH, W            
    BSF     PORTA, 1             ; Turn off GREEN RGB Array
    
    CPFSLT  ML_green_min,0       
    GOTO    Check_ML_Blue                
    CPFSGT  ML_green_max,0       
    GOTO    Check_ML_Blue        
    
    ; It's GREEN - send 'G'
    MOVLW   'G'
    CALL    SendChar
    RETURN
    
Check_ML_Blue:
    BCF     PORTA, 2             ; Turn on BLUE RGB Array
    CALL    Delay_125us
    CALL    ADC_Start
    MOVF    ADRESH, W            
    BSF     PORTA, 2             ; Turn off BLUE RGB Array
    
    CPFSLT  ML_blue_min,0        
    GOTO    Check_ML_Black               
    CPFSGT  ML_blue_max,0        
    GOTO    Check_ML_Black       
    
    ; It's BLUE - send 'B'
    MOVLW   'B'
    CALL    SendChar
    RETURN
    
Check_ML_Black:                
    CPFSGT  ML_black_max_blue,0      
    GOTO    Check_ML_Unknown    ; No specific white test for ML
    
    ; It's BLACK - send 'K'
    MOVLW   'K'
    CALL    SendChar
    RETURN
    
Check_ML_Unknown:
    ; If no color detected - send '?'
    MOVLW   '?'
    CALL    SendChar
    RETURN
    
;----- Check RR Sensor Color -----
Check_RR_Color:
    ; Configure ADC for RR sensor
    MOVLW   0b00110101           ; Select ADC Channel AN13 -> RB5 (sensor_RR)
    MOVWF   ADCON0
    
    ; Check for Red
    BCF     PORTA, 0             ; Turn on RED RGB Array
    CALL    Delay_125us
    CALL    ADC_Start
    MOVF    ADRESH, W            ; Store current ADC reading in WREG
    BSF     PORTA, 0             ; Turn off RED RGB Array
    
    CPFSLT  RR_red_min,0         ; Compare RR_red_min with sensor_RR, skip if RR_red_min < sensor_RR (WREG)
    GOTO    Check_RR_Green       ; Checks if green      
    CPFSGT  RR_red_max,0         ; Compare RR_red_max with sensor_RR, skip if RR_red_max > sensor_RR (WREG)
    GOTO    Check_RR_Green       ; Checks if green
    
    ; It's RED - send 'R'
    MOVLW   'R'
    CALL    SendChar
    RETURN
    
Check_RR_Green:
    BCF     PORTA, 1             ; Turn on GREEN RGB Array
    CALL    Delay_125us
    CALL    ADC_Start
    MOVF    ADRESH, W            
    BSF     PORTA, 1             ; Turn off GREEN RGB Array
    
    CPFSLT  RR_green_min,0       
    GOTO    Check_RR_Blue                
    CPFSGT  RR_green_max,0       
    GOTO    Check_RR_Blue        
    
    ; It's GREEN - send 'G'
    MOVLW   'G'
    CALL    SendChar
    RETURN
    
Check_RR_Blue:
    BCF     PORTA, 2             ; Turn on BLUE RGB Array
    CALL    Delay_125us
    CALL    ADC_Start
    MOVF    ADRESH, W            
    BSF     PORTA, 2             ; Turn off BLUE RGB Array
    
    CPFSLT  RR_blue_min,0        
    GOTO    Check_RR_Black               
    CPFSGT  RR_blue_max,0        
    GOTO    Check_RR_Black       
    
    ; It's BLUE - send 'B'
    MOVLW   'B'
    CALL    SendChar
    RETURN
    
Check_RR_Black:                
    CPFSGT  RR_black_max_blue,0      
    GOTO    Check_RR_Unknown    ; No specific white test for RR
    
    ; It's BLACK - send 'K'
    MOVLW   'K'
    CALL    SendChar
    RETURN
    
Check_RR_Unknown:
    ; If no color detected - send '?'
    MOVLW   '?'
    CALL    SendChar
    RETURN
    
;----- Check LL Sensor Color -----
Check_LL_Color:
    ; Configure ADC for LL sensor
    MOVLW   0b00101101           ; Select ADC Channel AN11 -> RB4 (sensor_LL)
    MOVWF   ADCON0
    
    ; Check for Red
    BCF     PORTA, 0             ; Turn on RED RGB Array
    CALL    Delay_125us
    CALL    ADC_Start
    MOVF    ADRESH, W            ; Store current ADC reading in WREG
    BSF     PORTA, 0             ; Turn off RED RGB Array
    
    CPFSLT  LL_red_min,0         ; Compare LL_red_min with sensor_LL, skip if LL_red_min < sensor_LL (WREG)
    GOTO    Check_LL_Green       ; Checks if green      
    CPFSGT  LL_red_max,0         ; Compare LL_red_max with sensor_LL, skip if LL_red_max > sensor_LL (WREG)
    GOTO    Check_LL_Green       ; Checks if green
    
    ; It's RED - send 'R'
    MOVLW   'R'
    CALL    SendChar
    RETURN
    
Check_LL_Green:
    BCF     PORTA, 1             ; Turn on GREEN RGB Array
    CALL    Delay_125us
    CALL    ADC_Start
    MOVF    ADRESH, W            
    BSF     PORTA, 1             ; Turn off GREEN RGB Array
    
    CPFSLT  LL_green_min,0       
    GOTO    Check_LL_Blue                
    CPFSGT  LL_green_max,0       
    GOTO    Check_LL_Blue        
    
    ; It's GREEN - send 'G'
    MOVLW   'G'
    CALL    SendChar
    RETURN
    
Check_LL_Blue:
    BCF     PORTA, 2             ; Turn on BLUE RGB Array
    CALL    Delay_125us
    CALL    ADC_Start
    MOVF    ADRESH, W            
    BSF     PORTA, 2             ; Turn off BLUE RGB Array
    
    CPFSLT  LL_blue_min,0        
    GOTO    Check_LL_Black               
    CPFSGT  LL_blue_max,0        
    GOTO    Check_LL_Black       
    
    ; It's BLUE - send 'B'
    MOVLW   'B'
    CALL    SendChar
    RETURN
    
Check_LL_Black:                
    CPFSGT  LL_black_max_blue,0      
    GOTO    Check_LL_Unknown    ; No specific white test for LL
    
    ; It's BLACK - send 'K'
    MOVLW   'K'
    CALL    SendChar
    RETURN
    
Check_LL_Unknown:
    ; If no color detected - send '?'
    MOVLW   '?'
    CALL    SendChar
    RETURN
SendSensorValuesMsg:
    ; First send a header
    movlw   high SensorHeaderStr
    movwf   TBLPTRH, 0
    movlw   low SensorHeaderStr
    movwf   TBLPTRL, 0
    call    SendString
    
    ; Send Middle Middle sensor value
    movlw   'M'
    call    SendChar
    movlw   'M'
    call    SendChar
    movlw   ':'
    call    SendChar
    movlw   ' '
    call    SendChar
    movf    sensor_MM, W  ; Get MM sensor value
    call    SendHexByte   ; You'll need to create this helper
    call    SendCRLF
    
    ; Send Middle Right sensor value
    movlw   'M'
    call    SendChar
    movlw   'R'
    call    SendChar
    movlw   ':'
    call    SendChar
    movlw   ' '
    call    SendChar
    movf    sensor_MR, W  ; Get MR sensor value
    call    SendHexByte   ; Send as hex
    call    SendCRLF
    
    ; Send Middle Left sensor value
    movlw   'M'
    call    SendChar
    movlw   'L'
    call    SendChar
    movlw   ':'
    call    SendChar
    movlw   ' '
    call    SendChar
    movf    sensor_ML, W  ; Get ML sensor value
    call    SendHexByte   ; Send as hex
    call    SendCRLF
    
    ; Send Right Right sensor value
    movlw   'R'
    call    SendChar
    movlw   'R'
    call    SendChar
    movlw   ':'
    call    SendChar
    movlw   ' '
    call    SendChar
    movf    sensor_RR, W  ; Get RR sensor value
    call    SendHexByte   ; Send as hex
    call    SendCRLF
    
    ; Send Left Left sensor value
    movlw   'L'
    call    SendChar
    movlw   'L'
    call    SendChar
    movlw   ':'
    call    SendChar
    movlw   ' '
    call    SendChar
    movf    sensor_LL, W  ; Get LL sensor value
    call    SendHexByte   ; Send as hex
    call    SendCRLF
    
    return
;========== Check if command is "Howzit" ==========
CheckHowzit:
    movlw   6           ; Length of "Howzit"
    cpfslt  RXIndex, 0  ; Skip if RXIndex < 6
    bra     CheckHowzitChars
    bcf     STATUS, 0, 0 ; Not enough chars, set result to false
    return
    
CheckHowzitChars:
    lfsr    0, RXTable
    movf    INDF0, 0, 0  ; Check 'H'
    xorlw   'H'
    bnz     HowzitFail
    
    movf    PREINC0, 0, 0 ; Check 'o'
    xorlw   'o'
    bnz     HowzitFail
    
    movf    PREINC0, 0, 0 ; Check 'w'
    xorlw   'w'
    bnz     HowzitFail
    
    movf    PREINC0, 0, 0 ; Check 'z'
    xorlw   'z'
    bnz     HowzitFail
    
    movf    PREINC0, 0, 0 ; Check 'i'
    xorlw   'i'
    bnz     HowzitFail
    
    movf    PREINC0, 0, 0 ; Check 't'
    xorlw   't'
    bnz     HowzitFail
    
    ; "Howzit" matches - Load slogan from EEPROM
    ; Try to load slogan from EEPROM
    movlw   0x00                ; Start address in EEPROM
    movwf   START_ADDR
    movlw   LOW(CustomSlogan)   ; Destination in CustomSlogan
    movwf   DEST_PTR_L
    movlw   HIGH(CustomSlogan)
    movwf   DEST_PTR_H
    movlw   50                  ; Read up to 50 bytes
    movwf   BYTE_COUNT
    call    Read_From_EEPROM
    
    bsf     STATUS, 0, 0 ; Set result to true
    return
    
HowzitFail:
    bcf     STATUS, 0, 0 ; Set result to false
    return

;========== Command Handlers ==========
SendMainMenu:
    movlw   0           ; Set mode to Menu (0)
    movwf   CurrentMode, 0
    
    ; Update display to show 0
    movlw   0
    movwf   DisplayValue, 0  ; Display "0" for Menu mode
    call    UpdateDisplay
    bcf     PORTE, 0, 0   ; RE0 = 0
    bcf     PORTE, 1, 0   ; RE1 = 0
    bcf     PORTE, 2, 0   ; RE2 = 0

    
    call    SendCRLF
    call    SendMenu
    goto    FinalizeCommand

SelectColor:
    movlw   1           ; Set mode to Select Color (1)
    movwf   CurrentMode, 0
    
    ; Update display to show 1
    movlw   1
    movwf   DisplayValue, 0  ; Display "1" for Select Color mode
    call    UpdateDisplay
    bsf     PORTE, 0, 0   ; RE0 = 1
    bcf     PORTE, 1, 0   ; RE1 = 0
    bcf     PORTE, 2, 0   ; RE2 = 0

    
    call    SendCRLF
    call    SendSelectColorMsg
    goto    FinalizeCommand

Calibrate:
    movlw   2           ; Set mode to Calibrate (2)
    movwf   CurrentMode, 0
    
    ; Update display to show 2
    movlw   2
    movwf   DisplayValue, 0  ; Display "2" for Calibrate mode
    call    UpdateDisplay
    
    call    SendCRLF
    call    SendCalibrateMsg
    
    ; Directly set the INT0 interrupt flag to trigger calibration
    BSF     INTCON, 1       ; Set INT0IF (INT0 interrupt flag)
    
    goto    FinalizeCommand

RaceMode:
    movlw   3           ; Set mode to Race (3)
    movwf   CurrentMode, 0
    
    ; Update display to show 3
    movlw   3
    movwf   DisplayValue, 0  ; Display "3" for Race mode
    call    UpdateDisplay
    bsf     PORTE, 0, 0   ; RE0 = 1
    bsf     PORTE, 1, 0   ; RE1 = 1
    bcf     PORTE, 2, 0   ; RE2 = 0
    
    call    SendCRLF
    call    SendRaceMsg
    
    ; Check if a color is already selected
    btfsc   CS_Enable, 0
    call    DisplaySelectedColor  ; Display selected color
    
    ; If no color selected, prompt to select one
    btfss   CS_Enable, 0
    call    SendSelectColorFirst
    
    goto    FinalizeCommand

; New helper function to display the selected color
DisplaySelectedColor:
    ; Check which color is selected and turn on the corresponding LED
    btfsc   follow_colour, 4       ; Check if RED is selected
    bsf     PORTA, 4               ; Turn on RED indicator LED
    
    btfsc   follow_colour, 5       ; Check if GREEN is selected
    bsf     PORTA, 5               ; Turn on GREEN indicator LED
    
    btfsc   follow_colour, 6       ; Check if BLUE is selected
    bsf     PORTA, 6               ; Turn on BLUE indicator LED
    
    btfsc   follow_colour, 7       ; Check if BLACK is selected
    bsf     PORTA, 7               ; Turn on BLACK indicator LED
    
    ; Send message about selected color
    call    SendSelectedColorInfo
    return


; New helper function to show "Select color first" message
SendSelectColorFirst:
    movlw   high SelectColorFirstStr
    movwf   TBLPTRH, 0
    movlw   low SelectColorFirstStr
    movwf   TBLPTRL, 0
    call    SendString
    return

; New helper function to display info about the selected color
SendSelectedColorInfo:
    ; Determine which color is selected and send the appropriate message
    btfsc   follow_colour, 4       ; Check if RED is selected
    goto    SendRedForRaceMsg
    
    btfsc   follow_colour, 5       ; Check if GREEN is selected
    goto    SendGreenForRaceMsg
    
    btfsc   follow_colour, 6       ; Check if BLUE is selected
    goto    SendBlueForRaceMsg
    
    btfsc   follow_colour, 7       ; Check if BLACK is selected
    goto    SendBlackForRaceMsg
    
    return

SendRedForRaceMsg:
    movlw   high RedForRaceStr
    movwf   TBLPTRH, 0
    movlw   low RedForRaceStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendGreenForRaceMsg:
    movlw   high GreenForRaceStr
    movwf   TBLPTRH, 0
    movlw   low GreenForRaceStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendBlueForRaceMsg:
    movlw   high BlueForRaceStr
    movwf   TBLPTRH, 0
    movlw   low BlueForRaceStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendBlackForRaceMsg:
    movlw   high BlackForRaceStr
    movwf   TBLPTRH, 0
    movlw   low BlackForRaceStr
    movwf   TBLPTRL, 0
    call    SendString
    return

Diagnostics:
    movlw   4           ; Set mode to Diagnostics (4)
    movwf   CurrentMode, 0
    
    ; Update display to show 4
    movlw   4
    movwf   DisplayValue, 0  ; Display "4" for Diagnostics mode
    call    UpdateDisplay
    bcf     PORTE, 0, 0   ; RE0 = 0
    bcf     PORTE, 1, 0   ; RE1 = 0
    bsf     PORTE, 2, 0   ; RE2 = 1

    
    call    SendCRLF
    call    SendDiagnosticsMsg
    goto    FinalizeCommand

ProgramMode:
    movlw   5           ; Set mode to Program (5)
    movwf   CurrentMode, 0
    
    ; Update display to show 5
    movlw   5
    movwf   DisplayValue, 0  ; Display "5" for Program mode
    call    UpdateDisplay
    bsf     LATE, 0, 0   ; RE0 = 1
    bcf     PORTE, 1, 0   ; RE1 = 0
    bsf     PORTE, 2, 0   ; RE2 = 1
 
    ; Initialize program mode
    clrf    ProgramIndex, 0  ; Reset index for new slogan
    bsf     EditMode, 0, 0   ; Set edit mode flag
    
    call    SendCRLF
    call    SendProgramMsg
    goto    FinalizeCommand

TimeMode:
    movlw   6           ; Set mode to Time (6)
    movwf   CurrentMode, 0
    
    ; Update display to show 6
    movlw   6
    movwf   DisplayValue, 0  ; Display "6" for Time mode
    call    UpdateDisplay
    bcf     PORTE, 0, 0   ; RE0 = 0
    bsf     PORTE, 1, 0   ; RE1 = 1
    bsf     PORTE, 2, 0   ; RE2 = 1

    
    call    SendCRLF
    call    SendTimeMsg
    goto    FinalizeCommand

;========== Update 7-Segment Display ==========
UpdateDisplay:
    ; Update RE0-RE2 pins based on DisplayValue (0-7)
    btfsc   DisplayValue, 0
    bsf     PORTE, 0
    btfss   DisplayValue, 0
    bcf     PORTE, 0
    
    btfsc   DisplayValue, 1
    bsf     PORTE, 1
    btfss   DisplayValue, 1
    bcf     PORTE, 1
    
    btfsc   DisplayValue, 2
    bsf     PORTE, 2
    btfss   DisplayValue, 2
    bcf     PORTE, 2
    
    return


;========== Message Sending Routines ==========
SendError:
    call    SendCRLF
    movlw   high ErrorMsg
    movwf   TBLPTRH, 0
    movlw   low ErrorMsg
    movwf   TBLPTRL, 0
    call    SendString
    return

SendMenu:
    ; First part of menu (team name and fixed text)
    movlw   high MenuStr1
    movwf   TBLPTRH, 0
    movlw   low MenuStr1
    movwf   TBLPTRL, 0
    call    SendString
    
    ; Send custom slogan from RAM
    lfsr    0, CustomSlogan
    call    SendRAMString
    
    ; Add newline if not already present in slogan
    call    SendCRLF
    
    ; Send rest of menu
    movlw   high MenuStr2
    movwf   TBLPTRH, 0
    movlw   low MenuStr2
    movwf   TBLPTRL, 0
    call    SendString
    return

SendSelectColorMsg:
    movlw   high SelectColorStr
    movwf   TBLPTRH, 0
    movlw   low SelectColorStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendCalibrateMsg:
    movlw   high CalibrateStr
    movwf   TBLPTRH, 0
    movlw   low CalibrateStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendRaceMsg:
    movlw   high RaceStr
    movwf   TBLPTRH, 0
    movlw   low RaceStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendDiagnosticsMsg:
    movlw   high DiagnosticsStr
    movwf   TBLPTRH, 0
    movlw   low DiagnosticsStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendProgramMsg:
    movlw   high ProgramStr
    movwf   TBLPTRH, 0
    movlw   low ProgramStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendTimeMsg:
    movlw   high TimeStr
    movwf   TBLPTRH, 0
    movlw   low TimeStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendStartupMsg:
    movlw   high StartupStr
    movwf   TBLPTRH, 0
    movlw   low StartupStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendRedSelectedMsg:
    movlw   high RedSelectedStr
    movwf   TBLPTRH, 0
    movlw   low RedSelectedStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendGreenSelectedMsg:
    movlw   high GreenSelectedStr
    movwf   TBLPTRH, 0
    movlw   low GreenSelectedStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendBlueSelectedMsg:
    movlw   high BlueSelectedStr
    movwf   TBLPTRH, 0
    movlw   low BlueSelectedStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendBlackSelectedMsg:
    movlw   high BlackSelectedStr
    movwf   TBLPTRH, 0
    movlw   low BlackSelectedStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendInvalidColorMsg:
    movlw   high InvalidColorStr
    movwf   TBLPTRH, 0
    movlw   low InvalidColorStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendInvalidDiagMsg:
    movlw   high InvalidDiagStr
    movwf   TBLPTRH, 0
    movlw   low InvalidDiagStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendSensorTestMsg:
    movlw   high SensorTestStr
    movwf   TBLPTRH, 0
    movlw   low SensorTestStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendForwardMsg:
    movlw   high ForwardStr
    movwf   TBLPTRH, 0
    movlw   low ForwardStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendLeftMsg:
    movlw   high LeftStr
    movwf   TBLPTRH, 0
    movlw   low LeftStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendRightMsg:
    movlw   high RightStr
    movwf   TBLPTRH, 0
    movlw   low RightStr
    movwf   TBLPTRL, 0
    call    SendString
    return

SendSloganUpdatedMsg:
    movlw   high SloganUpdatedStr
    movwf   TBLPTRH, 0
    movlw   low SloganUpdatedStr
    movwf   TBLPTRL, 0
    call    SendString
    return

;========== Utility Routines ==========
SendString:
    tblrd*+
    movf    TABLAT, 0, 0
    bz      SendStringEnd  ; Check for null terminator
    call    SendChar
    bra     SendString
SendStringEnd:
    return

; Send string from RAM (pointed to by FSR0)
SendRAMString:
    movf    POSTINC0, 0, 0
    bz      SendRAMStringEnd  ; Check for null terminator
    call    SendChar
    bra     SendRAMString
SendRAMStringEnd:
    return

SendCRLF:
    movlw   0x0D        ; Carriage return
    call    SendChar
    movlw   0x0A        ; Line feed
    call    SendChar
    return

;========== Clear RX Table ==========
ClearBuffer:
    clrf    RXIndex, 0
    lfsr    0, RXTable
    movf    RXBuffSize, 0, 0
    movwf   Counter, 0
    
ClearBuffer_Loop:
    ; Loop to clear buffer
    clrf    POSTINC0, 0
    decfsz  Counter, 1, 0
    bra     ClearBuffer_Loop
    
    return

;========== Send One Byte ==========
SendChar:
    btfss   PIR1, 4, 0  ; Check if TXREG is empty
    bra     SendChar
    movwf   TXREG1, 0   ; Send the character
    return

Write_To_EEPROM:
    ; Set up EEPROM address
    movf    START_ADDR, W
    movwf   EEPROM_ADDRESS
    
    ; Set up source pointer
    movf    SRC_PTR_H, W
    movwf   FSR0H
    movf    SRC_PTR_L, W
    movwf   FSR0L
    
    ; Set up byte counter
    movf    BYTE_COUNT, W
    movwf   TEMP_COUNTER
    
    ; Check if byte count is zero
    movf    TEMP_COUNTER, W
    bz      Write_Done         ; If zero, nothing to write
    
Write_EEPROM_Loop:
    ; 1. Generate start condition
    call    I2C_START_CONDITION
    
    ; 2. Load & send the control byte/slave address
    movlw   WRITE_CONTROL
    movwf   TX_BYTE    
    call    my_I2C_WRITE
    
    ; 3. Load & send the address
    movf    EEPROM_ADDRESS, W
    movwf   TX_BYTE        
    call    my_I2C_WRITE
   
    ; 4. Load & send the data from memory
    movf    POSTINC0, W        ; Get byte from memory and increment pointer
    movwf   TX_BYTE
    call    my_I2C_WRITE
    
    ; 5. Generate a stop bit    
    call    I2C_STOP_CONDITION
    
    ; 6. Wait for Acknowledge
    call    POLLING_WRITE_ACK
    
    call    I2C_DELAY          ; Changed from DELAY to I2C_DELAY
    
    ; Increment EEPROM address for next write
    incf    EEPROM_ADDRESS, F
        
    decfsz  TEMP_COUNTER, F
    goto    Write_EEPROM_Loop
    
Write_Done:
    return

;-------------------------------------------------------------------------------
; Function: Read_From_EEPROM
; Reads data from EEPROM to memory
; Input:
;   - START_ADDR: Starting address in EEPROM
;   - DEST_PTR_L/H: Destination pointer (FSR address)
;   - BYTE_COUNT: Number of bytes to read
; Output: None
;-------------------------------------------------------------------------------
Read_From_EEPROM:
    ; Set up EEPROM address
    movf    START_ADDR, W
    movwf   EEPROM_ADDRESS
    
    ; Set up destination pointer
    movf    DEST_PTR_H, W
    movwf   FSR0H
    movf    DEST_PTR_L, W
    movwf   FSR0L
    
    ; Set up byte counter
    movf    BYTE_COUNT, W
    movwf   TEMP_COUNTER
    
    ; Check if byte count is zero
    movf    TEMP_COUNTER, W
    bz      Read_Done          ; If zero, nothing to read

Read_EEPROM_Loop:
    ; 1. Set the address (with a dummy write)
    call    I2C_START_CONDITION
    movlw   WRITE_CONTROL      ; Control byte (write mode)
    movwf   TX_BYTE
    call    my_I2C_WRITE

    movf    EEPROM_ADDRESS, W  ; EEPROM address
    movwf   TX_BYTE
    call    my_I2C_WRITE
    
    ; 2. Start a new transaction for reading
    call    I2C_RESTART        ; Restart for read operation
    movlw   READ_CONTROL       ; Control byte (read mode)
    movwf   TX_BYTE
    call    my_I2C_WRITE
    
    ; 3. Read one byte
    bcf     SSP1IF              ; Clear interrupt flag
    bsf     SSP1CON2, 3         ; Enable receive mode
Wait_For_Byte:
    btfss   SSP1IF              ; Wait for interrupt flag
    bra     Wait_For_Byte       
    
    movf    SSP1BUF, W          ; Get received byte
    movwf   INDF0               ; Store at current FSR0 address
    incf    FSR0L, F            ; Increment FSR0 pointer
    
    ; 4. Send NACK as we're done with this byte
    bcf     SSP1CON2, 6         ; NACK - we're only reading one byte
    
    ; 5. End this transaction
    call    I2C_STOP_CONDITION
    
    ; 6. Prepare for next byte
    incf    EEPROM_ADDRESS, F   ; Increment EEPROM address
    
    decfsz  TEMP_COUNTER, F
    goto    Read_EEPROM_Loop
    
Read_Done:
    return

    
; Convert byte in W to hex and send via UART
SendHexByte:
    movwf   Temp          ; Save the byte
    
    ; Send high nibble
    swapf   Temp, W       ; Swap nibbles, result in W
    andlw   0x0F          ; Mask off high nibble
    call    NibbleToASCII
    call    SendChar
    
    ; Send low nibble
    movf    Temp, W       ; Get original byte
    andlw   0x0F          ; Mask off high nibble
    call    NibbleToASCII
    call    SendChar
    
    return

; Convert nibble in W to ASCII hex character
NibbleToASCII:
    addlw   '0'           ; Convert to ASCII
    movwf   Temp          ; Store temporarily
    movlw   '9'           ; Load '9' for comparison
    cpfslt  Temp, 0       ; Skip if Temp < '9'+1 (W = '9'+1)
    goto    AlphaChar     ; It's A-F
    movf    Temp, W       ; It's 0-9, retrieve the value
    return
    
AlphaChar:
    movf    Temp, W       ; Get value back
    addlw   7             ; Adjust for A-F (ASCII 'A' - '9' - 1 = 7)
    return
;-------------------------------------------------------------------------------
; I2C Helper Functions
;-------------------------------------------------------------------------------
I2C_START_CONDITION:       
    bcf     SSP1IF
    bsf     SSP1CON2, 0     ; Send start condition 
wait_START:        
    btfsc   SSP1CON2, 0        
    bra     wait_START    
    btfss   SSP1STAT, 3
    setf    PORTA           ; All PORTA set = start failed
    return
    
I2C_RESTART:
    bcf     SSP1IF
    bsf     SSP1CON2, 1     ; Send restart condition
wait_RESTART:    
    btfsc   SSP1CON2, 1    
    bra     wait_RESTART
    return
    
I2C_STOP_CONDITION:    
    bcf     SSP1IF
    bsf     SSP1CON2, 2     ; Send stop condition
wait_STOP:    
    btfsc   SSP1CON2, 2    
    bra     wait_STOP
    return
    
my_I2C_WRITE:        
    btfsc   SSP1STAT, 0
    goto    my_I2C_WRITE    ; Wait for buffer to be empty
    bcf     SSP1IF
    movf    TX_BYTE, W
    movwf   SSP1BUF
wait_WRITE:
    btfss   SSP1IF
    bra     wait_WRITE
    return
    
POLLING_WRITE_ACK:    
    call    I2C_RESTART
    movlw   10100000B       ; Control write
    movwf   TX_BYTE
    call    my_I2C_WRITE
    btfss   SSP1CON2, 6     ; Checking if Acknowledge was not received
    goto    POLLING_DONE
    goto    POLLING_WRITE_ACK
    
POLLING_DONE:
    call    I2C_STOP_CONDITION
    btfsc   SSP1IF
    call    FLASH_LED
    return
    
FLASH_LED:
    ; Save current PORTD state (optional)
    movf    PORTD, W
    movwf   Temp
    
    ; Flash the white LED on RD5
    bsf     PORTD, 5        ; Turn on white LED (RD5)
    call    I2C_DELAY       ; Delay
    bcf     PORTD, 5        ; Turn off white LED (RD5)
    call    I2C_DELAY       ; Delay (optional)
    bsf     PORTD, 5        ; Turn on white LED again (optional)
    call    I2C_DELAY       ; Delay (optional)
    bcf     PORTD, 5        ; Turn off white LED again
    
    ; Restore original PORTD state (optional)
    movf    Temp, W
    movwf   PORTD
    
    return   
    
; Renamed from DELAY to I2C_DELAY to avoid conflicts
I2C_DELAY:    
    movlw   0xFF        
    movwf   Delay2       
LOOP1:        
    movlw   0xFF
    movwf   Delay1
LOOP2:
    decfsz  Delay1, F   
    goto    LOOP2     
    decfsz  Delay2, F   
    goto    LOOP1     
    return
;========== Program Memory Strings ==========
    org 0x3000
    
StartupStr:
    db "Team 022 iTrack, Therefore I Am", 0x0D, 0x0A, "Starting in Race mode...", 0x0D, 0x0A, 0

MenuStr1:
    db "Team 022 iTrack, Therefore I Am", 0x0D, 0x0A, 0

; Default slogan to be stored in RAM for editing
DefaultSlogan:
    db "Catch us if you can!", 0x0D, 0x0A, 0

MenuStr2:
    db "Choose your MARV mode...", 0x0D, 0x0A
    db "(S)elect colour", 0x0D, 0x0A
    db "(C)alibrate", 0x0D, 0x0A
    db "(R)ace", 0x0D, 0x0A
    db "(D)iagnostics", 0x0D, 0x0A
    db "(P)rogram", 0x0D, 0x0A
    db "(T)ime (optional)", 0x0D, 0x0A, 0

SelectColorStr:
    db "Select color mode", 0x0D, 0x0A
    db "Choose: R (red), G (green), B (blue), k (black)", 0x0D, 0x0A
    db "Type 'Howzit' to return to main menu", 0x0D, 0x0A, 0

CalibrateStr:
    db "Calibration mode", 0x0D, 0x0A
    db "Calibrating for selected color...", 0x0D, 0x0A, 0

RaceStr:
    db "Race mode", 0x0D, 0x0A
    db "Racing on selected track", 0x0D, 0x0A, 0

DiagnosticsStr:
    db "Diagnostics mode", 0x0D, 0x0A
    db "Enter: S (sensor test), F (forward), L (left), R (right), T (stop)", 0x0D, 0x0A
    db "Type 'Howzit' to return to main menu", 0x0D, 0x0A, 0

ProgramStr:
    db "Program mode", 0x0D, 0x0A
    db "Enter new slogan (press Enter when done):", 0x0D, 0x0A, 0

TimeStr:
    db "Time mode", 0x0D, 0x0A
    db "Last race time: N/A", 0x0D, 0x0A, 0

ErrorMsg:
    db "Error: Invalid command", 0x0D, 0x0A, 0

RedSelectedStr:
    db "Red color selected", 0x0D, 0x0A
    db "Still in Select Color mode. Choose another color or type 'Howzit' to return to main menu", 0x0D, 0x0A, 0

GreenSelectedStr:
    db "Green color selected", 0x0D, 0x0A
    db "Still in Select Color mode. Choose another color or type 'Howzit' to return to main menu", 0x0D, 0x0A, 0

BlueSelectedStr:
    db "Blue color selected", 0x0D, 0x0A
    db "Still in Select Color mode. Choose another color or type 'Howzit' to return to main menu", 0x0D, 0x0A, 0

BlackSelectedStr:
    db "Black color selected", 0x0D, 0x0A
    db "Still in Select Color mode. Choose another color or type 'Howzit' to return to main menu", 0x0D, 0x0A, 0

InvalidColorStr:
    db "Invalid color selection", 0x0D, 0x0A
    db "Choose: R (red), G (green), B (blue), k (black)", 0x0D, 0x0A, 0

InvalidDiagStr:
    db "Invalid diagnostics command", 0x0D, 0x0A
    db "Enter: S (sensor test), F (forward), L (left), R (right)", 0x0D, 0x0A, 0

SensorTestStr:
    db "Running sensor test...", 0x0D, 0x0A
    db "Sensor reading: WWWBW", 0x0D, 0x0A  ; Example output
    db "Still in Diagnostics mode. Enter another command or type 'Howzit' to return to main menu", 0x0D, 0x0A, 0

ForwardStr:
    db "Moving forward...", 0x0D, 0x0A
    db "Still in Diagnostics mode. Enter another command or type 'Howzit' to return to main menu", 0x0D, 0x0A, 0

LeftStr:
    db "Turning left...", 0x0D, 0x0A
    db "Still in Diagnostics mode. Enter another command or type 'Howzit' to return to main menu", 0x0D, 0x0A, 0

RightStr:
    db "Turning right...", 0x0D, 0x0A
    db "Still in Diagnostics mode. Enter another command or type 'Howzit' to return to main menu", 0x0D, 0x0A, 0

SloganUpdatedStr:
    db "Slogan updated successfully!", 0x0D, 0x0A, 0

SensorHeaderStr:
    db "Sensor Readings:", 0x0D, 0x0A, 0

SendStopMsg:
    movlw   high StopStr
    movwf   TBLPTRH, 0
    movlw   low StopStr
    movwf   TBLPTRL, 0
    call    SendString
    return
    
StopStr:
    db "Stopping motors...", 0x0D, 0x0A
    db "Still in Diagnostics mode. Enter another command or type 'Howzit' to return to main menu", 0x0D, 0x0A, 0
    
SelectColorFirstStr:
    db "Please select a color first using Select Color mode", 0x0D, 0x0A, 0

RedForRaceStr:
    db "Ready to race on RED track", 0x0D, 0x0A, "Press the Start button or use INT2 to begin racing", 0x0D, 0x0A, 0

GreenForRaceStr:
    db "Ready to race on GREEN track", 0x0D, 0x0A, "Press the Start button or use INT2 to begin racing", 0x0D, 0x0A, 0

BlueForRaceStr:
    db "Ready to race on BLUE track", 0x0D, 0x0A, "Press the Start button or use INT2 to begin racing", 0x0D, 0x0A, 0

BlackForRaceStr:
    db "Ready to race on BLACK track", 0x0D, 0x0A, "Press the Start button or use INT2 to begin racing", 0x0D, 0x0A, 0

SensorColorStr:
    db "Sensor Color Detection:", 0x0D, 0x0A, 0

;========== RAM Buffer ==========
    org 0x100
RXTable:
    ds 20  ; 20-byte receive buffer

    org 0x120
CustomSlogan:
    ds 50  ; 50-byte buffer for editable slogan

END      
