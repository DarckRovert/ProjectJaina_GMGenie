# ❄️ Project Jaina — GMGenie

[![GitHub](https://img.shields.io/badge/GitHub-DarckRovert%2FProjectJaina_GMGenie-black?logo=github)](https://github.com/DarckRovert/ProjectJaina_GMGenie)

> **Project Jaina Ecosystem** · WotLK 3.3.5a compatible · `Interface: 30300`  
> Fork de [Game Master Genie](https://www.curse.com/addons/wow/game-master-genie) por Chocochaos — Adaptado para JainaCore/Project Jaina por DarckRovert

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)

Suite completa de herramientas para **Game Masters** de Project Jaina sobre JainaCore. Combina múltiples paneles (tickets, spawns, HUD, disciplina, teleports) en una interfaz unificada diseñada para la gestión eficiente del servidor.

---

## Características
 
### Panel de Control JainaGM (Staff Suite Unificada)
- **Arte Facial Animado** — Retratos de alta resolución de Jaina y Sylvanas con ciclo realista de parpadeo ocular.
- **Pestaña General** — Estados de GM (.gm on/off), vuelo (.fly on/off), invisibilidad, chat y control deslizante de velocidad de movimiento (1x a 20x).
- **Pestaña Tele** — Teletransporte a capitales y enclaves clave con casilla de arrastre grupal de miembros de grupo y menú dinámico `.tele add/del`.
- **Pestaña Mundo 2.5** — Control y teletransporte en tiempo real a los 6 Baluartes (`.outpost`) y el Galeón de los Desertores.
- **Pestaña Items** — Spawner protegido por ItemEntry y buzón de correo rápido para asistencia a jugadores.
- **Pestaña Utils** — Escala de personaje, modificaciones cosméticas de rol, alternancia PvP y terminal de comandos libre.

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
| `/wgm`, `/wanigm` | Alias de compatibilidad retroactiva para el Panel de Control. |

## Variables Guardadas

- `GMGenie_SavedVars` — Configuración global, layouts de paneles, macros de tickets.
- `JainaGM_DB` — Estado persistente, pestaña activa, configuración de velocidad y teletransporte grupal.

## Estructura

```
GMGenie/
├── GMGenie.lua         # Core del addon
├── GMGenie.xml         # Frames principales
├── Hud.lua/.xml        # HUD overlay
├── Tickets.lua/.xml    # Sistema de tickets
├── Spawns.lua/.xml     # Panel de spawns
├── Spy.lua/.xml        # Monitor de chat
├── Macros.*.lua        # Módulos de macros
├── Options/            # Paneles de configuración
├── Chronos/            # Librería de timers
└── Textures/           # Recursos gráficos
```

## Créditos y Licencia

- **Autor original:** Chocochaos
- **Adaptación y Hardening Project Jaina:** DarckRovert (Elnazzareno) & Antigravity (Mythos 5)
- **Versión:** 1.3.1
- **Licencia:** [GNU General Public License v3.0](LICENSE)

---

## Documentación del Ecosistema

* [Ficha Técnica Oficial del Ecosistema](ECOSYSTEM_REGISTRY.md)
* [Historial de Cambios](CHANGELOG.md)
* [Aviso Legal y Atribución Upstream](NOTICE.md)
* [Texto Completo de la Licencia GPLv3](LICENSE)

---

*Parte del [ecosistema Project Jaina](https://github.com/DarckRovert)*
