# Orga 2 Kernel

* Para compilar y correr gdb 
```
make gdb
```
* Una vez en gdb establecer un breakpoin en kernel.asm y luego continue para ejecutar.
```
(gdb)continue
```
- [x] Inciar modo real y hacer el far jump para habilitar protección
      - completando la GDT  
      - habilitar protección seteando el bit menos sig. de CR0  
      - hacer el jmp far al segmento de código de nivel cero en el offset de la etiqueta modo_protegido  
- [x] Iniciar modo protegido:  
      - luego de hacer el far jump cargamos en los registros de segmento el selector de segmento de datos de nivel 0. 
      - Setear el tope y la base de la pila en la dir 0x25000.
      - imprimir el mensaje "Iniciando modo protegido"

