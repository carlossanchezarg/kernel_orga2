/* ** por compatibilidad se omiten tildes **
================================================================================
 TRABAJO PRACTICO 3 - System Programming - ORGANIZACION DE COMPUTADOR II - FCEN
================================================================================

  Definicion de funciones del manejador de memoria
*/

#include "mmu.h"
#include "i386.h"

#include "kassert.h"

// Esta página la usan las tareas para comunicarse con el kernel.
#define PAGINA_COMPARTIDA_KERNEL_USER 0x0001D000

static pd_entry_t* kpd = (pd_entry_t*)KERNEL_PAGE_DIR;
static pt_entry_t* kpt = (pt_entry_t*)KERNEL_PAGE_TABLE_0;

static const uint32_t identity_mapping_end = 0x003FFFFF;
static const uint32_t user_memory_pool_end = 0x02FFFFFF;

static paddr_t next_free_kernel_page = 0x100000;
static paddr_t next_free_user_page = 0x400000;

/**
 * kmemset asigna el valor c a un rango de memoria interpretado
 * como un rango de bytes de largo n que comienza en s
 * @param s es el puntero al comienzo del rango de memoria
 * @param c es el valor a asignar en cada byte de s[0..n-1]
 * @param n es el tamaño en bytes a asignar
 * @return devuelve el puntero al rango modificado (alias de s)
*/
static inline void* kmemset(void* s, int c, size_t n) {
  uint8_t* dst = (uint8_t*)s;
  for (size_t i = 0; i < n; i++) {
    dst[i] = c;
  }
  return dst;
}

/**
 * zero_page limpia el contenido de una página que comienza en addr
 * @param addr es la dirección del comienzo de la página a limpiar
*/
static inline void zero_page(paddr_t addr) {
  kmemset((void*)addr, 0x00, PAGE_SIZE);
}


void mmu_init(void) {}


/**
 * mmu_next_free_kernel_page devuelve la dirección física de la próxima página de kernel disponible. 
 * Las páginas se obtienen en forma incremental, siendo la primera: next_free_kernel_page
 * @return devuelve la dirección de memoria de comienzo de la próxima página libre de kernel
 */
paddr_t mmu_next_free_kernel_page(void) {
  paddr_t paginaLibre = next_free_kernel_page;
  next_free_kernel_page += PAGE_SIZE;
  return paginaLibre;
}

/**
 * mmu_next_free_user_page devuelve la dirección de la próxima página de usuarix disponible
 * @return devuelve la dirección de memoria de comienzo de la próxima página libre de usuarix
 */
paddr_t mmu_next_free_user_page(void) {
   paddr_t paginaLibre = next_free_user_page;
  next_free_user_page += PAGE_SIZE;
  return paginaLibre;
}

/**
 * mmu_init_kernel_dir inicializa las estructuras de paginación vinculadas al kernel y
 * realiza el identity mapping
 * @return devuelve la dirección de memoria de la página donde se encuentra el directorio
 * de páginas usado por el kernel
 */
paddr_t mmu_init_kernel_dir(void) {
   // Limpiar el Directorio de Tablas de Paginas
  // la funcion recibe la direccion fisica del DTP y limpia una pagina
  zero_page((paddr_t) kpd); 
  // Limpiar la Tabla de Paginas
  // la funcion recibe la direccion fisica de la PT y limpia una pagina
  zero_page((paddr_t) kpt);   

  // Completar la 1ra entrada del DTP
  kpd[0] = (pd_entry_t) {
    // Los 20 bits mas significativos de la direccion fisica de la TP  
    .pt = ((paddr_t) kpt) >> 12,
    // Atributos: 0000000 | Supervisor:0 | ReadWrite:1 | Present:1
    .attrs = MMU_W | MMU_P 
  };

  // Completar la Tabla de paginas
  for(int i=0; i<1024; i++){
    // Los 20 bits mas significativos de la direccion fisica de la pagina 
    // |  20 bits |12 bits| 
    kpt[i].page = i;
    // Atributos: 0000000 | Supervisor:0 | ReadWrite:1 | Present:1
    kpt[i].attrs = MMU_W | MMU_P;
  }

  // devolver la direccion fisica del DTP
  return ((paddr_t) kpd);


}

/**
 * mmu_map_page agrega las entradas necesarias a las estructuras de paginación de modo de que
 * la dirección virtual virt se traduzca en la dirección física phy con los atributos definidos en attrs
 * @param cr3 el contenido que se ha de cargar en un registro CR3 al realizar la traducción
 * @param virt la dirección virtual que se ha de traducir en phy
 * @param phy la dirección física que debe ser accedida (dirección de destino)
 * @param attrs los atributos a asignar en la entrada de la tabla de páginas
 */
void mmu_map_page(uint32_t cr3, vaddr_t virt, paddr_t phy, uint32_t attrs) {
  uint32_t idx_pdt = VIRT_PAGE_DIR(virt);
  uint32_t idx_pte = VIRT_PAGE_TABLE(virt);

  pd_entry_t* PD = (pd_entry_t*)(CR3_TO_PAGE_DIR(cr3));
  pd_entry_t pde = PD[idx_pdt];

  if(!(pde.attrs & MMU_P)){
    paddr_t pt_new = mmu_next_free_kernel_page();
    zero_page(pt_new);

    PD[idx_pdt].pt = ((uint32_t) pt_new)>>12;
  }

  PD[idx_pdt].attrs |= attrs | MMU_P;

  pt_entry_t* PT = (pt_entry_t*)(PD[idx_pdt].pt << 12);
  PT[idx_pte].attrs = attrs | MMU_P;
  PT[idx_pte].page = phy>>12;

  tlbflush();
}
 

