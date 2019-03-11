# SurvivalDX
Plugin survival utilizado en los servidores de Imperium Sven Co-op.
## Que es esto?
No voy a mentirles. Siempre estube en contra de un servidor Survival por la malisima calidad que estas han tenido. Cansado de que el ciclo se repitiera he decidido romper la "meta" y creado MI estilo Survival. Lo que termino con resultados mucho mas positivos de lo que esperaba. Le he dedicado solo un poco de trabajo a este plugin, ya que en si es bastante sencillo.

Aunque admito que mi imaginacion siempre me hace planear metas completamente inalcanzables. Queria agregar un "Story Mode" al servidor y para esto necesitaria de un agregado extra, los "Items". Objetos, si asi lo deseas llamar. Hay remanentes de codigo de esta funcion y lo podras examinar, y se encuentra completamente funcional. Bueno, CASI funcional. Falta un poco de trabajo para poder finalizarse pero en si es utilizable. Debido a eso, solo un comando secreto de admin permite otorgar objetos.

De donde saque la idea? Bien, la idea del SurvivalDX lo tome por inspiracion y homenaje al clan de Killing Floor 1: **Last Bullet**. Su servidor eleva la dificultad normal del juego a niveles que nadie espera, lo que obliga a coordinarse y tener una destreza y habilidad de la cual... me enamore... **EXTRAÑABA JUGAR ASI CARAJO**.

Fue precisamente de ahi que saque la idea del *Mirror Friendly Fire*, aunque las dificultades y los "Perks" que se ven en el servidor son claramente un homenaje al Killing Floor 1 original. Lo unico que lamento fue no poder implementar el Perk "Firebug" del KF1, ya que esto era simplemente imposible. Bah, en realidad **ERA POSIBLE** pero era un excesivo trabajo, el codigo que demandaria hacer funcionar el Firebug seria mayor a todo el plugin en si, eso... no es realmente balanceado... Ademas, tendria otro problema, que armas dejarle a dicho Perk? Sven Co-op no tiene un amplio arsenal de armas a diferencia del KF1.

En cambio a los objetos y su objetivo a largo plazo: Bueno, si lees los nombres de los items notaras que vienen de...

...Pokémon.

Si... mejor no preguntes.

Toda la forma en que este survival modifica el juego hizo que el proyecto Survival DeluXe -*Abreviado SDX*- sea finalmente un servidor survival el cual disfrute trabajar. Su codigo lo veo bien escrito, aunque puede ser mejor, ahora que tu podras mejorarlo, verdad?

PEROOO... Por lastima, este plugin tiene nuevamente el problema del contenido mixto, de usar tanto AngelScript como AMX Mod X para que funcione... Do'h!
## Porque mezclar tanto AngelScript como AMX Mod X para este sistema?
AngelScript carece de ciertas utilidades especificas que solo el AMX Mod X tiene. Con el paso del tiempo AngelScript fue mejorando sus capacidades, pero decidi dejar algunas funciones en AMXX para evitar inconvenientes. No obstante, el AngelScript aun esta muy lejos de reemplazar al AMXX por completo. El mas primordial ejemplo es la posibilidad de hookear cualquier funcion de cualquier entidad, algo completamente inexistente en AngelScript. Estos hooks son de suma importancia para el plugin principal, ya que son lo que le da **VIDA** a la utilidad de los Perks, en adicion a la **UNICA MANERA** de poder subir de nivel los Perks por estas funciones especificas que el AngelScript no tiene. Aguante el modulo HAM!

Esto lleva a un segundo problema, como puedes ver, estoy utilizando el modulo *HamSandwich* del AMXX para hacer estos hooks, las cuales requieren que sus funciones esten especificados y actualizados en el archivo de configuracion **hamdata.ini**. El unico problema con esto es que dicho archivo debia actualizarse constantemente, ya que cada actualizacion del Sven Co-op que los desarrolladores hagan, implicaba que alguno de esos numeros se cambiasen. Intentar detectar esto de manera manual por AngelScript es... No. Como diablos quieres que lo haga? Como detecto cuanto daño recibe CADA monstruo que el mapa tiene? Aun si existiesen metodos serian asquerosamente ineficientes! No quiero perjudicar el rendimiento del servidor solo por un detalle!

Y finalmente tercer y ultimo problema, si intentase dejar todo en AMXX.
................................................................................................................................

No creo que alcanzen los puntos suspensivos para explicar que simplemente no es posible, el trabajo sencillamente no lo vale.
## Archivos del proyecto
Este proyecto se maneja con los siguientes archivos:

1. **SDX_Main.as**
   - Este es el plugin principal. La mayoria de su codigo se encuentra aqui pero no es el total, si los plugins adicionales no pueden correr, el SDX tendra una funcionabilidad muy limitada o bien puede directamente no funcionar.
2. **SDX_Helper.sma**
   - Este plugin auxiliar complementa el resto del codigo faltante del plugin principal. Con este plugin y el principal, el SDX puede ejecutarse al maximo de su potencial.
3. **SDX_Checkpoint.as**
   - Entidad point_checkpoint. Si bien pueden utlizarse los CheckPoints que ya vienen en los mapas por defecto. Este script editado esta ajustado para su acompañamiento con el plugin principal. Ajustable segun dificultad, hitbox reducido, configuraciones adicionales, y notificacion de quien agarra estos CheckPoints. El uso de este plugin es altamente recomendado.

