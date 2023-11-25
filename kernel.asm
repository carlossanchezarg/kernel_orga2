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
extern print_text_pm
extern pic_reset
extern pic_enable
extern mmu_init_kernel_dir
extern mmu_map_page
extern mmu_unmap_page
extern mmu_init_task_dir
extern copy_page
extern tss_init
extern tasks_screen_draw
extern tasks_init
extern sched_init
; COMPLETAR - Definan correctamente estas constantes cuando las necesiten
;
%define CS_RING_0_SEL (1<<3)
%define DS_RING_0_SEL (3 << 3)    
%define STACK_BASE 0x25000
%define ON_DEMAND_MEM_START_VIRTUAL 0x07000000

%define TSS_INITIAL_0_SEL (11 << 3)
%define TSS_IDLE_0_SEL (12 << 3)

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

idty_mapping db     'Identity Mapping listo!',0
idty_mapping_len equ    $ - idty_mapping

mmu_ini_msg db     'Iniciando MMU..'
mmu_ini_msg_len equ    $ - mmu_ini_msg

cambia_CR3 db "Se carga en CR3 address de PD de tarea.",0
cambia_CR3_len equ    $ - cambia_CR3

restaura_CR3 db "Se restaura CR3 del kernel.",0
restaura_CR3_len equ    $ - restaura_CR3

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

    ;##########TEST MAPEO Y DESMAPEO de Paginas ###############################
     ;# Test de mapeo de direccion virtual a fisica:  0x00400000 ---> 0x0050E000
     push 0x2; attrs=0x2 P=1  W=1
     push 0x00400000; Dir Fisica
     push 0x0050E000; Dir virtual
     mov eax, cr3
     push eax;
     call mmu_map_page
     add esp, 4*4

     mov byte[0x50E000], 0x1
     mov byte[ON_DEMAND_MEM_START_VIRTUAL], 0xFFFF
     ;mov byte[0x8000000], 0xFFFF
     
     ;Aca desmapeo la dir virtual 0x0050E00
     push 0x0050E000; Dir virtual
     mov eax, cr3
     push eax;
     call mmu_unmap_page
     add esp, 4*2

     ;############ TEST copy_page ###############
     ; Copio la pagina del page directory en 0x25000 a 0xB0000
     push 0x25000; dir fisica fuente(pagina que contiene el PD)
     push 0x50000; dir fisica destino
     call copy_page
     add esp, 4*2

    ;############ TEST mmu_init_task_dir ###############
    ; Se arma estructura de paginacion para tarea
    mov eax, 0x18000
    push eax
    call mmu_init_task_dir
    add esp, 4
    ;guardo cr3 actual para luego volver
    mov edi, cr3
    push edi
    ; Cambio al page directory de la tarea y entonces cambiara el mapeo de memoria virutal
    mov cr3,eax
    ;print_text_pm cambia_CR3, cambia_CR3_len, 0x07, 0, 800

    ; Se reestablece el valor de CR3.
    pop edi
    mov cr3,edi
    ;print_text_pm restaura_CR3, restaura_CR3_len, 0x07, 0, 880
    
    ;######## TAREAS
    ; Carga las tasks gate en la GDT 
    ; TAREAS INICIALES
    call tss_init

    call tasks_screen_draw

    mov ax, TSS_INITIAL_0_SEL
    ltr ax

    call sched_init
    call tasks_init

    ; CAMBIAMOS PIT 
    ; ahora se pueden jugar mejor
    mov ax, 0xFF8; LENTO
    out 0x40, al 
    rol ax, 8
    out 0x40, al
    
    jmp TSS_IDLE_0_SEL:0

    ; Ciclar infinitamente 
    mov eax, 0xFFFF
    mov ebx, 0xFFFF
    mov ecx, 0xFFFF
    mov edx, 0xFFFF
    jmp $

;; -------------------------------------------------------------------------- ;;

%include "a20.asm"