/**
 * mmu_unmap_page elimina la entrada vinculada a la dirección virt en la tabla de páginas correspondiente
 * @param virt la dirección virtual que se ha de desvincular
 * @return la dirección física de la página desvinculada
 */
paddr_t mmu_unmap_page(uint32_t cr3, vaddr_t virt) {
  uint32_t idx_pdt = VIRT_PAGE_DIR(virt);
  uint32_t idx_pte = VIRT_PAGE_TABLE(virt);

  pd_entry_t* PD = (pd_entry_t*)(CR3_TO_PAGE_DIR(cr3));
  pt_entry_t* PT = (pt_entry_t*)(PD[idx_pdt].pt << 12);

  paddr_t phy = MMU_ENTRY_PADDR(PT[idx_pte].page);

  PT[idx_pte].attrs = ~ MMU_P;

  tlbflush();

  return phy;
}

#define DST_VIRT_PAGE 0xA00000
#define SRC_VIRT_PAGE 0xB00000

/**
 * copy_page copia el contenido de la página física localizada en la dirección src_addr a la página física ubicada en dst_addr
 * @param dst_addr la dirección a cuya página queremos copiar el contenido
 * @param src_addr la dirección de la página cuyo contenido queremos copiar
 *
 * Esta función mapea ambas páginas a las direcciones SRC_VIRT_PAGE y DST_VIRT_PAGE, respectivamente, realiza
 * la copia y luego desmapea las páginas. Usar la función rcr3 definida en i386.h para obtener el cr3 actual
 */
void copy_page(paddr_t dst_addr, paddr_t src_addr) {
  mmu_map_page(rcr3(), (vaddr_t)DST_VIRT_PAGE, dst_addr, MMU_W | MMU_P);
  mmu_map_page(rcr3(), (vaddr_t)SRC_VIRT_PAGE, src_addr, MMU_W | MMU_P);

  //puntero a primer byte
  uint8_t* dest = (uint8_t*) (DST_VIRT_PAGE);
  uint8_t* src = (uint8_t*) (SRC_VIRT_PAGE);

  //copiamos de a un byte
  for(size_t i=0; i < PAGE_SIZE; i++){
    dest[i] = src[i];
  }

  //desmapear
  mmu_unmap_page(rcr3(), DST_VIRT_PAGE);
  mmu_unmap_page(rcr3(), SRC_VIRT_PAGE);
}




 /**
 * mmu_init_task_dir inicializa las estructuras de paginación vinculadas a una tarea cuyo código se encuentra en la dirección phy_start
 * @pararm phy_start es la dirección donde comienzan las dos páginas de código de la tarea asociada a esta llamada
 * @return el contenido que se ha de cargar en un registro CR3 para la tarea asociada a esta llamada
 */
paddr_t mmu_init_task_dir(paddr_t phy_start) {
   // nuevo page directory en el kernel
  paddr_t cr3 = mmu_next_free_kernel_page();
  zero_page(cr3);

  //pedimos pagina nueva al area libre del kernel para una page table
  paddr_t addr_task_PT = (paddr_t) mmu_next_free_kernel_page();
  zero_page(addr_task_PT);

  pd_entry_t* task_PD = (pd_entry_t*) cr3;

  //en el task page directory se carga la direccion de la page table
  // y se le asigna permiso de r/w
  task_PD[0].pt = (addr_task_PT >> 12);
  task_PD->attrs = MMU_W | MMU_P;

  pt_entry_t* task_PT = (pt_entry_t*) addr_task_PT;

  // Crear las paginas dentro de la task PT ¿para el kernel?
  for(int i=0; i<1024; i++){
    // Los 20 bits mas significativos de la direccion fisica de la pagina
    task_PT[i].page = i;
    // Atributos: 0000000 | Supervisor:0 | ReadWrite:1 | Present:1
    task_PT[i].attrs = MMU_W | MMU_P;
  }

  // Mapear 2 paginas de codigo TASK_CODE_VIRTUAL -> phy_start
  // Atributos: 0000000 | User:1 | Read:0 | Present:1
  mmu_map_page(cr3, (vaddr_t) TASK_CODE_VIRTUAL, phy_start, MMU_U | MMU_P);
  mmu_map_page(cr3, (vaddr_t) TASK_CODE_VIRTUAL + PAGE_SIZE, phy_start + PAGE_SIZE, MMU_U |  MMU_P);

  // Mapear el stack de la tarea en la proxima pagina libre de usuario
  // Atributos: 0000000 | User:1 | ReadWrite:1 | Present:1
  mmu_map_page(cr3, (vaddr_t) (TASK_STACK_BASE - PAGE_SIZE), mmu_next_free_user_page(), MMU_U | MMU_W | MMU_P);

  // Mapear una pagina de memoria compartida TASK_SHARED_PAGE -->shared
  // Atributos: 0000000 | User:1 | Read:0 | Present:1
  mmu_map_page(cr3, (vaddr_t) TASK_SHARED_PAGE, PAGINA_COMPARTIDA_KERNEL_USER, MMU_U|MMU_W|MMU_P);

  return cr3;

}

// COMPLETAR: devuelve true si se atendió el page fault y puede continuar la ejecución 
// y false si no se pudo atender
bool page_fault_handler(vaddr_t virt) {

  print("Atendiendo page fault...", 0, 0, C_FG_WHITE | C_BG_BLACK);
  // Chequeemos si el acceso fue dentro del area on-demand
  // En caso de que si, mapear la pagina
  //Chequear que esta en el rango on demand
}
