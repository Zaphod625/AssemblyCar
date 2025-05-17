PROCESSOR 18F45K22
    CONFIG FOSC = INTIO67
    CONFIG WDTEN = OFF
    #include <xc.inc>
    #include "pic18f45k22.inc"
    PSECT code, abs
    org 0x00
    goto Setup

;========== UART RAM Variables ==========
RXIndex         equ 0x20  ; Index for received characters
Temp            equ 0x21  ; Temporary variable
Counter         equ 0x22  ; Counter for loops
RXBuffSize      equ 0x23  ; Size of receive buffer
CurrentMode     equ 0x24  ; Current MARV mode (0=Menu, 1=Select, 2=Calibrate, 3=Race, etc.)
SelectedColor   equ 0x25  ; Selected color (0=None, 1=Red, 2=Green, 3=Blue, 4=Black)
DisplayValue    equ 0x26  ; Value to display on 7-segment display
ProgramIndex    equ 0x27  ; Index for program mode (editing slogan)
EditMode        equ 0x28  ; Flag to indicate we are in edit mode
	
;--- I2C Variables (Adjusted to avoid conflicts with UART code)
    TX_BYTE         EQU 0x40
    POLL_COUNTER    EQU 0x41
    Delay1          EQU 0x42
    Delay2          EQU 0x43
    EEPROM_ADDRESS  EQU 0x44
    BYTE_COUNT      EQU 0x45
    TEMP_COUNTER    EQU 0x46
    
    ; Parameters for functions
    SRC_PTR_L       EQU 0x47
    SRC_PTR_H       EQU 0x48
    DEST_PTR_L      EQU 0x49
    DEST_PTR_H      EQU 0x4A
    START_ADDR      EQU 0x4B
    
    WRITE_CONTROL   EQU 10100000B  ; Control byte for write operations (A0h)
    READ_CONTROL    EQU 10100001B  ; Control byte for read operations (A1h)

;========== Setup ==========
Setup:
    movlw   0x50        ; Set internal oscillator to 16MHz
    movwf   OSCCON, 0
    
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
    goto    MainLoop

;========== Initialize Slogan ==========
InitializeSlogan:
    ; Copy default slogan to editable buffer
    lfsr    0, CustomSlogan
    lfsr    1, DefaultSlogan
CopySlogan:
    movf    POSTINC1, 0, 0
    movwf   POSTINC0, 0
    bnz     CopySlogan    ; Continue until null terminator
    return

;========== Main Loop ==========
MainLoop:
WaitRX:
    btfss   PIR1, 5, 0  ; Check if data received
    bra     WaitRX
    movff   RCREG1, Temp
    
    ; Echo typed character
    movf    Temp, 0, 0
    call    SendChar
    
    ; Check for <Enter>
    movf    Temp, 0, 0
    xorlw   0x0D
    bz      ProcessInput
    
    ; Check if we're in Program/Edit mode
    btfsc   EditMode, 0, 0
    goto    StoreInSloganBuffer
    
    ; Store in RXTable (up to buffer size limit)
    movf    RXBuffSize, 0, 0
    cpfslt  RXIndex, 0  ; Skip if RXIndex < RXBuffSize
    bra     MainLoop    ; Buffer full, ignore character
    
    lfsr    0, RXTable  ; Point to start of buffer
    movf    RXIndex, 0, 0
    addwf   FSR0L, 1, 0 ; Adjust pointer to current position
    movf    Temp, 0, 0  ; Get the received character
    movwf   POSTINC0, 0 ; Store it in buffer
    incf    RXIndex, 1, 0 ; Increment index
    goto    MainLoop

;========== Store character in slogan buffer (Program Mode) ==========
StoreInSloganBuffer:
    ; Only store printable ASCII characters (32-126)
    movlw   32          ; Space character
    cpfslt  Temp, 0     ; Skip if Temp < 32
    goto    CheckUpperLimit
    goto    MainLoop    ; Ignore control characters
    
CheckUpperLimit:
    movlw   127         ; Above printable ASCII
    cpfslt  Temp, 0     ; Skip if Temp < 127 
    goto    MainLoop    ; Ignore high-ASCII characters
    
    ; Store in CustomSlogan (up to buffer size limit)
    movlw   48          ; Max slogan size (safe limit)
    cpfslt  ProgramIndex, 0  ; Skip if ProgramIndex < 48
    goto    MainLoop    ; Buffer full, ignore character
    
    lfsr    0, CustomSlogan  ; Point to start of buffer
    movf    ProgramIndex, 0, 0
    addwf   FSR0L, 1, 0 ; Adjust pointer to current position
    movf    Temp, 0, 0  ; Get the received character
    movwf   POSTINC0, 0 ; Store it in buffer
    movlw   0           ; Add null terminator
    movwf   INDF0, 0    ; Store it
    incf    ProgramIndex, 1, 0 ; Increment index
    goto    MainLoop

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
    goto    MainLoop

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
    goto    MainLoop

SelectRed:
    movlw   1           ; Set color to Red (1)
    movwf   SelectedColor, 0
    call    SendCRLF
    call    SendRedSelectedMsg
    call    ClearBuffer
    goto    MainLoop

SelectGreen:
    movlw   2           ; Set color to Green (2)
    movwf   SelectedColor, 0
    call    SendCRLF
    call    SendGreenSelectedMsg
    call    ClearBuffer
    goto    MainLoop

SelectBlue:
    movlw   3           ; Set color to Blue (3)
    movwf   SelectedColor, 0
    call    SendCRLF
    call    SendBlueSelectedMsg
    call    ClearBuffer
    goto    MainLoop

SelectBlack:
    movlw   4           ; Set color to Black (4)
    movwf   SelectedColor, 0
    call    SendCRLF
    call    SendBlackSelectedMsg
    call    ClearBuffer
    goto    MainLoop

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
    
    ; Invalid diagnostics command
    call    SendInvalidDiagMsg
    call    ClearBuffer
    goto    MainLoop

DiagSensorTest:
    call    SendCRLF
    call    SendSensorTestMsg
    call    ClearBuffer
    goto    MainLoop

DiagForward:
    call    SendCRLF
    call    SendForwardMsg
    call    ClearBuffer
    goto    MainLoop

DiagLeft:
    call    SendCRLF
    call    SendLeftMsg
    call    ClearBuffer
    goto    MainLoop

DiagRight:
    call    SendCRLF
    call    SendRightMsg
    call    ClearBuffer
    goto    MainLoop

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
    bcf     PORTE, 0, 0   ; RE0 = 0
    bsf     PORTE, 1, 0   ; RE1 = 1
    bcf     PORTE, 2, 0   ; RE2 = 0

    
    call    SendCRLF
    call    SendCalibrateMsg
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
    goto    FinalizeCommand

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
    ; Safely update RE0?RE2 with DisplayValue (0?7)
    ; RE3?RE7 are completely untouched

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
    movlw   11000000B
    movwf   PORTA, A
    call    I2C_DELAY       ; Changed from DELAY to I2C_DELAY
    movlw   10000000B
    movwf   PORTA
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
    db "Team 100 iTrack, Therefore I Am", 0x0D, 0x0A, "Starting in Race mode...", 0x0D, 0x0A, 0

MenuStr1:
    db "Team 100 iTrack, Therefore I Am", 0x0D, 0x0A, 0

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
    db "Enter: S (sensor test), F (forward), L (left), R (right)", 0x0D, 0x0A
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

;========== RAM Buffer ==========
    org 0x100
RXTable:
    ds 20  ; 20-byte receive buffer

    org 0x120
CustomSlogan:
    ds 50  ; 50-byte buffer for editable slogan
    
    end