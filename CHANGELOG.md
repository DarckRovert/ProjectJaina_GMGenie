# 📋 Registro de Cambios — ProjectJaina_GMGenie

Todos los cambios notables de este proyecto están documentados en este archivo siguiendo el estándar [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).

---

## [3.3.1-Sovereign] — 2026-11-22
### Corrección de StaticPopup, Minimapa trigonométrico y Comandos 3.3.5a (Hito #386)
- **Confirmación de Borrado de Objetos (`Spawns.lua`):**
  - Corregido desajuste de 3 placeholders `%s` en `StaticPopupDialogs["GMGENIE_CONFIRM_DELETE_OBJECT"]`, consolidando el texto a 2 argumentos con `"GUID: %s, ID: %s"` en `text_arg2`.
- **Posición Orbital del Minimapa (`GMGenie.lua`):**
  - Corregido error de grados vs radianes en `GMGenie.minimap.reposition()` aplicando `math.rad(GMGenie_SavedVars.minimapPos or 45)`.
- **Panel de Control & Tickets (`Tickets.lua`, `ControlPanel.lua`):**
  - Añadido alias `GMGenie.Tickets.Toggle = GMGenie.Tickets.toggle` con respaldo defensivo en `ControlPanel.lua`.
  - Corregido botón `"Nivel 80"` para resolver el nombre del objetivo o del propio GM y emitir sintaxis válida de JainaCore (`".character level " .. tName .. " 80"`).
  - Protegido `f:RegisterEvent("GET_ITEM_INFO_RECEIVED")` con `pcall` para compatibilidad estricta con WoW 3.3.5a.

---

## [3.3.0-Sovereign] — 2026-11-14
### Reingeniería de Comandos AzerothCore, Resiliencia Dual-Locale esES/enUS y Hitos #356-360
- **Comandos de Barra y Minimapa:**
  - Registrados formalmente `/gmgenie` y `/gmg` con soporte de subcomandos (`hud`, `tickets`, `spawns`, `spy`).
  - Botón del minimapa bifuncional: Clic Izquierdo abre el Panel de Control (`JainaGM`) y Clic Derecho alterna el HUD Overlay, con tooltip explicativo.
- **Sintaxis Canónica AzerothCore:**
  - Teletransporte con grupo corregido: envía `.tele <dest>` seguido de `.groupsummon` para evitar fallos de comando.
  - Corrección de `.npc del` a `.npc delete` y de `.list object/creature` a `.lookup object/creature` en `Spawns.lua`.
  - Corrección de `.mod speed all <val>` a `.modify speed <val>` en `Hud.lua`.
- **Integración con Sistemas de Servidor (Hitos #356, #358 y #360):**
  - **Rebobinado de Raid (`102_ResetPull_Command.lua`):** Incorporado el botón `.resetpull` en la Pestaña 3 para rebobinado limpio de wipes en 3 segundos (100% vida/maná, reset de CDs y sesión de Caja Negra).
  - **Baluartes Territoriales (`14_GuildOutposts_Engine.lua`):** Corregido el despacho de `.outpost <n>` a `.outpost tele <n>` en la Pestaña 5.
  - **Galeón de los Desertores (`15_LoreWorld_DeserterGalleon.lua`):** Vinculados los botones directos a `.galleon tele` (cubierta) y `.galleon ladder` (escala acuática).
  - **HeroBots de la Trinidad:** Incorporados Jaina, Varian, Thrall y Sylvanas a la Pestaña 4 con despacho canónico `.bot add / .bot remove`.
- **Resiliencia Dual-Locale (`esES` / `enUS`):**
  - Detección de mensajes del sistema para modo GM, vuelo, visibilidad y susurros compatible tanto con cliente español (`locale "esES"`) como inglés.
- **Portabilidad de Rutas de Texturas:**
  - Detección dinámica del directorio de texturas `TEXTURE_DIR` relativo al nombre de carpeta del AddOn.

---

## [3.2.0-Sovereign] — 2026-10-28
### Reemplazo de Icono Incompatible de Cataclysm por Arte Canónico WotLK 3.3.5
- **Iconografía y Arte de Interfaz (`ControlPanel.lua`):**
  - Sustituido el icono incompatible de Cataclysm (`spell_fire_soulburn`) en la pestaña WaniGM por la textura oficial canónica de Wrath of the Lich King 3.3.5a (`Spell_Holy_MagicalSentry`).
  - Eliminado el cuadrado verde/textura ausente en clientes sin parches de expansión superior.

---

## [3.1.0-Sovereign] — 2026-10-22
### Unificación de Staff Suite & Absorción de WaniGM (Project Jaina Soberano)
- **Absorción de WaniGM:** Integración nativa del Panel de Control de 5 pestañas (`ControlPanel.lua`) dentro de ProjectJaina_GMGenie, erradicando por completo la carpeta y dependencia externa de WaniGM.
- **Arte Facial Animado:** Incorporadas texturas de alta resolución de Jaina y Sylvanas con ciclo dinámico de parpadeo ocular en `Textures/`.
- **5 Pestañas Operativas:**
  - *General*: Estados GM (.gm on/off), vuelo, invisibilidad, chat y control deslizante de velocidad (1x a 20x).
  - *Tele*: Teletransporte a capitales y puntos clave con opción de arrastre de grupo y menú dinámico `.tele add/del`.
  - *Mundo 2.5*: Control en tiempo real de los 6 Baluartes (`.outpost`) y el Galeón de los Desertores.
  - *Items*: Spawner seguro por ItemEntry y buzón de correo GM rápido.
  - *Utils*: Escala de modelo, modificador visual de apariencias, alternancia PvP y terminal de comandos libre.
- **Reconexión de HUD:** Botón nativo en `Hud.xml` (`$parent_ControlPanel`) enlazado directamente a `GMGenie.ControlPanel.Toggle()`.
- **Comandos Slash Unificados:** Registrados `/gm`, `/jainagm`, `/staff`, `/control`, `/genie`, `/pjgm`, con alias de retrocompatibilidad pasiva para `/wgm` y `/wanigm`.
- **Persistencia Transparente:** Migración automática de `WaniGM_DB` a `JainaGM_DB` en WTF.

---

## [1.0.1] — 2026-10-10
### Estabilización de Ecosistema y Gobernanza Oficial (Project Jaina)
- **Normalización de UI y Gráficos:** Consolidación de nombre de AddOn oficial, eliminación de enlaces huérfanos y confirmación de exclusión en la distribución pública de jugadores.
- **Homologación Documental:** Incorporación y actualización formal de `GOVERNANCE.md`, `LICENSE`, `NOTICE.md` y `SECURITY.md`.
- **Licencia Canónica:** Consolidación de licencia MIT 2026 bajo titularidad de DarckRovert & Project Jaina Team.
- **Validación de Runtime:** Verificado al 100% con compilador sintáctico `lua52_compiler.exe -p` con 0 errores y 0 warnings.

---

## [1.0.0] — 2026-10-04
### Lanzamiento Inicial — Ecosistema Project Jaina WotLK 3.3.5a
- Implementación de la arquitectura base para Project Jaina GM Genie.
- Registro de comandos slash: `/genie, /gmgenie`.
- Persistencia de configuración en `GMGenieDB`.
- Compatibilidad certificada con cliente WotLK 3.3.5a (Build 12340) y directiva `Interface: 30300`.