Encontraras archivos y carpetas adicionales de configuracion en la carpeta **src/SDX** de este repositorio. Sus propositos e instructivos se encuentran en el interior de dichas carpetas.
## Una nota sobre los archivos
El proyecto solamente contendra el codigo fuente, no provere de los sonidos/models/sprites o cualquier otro archivo adicional que el proyecto utiliza en su codigo. Y solicito que por favor se mantenga asi, aunque estoy abierto a negociar esta regla.

Si decides compilar y utilizar los codigos para tu propio uso tendras que inventar sus propios archivos adicionales que el proyecto utilize, o bien desactivarlos por completo.
## Instrucciones de compilacion/instalacion
La compilacion de los diferentes archivos del proyecto se realizan de tarea manual con los siguientes pasos:

### Plugins AngelScript (Extension .as):
Para compilar estos plugins solo basta con subir los nuevos archivos al servidor, cuya ubicacion es **svencoop/scripts/plugins**. Hecho eso se debe editar el archivo **default_plugins.txt** ubicado en la carpeta **svencoop** BASE. Y agregar nuestro plugin a la lista, esto solo se hace una vez, y esta nueva entrada en la lista se debe ver de la siguiente manera:

```
"plugin"
{
  "name" "SurvivalDX"
  "script" "SDX_Main"
}
```

Finalmente, vamos a la consola del servidor y escribimos el comando **as_reloadplugin "SurvivalDX"** para recompilar el plugin. -*Es posible que sea necesario cambiar el mapa para que la compilacion se lleve a cabo*-.

Dare enfasis a las palabras **consola del servidor**, si estas usando un dedicado escribir los comandos "asinomas" no tendra efecto alguno, deberas escribir los comandos desde **RCON** para que sean enviados al servidor.

Si la compilacion falla, los errores seran mostrados en la consola o bien en los logs del servidor, ubicado en **svencoop/logs/Angelscript** para su facil acceso.

**_IMPORTANTE_**
El proyecto no guardara ningun dato inicialmente hasta que su carpeta de almacenamiento este creada y haya acceso de lectura/escritura en ella. Ve a la carpeta **svencoop/scripts/plugins/store** y crea el siguiente directorio cuyo proposito es el siguiente:

- **sdx_plrdata**: Niveles, Perks, y otros datos de los jugadores. De suma importancia para el plugin principal.

Buscas los registros? El SDX imprime los sucesos directo a los logs del servidor. Solo ve a **svencoop/logs** y examina segun fecha. Todo registro perteneciente al plugin tendra el prefijo **[SDX]** para su facil ubicacion.

### Plugins AMXX (Extension .sma):
El codigo de estos plugins fue escrito en AMXX 1.8.3 (Ahora 1.9). Debes descargar/instalar esas versiones experimentales del AMXX para poder compilarlos.

Hecho eso, copiamos nuestro archivo .sma a **addons/amxmodx/scripting**. Ahora, debemos ejecutar una linea de comandos en el simbolo de sistema. Asegurate que la terminal este apuntando al directorio mencionado anteriormente y ejecuta el siguiente comando: **amxxpc.exe SDX_Helper.sma**. Si la compilacion es existosa, el programa creara su fichero compilado con extension **.amxx**. Este nuevo archivo es subido al servidor, en **addons/amxmodx/plugins**. Finalmente agregamos estos nuevos plugins a la lista de plugins AMXX, cuyo archivo de configuracion **plugins.ini** se encuentra en **addons/amxmodx/config**. Solo nos vamos al final del fichero y agregamos una linea, que sera SDX_Helper.amxx. Hecho! Si queremos recompilar los plugins solo modificamos el archivo .sma, compilamos y copiamos el nuevo archivo .amxx al servidor. -*Todos los cambios que realizemos solo tomaran efecto al cambiar de mapa*-.

Si no queremos utilizar el simbolo del sistema puedes crear un archivo **.bat** para simplificar la tarea. Que puede armarse de la manera siguiente: Crea un archivo .bat en **addons/amxmodx/scripting**, edita su contenido y agrega las siguientes lineas:

```
@echo off
amxxpc.exe SDX_Helper.sma
pause
```

Cuando quieras recompilar los plugins, copia los nuevos .sma a la carpeta, ejecuta el .bat, y si la compilacion es exitosa tendras tus nuevos .amxx para utilizar.

Lamentablemente si las compilaciones fallan, estos no son exportados a un archivo .log el cual poder inspeccionar, deberas leer la ventana de la terminal para identificar y corregir fallos que se presenten. No obstante, si tienes buen conocimiento de los archivos .bat puedes editar las lineas y exportar manualmente el proceso de compilacion a un archivo para que sus errores sean legibles ahi.
# Finalizando
Un proyecto survival que seguramente te sorprenda con la delicadeza de todo lo que realmente hace a la jugabilidad. Codigo libre, mi amigo! Utiliza, modifica, aprende! Si quieres ayudarme y mejorar el codigo, no dudes en hacerlo.

Good luck, and have fun!
