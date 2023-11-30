# Orga 2 Kernel

Respuestas ejercicios:  
- [x]  1)
 Necesitamos:
 - definir dos nuevas task gates en la GDT.
 - Generar dos nuevas TSS en memoria para las tareas, las cuales serán apuntadas por los descriptores de la GDT.
 - los esquemas de paginación de cada tarea, i.e. dos nuevos directorios y tablas de página, uno para cada tarea. Esto ocupará en total 4 páginas nuevas en el área libre del kernel. Cada tarea necesita dos páginas de solo lectura para código de nivel 3, una página para la pila de nivel 3, una página en el área libre del kernel para la pila de nivel 0.

- [x] 2) 
- El cambio de contexto se produce cuando una tarea es desalojada, al hacer un jmp far selector_de_segmento:00. En el taller el cambio de contexto es realizado por la interrupción de reloj. Al hacer el far jmp pasa lo siguiente:   
     * Se guarda en la TSS de la tarea actual el contexto de ejecución: registros de propósito general, ECFLAGS, registros de segmento y estado de la pila de nivel 0 y nivel 3. El TSS actual se obtiene a partir del selector de segmento guardado en TR, el cual apunta al task gate de la GDT que tiene la dirección base del TSS asociado a la tarea.   
     * Se reemplaza el TR actual por el de la tarea a cambiar. Luego de esto y a partir del selector de segmento, se busca en la GDT el descriptor de TSS de la tarea a la cual se va a cambiar, se busca su TSS para obtener el contexto de la tarea, el cual es restablecido automáticamente (gracias al mecanismo que nos provee INTEL) a partir de lo que encuentra en la TSS de la tarea.

- [x] 3)  
- Para hacer el primer cambio de contexto necesitamos una tarea inicial, la cual es un TSS Nulo, en el cual se almacena el estado del procesador cuando se hace el primer jmp far y dado que nunca volveremos a este contexto lo que se guarda en esta TSS inicial es "basura".
 - También definimos una tarea idle para cuando no hay tareas a ejecutar. Esta sería la tarea a la que "salta" el scheduler cuando no hay tareas para correr.

- [x] 4) 
- El scheduler del sistema operativo es el que gestiona las tareas que se están ejecutando y cuál será la próxima tarea a ejecutar a partir de su política de scheduling. En el taller el scheduler utiliza una política de tipo "Round Robin", alternando cíclicamente entre las tareas en cada interrupción de reloj.


- [x] 5) - Para que las tareas parezcan ejecutarse en simultáneo lo que se hace es darles un tiempo finito para ejecutarse (en nuestro caso establecido por la interrupción de reloj) y desalojarse, cambiando a otra tarea para volver luego en otro ciclo de ejecución, alternando entre ellas, de manera tal de que cada cierto intervalo de tiempo, todas las tareas se ejecutaron al menos una vez.


- [x] 11)       
   a) La interrupción de reloj hace lo siguiente: - Un pushadd que guarda los registros de propósito general de la tarea interrumpida en la pila de nivel 0 de la tarea.
       * un pic_finish1 que avisa al PIC que la interrupción fue atendida.   
       * Le pide al scheduler el selector de segmento de la próxima tarea a ejecutar.    
       * Chequea que la próxima tarea a ejecutar sea diferente de la actual.   
       * carga en [shed_task_selector] el selector de segmento de la próxima tarea.  
       * Se hace el far jmp a la próxima tarea, produciéndose un cambio de context.   
       * Cuando la tarea se restablezca se volvera a la interrupción de reloj luego del jmp far, luego de cual se hará un popad que restablece los registros de propósito general y un iret que restablecerá ecflags, cs:eip de la tarea.    
       b) el tamaño de ese dato es 48 bits, 16 bits del selector de segmento y 32 bits del offset. Debido al endianness el selector de segmento estará en shed_task_offset, ya que intel emplea little endian. El offset elegido no tiene ningún efecto, ya que será ignorado.   
       c) como se mencionó antes al restablecer el contexto de la tarea, iniciaremos en el contexto de la interrupción de reloj, el eip apuntará justo después del jmp far. Son el popad y el iret al final, los que restablecen el contexto que tenía la tarea antes de ser desalojada.     
 - [x] 14)    
      a) crea una una nueva TSS en memoria para una tarea de usuario y carga una nueva entrada en la GDT que apunta a dicho TSS.      
      b) El gdt_id es el índice dentro de la GDT, para convertirlo en un selector de segmento debemos shiftear, desplazando hacia la izquierda, agregando 3 bits nuevos que corresponden a los 3 bits menos significativos, que son los flags TI y RPL del selector de segmento, todos cero en nuestro caso.       
 - [x] 15)
      a) El área de memoria shared es un área de memoria del kernel que todas las tareas tienen mapeado y pueden leer, de esta manera el kernel puede comunicarse con las tareas.    
      b) Porque cada tarea tiene un mapeo de memoria diferentes.Si una tarea escribiera en su sección data podría estar escribiendo un área de memoria de otra tarea.    
  - [x] 16)   
      a) Este es el punto de entrada del kernel y no se puede hacer un ret, ya que no hay ningún lugar hacia donde retornar, con lo que se llama a task, que prepara la pantalla y luego se queda "loopeando" al final hasta que llega la interrupción de reloj y comienza a funcionar el scheduler.   
      b) se podría implementar un handler que nos permita finalizar.

- [x] 18) En el makefile las variables TASKA y TASKB apuntan al código de las tareas A y B a ejecutar en el sheduler.   

- [x] 19) Se escribe en el área de memoria ondemand, dicha dirección no está mapeada(page fault) y se pide al querer escribir, gracias al handler de interrupción que hicimos en el taller de paginación.  

 -----------------------------
* Para compilar y correr gdb 
```
make gdb
```
* Una vez en gdb establecer un breakpoin en kernel.asm y luego continue para ejecutar.
```
(gdb)continue
```