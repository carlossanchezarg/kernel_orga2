; ** por compatibilidad se omiten tildes **
; ==============================================================================
; TALLER System Programming - ORGANIZACION DE COMPUTADOR II - FCEN
; ==============================================================================

%include "print.mac"

global start


; COMPLETAR - Agreguen declaraciones extern según vayan necesitando
extern GDT_DESC
extern IDT_DESC
extern idt_init
extern screen_draw_layout
extern pic_reset
extern pic_enable
extern mmu_init_kernel_dir
; COMPLETAR - Definan correctamente estas constantes cuando las necesiten
;
%define CS_RING_0_SEL (1<<3)
%define DS_RING_0_SEL (3 << 3)    
%define STACK_BASE 0x25000

BITS 16
;; Saltear seccion de datos
jmp start

;;
;; Seccion de datos.
;; -------------------------------------------------------------------------- ;;
start_rm_msg db     'Iniciando kernel en Modo Real'
start_rm_len equ    $ - start_rm_msg

start_pm_msg db     'Iniciando kernel en Modo Protegido'
start_pm_len equ    $ - start_pm_msg

;;
;; Seccion de código.
;; -------------------------------------------------------------------------- ;;

;; Punto de entrada del kernel.
BITS 16
start:
    ; COMPLETAR - Deshabilitar interrupciones
     cli ; desabilita las interrupciones

    ; Cambiar modo de video a 80 X 50
    mov ax, 0003h
    int 10h ; set mode 03h
    xor bx, bx
    mov ax, 1112h
    int 10h ; load 8x8 font

    ; COMPLETAR - Imprimir mensaje de bienvenida - MODO REAL
    ; (revisar las funciones definidas en print.mac y los mensajes se encuentran en la
    ; sección de datos)
    print_text_rm start_rm_msg, start_rm_len, 0xf, 0x0, 0x0  
    ; COMPLETAR - Habilitar A20
    ; (revisar las funciones definidas en a20.asm)
    call A20_disable
    call A20_check
    call A20_enable
    call A20_check
    ; COMPLETAR - Cargar la GDT
    lgdt [GDT_DESC]
    ; COMPLETAR - Setear el bit PE del registro CR0
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax
    ; COMPLETAR - Saltar a modo protegido (far jump)
    ; (recuerden que un far jmp se especifica como jmp CS_selector:address)
    ; Pueden usar la constante CS_RING_0_SEL definida en este archivo
    ;#########
    ; Al hacer este far jmp le decimos al micro que carge el selector de segmento en 
    ; el registro CS y que el IP apunte a la dir de la etiqueta "modo_protegido"
    jmp CS_RING_0_SEL:modo_protegido

BITS 32
modo_protegido:
    ; COMPLETAR - A partir de aca, todo el codigo se va a ejectutar en modo protegido
    ; Establecer selectores de segmentos DS, ES, GS, FS y SS en el segmento de datos de nivel 0
    ; Pueden usar la constante DS_RING_0_SEL definida en este archivo
    mov ax, DS_RING_0_SEL
    mov ds, ax
    mov es, ax
    mov gs, ax 
    mov fs, ax
    mov ss, ax

    ; COMPLETAR - Establecer el tope y la base de la pila
     mov esp, STACK_BASE
     mov ebp, STACK_BASE

    ; COMPLETAR - Imprimir mensaje de bienvenida - MODO PROTEGIDO
     print_text_pm start_pm_msg, start_pm_len, 0xa, 0x0, 0x0

    ; COMPLETAR - Inicializar pantalla
    call screen_draw_layout
   
    ; INTERRUPCIONES
    ; Cargamos IDT en IDTR
    call idt_init
    lidt [IDT_DESC]

    ; Remapeamos puertos del PIC
    call pic_reset
    call pic_enable
    sti ; habilitamos interrupciones
    
    ; testear syscall
    int 88
    int 98

    ;##### Paginación
     
    call mmu_init_kernel_dir
    mov cr3, eax

    ; Activar paginacion seteando el bit CR0.PG
    mov eax, cr0
    or eax, 0x80000000 ; 31=1 31-0=0
    mov cr0, eax    

    ;# TEST de mapeo de paginas
    ; Ciclar infinitamente 
    mov eax, 0xFFFF
    mov ebx, 0xFFFF
    mov ecx, 0xFFFF
    mov edx, 0xFFFF
    jmp $

;; -------------------------------------------------------------------------- ;;

%include "a20.asm"
