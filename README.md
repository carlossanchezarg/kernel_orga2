# Orga 2 Kernel  
**Descripción:** kernel multitarea para la arquitectura Intel x86 de 32 bits. Desarrollado en el contexto de la materia Organización del computador 2 (FCEN-UBA).  

 **Resultados:**  
  | Visualización de la ejecución de 4 tareas en simultaneo:| 
  | :------------:|
  | ![Ejecuación de 4 tareas](./tareas_kernel_anim.gif)  |

- Completar todo el kernel tomo la mitad de la materia (2 meses aprox.) y consistio en varias etapas de desarrollo incrementales hasta lograr tener un kernel que permita ejecutar varias tareas en simultáneo.
- **Etapas**:   
	- Pasaje de modo real a modo protegido con segmentación flat. Se definió una Global Descriptor Table (GDT) con cuatro segementos utilizando un esquema de segmentación flat, que consistió en cuatro segmentos solapados: dos segmentos de codigo uno de nivel 0 y otro de nivel 3, dos segmentos de datos uno de nivel 0 y otro de nivel 3. Antes de activar paginación es necesario pasar por segmentación debido a la retrocompatibilidad de los procesadores INTEL, este mecanismo está mayormente en desuso.
	- Interrupciones: se generan las estructuras necesarias para el manejo de interrupciones: se define la Interrupt Descriptor Table (IDT) y sus correspondientes handlers de interrupción.  
	- MMU: Se desarrollo una unidad de manejo de memoria utilizando paginación. La unidad de memoria permite crear para una determinada tarea una estructura de paginación independiente con su propio page directroy y sus distintas page tables.   
	- Para hacer el intercambio de tareas y manejar los cambios de contexto en el procesador se utilizo Taks Segment Descriptors (TSS), que es un mecanismo provisto por la arquitectura x86. Para esto se desarrollo un modulo para el manejo de tareas, el cual creaba las estructuras necesarias:las entradas en la GDT y sus correspondientes TSS. También se desarrollo un sheduler que intercambia las tareas según una estrategia "round robin", utilizando la interrupción de reloj del procesador para comandar la comutación de tareas.  


 -----------------------------
 ! Para compilar y ejecutar se requiere QEMU, NASM, GCC, GDB y python3.
 
* Para compilar y correr gdb 
```
make gdb
```
* Una vez en gdb establecer un breakpoin en kernel.asm y luego continue para ejecutar.
```
(gdb)continue
```
