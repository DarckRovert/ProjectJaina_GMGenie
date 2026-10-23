# 📋 Registro de Cambios — ProjectJaina_GMGenie

Todos los cambios notables de este proyecto están documentados en este archivo siguiendo el estándar [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/).

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
