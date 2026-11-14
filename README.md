<p align="center">
  <img src="https://raw.githubusercontent.com/DarckRovert/ProjectJaina_Web/main/images/project_jaina_official_logo.jpg" alt="Project JAIna Official Crest" width="180">
</p>

# ❄️ Project Jaina — GMGenie

[![GitHub](https://img.shields.io/badge/GitHub-DarckRovert%2FProjectJaina_GMGenie-black?logo=github)](https://github.com/DarckRovert/ProjectJaina_GMGenie)

> **Project Jaina Ecosystem** · WotLK 3.3.5a compatible · `Interface: 30300`  
> Fork de [Game Master Genie](https://www.curse.com/addons/wow/game-master-genie) por Chocochaos — Adaptado para JainaCore/Project Jaina por DarckRovert

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--2.0-blue.svg)](LICENSE)

Suite completa de herramientas para **Game Masters** de Project Jaina sobre JainaCore. Combina múltiples paneles (tickets, spawns, HUD, disciplina, teleports) en una interfaz unificada diseñada para la gestión eficiente del servidor.

---

## Características
 
### Panel de Control JainaGM (Staff Suite Unificada)
- **Arte Facial Animado** — Retratos de alta resolución de Jaina y Sylvanas con ciclo realista de parpadeo ocular.
- **Pestaña General** — Estados de GM (.gm on/off), vuelo (.fly on/off), invisibilidad, chat y control deslizante de velocidad de movimiento (1x a 20x).
- **Pestaña Tele** — Teletransporte a capitales y enclaves clave con casilla de arrastre grupal de miembros de grupo y menú dinámico `.tele add/del`.
- **Pestaña Mundo 2.5 & Baluartes** — Control y teletransporte en tiempo real a los 6 Baluartes (`.outpost tele <1..6>`) y el Galeón de los Desertores (`.galleon tele` / `.galleon ladder`).
- **Pestaña Banda ICC & HeroBots** — Desbloqueo de puertas de ICC, invocación y control de la Tríada HeroBots (Lady Jaina, Rey Varian, Thrall, Reina Sylvanas), modo Inmortal de escuadrón y botón de Rebobinado de Wipe (`.resetpull` - Hito #356).
- **Pestaña Items** — Spawner protegido por ItemEntry y buzón de correo rápido para asistencia a jugadores.
- **Pestaña Utils** — Escala de personaje, modificaciones cosméticas de rol, alternancia PvP y terminal de comandos libre con auto-prefijo.

### Gestión de Tickets
- Visualización y respuesta a tickets de jugadores en tiempo real.
- Sistema de categorización y prioridades.

### Sistema de Spawns
- Panel de spawn de NPCs y objetos con coordenadas.
- Base de datos de spawns frecuentes.

### HUD de GM
- Overlay de información del GM visible con `.gm on` con botón de acceso directo `"JainaGM"`.
- Estado del servidor, jugadores online y accesos directos.

### Macros GM
- **Disciplina** — Macros de sanciones (warn, mute, ban).
- **Teleports** — Teletransporte rápido a zonas clave.
- **Mail** — Envío masivo de correos de anuncio.
- **Whispers** — Plantillas de respuesta rápida.

---

## Instalación

Solo para cuentas de Staff (GM Level >= 1) en servidores Project Jaina.

1. Instala ejecutando el script automático `AddOns_Staff\Instalar_AddOns_Staff_En_Cliente.bat` o copia la carpeta `ProjectJaina_GMGenie` a `Interface/AddOns/`.
2. Requiere nivel de Game Master para acceder a los paneles.

## 💻 Comandos de Barra (Slash Commands)

| Comando | Acción |
|---|---|
| `/jainagm`, `/staff`, `/control`, `/gm` | Alterna el Panel de Control JainaGM (5 pestañas). |
| `/gmgenie`, `/gmg` | Alterna la visualización del panel principal de GMGenie (Tickets y Spawns). |
| `/gmg hud` | Alterna la visualización del overlay HUD de GM. |
| `/gmg tickets` | Abre o enfoca el módulo de Tickets de GM. |
| `/gmg spawns` | Abre o enfoca el gestor de Spawns (NPCs y GameObjects). |
| `/gmg spy` | Abre el módulo de monitoreo e inspección Spy. |
| `/wgm`, `/wanigm` | Alias de compatibilidad retroactiva para el Panel de Control. |

## Botón de Minimapa Bifuncional

- **Click Izquierdo**: Alterna la apertura/cierre del Panel de Control JainaGM (`JainaGM`).
- **Click Derecho**: Alterna el HUD Overlay de estado del GM (`GMGenie_HudFrame`).
- **Tooltip**: Despliega atajos e información de estado al pasar el ratón.

## Variables Guardadas

- `GMGenie_SavedVars` — Configuración global, layouts de paneles, macros de tickets.
- `JainaGM_DB` — Estado persistente, pestaña activa, configuración de velocidad y teletransporte grupal.

## Estructura

```
GMGenie/
├── GMGenie.lua         # Core del addon y registro de slash commands
├── GMGenie.xml         # Frames principales y botón de minimapa
├── ControlPanel.lua    # Panel de Control JainaGM unificado (5 pestañas)
├── Hud.lua/.xml        # HUD overlay de estado
├── Tickets.lua/.xml    # Sistema de tickets alineado a AzerothCore
├── Spawns.lua/.xml     # Panel de spawns alineado a .gobject y .go gameobject
├── Spy.lua/.xml        # Monitor de chat e inspección de cuentas
├── Macros.*.lua        # Módulos de macros (Disciplina, Tele, Mail, Whispers)
├── Options/            # Paneles de configuración
├── Chronos/            # Librería de timers
└── Textures/           # Recursos gráficos (Jaina, Sylvanas, tabs)
```

## Créditos y Licencia

- **Autor original:** Chocochaos
- **Adaptación y Hardening Project Jaina:** DarckRovert (Elnazzareno) & Antigravity (Mythos 5)
- **Versión:** 3.3.0-Sovereign
- **Licencia:** [GNU General Public License v3.0](LICENSE)

---

## Documentación del Ecosistema

* [Ficha Técnica Oficial del Ecosistema](ECOSYSTEM_REGISTRY.md)
* [Historial de Cambios](CHANGELOG.md)
* [Aviso Legal y Atribución Upstream](NOTICE.md)
* [Texto Completo de la Licencia GPLv3](LICENSE)

---

*Parte del [ecosistema Project Jaina](https://github.com/DarckRovert)*
